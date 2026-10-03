/**
 * AEF persistence contract + in-memory implementation.
 * IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 *
 * In-memory store mirrors the DB invariants (append-only receipts,
 * idempotency enforcement, gate state machine) so the kernel can be
 * tested without a real database.
 *
 * Note on attempt tracking: executions attempts are NOT persisted in either
 * the in-memory or Supabase store. The receipt (issued atomically with the
 * request) is the canonical record of every submission outcome. A dedicated
 * attempts table (with retry-level granularity) is a future migration task.
 * The AefStore interface does not expose an insertAttempt method to avoid
 * pretending persistence exists where it does not.
 */
import type {
  AefExecutionRequest,
  ExecutionReceipt,
  HumanGateState,
  HumanGateStatus,
  PolicyDecision,
} from './types.ts';

// ── Store contract ───────────────────────────────────────────────────────────

export interface AefStore {
  /**
   * Pre-check: return existing request by idempotency key + caller + kind.
   * Used by the kernel to detect duplicates before building objects.
   */
  findByIdempotencyKey(
    idempotencyKey: string,
    callerUserId: string,
    intentKind: string,
  ): Promise<AefStoreResult<AefExecutionRequest | null>>;

  /**
   * Atomic submit: persists request + policy decision + optional human gate +
   * receipt in one all-or-nothing operation. Returns ALREADY_EXISTS if the
   * idempotency key is already present (unique_violation); returns
   * AEF_PERSISTENCE_UNAVAILABLE on any other failure. On success every record
   * is guaranteed to be durable and consistent — no partial state is possible.
   */
  submitAtomic(
    request: AefExecutionRequest,
    decision: PolicyDecision,
    gate: HumanGateState | null,
    receipt: ExecutionReceipt,
  ): Promise<AefStoreResult<void>>;

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

  /**
   * Persist a gate-resolution receipt (approve/reject path).
   * Only used by resolveHumanGate, not by submitAction.
   */
  insertReceipt(receipt: ExecutionReceipt): Promise<AefStoreResult<void>>;

  /** Return receipt by requestId (most recent). */
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
  private readonly receipts = new Map<string, ExecutionReceipt>(); // receiptId → receipt
  private readonly receiptsByRequest = new Map<string, string>(); // requestId → receiptId (latest)

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

  async submitAtomic(
    request: AefExecutionRequest,
    decision: PolicyDecision,
    gate: HumanGateState | null,
    receipt: ExecutionReceipt,
  ): Promise<AefStoreResult<void>> {
    const idxKey = `${request.caller.authenticatedUserId}:${request.intent.kind}:${request.intent.idempotencyKey}`;
    // Check idempotency before any mutation (mirrors DB UNIQUE constraint).
    if (this.idempotencyIndex.has(idxKey)) return { ok: false, code: 'ALREADY_EXISTS' };
    // No await below — all operations are synchronous, so this method is
    // effectively atomic in JavaScript's single-threaded event loop.
    this.requests.set(request.requestId, request);
    this.idempotencyIndex.set(idxKey, request.requestId);
    this.decisions.set(request.requestId, decision);
    if (gate !== null) {
      this.gates.set(gate.gateId, gate);
      this.gatesByRequest.set(request.requestId, gate.gateId);
    }
    this.receipts.set(receipt.receiptId, receipt);
    this.receiptsByRequest.set(request.requestId, receipt.receiptId);
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
