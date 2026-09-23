/**
 * AefGovernance — the persistent AEF service (IV-AEF-PERSISTENCE-01).
 *
 * Reuses the v0 building blocks (identity resolver, contract validator,
 * policy evaluator, sealed tool registry) and replaces every in-memory store
 * with the PostgreSQL state machine (store.ts). The in-memory AefKernel stays
 * as the reference pipeline; it is not used here.
 *
 * Flow:
 *   submit()     identity → contract → v1 restrictions → tool → policy →
 *                canonical payload hash → register (durable, idempotent) →
 *                AWAITING_APPROVAL | claim → tool → complete → receipt
 *   decideGate() identity of the approver → bound decision in the DB
 *   submit()     again, same idempotency key + same payload, after approval
 *                → claim → tool → complete
 *   cancel(), getOperation(), recover(), verifyReceipt(), verifyAuditChain()
 *
 * Invariants kept here (the DB re-enforces the state ones):
 *   - a tool runs only after the DB granted an execution claim (at most once
 *     per operation: attempt_count 0 → 1, one token);
 *   - every returned receipt was read back from the DB; this process never
 *     builds one;
 *   - a timeout, a throw, a failure without a side-effect declaration, or a
 *     completion that could not be persisted is UNKNOWN — never SUCCESS, and
 *     never retried automatically;
 *   - the request carries no authority: subject comes from the verified
 *     credential, tool/risk/gate requirement from the server registry and
 *     policy, versions from limits.ts; a client human_gate_ref is refused.
 */
import { validateExecutionRequest } from "../../contracts/aef/validators.ts";
import type { Actor, ExecutionRequest } from "../../contracts/aef/types.ts";
import { evaluatePolicy } from "../policy_evaluator.ts";
import type { ExecuteFn, ToolRegistry } from "../tool_registry.ts";
import type { IdentityResolver, RawCredential, ToolExecutionResult } from "../types.ts";
import { canonicalJson, sha256Hex } from "./canonical.ts";
import type { AefErrorCode } from "./errors.ts";
import {
  AEF_POLICY_VERSION,
  AEF_RISK_VERSION,
  EXECUTION_LEASE_SECONDS,
  GATE_TTL_SECONDS,
  OPERATION_TTL_SECONDS,
  TOOL_TIMEOUT_MS,
} from "./limits.ts";
import { type PostgresAefStore, StoreProtocolError, type StoreView, TERMINAL_STATES } from "./store.ts";

export type GovernanceResult =
  | { status: "DENIED"; code: AefErrorCode }
  /** Registered; waiting for the subject's bound decision. */
  | ({ status: "AWAITING_APPROVAL"; replayed: boolean } & StoreView)
  /** Approved (or needs no approval) but not executed yet — resubmit to execute. */
  | ({ status: "AUTHORIZED"; replayed: boolean } & StoreView)
  /** Another worker holds the execution claim. */
  | ({ status: "EXECUTING"; replayed: boolean } & StoreView)
  /** Terminal, with the persisted receipt. */
  | ({ status: "FINAL"; replayed: boolean } & StoreView)
  /** The tool was invoked but its outcome could not be durably recorded. Never a success. */
  | { status: "OUTCOME_UNCONFIRMED"; code: AefErrorCode; operationId: string };

export interface AefGovernanceDeps {
  identityResolver: IdentityResolver;
  toolRegistry: ToolRegistry;
  store: PostgresAefStore;
  now?: () => Date;
  toolTimeoutMs?: number;
}

type Denied = { status: "DENIED"; code: AefErrorCode };
const deny = (code: AefErrorCode): Denied => ({ status: "DENIED", code });

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HEX64 = /^[0-9a-f]{64}$/;

interface BoundPayload {
  intent: string;
  parameters: Record<string, unknown>;
  constraints: ExecutionRequest["constraints"] | null;
  quant_execution_tier: ExecutionRequest["quant_execution_tier"] | null;
  context_ref: string | null;
}

/** The client-supplied part of what the tool observes; hashed into payload_hash. */
function boundPayload(request: ExecutionRequest): BoundPayload {
  return {
    intent: request.intent,
    parameters: request.parameters ?? {},
    constraints: request.constraints ?? null,
    quant_execution_tier: request.quant_execution_tier ?? null,
    context_ref: request.context_ref ?? null,
  };
}

/**
 * The exact request a tool receives (Codex Gate 1 G1-01). Built ONLY from:
 *   - the normalized, hashed payload (so equal hash ⇒ equal tool input,
 *     whatever the client sent for omitted-vs-empty fields);
 *   - fields bound in the DB binding hash (domain, action, resource);
 *   - server-owned values (verified subject, the durable operation id and
 *     its expiry, the execution time).
 * Never from unbound client fields (request_id, correlation_id, timestamps,
 * idempotency_key, metadata, human_gate_ref, delegation_ref).
 */
