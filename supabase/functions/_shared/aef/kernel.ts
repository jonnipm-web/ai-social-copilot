/**
 * AEF Kernel — Action Execution Framework.
 * IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 *
 * The kernel enforces:
 *   1. Idempotency — same (user, intentKind, idempotencyKey) never executes twice.
 *   2. Policy — every class C action is evaluated before execution.
 *   3. Human Gate — CONSEQUENTIAL actions require human review when policy demands.
 *   4. Receipt — every submission produces a durable, immutable receipt.
 *   5. Identity separation — authentication / authorization / service / user / tenant
 *      are never conflated.
 *   6. Atomicity — request + decision + gate + receipt are persisted as one unit
 *      (via store.submitAtomic); any failure rolls back completely.
 *
 * The kernel does NOT execute the action itself. It governs the authorization
 * envelope, then hands back an AUTHORIZED receipt for the caller to act on.
 * If the receipt is DENIED or REQUIRES_HUMAN_REVIEW, the caller MUST NOT
 * execute.
 */
import { sha256Hex } from '../impact/provenance.ts';
import type { AefStore } from './store.ts';
import type {
  ActionClassification,
  AefError,
  AefExecutionRequest,
  AefResult,
  CallerContext,
  ExecutionReceipt,
  HumanGateState,
  ImpactActionIntent,
  ImpactActionIntentKind,
  PolicyDecision,
  PolicyOutcome,
} from './types.ts';

export const AEF_POLICY_VERSION = 'aef-policy/1+impact-i7';

// ── Intent classification ────────────────────────────────────────────────────

const INTENT_CLASSIFICATION: Readonly<Record<ImpactActionIntentKind, ActionClassification>> = {
  REQUEST_MANUAL_VERIFICATION: 'CONSEQUENTIAL',
  APPROVE_DOSSIER_PUBLICATION: 'CONSEQUENTIAL',
  ACKNOWLEDGE_CONFLICT: 'REVERSIBLE',
  MARK_INVESTIGATION_REVIEWED: 'REVERSIBLE',
};

export function classifyIntent(kind: ImpactActionIntentKind): ActionClassification {
  return INTENT_CLASSIFICATION[kind];
}

// ── Human gate policy ────────────────────────────────────────────────────────

const HUMAN_GATE_REQUIRED_CLASSIFICATIONS: ReadonlySet<ActionClassification> = new Set([
  'CONSEQUENTIAL', 'IRREVERSIBLE',
]);

const HUMAN_GATE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

// ── ID generation ────────────────────────────────────────────────────────────

function randomUuid(): string {
  return crypto.randomUUID();
}

// ── Receipt hash ─────────────────────────────────────────────────────────────

/**
 * Canonical binding hash for an AefExecutionRequest. Used by resolveHumanGate
 * to verify the approver's binding hash against the stored request state.
 * The approver must compute this same hash over the request they intend to approve.
 */
export async function buildRequestBindingHash(request: AefExecutionRequest): Promise<string> {
  const canonical = [
    request.requestId,
    request.correlationId,
    request.caller.authenticatedUserId,
    request.caller.projectId ?? '',
    request.caller.serviceId,
    request.intent.kind,
    request.intent.investigationId,
    request.intent.idempotencyKey,
    request.intent.classification,
    request.requestedAt,
  ].join('|');
  return sha256Hex(canonical);
}

async function buildReceiptHash(receipt: Omit<ExecutionReceipt, 'receiptHash'>): Promise<string> {
  const canonical = [
    receipt.receiptId,
    receipt.requestId,
    receipt.correlationId,
    receipt.callerUserId,
    receipt.projectId ?? '',
    receipt.serviceId,
    receipt.intentKind,
    receipt.investigationId,
    receipt.idempotencyKey,
    receipt.classification,
    receipt.policyVersion,
    receipt.policyOutcome,
    receipt.executionOutcome,
    receipt.humanGateId ?? '',
    receipt.errorCode ?? '',
    receipt.issuedAt,
  ].join('|');
  return sha256Hex(canonical);
}

// ── Kernel ───────────────────────────────────────────────────────────────────

export interface KernelDeps {
  readonly store: AefStore;
  readonly now?: () => string;
}

/**
 * Submit a consequential Impact action for AEF governance.
 *
 * All AEF records (request, decision, gate, receipt) are built in memory
 * before any I/O, then persisted atomically via store.submitAtomic(). A
 * failure at any point leaves no orphaned records.
 *
 * Returns:
 *   ok=true  + receipt.executionOutcome=AUTHORIZED  → caller may execute
 *   ok=false + error.code=REQUIRES_HUMAN_REVIEW     → caller must wait for gate
 *   ok=false + error.code=DENIED                    → caller must not execute
 *   ok=false + error.code=IDEMPOTENCY_CONFLICT       → already submitted; see receipt
 *   ok=false + error.code=AEF_PERSISTENCE_UNAVAILABLE → store down; fail closed
 */
