/**
 * Persisted AEF receipt formats (IV-AEF-HARDENING-01).
 *
 *   aef-receipt/1    legacy EXECUTION receipts issued before the hardening
 *                    migration. Read and verified as-is, never rewritten or
 *                    reinterpreted as 1.1.
 *   aef-receipt/1.1  receipt_kind EXECUTION   — terminal outcome of an operation
 *                    receipt_kind RECONCILIATION — complementary, append-only
 *                    record that reconciles an UNKNOWN_OUTCOME; the original
 *                    receipt stays unchanged and is referenced by hash.
 *
 * Canonical JSON Schema: contracts/aef/schema/aef-receipt.v1_1.schema.json
 * (parity-tested). The database is the authority that issues and verifies
 * receipts (aef_verify_receipt); this validator only refuses a malformed or
 * inconsistent shape before anything reads it (fail closed).
 */
export type ReceiptKind = "EXECUTION" | "RECONCILIATION";
export type ReceiptValidation =
  | { ok: true; version: "aef-receipt/1" | "aef-receipt/1.1"; kind: ReceiptKind }
  | { ok: false; errors: string[] };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const HEX64 = /^[0-9a-f]{64}$/;
const CODE = /^[A-Z][A-Z0-9_]{0,63}$/;
const VERSION = /^[a-z0-9._/-]{1,64}$/;
const TS = /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$/;
const ACTION = /^[a-z][a-z0-9_]*([.][a-z][a-z0-9_]*)+$/;

const EXECUTION_V1_KEYS = [
  "receipt_version", "receipt_id", "operation_id", "request_id", "subject_id", "domain", "action", "tool_id",
  "action_class", "resource_type", "resource_id", "binding_hash", "payload_hash", "policy_version", "risk_version",
  "human_gate_id", "approver_id", "policy_decision", "outcome", "final_state", "reason_code", "side_effect_observed",
  "attempt_count", "registered_at", "authorized_at", "completed_at",
] as const;
const RECONCILIATION_KEYS = [
  "receipt_version", "receipt_kind", "receipt_id", "operation_id", "request_id", "subject_id", "action", "tool_id",
  "binding_hash", "original_receipt_id", "original_receipt_hash", "original_outcome", "verdict", "reconciler_kind",
  "reconciler_ref", "evidence_kind", "evidence_hash", "operation_policy_version", "operation_risk_version",
  "policy_version", "risk_version", "reconciled_at",
] as const;

const OUTCOME_FOR: Record<string, string[]> = {
  SUCCEEDED: ["SUCCESS"],
  FAILED: ["FAILURE", "PARTIAL"],
  UNKNOWN_OUTCOME: ["UNKNOWN_OUTCOME"],
  REJECTED: ["NOT_EXECUTED"],
  EXPIRED: ["NOT_EXECUTED"],
  CANCELLED: ["NOT_EXECUTED"],
  INVALIDATED: ["NOT_EXECUTED"],
};

function exactKeys(r: Record<string, unknown>, keys: readonly string[], errors: string[]): void {
  const got = Object.keys(r);
  for (const k of got) if (!keys.includes(k)) errors.push(`unknown field '${k}'`);
  for (const k of keys) if (!(k in r)) errors.push(`missing field '${k}'`);
}

function check(errors: string[], ok: boolean, what: string): void {
  if (!ok) errors.push(what);
}
const isStr = (v: unknown, re?: RegExp): boolean => typeof v === "string" && (!re || re.test(v));
const isStrOrNull = (v: unknown, re?: RegExp): boolean => v === null || isStr(v, re);

