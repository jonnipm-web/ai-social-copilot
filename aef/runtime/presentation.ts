/**
 * What IVE / the client may show about an AEF operation
 * (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
 *
 * Derived ONLY from the governance result, which in turn comes from the
 * persisted state (the receipt is read back from the database). Rules:
 *   - `completed` is true ONLY for a persisted SUCCEEDED operation whose
 *     stored receipt says SUCCESS — nothing else may be presented as done;
 *   - UNKNOWN_OUTCOME (and a completion that could not be persisted) is its
 *     own phase with `reconciliationRequired`, never FAILED, never SUCCEEDED,
 *     and `retryAllowed` is false: nothing is retried automatically;
 *   - a denial carries only its code.
 */
import type { GovernanceResult } from "../persistence/governance.ts";
import type { OperationState } from "../persistence/store.ts";

export type RuntimePhase = OperationState | "DENIED";

export interface RuntimePresentation {
  phase: RuntimePhase;
  /** true only for a persisted SUCCEEDED operation with a SUCCESS receipt. */
  completed: boolean;
  /** UNKNOWN_OUTCOME: the effect may or may not have happened. */
  reconciliationRequired: boolean;
  /** Always false in this runtime: no automatic retry of anything. */
  retryAllowed: false;
  operationId: string | null;
  denialCode: string | null;
  /** Present while a decision is pending: what the approver must echo back. */
  gate: { gateId: string; bindingHash: string; expiresAt: string } | null;
  receipt: { receiptId: string; outcome: string; receiptHash: string } | null;
  replayed: boolean;
}

const EMPTY = { completed: false, reconciliationRequired: false, retryAllowed: false as const, gate: null, receipt: null, replayed: false };

export function presentResult(r: GovernanceResult): RuntimePresentation {
  switch (r.status) {
    case "DENIED":
      return { ...EMPTY, phase: "DENIED", operationId: null, denialCode: r.code };
    case "OUTCOME_UNCONFIRMED":
      return { ...EMPTY, phase: "UNKNOWN_OUTCOME", reconciliationRequired: true, operationId: r.operationId, denialCode: null };
    case "REMAINS_UNKNOWN":
      return { ...EMPTY, phase: "UNKNOWN_OUTCOME", reconciliationRequired: true, operationId: r.operationId, denialCode: null };
    default: {
      const op = r.operation;
      const gate = r.status === "AWAITING_APPROVAL" && r.gate
        ? { gateId: r.gate.gateId, bindingHash: r.gate.bindingHash, expiresAt: r.gate.expiresAt }
        : null;
      const receipt = r.receipt
        ? { receiptId: r.receipt.receipt.receipt_id, outcome: r.receipt.receipt.outcome, receiptHash: r.receipt.receiptHash }
        : null;
      const phase = op.state;
      return {
        phase,
        completed: r.status === "FINAL" && phase === "SUCCEEDED" && receipt !== null && receipt.outcome === "SUCCESS",
        reconciliationRequired: phase === "UNKNOWN_OUTCOME" && r.reconciliation === null,
        retryAllowed: false,
        operationId: op.operationId,
        denialCode: null,
        gate,
        receipt,
        replayed: r.replayed,
      };
    }
  }
}
