# AEF Execution Receipt (persisted, `aef-receipt/1` → `aef-receipt/1.1`)

Mission `IV-AEF-PERSISTENCE-01`. Table `aef_receipts`, built only by
`aef__issue_receipt` inside the terminal transition's transaction.

## Authority

- Issued by the database, from the operation row, in the same transaction
  as the terminal state. The service returns the receipt it read back; it
  never builds one (the v0 `receipt_builder.ts` is not used by the
  persistent path).
- One receipt per operation (`UNIQUE(operation_id)`), only for a terminal
  operation, consistent with it (insert trigger re-checks subject, binding,
  final state, outcome and hash).
- Append-only: UPDATE/DELETE/TRUNCATE refused for every role, including the
  table owner (triggers); end users have no write grant at all.
- Anchored: the `RECEIPT_ISSUED` audit event carries `receipt_hash` in the
  subject's hash chain.
- Returned to callers as a deep-frozen object.

## Content

`receipt_version, receipt_id, operation_id, request_id, subject_id, domain,
action, tool_id, action_class, resource_type, resource_id, binding_hash,
payload_hash, policy_version, risk_version, human_gate_id, approver_id,
policy_decision, outcome, final_state, reason_code, side_effect_observed,
attempt_count, registered_at, authorized_at, completed_at`.

No payload, prompt, credential or free text. `reason_code` is a code
(`TOOL_SUCCEEDED`, `LEASE_EXPIRED`, `REJECTED_BY_SUBJECT`, …).

| final_state | outcome | policy_decision |
|---|---|---|
| SUCCEEDED | SUCCESS | ALLOWED |
| FAILED (no side effect) | FAILURE | ALLOWED |
| FAILED (after side effect) | PARTIAL | ALLOWED |
| UNKNOWN_OUTCOME | UNKNOWN_OUTCOME | ALLOWED |
| REJECTED / EXPIRED / CANCELLED / INVALIDATED | NOT_EXECUTED | ALLOWED if it had been authorized, else DENIED |

## Verification (forgery resistance)

`aef_verify_receipt({receipt})` → valid only if: the receipt id exists; the
submitted object equals the stored jsonb exactly; the stored hash matches
its content; the hash is anchored by a `RECEIPT_ISSUED` event whose own
event hash is intact; and the subject's whole audit chain verifies
(`RECEIPT_ANCHOR_INVALID` / `RECEIPT_CHAIN_INVALID`, Codex G1-04, T17c/d).
Tested: altered field → `RECEIPT_MISMATCH`; invented id → `RECEIPT_UNKNOWN`;
malformed → `RECEIPT_MALFORMED`; a v0 in-memory `buildSuccess()` receipt →
invalid (PG-16, SQL T11).

## Versions (IV-AEF-HARDENING-01)

| Version | Kinds | Issued | Status |
|---|---|---|---|
| `aef-receipt/1` | execution (no `receipt_kind` field) | before migration `20260926000000` | legacy: stored as issued, never rewritten or re-labelled; still verifiable (L01/L02, HP legacy cycle) |
| `aef-receipt/1.1` | `EXECUTION` (= v1 fields + `receipt_kind`) | every terminal operation after the hardening migration | current |
| `aef-receipt/1.1` | `RECONCILIATION` | by `aef_reconcile`, complementary to an `UNKNOWN_OUTCOME` execution receipt | current, append-only (AEF_UNKNOWN_OUTCOME_RECONCILIATION.md) |

Canonical schema: `contracts/aef/schema/aef-receipt.v1_1.schema.json`
(`oneOf` the three shapes, `additionalProperties: false`, outcome ↔
final_state consistency). TS validator `aef/persistence/receipt_v1_1.ts`;
parity-tested with ajv (RV-01..03). The store refuses any receipt that does
not validate (fail closed).

Backward compatibility, tested on a real database: v1 receipts created
before the migration keep their exact content and hash, still verify after
the migration, a chain mixing v1 and v1.1 events verifies, and after the
hardening rollback every v1 and v1.1 receipt still verifies (runner
`AEF_LEGACY: PASS` / `DOWN_OK`).

Verification covers both tables: a receipt is valid only if it is stored
byte-for-byte, its hash matches, its anchor event (`RECEIPT_ISSUED` or
`RECONCILIATION_RECORDED`) is intact and the whole subject chain verifies
(from its checkpoint when the prefix was pruned). A purged receipt is
`RECEIPT_UNKNOWN`.

## Relation to contract v1 (`contracts/aef/ExecutionReceipt`)

The wire contract v1 has outcomes `SUCCESS|FAILURE|PARTIAL|ROLLED_BACK|NOT_EXECUTED`
and no `UNKNOWN_OUTCOME`. The persisted receipt is a separate, server-side
record (`aef-receipt/1`); it is not coerced into v1, because mapping
`UNKNOWN_OUTCOME` to any v1 value would state something that is not known.
The wire contract `ExecutionReceipt` v1 (`execution-receipt.v1.schema.json`)
is unchanged: its validator still accepts only `contract_version: "1.0"`,
so nothing is silently reinterpreted. Exposing receipts to clients over the
wire (and choosing whether that is the persisted `aef-receipt/1.1` or a wire
`1.1` derived from it) belongs to the runtime-integration gate.
