/**
 * AefKernel -- the AEF v0 pipeline (Section 3):
 *
 *   ExecutionRequest -> Identity Resolution -> Contract Validation ->
 *   Policy Evaluation -> Human Gate -> Idempotency ->
 *   Controlled Tool Registry -> Mock Execution -> Execution Receipt ->
 *   Verification State.
 *
 * Every exit point returns a KernelResult with a real, schema-valid
 * ExecutionReceipt (Section 21) -- there is no path that silently drops a
 * processed attempt without a record, and no path that reports SUCCESS
 * without a tool actually having run.
 *
 * NO_DIRECT_EXECUTION_FALLBACK (Section 23): if any dependency required
 * for governance is unavailable or misconfigured (identity backend down,
 * unknown tool, policy cannot be evaluated), this kernel denies. It never
 * has a code path that lets a caller bypass governance and execute
 * directly -- there is no `execute()`/`run()` export from this module
 * that skips the pipeline (see kernel_test.ts's negative-space test,
 * mirroring contracts/aef/NO_DIRECT_EXECUTION.md's own pattern).
 */
import { validateDelegationEnvelope, validateExecutionRequest, validateRequestAgainstDelegation } from "../contracts/aef/validators.ts";
import type { Actor, DelegationEnvelope, ExecutionRequest, NonceStore, RequestIdStore } from "../contracts/aef/types.ts";
import { checkSubjectBinding } from "./delegation_binding.ts";
import { evaluateHumanGate } from "./human_gate_evaluator.ts";
import { InMemoryIdempotencyStore, IdempotencyGuard } from "./idempotency_guard.ts";
import { evaluatePolicy } from "./policy_evaluator.ts";
import {
  buildAuthFailed,
  buildDenied,
  buildDuplicateNoPriorResult,
  buildFailure,
  buildHumanReviewRequired,
  buildInvalid,
  buildSuccess,
  tagAsDuplicate,
} from "./receipt_builder.ts";
import { ToolRegistry } from "./tool_registry.ts";
import type { DelegationResolver, HumanGateResolver, IdentityResolver, KernelResult, RawCredential } from "./types.ts";

const UUID_V4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ACTION_RE = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/;
const FALLBACK_INVALID_ACTION = "internal.invalid_request";
/** Never a real identity. Used ONLY as a receipt/audit placeholder when the submitted actor is too malformed to even describe -- policy_decision is always DENIED whenever this appears, so it never implies anything was trusted. */
const UNVERIFIED_UNKNOWN_ACTOR: Actor = { type: "user", id: "unknown", auth_ref: "usr:unresolved-actor" };

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function safeRequestId(raw: unknown): string {
  return typeof raw === "string" && UUID_V4_RE.test(raw) ? raw : crypto.randomUUID();
}

function safeAction(raw: unknown): string {
  return typeof raw === "string" && ACTION_RE.test(raw) ? raw : FALLBACK_INVALID_ACTION;
}

function safeActorForReceipt(raw: unknown): Actor {
  if (isRecord(raw) && typeof raw.type === "string" && typeof raw.id === "string" && typeof raw.auth_ref === "string") {
    return raw as unknown as Actor; // best-effort audit passthrough only -- NEVER implies verification.
  }
  return UNVERIFIED_UNKNOWN_ACTOR;
}

export interface AefKernelDeps {
  identityResolver: IdentityResolver;
  delegationResolver: DelegationResolver;
  humanGateResolver: HumanGateResolver;
  toolRegistry: ToolRegistry;
  requestIdStore: RequestIdStore;
  /** Authentication-replay defense for DelegationEnvelope.nonce (Section 9/29 test #24) -- shared across submit() calls so a nonce reused across two different delegations is caught, exactly mirroring contracts/aef's own NonceStore usage pattern. */
  nonceStore: NonceStore;
  idempotencyStore: InMemoryIdempotencyStore;
  /** Injectable clock for deterministic tests. Defaults to real time. */
  now?: () => Date;
}

export class AefKernel {
  private readonly idempotencyGuard: IdempotencyGuard;

  constructor(private readonly deps: AefKernelDeps) {
    this.idempotencyGuard = new IdempotencyGuard(deps.requestIdStore, deps.idempotencyStore);
  }

  private now(): Date {
    return this.deps.now ? this.deps.now() : new Date();
  }

