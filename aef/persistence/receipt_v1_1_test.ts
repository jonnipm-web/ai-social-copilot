/**
 * aef-receipt/1 (legacy) and aef-receipt/1.1 shapes — TS validator and the
 * canonical JSON Schema must agree on every fixture (IV-AEF-HARDENING-01).
 */
import AjvModule from "npm:ajv@8";
import { assert, assertEquals } from "jsr:@std/assert@1";
import { validateAefReceipt } from "./receipt_v1_1.ts";

// deno-lint-ignore no-explicit-any
const Ajv = AjvModule as any;
const schema = JSON.parse(await Deno.readTextFile(new URL("../../contracts/aef/schema/aef-receipt.v1_1.schema.json", import.meta.url)));
const ajvValidate = new Ajv({ strict: false, allErrors: true }).compile(schema);

const TS = "2026-09-26T00:00:00.000000Z";
const U = (n: number) => `a${n}000000-0000-4000-8000-00000000000${n}`;
const H = (c: string) => c.repeat(64);

function executionV1(): Record<string, unknown> {
  return {
    receipt_version: "aef-receipt/1", receipt_id: U(1), operation_id: U(2), request_id: U(3), subject_id: U(4),
    domain: "internal", action: "internal.mock_effect_reversible", tool_id: "internal.mock_effect_reversible",
    action_class: "REVERSIBLE", resource_type: null, resource_id: null, binding_hash: H("b"), payload_hash: H("a"),
    policy_version: "aef-policy/2026-09-25.1", risk_version: "aef-risk/2026-09-25.1", human_gate_id: null,
    approver_id: null, policy_decision: "ALLOWED", outcome: "UNKNOWN_OUTCOME", final_state: "UNKNOWN_OUTCOME",
    reason_code: "LEASE_EXPIRED", side_effect_observed: null, attempt_count: 1, registered_at: TS, authorized_at: TS,
    completed_at: TS,
  };
}
const executionV11 = (): Record<string, unknown> => ({ ...executionV1(), receipt_version: "aef-receipt/1.1", receipt_kind: "EXECUTION" });
function reconciliation(): Record<string, unknown> {
  return {
    receipt_version: "aef-receipt/1.1", receipt_kind: "RECONCILIATION", receipt_id: U(5), operation_id: U(2),
    request_id: U(3), subject_id: U(4), action: "internal.mock_effect_reversible", tool_id: "internal.mock_effect_reversible",
    binding_hash: H("b"), original_receipt_id: U(1), original_receipt_hash: H("c"), original_outcome: "UNKNOWN_OUTCOME",
    verdict: "CONFIRMED_APPLIED", reconciler_kind: "VERIFIER", reconciler_ref: H("d"), evidence_kind: "VERIFIER_CHECK",
    evidence_hash: H("e"), operation_policy_version: "aef-policy/2026-09-25.1", operation_risk_version: "aef-risk/2026-09-25.1",
    policy_version: "aef-policy/2026-09-25.1", risk_version: "aef-risk/2026-09-25.1", reconciled_at: TS,
  };
}

const VALID: [string, Record<string, unknown>, string, string][] = [
  ["legacy v1 execution", executionV1(), "aef-receipt/1", "EXECUTION"],
  ["v1.1 execution", executionV11(), "aef-receipt/1.1", "EXECUTION"],
  ["v1.1 execution success with project", { ...executionV11(), outcome: "SUCCESS", final_state: "SUCCEEDED",
    resource_type: "project", resource_id: U(6), side_effect_observed: true }, "aef-receipt/1.1", "EXECUTION"],
  ["v1.1 reconciliation", reconciliation(), "aef-receipt/1.1", "RECONCILIATION"],
];

const INVALID: [string, Record<string, unknown>][] = [
  ["v1 reinterpreted with a kind", { ...executionV1(), receipt_kind: "EXECUTION" }],
  ["v1.1 without kind", { ...executionV1(), receipt_version: "aef-receipt/1.1" }],
  ["unknown version", { ...executionV11(), receipt_version: "aef-receipt/2" }],
  ["UNKNOWN_OUTCOME dressed as success", { ...executionV11(), outcome: "SUCCESS" }],
  ["success without SUCCEEDED", { ...executionV11(), final_state: "SUCCEEDED", outcome: "PARTIAL" }],
  ["payload smuggled in", { ...executionV11(), parameters: { amount: 1 } }],
  ["missing binding", (() => { const r = executionV11(); delete r.binding_hash; return r; })()],
  ["forged subject id", { ...executionV11(), subject_id: "admin" }],
  ["second attempt claimed", { ...executionV11(), attempt_count: 2 }],
  ["resource id without type", { ...executionV11(), resource_id: U(6) }],
  ["reconciliation of a non-unknown", { ...reconciliation(), original_outcome: "FAILURE" }],
  ["invented verdict", { ...reconciliation(), verdict: "SUCCEEDED" }],
  ["raw operator id instead of hash", { ...reconciliation(), reconciler_ref: U(7) }],
  ["raw evidence smuggled in", { ...reconciliation(), evidence_ref: "ticket-123" }],
  ["reconciliation without original hash", (() => { const r = reconciliation(); delete r.original_receipt_hash; return r; })()],
  ["execution fields on a reconciliation", { ...reconciliation(), outcome: "SUCCESS" }],
  ["empty tool id (Codex HG3-04)", { ...executionV11(), tool_id: "" }],
  ["empty tool id on a reconciliation", { ...reconciliation(), tool_id: "" }],
];

Deno.test("RV-01 valid receipts: TS validator and JSON Schema both accept, with the right version/kind", () => {
  for (const [label, r, version, kind] of VALID) {
    const v = validateAefReceipt(r);
    assert(v.ok, `${label}: ${JSON.stringify(v)}`);
    assertEquals([v.version, v.kind], [version, kind], label);
    assert(ajvValidate(r), `${label} (schema): ${JSON.stringify(ajvValidate.errors)}`);
  }
});

Deno.test("RV-02 forged, altered or reinterpreted receipts: both refuse", () => {
  for (const [label, r] of INVALID) {
    assert(!validateAefReceipt(r).ok, `${label} accepted by the validator`);
    assert(!ajvValidate(r), `${label} accepted by the schema`);
  }
});

Deno.test("RV-03 non-objects are refused", () => {
  for (const v of [null, [], "receipt", 1]) assert(!validateAefReceipt(v).ok);
});
