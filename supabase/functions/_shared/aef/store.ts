/**
 * AEF persistence contract + in-memory implementation.
 * IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 *
 * In-memory store mirrors the DB invariants (append-only receipts,
 * idempotency enforcement, gate state machine) so the kernel can be
 * tested without a real database.
 *
 * Phase 3: submitAtomic() replaces individual insert methods.
 * Phase 4: resolveGateAtomic() replaces updateHumanGate() + insertReceipt().
 *
 * Note on attempt tracking: execution attempts are NOT persisted.
 * The receipt (issued atomically with the request) is the canonical record.
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
   * idempotency key is already present; AEF_PERSISTENCE_UNAVAILABLE on other
   * failures. On success every record is durable — no partial state possible.
   */
  submitAtomic(
    request: AefExecutionRequest,
    decision: PolicyDecision,
    gate: HumanGateState | null,
    receipt: ExecutionReceipt,
  ): Promise<AefStoreResult<void>>;

  /**
   * Atomic gate resolution: validates gate state, updates gate status +
   * approver_ref + binding_hash + resolved_at, AND inserts the resolution
   * receipt, all in a single all-or-nothing operation.
   *
   * Returns:
   *   ok: true           — gate resolved, receipt persisted
   *   GATE_NOT_FOUND     — no gate exists for this requestId
   *   GATE_ALREADY_RESOLVED — gate is not PENDING
   *   GATE_EXPIRED       — gate expired; atomically marks EXPIRED, no receipt
   *   RECEIPT_ALREADY_EXISTS — receipt PK collision (full rollback)
   *   AEF_PERSISTENCE_UNAVAILABLE — DB error
   */
  resolveGateAtomic(
    requestId: string,
    resolution: 'APPROVED' | 'REJECTED',
    approverRef: string,
    bindingHash: string,
    receipt: ExecutionReceipt,
  ): Promise<AefStoreResult<void>>;

  /** Return the current gate state for a request. */
  getHumanGate(requestId: string): Promise<AefStoreResult<HumanGateState | null>>;

  /** Return receipt by requestId (most recent). */
  getReceipt(requestId: string): Promise<AefStoreResult<ExecutionReceipt | null>>;

  /** Return the original execution request by requestId. */
  getRequest(requestId: string): Promise<AefStoreResult<AefExecutionRequest | null>>;
}

export type AefStoreResult<T> =
  | { readonly ok: true; readonly value: T }
  | {
      readonly ok: false;
      readonly code:
        | 'AEF_PERSISTENCE_UNAVAILABLE'
        | 'ALREADY_EXISTS'
        | 'NOT_FOUND'
        | 'GATE_NOT_FOUND'
        | 'GATE_ALREADY_RESOLVED'
        | 'GATE_EXPIRED'
        | 'RECEIPT_ALREADY_EXISTS';
    };

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

  resolveGateAtomic(
    requestId: string,
    resolution: 'APPROVED' | 'REJECTED',
    approverRef: string,
    bindingHash: string,
    receipt: ExecutionReceipt,
  ): Promise<AefStoreResult<void>> {
    // All operations below are synchronous — JS-event-loop atomic.
    const gateId = this.gatesByRequest.get(requestId);
    if (!gateId) return Promise.resolve({ ok: false, code: 'GATE_NOT_FOUND' });
    const gate = this.gates.get(gateId);
    if (!gate) return Promise.resolve({ ok: false, code: 'GATE_NOT_FOUND' });

    if (gate.status !== 'PENDING') {
      return Promise.resolve({ ok: false, code: 'GATE_ALREADY_RESOLVED' });
    }

    // Expiry check: consistent with the RPC (>= to reject at the expiry instant).
    if (new Date(receipt.issuedAt).getTime() >= new Date(gate.expiresAt).getTime()) {
      this.gates.set(gateId, { ...gate, status: 'EXPIRED', resolvedAt: receipt.issuedAt });
      return Promise.resolve({ ok: false, code: 'GATE_EXPIRED' });
    }

    // Receipt ID uniqueness (mirrors receipt PK constraint).
    if (this.receipts.has(receipt.receiptId)) {
      return Promise.resolve({ ok: false, code: 'RECEIPT_ALREADY_EXISTS' });
    }

    // Atomic update: gate state + receipt (no awaits → event-loop atomic).
    this.gates.set(gateId, {
      ...gate,
      status: resolution,
      approverRef,
      bindingHash,
      resolvedAt: receipt.issuedAt,
    });
    this.receipts.set(receipt.receiptId, receipt);
    this.receiptsByRequest.set(requestId, receipt.receiptId);
    return Promise.resolve({ ok: true, value: undefined });
  }

  async getHumanGate(requestId: string): Promise<AefStoreResult<HumanGateState | null>> {
    const gateId = this.gatesByRequest.get(requestId);
    if (!gateId) return { ok: true, value: null };
    return { ok: true, value: this.gates.get(gateId) ?? null };
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