function toolRequest(request: ExecutionRequest, payload: BoundPayload, subjectId: string, op: { operationId: string; expiresAt: string }, now: Date): ExecutionRequest {
  const built: ExecutionRequest = {
    contract_version: "1.0",
    request_id: op.operationId,
    requested_at: now.toISOString(),
    expires_at: op.expiresAt,
    actor: { type: "user", id: subjectId, auth_ref: `usr:${subjectId}` },
    intent: payload.intent,
    domain: request.domain,
    action: request.action,
    parameters: structuredClone(payload.parameters),
  };
  if (request.resource) built.resource = { type: request.resource.type, id: request.resource.id.toLowerCase() };
  if (payload.constraints !== null) built.constraints = structuredClone(payload.constraints);
  if (payload.quant_execution_tier !== null) built.quant_execution_tier = payload.quant_execution_tier;
  if (payload.context_ref !== null) built.context_ref = payload.context_ref;
  return deepFreeze(built);
}

function deepFreeze<T>(v: T): T {
  if (typeof v === "object" && v !== null) {
    for (const child of Object.values(v)) deepFreeze(child);
    Object.freeze(v);
  }
  return v;
}

type CompletionResult = "SUCCEEDED" | "FAILED_NO_SIDE_EFFECT" | "FAILED_AFTER_SIDE_EFFECT" | "UNKNOWN_OUTCOME";

function classifyToolResult(r: ToolExecutionResult | undefined): CompletionResult {
  if (!r || typeof r !== "object") return "UNKNOWN_OUTCOME";
  if (r.outcome === "SUCCESS") return "SUCCEEDED";
  if (r.outcome === "FAILURE" && r.sideEffect === "NONE") return "FAILED_NO_SIDE_EFFECT";
  if (r.outcome === "FAILURE" && r.sideEffect === "APPLIED") return "FAILED_AFTER_SIDE_EFFECT";
  return "UNKNOWN_OUTCOME";
}

export class AefGovernance {
  #execute: ExecuteFn;

  constructor(private readonly deps: AefGovernanceDeps) {
    // Same one-time capability as the v0 kernel: whoever builds the
    // governance service owns tool execution; nobody else can obtain it.
    this.#execute = deps.toolRegistry.claimExecutionRights();
  }

  private now(): Date {
    return this.deps.now ? this.deps.now() : new Date();
  }

  private async verifiedUser(actor: unknown, credential: RawCredential): Promise<string | null> {
    try {
      const identity = await this.deps.identityResolver.resolve(actor as Actor, credential);
      return identity.status === "VERIFIED" && identity.verifiedType === "user" ? identity.verifiedId : null;
    } catch {
      return null;
    }
  }

  /** Denial of a verified subject: audited best-effort, then denied regardless. */
  private async denyAudited(subjectId: string, code: AefErrorCode): Promise<Denied> {
    try {
      await this.deps.store.recordDenial({ subject_id: subjectId, reason_code: code });
    } catch {
      // Audit is best-effort for a request that was refused anyway.
    }
    return deny(code);
  }

  private storeFailure(err: unknown): Denied {
    return deny(err instanceof StoreProtocolError ? "STORE_PROTOCOL_ERROR" : "STORE_UNAVAILABLE");
  }