  /**
   * `rawRequest` is deliberately `unknown`, not `ExecutionRequest` --
   * this is the actual trust boundary a real caller crosses, and it must
   * survive arbitrary garbage without throwing (Section 6/23 fail-closed
   * requirement: "Nunca... [throw]", every input produces a KernelResult).
   */
  async submit(rawRequest: unknown, credential: RawCredential): Promise<KernelResult> {
    const startedAt = this.now();
    const rawActor = isRecord(rawRequest) ? rawRequest.actor : undefined;
    const receiptRequestId = safeRequestId(isRecord(rawRequest) ? rawRequest.request_id : undefined);
    const receiptAction = safeAction(isRecord(rawRequest) ? rawRequest.action : undefined);
    const fallbackActorForReceipt = safeActorForReceipt(rawActor);

    const paramsWith = (actorForReceipt: Actor, extra: { humanGateRef?: string | null; tool?: string | null; completedAt?: Date } = {}) => ({
      request: { request_id: receiptRequestId, action: receiptAction } as ExecutionRequest,
      actorForReceipt,
      startedAt,
      ...extra,
    });

    // -----------------------------------------------------------------
    // Step 1: Identity Resolution (Section 3/7). Runs BEFORE full
    // contract validation, per the mission's stated pipeline order --
    // this is safe because AefIdentityResolver independently re-checks
    // actor shape itself and never throws on malformed input.
    // -----------------------------------------------------------------
    let identity;
    try {
      identity = await this.deps.identityResolver.resolve(rawActor as Actor, credential);
    } catch (err) {
      // Section 29 test #30 (identity failure) / Section 23 fail-closed:
      // an IdentityResolver must not throw per its own interface contract,
      // but the kernel does not trust that promise blindly -- a resolver
      // regression must still fail closed, never crash into an
      // unhandled rejection that some caller might mistake for "proceed."
      return buildAuthFailed(paramsWith(fallbackActorForReceipt), `identity resolver threw unexpectedly: ${String(err)}`);
    }
    if (identity.status !== "VERIFIED") {
      return buildAuthFailed(paramsWith(fallbackActorForReceipt), `identity resolution status=${identity.status}: ${identity.reason}`);
    }
    const verifiedActorForReceipt: Actor = { type: "user", id: identity.verifiedId, auth_ref: (rawActor as Actor).auth_ref };

    // -----------------------------------------------------------------
    // Step 2: Contract Validation (Section 3/6) -- full ExecutionRequest
    // schema + PROHIBITED_AUTHORITY_FIELDS scan. Deliberately does NOT
    // pass a requestIdStore here: request-replay defense is deferred to
    // the Idempotency step (Section 19/20's own stated pipeline
    // position), so a request denied here never burns its request_id.
    // -----------------------------------------------------------------
    const contractCheck = validateExecutionRequest(rawRequest, { now: startedAt });
    if (!contractCheck.ok) {
      return buildInvalid(paramsWith(verifiedActorForReceipt), contractCheck.errors.join("; "));
    }
    const request = rawRequest as ExecutionRequest;
    // From here on, request.request_id/action are contract-valid -- use
    // them directly instead of the pre-validation safe-fallback values.
    const params = (extra: { humanGateRef?: string | null; tool?: string | null; completedAt?: Date } = {}) => ({
      request,
      actorForReceipt: verifiedActorForReceipt,
      startedAt,
      ...extra,
    });

    // -----------------------------------------------------------------
    // Step 2b: Delegation validation (Section 8), only if declared.
    // -----------------------------------------------------------------
    if (request.delegation_ref) {
      const delegationOutcome = await this.checkDelegation(request, identity.verifiedId);
      if (delegationOutcome) return delegationOutcome;
    }

    // -----------------------------------------------------------------
    // Step 3: Tool lookup (feeds classification into Policy Evaluation).
    // Unknown tool/action -> DENY, no dynamic selection (Section 17).
    // -----------------------------------------------------------------
    const tool = this.deps.toolRegistry.lookup(request);
    if (!tool) {
      return buildDenied(params(), `unknown tool/action '${request.domain}::${request.action}' -- no dynamic tool selection permitted (Section 17)`);
    }

    // -----------------------------------------------------------------
    // Step 4: Policy Evaluation (Section 3/13/14) -- deterministic code,
    // includes the hard, unconditional Quant/Impact domain boundary.
    // -----------------------------------------------------------------
    let policy;
    try {
      policy = evaluatePolicy(request, tool);
    } catch (err) {
      // Section 29 test #14 (policy unavailable) / Section 23 fail-closed:
      // policy evaluation is pure, deterministic, in-process code with no
      // I/O, so it structurally cannot be "down" the way an external
      // service could be -- but a defensive/malformed ToolDefinition
      // (e.g. a corrupt registration) must still deny, never silently
      // default to ALLOW just because the evaluator itself broke.
      return buildDenied(params(), `policy evaluation unavailable: ${String(err)}`);
    }
    if (policy.decision === "DENY") {
      return buildDenied(params(), policy.reason);
    }

    // -----------------------------------------------------------------
    // Step 5: Human Gate (Section 3/16), only when policy requires it.
    // -----------------------------------------------------------------
    if (policy.decision === "REQUIRE_HUMAN_REVIEW") {
      const gate = evaluateHumanGate(request, this.deps.humanGateResolver, startedAt);
      if (gate.decision !== "ALLOW") {
        return buildHumanReviewRequired(params({ humanGateRef: request.human_gate_ref ?? null }), gate.reason);
      }
    }

    // -----------------------------------------------------------------
    // Step 6: Idempotency (Section 3/19/20) -- right before real
    // execution, so a denied/gated request never consumes replay state.
    // -----------------------------------------------------------------
    const claim = this.idempotencyGuard.checkBeforeExecution(request);
    if (claim.status === "COMPLETED") return tagAsDuplicate(claim.result);
    if (claim.status === "IN_FLIGHT") {
      return buildDuplicateNoPriorResult(params(), "an identical idempotency_key is currently being processed by a concurrent request");
    }
    if (claim.status === "REQUEST_ID_REPLAYED") {
      return buildDuplicateNoPriorResult(params(), `request_id '${request.request_id}' has already been processed`);
    }

    // -----------------------------------------------------------------
    // Step 7: Controlled Tool Registry execution (Section 3/17/18) --
    // SAFE MOCK TOOLS ONLY. Step 8/9: Execution Receipt + Verification
    // State (Section 21/22) are produced by receipt_builder.ts.
    // -----------------------------------------------------------------
    let finalResult: KernelResult;
    try {
      const toolResult = await tool.execute(request);
      const completedAt = this.now();
      finalResult = toolResult.outcome === "SUCCESS"
        ? buildSuccess(params({ tool: tool.toolId, humanGateRef: request.human_gate_ref ?? null, completedAt }), toolResult.detail)
        : buildFailure(params({ tool: tool.toolId, humanGateRef: request.human_gate_ref ?? null, completedAt }), toolResult.detail);
    } catch (err) {
      this.idempotencyGuard.releaseOnTechnicalFailure(request);
      finalResult = buildFailure(params({ tool: tool.toolId, humanGateRef: request.human_gate_ref ?? null, completedAt: this.now() }), `tool threw unexpectedly: ${String(err)}`);
    }

    this.idempotencyGuard.recordCompletion(request, finalResult);
    return finalResult;
  }