export function validateAefReceipt(value: unknown): ReceiptValidation {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return { ok: false, errors: ["object required"] };
  const r = value as Record<string, unknown>;
  const errors: string[] = [];
  const version = r.receipt_version;

  if (version === "aef-receipt/1.1" && r.receipt_kind === "RECONCILIATION") {
    exactKeys(r, RECONCILIATION_KEYS, errors);
    for (const k of ["receipt_id", "operation_id", "request_id", "subject_id", "original_receipt_id"]) check(errors, isStr(r[k], UUID), k);
    for (const k of ["binding_hash", "original_receipt_hash", "reconciler_ref", "evidence_hash"]) check(errors, isStr(r[k], HEX64), k);
    for (const k of ["operation_policy_version", "operation_risk_version", "policy_version", "risk_version"]) check(errors, isStr(r[k], VERSION), k);
    check(errors, isStr(r.action, ACTION), "action");
    check(errors, isStr(r.tool_id) && (r.tool_id as string).length >= 1 && (r.tool_id as string).length <= 200, "tool_id");
    check(errors, r.original_outcome === "UNKNOWN_OUTCOME", "original_outcome must be UNKNOWN_OUTCOME");
    check(errors, r.verdict === "CONFIRMED_APPLIED" || r.verdict === "CONFIRMED_NOT_APPLIED", "verdict");
    check(errors, r.reconciler_kind === "VERIFIER" || r.reconciler_kind === "OPERATOR", "reconciler_kind");
    check(errors, isStr(r.evidence_kind, CODE), "evidence_kind");
    check(errors, isStr(r.reconciled_at, TS), "reconciled_at");
    return errors.length ? { ok: false, errors } : { ok: true, version: "aef-receipt/1.1", kind: "RECONCILIATION" };
  }

  if (version === "aef-receipt/1" || (version === "aef-receipt/1.1" && r.receipt_kind === "EXECUTION")) {
    exactKeys(r, version === "aef-receipt/1" ? EXECUTION_V1_KEYS : [...EXECUTION_V1_KEYS, "receipt_kind"], errors);
    for (const k of ["receipt_id", "operation_id", "request_id", "subject_id"]) check(errors, isStr(r[k], UUID), k);
    for (const k of ["binding_hash", "payload_hash"]) check(errors, isStr(r[k], HEX64), k);
    for (const k of ["policy_version", "risk_version"]) check(errors, isStr(r[k], VERSION), k);
    check(errors, isStr(r.action, ACTION), "action");
    check(errors, ["core", "quant", "impact", "internal"].includes(r.domain as string), "domain");
    check(errors, ["READ_ONLY", "REVERSIBLE", "CONSEQUENTIAL"].includes(r.action_class as string), "action_class");
    check(errors, isStr(r.tool_id) && (r.tool_id as string).length >= 1 && (r.tool_id as string).length <= 200, "tool_id");
    check(errors, (r.resource_type === null && r.resource_id === null) ||
      (r.resource_type === "project" && isStr(r.resource_id, UUID)), "resource");
    check(errors, isStrOrNull(r.human_gate_id, UUID) && isStrOrNull(r.approver_id, UUID), "gate refs");
    check(errors, r.policy_decision === "ALLOWED" || r.policy_decision === "DENIED", "policy_decision");
    const allowed = OUTCOME_FOR[r.final_state as string];
    check(errors, Array.isArray(allowed) && allowed.includes(r.outcome as string), "outcome does not match final_state");
    check(errors, isStrOrNull(r.reason_code, CODE), "reason_code");
    check(errors, r.side_effect_observed === null || typeof r.side_effect_observed === "boolean", "side_effect_observed");
    check(errors, r.attempt_count === 0 || r.attempt_count === 1, "attempt_count");
    check(errors, isStr(r.registered_at, TS) && isStrOrNull(r.authorized_at, TS) && isStr(r.completed_at, TS), "timestamps");
    return errors.length
      ? { ok: false, errors }
      : { ok: true, version: version as "aef-receipt/1" | "aef-receipt/1.1", kind: "EXECUTION" };
  }
  return { ok: false, errors: [`unsupported receipt version/kind '${String(version)}'/'${String(r.receipt_kind)}'`] };
}