  async submit(rawRequest: unknown, credential: RawCredential): Promise<GovernanceResult> {
    const subjectId = await this.verifiedUser(isRecord(rawRequest) ? rawRequest.actor : undefined, credential);
    if (!subjectId) return deny("AUTH_FAILED");

    const contract = validateExecutionRequest(rawRequest, { now: this.now() });
    if (!contract.ok) return this.denyAudited(subjectId, "INVALID_REQUEST");
    const request = rawRequest as ExecutionRequest;

    // Persistence v1 restrictions (AEF_SECURITY_MODEL.md).
    if (request.delegation_ref) return this.denyAudited(subjectId, "DELEGATION_UNSUPPORTED");
    if (request.human_gate_ref) return this.denyAudited(subjectId, "CLIENT_APPROVAL_REJECTED");
    if (!request.idempotency_key) return this.denyAudited(subjectId, "IDEMPOTENCY_KEY_REQUIRED");
    if (request.resource && request.resource.type !== "project") return this.denyAudited(subjectId, "RESOURCE_TYPE_UNSUPPORTED");

    const tool = this.deps.toolRegistry.describe(request);
    if (!tool) return this.denyAudited(subjectId, "UNKNOWN_TOOL");
    let decision;
    try {
      decision = evaluatePolicy(request, tool).decision;
    } catch {
      return this.denyAudited(subjectId, "POLICY_DENIED");
    }
    if (decision === "DENY") return this.denyAudited(subjectId, "POLICY_DENIED");
    const requiresGate = decision === "REQUIRE_HUMAN_REVIEW" || tool.requiresHumanGate || tool.classification === "CONSEQUENTIAL";

    const canonical = canonicalJson(boundPayload(request));
    if (!canonical.ok) return this.denyAudited(subjectId, canonical.code);
    const payloadHash = await sha256Hex(canonical.json);

    let registered;
    try {
      registered = await this.deps.store.register({
        subject_id: subjectId,
        request_id: request.request_id,
        idempotency_key: request.idempotency_key,
        domain: request.domain,
        action: request.action,
        tool_id: tool.toolId,
        action_class: tool.classification,
        resource_type: request.resource ? request.resource.type : null,
        resource_id: request.resource ? request.resource.id : null,
        payload_hash: payloadHash,
        payload_bytes: canonical.bytes,
        policy_version: AEF_POLICY_VERSION,
        risk_version: AEF_RISK_VERSION,
        requires_human_gate: requiresGate,
        ttl_seconds: OPERATION_TTL_SECONDS,
        gate_ttl_seconds: GATE_TTL_SECONDS,
      });
    } catch (err) {
      return this.storeFailure(err);
    }
    if (!registered.ok) return deny(registered.code);
    if (registered.operation.payloadHash !== payloadHash) return deny("STORE_PROTOCOL_ERROR");

    const view: StoreView = { operation: registered.operation, gate: registered.gate, receipt: registered.receipt };
    if (view.operation.state === "AUTHORIZED") {
      return this.execute(subjectId, view, request, registered.replayed);
    }
    return this.present(view, registered.replayed);
  }

  private present(view: StoreView, replayed: boolean): GovernanceResult {
    const state = view.operation.state;
    if (TERMINAL_STATES.includes(state)) {
      if (!view.receipt) return deny("STORE_PROTOCOL_ERROR");
      return { status: "FINAL", replayed, ...view };
    }
    if (state === "AWAITING_APPROVAL") return { status: "AWAITING_APPROVAL", replayed, ...view };
    if (state === "EXECUTING") return { status: "EXECUTING", replayed, ...view };
    return { status: "AUTHORIZED", replayed, ...view };
  }

  private async execute(subjectId: string, view: StoreView, request: ExecutionRequest, replayed: boolean): Promise<GovernanceResult> {
    const op = view.operation;
    let claim;
    try {
      claim = await this.deps.store.claimExecution({
        operation_id: op.operationId,
        subject_id: subjectId,
        binding_hash: op.bindingHash,
        policy_version: AEF_POLICY_VERSION,
        lease_seconds: EXECUTION_LEASE_SECONDS,
      });
    } catch (err) {
      return this.storeFailure(err);
    }
    if (!claim.ok) {
      if (claim.code !== "NOT_CLAIMABLE" && claim.code !== "OPERATION_EXPIRED" && claim.code !== "POLICY_VERSION_CHANGED") {
        return deny(claim.code);
      }
      // Someone else won the claim, or the operation moved on: report the
      // durable truth, never a local guess.
      let current;
      try {
        current = await this.deps.store.getOperation({ operation_id: op.operationId, subject_id: subjectId });
      } catch (err) {
        return this.storeFailure(err);
      }
      return current.ok ? this.present(current, true) : deny(current.code);
    }

    const result = await this.runTool(toolRequest(request, boundPayload(request), subjectId, op, this.now()), op.operationId);
    let completed;
    try {
      completed = await this.deps.store.completeExecution({
        operation_id: op.operationId,
        execution_token: claim.executionToken,
        result,
      });
    } catch (err) {
      // The lease will run out and recovery records UNKNOWN_OUTCOME.
      return { status: "OUTCOME_UNCONFIRMED", code: this.storeFailure(err).code, operationId: op.operationId };
    }
    if (!completed.ok) return { status: "OUTCOME_UNCONFIRMED", code: completed.code, operationId: op.operationId };
    // The tool has run: from here on, anything but a durable final receipt
    // is reported as unconfirmed — never as a denial or a success.
    const shown = this.present(completed, replayed);
    return shown.status === "FINAL" ? shown : { status: "OUTCOME_UNCONFIRMED", code: "STORE_PROTOCOL_ERROR", operationId: op.operationId };
  }