export async function submitAction(
  caller: CallerContext,
  intent: ImpactActionIntent,
  deps: KernelDeps,
): Promise<AefResult<{ readonly requestId: string }>> {
  const now = deps.now ? deps.now() : new Date().toISOString();
  const store = deps.store;

  // 1. Idempotency pre-check
  const existingResult = await store.findByIdempotencyKey(
    intent.idempotencyKey,
    caller.authenticatedUserId,
    intent.kind,
  );
  if (!existingResult.ok) {
    return { ok: false, error: { code: 'AEF_PERSISTENCE_UNAVAILABLE' }, receipt: null };
  }
  if (existingResult.value !== null) {
    const existingReq = existingResult.value;
    const receiptResult = await store.getReceipt(existingReq.requestId);
    return {
      ok: false,
      error: { code: 'IDEMPOTENCY_CONFLICT', existingRequestId: existingReq.requestId },
      receipt: receiptResult.ok ? receiptResult.value : null,
    };
  }

  // 2. Build execution request (no I/O)
  const requestId = randomUuid();
  const aefRequest: AefExecutionRequest = {
    requestId,
    correlationId: caller.correlationId,
    caller,
    intent: { ...intent, classification: classifyIntent(intent.kind) },
    requestedAt: now,
  };
  const classification = aefRequest.intent.classification;

  // 3. Evaluate policy (pure logic, no I/O)
  let policyOutcome: PolicyOutcome;
  let policyReason: string;

  if (classification === 'IRREVERSIBLE') {
    policyOutcome = 'DENIED';
    policyReason = 'IRREVERSIBLE actions are not available in the Lab';
  } else if (HUMAN_GATE_REQUIRED_CLASSIFICATIONS.has(classification)) {
    policyOutcome = 'REQUIRES_HUMAN_REVIEW';
    policyReason = `${classification} actions require human gate`;
  } else {
    policyOutcome = 'AUTHORIZED';
    policyReason = `${classification} action authorized by policy`;
  }

  const decision: PolicyDecision = {
    requestId,
    outcome: policyOutcome,
    policyVersion: AEF_POLICY_VERSION,
    decidedAt: now,
    reason: policyReason,
  };

  // 4. Build human gate if required (no I/O)
  let gate: HumanGateState | null = null;
  let gateError: AefError | null = null;

  if (policyOutcome === 'REQUIRES_HUMAN_REVIEW') {
    const gateId = randomUuid();
    const expiresAt = new Date(Date.parse(now) + HUMAN_GATE_TTL_MS).toISOString();
    gate = {
      gateId,
      requestId,
      approverRef: null,
      status: 'PENDING',
      expiresAt,
      resolvedAt: null,
      bindingHash: null,
    };
    gateError = { code: 'REQUIRES_HUMAN_REVIEW', gateId, expiresAt };
  }

  // 5. Build receipt (no I/O — computed before atomic persist)
  const attemptOutcome = policyOutcome === 'DENIED' ? 'DENIED'
    : policyOutcome === 'REQUIRES_HUMAN_REVIEW' ? 'REQUIRES_HUMAN_REVIEW'
    : 'AUTHORIZED';

  const receiptPartial: Omit<ExecutionReceipt, 'receiptHash'> = {
    receiptId: randomUuid(),
    requestId,
    correlationId: caller.correlationId,
    callerUserId: caller.authenticatedUserId,
    projectId: caller.projectId,
    serviceId: caller.serviceId,
    intentKind: intent.kind,
    investigationId: intent.investigationId,
    idempotencyKey: intent.idempotencyKey,
    classification,
    policyVersion: AEF_POLICY_VERSION,
    policyOutcome,
    executionOutcome: attemptOutcome,
    humanGateId: gate?.gateId ?? null,
    errorCode: null,
    issuedAt: now,
  };
  const receiptHash = await buildReceiptHash(receiptPartial);
  const receipt: ExecutionReceipt = { ...receiptPartial, receiptHash };

  // 6. Atomic persist — request + decision + gate? + receipt in one operation
  const atomicResult = await store.submitAtomic(aefRequest, decision, gate, receipt);
  if (!atomicResult.ok) {
    if (atomicResult.code === 'ALREADY_EXISTS') {
      // Concurrent duplicate: re-fetch so the response is consistent with
      // the normal idempotency-conflict path (not a false 503).
      const raceResult = await store.findByIdempotencyKey(
        intent.idempotencyKey,
        caller.authenticatedUserId,
        intent.kind,
      );
      if (raceResult.ok && raceResult.value !== null) {
        const raceReceipt = await store.getReceipt(raceResult.value.requestId);
        return {
          ok: false,
          error: { code: 'IDEMPOTENCY_CONFLICT', existingRequestId: raceResult.value.requestId },
          receipt: raceReceipt.ok ? raceReceipt.value : null,
        };
      }
    }
    return { ok: false, error: { code: 'AEF_PERSISTENCE_UNAVAILABLE' }, receipt: null };
  }

  // 7. Return result
  if (policyOutcome === 'DENIED') {
    return { ok: false, error: { code: 'DENIED', reason: policyReason }, receipt };
  }
  if (gateError) {
    return { ok: false, error: gateError, receipt };
  }
  return { ok: true, value: { requestId }, receipt };
}

