# AEF Execution Receipt (persisted, `aef-receipt/1`)

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
its content; and the hash is anchored by a `RECEIPT_ISSUED` event.
Tested: altered field → `RECEIPT_MISMATCH`; invented id → `RECEIPT_UNKNOWN`;
malformed → `RECEIPT_MALFORMED`; a v0 in-memory `buildSuccess()` receipt →
invalid (PG-16, SQL T11).

## Relation to contract v1 (`contracts/aef/ExecutionReceipt`)

The wire contract v1 has outcomes `SUCCESS|FAILURE|PARTIAL|ROLLED_BACK|NOT_EXECUTED`
and no `UNKNOWN_OUTCOME`. The persisted receipt is a separate, server-side
record (`aef-receipt/1`); it is not coerced into v1, because mapping
`UNKNOWN_OUTCOME` to any v1 value would state something that is not known.
An additive contract revision (`1.1`, adding `UNKNOWN_OUTCOME`) is
**deferred** to the runtime-integration gate, under the contract
versioning policy.
