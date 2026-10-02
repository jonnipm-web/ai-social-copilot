/**
 * AEF persistence contract + in-memory implementation.
 * IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 *
 * In-memory store mirrors the DB invariants (append-only receipts,
 * idempotency enforcement, gate state machine) so the kernel can be
 * tested without a real database.
 */
import type {
  AefExecutionRequest,
  ExecutionAttempt,
  ExecutionReceipt,
  HumanGateState,
  HumanGateStatus,
  PolicyDecision,
} from './types.ts';

// ── Store contract ───────────────────────────────────────────────────────────

export interface AefStore {
  /** Persist a new execution request. Fails if requestId already exists. */
  insertRequest(req: AefExecutionRequest): Promise<AefStoreResult<void>>;

  /** Return existing request by idempotency key + caller user + intent kind. */
  findByIdempotencyKey(
    idempotencyKey: string,
    callerUserId: string,
    intentKind: string,
  ): Promise<AefStoreResult<AefExecutionRequest | null>>;

  /** Persist the policy decision for a request. One decision per request. */
  insertPolicyDecision(decision: PolicyDecision): Promise<AefStoreResult<void>>;

  /** Persist a human gate record. One gate per request. */
  insertHumanGate(gate: HumanGateState): Promise<AefStoreResult<void>>;

  /** Update human gate status (PENDING → APPROVED/REJECTED/EXPIRED only). */
  updateHumanGate(
    gateId: string,
    status: Exclude<HumanGateStatus, 'PENDING'>,
    approverRef: string | null,
    bindingHash: string | null,
    resolvedAt: string,
  ): Promise<AefStoreResult<void>>;

  /** Return the current gate state for a request. */
  getHumanGate(requestId: string): Promise<AefStoreResult<HumanGateState | null>>;

  /** Persist an execution attempt. */
  insertAttempt(attempt: ExecutionAttempt): Promise<AefStoreResult<void>>;

  /** Persist a receipt. Receipts are immutable once written. */
  insertReceipt(receipt: ExecutionReceipt): Promise<AefStoreResult<void>>;

  /** Return receipt by requestId (most recent attempt). */
  getReceipt(requestId: string): Promise<AefStoreResult<ExecutionReceipt | null>>;

  /** Return the original execution request by requestId. */
  getRequest(requestId: string): Promise<AefStoreResult<AefExecutionRequest | null>>;
}

export type AefStoreResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly code: 'AEF_PERSISTENCE_UNAVAILABLE' | 'ALREADY_EXISTS' | 'NOT_FOUND' };

// ── In-memory store ──────────────────────────────────────────────────────────

export class InMemoryAefStore implements AefStore {
  private readonly requests = new Map<string, AefExecutionRequest>();
  // idempotency index: `${userId}:${intentKind}:${idempotencyKey}` → requestId
  private readonly idempotencyIndex = new Map<string, string>();
  private readonly decisions = new Map<string, PolicyDecision>();
  private readonly gates = new Map<string, HumanGateState>(); // gateId → gate
  private readonly gatesByRequest = new Map<string, string>(); // requestId → gateId
  private readonly attempts = new Map<string, ExecutionAttempt>(); // attemptId → attempt
  private readonly receipts = new Map<string, ExecutionReceipt>(); // receiptId → receipt
  private readonly receiptsByRequest = new Map<string, string>(); // requestId → receiptId (latest)

  async insertRequest(req: AefExecutionRequest): Promise<AefStoreResult<void>> {
    if (this.requests.has(req.requestId)) return { ok: false, code: 'ALREADY_EXISTS' };
    this.requests.set(req.requestId, req);
    const idxKey = `${req.caller.authenticatedUserId}:${req.intent.kind}:${req.intent.idempotencyKey}`;
    this.idempotencyIndex.set(idxKey, req.requestId);
    return { ok: true, value: undefined };
  }

  async findByIdempotencyKey(
    idempotencyKey: string,
    callerUserId: string,
    intentKind: string,
  ): Promise<AefStoreResult<AefExecutionRequest | null>> {
    const idxKey = `${callerUserId}:${intentKind}:${idempotencyKey}`;
    const reqId = this.idempotencyIndex.get(idxKey);
    if (!reqId) return { ok: true, value: null };
    return { ok: true, value: this.requests.get(reqId) ?? null };
  }

  async insertPolicyDecision(decision: PolicyDecision): Promise<AefStoreResult<void>> {
    if (this.decisions.has(decision.requestId)) return { ok: false, code: 'ALREADY_EXISTS' };
    this.decisions.set(decision.requestId, decision);
    return { ok: true, value: undefined };
  }

  async insertHumanGate(gate: HumanGateState): Promise<AefStoreResult<void>> {
    if (this.gates.has(gate.gateId)) return { ok: false, code: 'ALREADY_EXISTS' };
    if (this.gatesByRequest.has(gate.requestId)) return { ok: false, code: 'ALREADY_EXISTS' };
    this.gates.set(gate.gateId, gate);
    this.gatesByRequest.set(gate.requestId, gate.gateId);
    return { ok: true, value: undefined };
  }

  async updateHumanGate(
    gateId: string,
    status: Exclude<HumanGateStatus, 'PENDING'>,
    approverRef: string | null,
    bindingHash: string | null,
    resolvedAt: string,
  ): Promise<AefStoreResult<void>> {
    const existing = this.gates.get(gateId);
    if (!existing) return { ok: false, code: 'NOT_FOUND' };
    if (existing.status !== 'PENDING') return { ok: false, code: 'ALREADY_EXISTS' };
    this.gates.set(gateId, { ...existing, status, approverRef, bindingHash, resolvedAt });
    return { ok: true, value: undefined };
  }

  async getHumanGate(requestId: string): Promise<AefStoreResult<HumanGateState | null>> {
    const gateId = this.gatesByRequest.get(requestId);
    if (!gateId) return { ok: true, value: null };
    return { ok: true, value: this.gates.get(gateId) ?? null };
  }

  async insertAttempt(attempt: ExecutionAttempt): Promise<AefStoreResult<void>> {
    if (this.attempts.has(attempt.attemptId)) return { ok: false, code: 'ALREADY_EXISTS' };
    this.attempts.set(attempt.attemptId, attempt);
    return { ok: true, value: undefined };
  }

  async insertReceipt(receipt: ExecutionReceipt): Promise<AefStoreResult<void>> {
    if (this.receipts.has(receipt.receiptId)) return { ok: false, code: 'ALREADY_EXISTS' };
    this.receipts.set(receipt.receiptId, receipt);
    this.receiptsByRequest.set(receipt.requestId, receipt.receiptId);
    return { ok: true, value: undefined };
  }

  async getReceipt(requestId: string): Promise<AefStoreResult<ExecutionReceipt | null>> {
    const receiptId = this.receiptsByRequest.get(requestId);
    if (!receiptId) return { ok: true, value: null };
    return { ok: true, value: this.receipts.get(receiptId) ?? null };
  }

  async getRequest(requestId: string): Promise<AefStoreResult<AefExecutionRequest | null>> {
    return { ok: true, value: this.requests.get(requestId) ?? null };
  }
}