/**
 * Resolve a human gate (approve or reject).
 *
 * The approver ref and binding hash must match the original request state.
 * A stale, expired, forged, or mismatched approval is always rejected.
 */
export async function resolveHumanGate(
  requestId: string,
  resolution: 'APPROVED' | 'REJECTED',
  approverRef: string,
  bindingHash: string,
  deps: KernelDeps,
): Promise<AefResult<{ readonly gateId: string }>> {
  const now = deps.now ? deps.now() : new Date().toISOString();
  const store = deps.store;

  const gateResult = await store.getHumanGate(requestId);
  if (!gateResult.ok) {
    return { ok: false, error: { code: 'AEF_PERSISTENCE_UNAVAILABLE' }, receipt: null };
  }
  const gate = gateResult.value;
  if (!gate) {
    return { ok: false, error: { code: 'HUMAN_GATE_INVALID', reason: 'no gate found for request' }, receipt: null };
  }
  if (gate.status !== 'PENDING') {
    return { ok: false, error: { code: 'HUMAN_GATE_INVALID', reason: `gate already ${gate.status}` }, receipt: null };
  }
  // Expiry check (>= to reject approval exactly at the expiry instant)
  if (Date.parse(now) >= Date.parse(gate.expiresAt)) {
    await store.updateHumanGate(gate.gateId, 'EXPIRED', null, null, now);
    return { ok: false, error: { code: 'HUMAN_GATE_INVALID', reason: 'gate expired' }, receipt: null };
  }
  // Approver must be non-empty opaque ref
  if (!approverRef || approverRef.length > 64) {
    return { ok: false, error: { code: 'HUMAN_GATE_INVALID', reason: 'invalid approver ref' }, receipt: null };
  }
  // Binding hash: validate format then verify against stored request state
  if (!bindingHash || !/^[0-9a-f]{64}$/.test(bindingHash)) {
    return { ok: false, error: { code: 'HUMAN_GATE_INVALID', reason: 'invalid binding hash' }, receipt: null };
  }
  const requestResult = await store.getRequest(requestId);
  if (!requestResult.ok) {
    return { ok: false, error: { code: 'AEF_PERSISTENCE_UNAVAILABLE' }, receipt: null };
  }
  if (!requestResult.value) {
    return { ok: false, error: { code: 'HUMAN_GATE_INVALID', reason: 'no request found for binding hash verification' }, receipt: null };
  }
  const expectedHash = await buildRequestBindingHash(requestResult.value);
  if (bindingHash !== expectedHash) {
    return { ok: false, error: { code: 'HUMAN_GATE_INVALID', reason: 'binding hash mismatch' }, receipt: null };
  }

  const updateResult = await store.updateHumanGate(
    gate.gateId,
    resolution,
    approverRef,
    bindingHash,
    now,
  );
  if (!updateResult.ok) {
    return { ok: false, error: { code: 'AEF_PERSISTENCE_UNAVAILABLE' }, receipt: null };
  }

  // Issue receipt for gate resolution
  const executionOutcome = resolution === 'APPROVED' ? 'AUTHORIZED' : 'DENIED';
  const storedReq = requestResult.value;
  const receiptPartial: Omit<ExecutionReceipt, 'receiptHash'> = {
    receiptId: randomUuid(),
    requestId,
    correlationId: storedReq.correlationId,
    callerUserId: approverRef,
    projectId: storedReq.caller.projectId,
    serviceId: 'aef-gate-resolver',
    intentKind: storedReq.intent.kind,
    investigationId: storedReq.intent.investigationId,
    idempotencyKey: gate.gateId,
    classification: storedReq.intent.classification,
    policyVersion: AEF_POLICY_VERSION,
    policyOutcome: resolution === 'APPROVED' ? 'AUTHORIZED' : 'DENIED',
    executionOutcome,
    humanGateId: gate.gateId,
    errorCode: null,
    issuedAt: now,
  };
  const receiptHash = await buildReceiptHash(receiptPartial);
  const receipt: ExecutionReceipt = { ...receiptPartial, receiptHash };
  const gateReceiptResult = await store.insertReceipt(receipt);
  if (!gateReceiptResult.ok) {
    return { ok: false, error: { code: 'AEF_PERSISTENCE_UNAVAILABLE' }, receipt: null };
  }

  if (resolution === 'APPROVED') {
    return { ok: true, value: { gateId: gate.gateId }, receipt };
  }
  return { ok: false, error: { code: 'DENIED', reason: 'gate rejected by approver' }, receipt };
}