  /**
   * Section 8 delegation identity binding. In AEF v0 this ALWAYS resolves
   * to AUTH_FAILED for any real delegation: a DelegationEnvelope's
   * `issuer` can never be `type=user` (contracts/aef/validators.ts
   * already rejects that at the contract layer, Finding F-02), and v0's
   * IdentityResolver can only verify `user` actors (Section 6) -- so
   * `issuer` identity resolution always returns UNSUPPORTED. This is a
   * deliberate, documented v0 boundary (delegated execution is not
   * supported end-to-end until a future mission adds real
   * service-identity verification), not a bug. The subject-binding check
   * (delegation_binding.ts) is still run and unit-tested in isolation so
   * that guarantee already exists for when issuer verification is added.
   */
  private async checkDelegation(request: ExecutionRequest, verifiedRequesterId: string): Promise<KernelResult | null> {
    const delegation = this.deps.delegationResolver.resolve(request.delegation_ref!);
    if (!delegation) {
      return buildInvalid(
        { request, actorForReceipt: { type: "user", id: verifiedRequesterId, auth_ref: request.actor.auth_ref }, startedAt: this.now() },
        `delegation_ref '${request.delegation_ref}' does not resolve to any known DelegationEnvelope`,
      );
    }
    const receiptActor: Actor = { type: "user", id: verifiedRequesterId, auth_ref: request.actor.auth_ref };
    const baseParams = { request, actorForReceipt: receiptActor, startedAt: this.now() };

    const shapeCheck = validateDelegationEnvelope(delegation, { now: this.now(), nonceStore: this.deps.nonceStore });
    if (!shapeCheck.ok) {
      return buildInvalid(baseParams, `delegation invalid: ${shapeCheck.errors?.join("; ")}`);
    }

    const bindingCheck = validateRequestAgainstDelegation(request, delegation);
    if (!bindingCheck.ok) {
      return buildDenied(baseParams, `delegation binding failed: ${bindingCheck.errors?.join("; ")}`);
    }

    const subjectCheck = checkSubjectBinding(delegation, verifiedRequesterId);
    if (subjectCheck) {
      return buildDenied(baseParams, subjectCheck.reason);
    }

    // The issuer must itself be an independently verified identity --
    // never trust a delegation just because ITS shape validated.
    const issuerIdentity = await this.deps.identityResolver.resolve(delegation.issuer, { kind: "none" });
    if (issuerIdentity.status !== "VERIFIED") {
      return buildAuthFailed(
        baseParams,
        `delegation issuer identity could not be verified (status=${issuerIdentity.status}) -- AEF v0 does not support delegated execution end-to-end (no service-identity verification exists yet, Section 6)`,
      );
    }

    return null; // delegation fully validated -- continue the pipeline (unreachable in v0 today, kept for forward compatibility).
  }
}

export { ToolRegistry };
export { registerMockTools } from "./tool_registry.ts";
export { InMemoryHumanGateStore } from "./human_gate_store.ts";
export { AefIdentityResolver } from "./identity_resolver.ts";
export type { DelegationEnvelope };