  private async runTool(input: ExecutionRequest, operationId: string): Promise<CompletionResult> {
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const timeout = new Promise<"TIMEOUT">((resolve) => {
      timer = setTimeout(() => resolve("TIMEOUT"), this.deps.toolTimeoutMs ?? TOOL_TIMEOUT_MS);
    });
    try {
      const invocation = this.#execute(input, { operationId, signal: controller.signal });
      if (!invocation) return "FAILED_NO_SIDE_EFFECT"; // unregistered at execution time: nothing ran
      const raced = await Promise.race([invocation, timeout]);
      if (raced === "TIMEOUT") {
        controller.abort();
        return "UNKNOWN_OUTCOME";
      }
      return classifyToolResult(raced);
    } catch {
      return "UNKNOWN_OUTCOME";
    } finally {
      clearTimeout(timer);
    }
  }

  /**
   * The subject's decision on a pending gate. `input` is untrusted: exactly
   * { gate_id, decision, binding_hash, approver } — any other key is a
   * mass-assignment attempt and is refused. The approver is the verified
   * credential holder; the DB only accepts the operation's own subject.
   */
  async decideGate(input: unknown, credential: RawCredential): Promise<GovernanceResult> {
    if (!isRecord(input)) return deny("INPUT_REJECTED");
    const allowed = new Set(["gate_id", "decision", "binding_hash", "approver"]);
    if (Object.keys(input).some((k) => !allowed.has(k))) return deny("INPUT_REJECTED");
    const { gate_id, decision, binding_hash, approver } = input;
    if (typeof gate_id !== "string" || !UUID.test(gate_id)) return deny("INPUT_REJECTED");
    if (decision !== "APPROVE" && decision !== "REJECT") return deny("INPUT_REJECTED");
    if (typeof binding_hash !== "string" || !HEX64.test(binding_hash)) return deny("INPUT_REJECTED");

    const approverId = await this.verifiedUser(approver, credential);
    if (!approverId) return deny("AUTH_FAILED");
    let reply;
    try {
      reply = await this.deps.store.decideGate({
        gate_id: gate_id.toLowerCase(),
        approver_id: approverId,
        decision,
        binding_hash,
        policy_version: AEF_POLICY_VERSION,
      });
    } catch (err) {
      return this.storeFailure(err);
    }
    return reply.ok ? this.present(reply, false) : deny(reply.code);
  }

  /** Cancels before execution only. Never compensates anything. */
  async cancel(input: unknown, credential: RawCredential): Promise<GovernanceResult> {
    const parsed = this.operationInput(input);
    if (!parsed) return deny("INPUT_REJECTED");
    const subjectId = await this.verifiedUser(parsed.actor, credential);
    if (!subjectId) return deny("AUTH_FAILED");
    try {
      const reply = await this.deps.store.cancel({ operation_id: parsed.operationId, subject_id: subjectId });
      return reply.ok ? this.present(reply, false) : deny(reply.code);
    } catch (err) {
      return this.storeFailure(err);
    }
  }

  async getOperation(input: unknown, credential: RawCredential): Promise<GovernanceResult> {
    const parsed = this.operationInput(input);
    if (!parsed) return deny("INPUT_REJECTED");
    const subjectId = await this.verifiedUser(parsed.actor, credential);
    if (!subjectId) return deny("AUTH_FAILED");
    try {
      const reply = await this.deps.store.getOperation({ operation_id: parsed.operationId, subject_id: subjectId });
      return reply.ok ? this.present(reply, true) : deny(reply.code);
    } catch (err) {
      return this.storeFailure(err);
    }
  }

  private operationInput(input: unknown): { operationId: string; actor: unknown } | null {
    if (!isRecord(input)) return null;
    if (Object.keys(input).some((k) => k !== "operation_id" && k !== "actor")) return null;
    if (typeof input.operation_id !== "string" || !UUID.test(input.operation_id)) return null;
    return { operationId: input.operation_id.toLowerCase(), actor: input.actor };
  }

  /** Infrastructure sweep (scheduler), no end-user entry point. */
  recover(limit = 100): Promise<{ unknownOutcome: number; expired: number }> {
    return this.deps.store.recover(limit);
  }

  /** A receipt is genuine only if it matches, byte for byte, the stored and chain-anchored one. */
  verifyReceipt(receipt: unknown): Promise<{ valid: boolean; reason: string | null }> {
    return this.deps.store.verifyReceipt(receipt);
  }

  verifyAuditChain(subjectId: string) {
    return this.deps.store.verifyAuditChain(subjectId);
  }
}
