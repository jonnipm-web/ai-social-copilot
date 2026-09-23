# AEF Persistence Model

Mission `IV-AEF-PERSISTENCE-01`. Migration
`supabase/migrations/20260925000000_aef_persistence.sql` — **Module Lab only,
not applied to production or any shared database.** Tested on a disposable
PostgreSQL 17 (local and CI job `disposable-db-rls-ci`).

## Principle

PostgreSQL is the only implementation of the AEF state machine. The
TypeScript service (`aef/persistence/governance.ts`) decides *policy* (who,
which tool, which risk class) and runs the tool; every *state* change is a
service_role-only SQL function that locks the operation row, checks the
transition, writes the audit trail and — for terminal states — issues the
receipt, all in one transaction. There is no in-memory copy of the state
machine to drift from it.

## Tables

| Table | Purpose | Key constraints |
|---|---|---|
| `aef_operations` | one governed business operation | `UNIQUE(subject_id, idempotency_key_hash)`, `UNIQUE(request_id)`, `attempt_count IN (0,1)`, CONSEQUENTIAL ⇒ gated, resource = owned project or none |
| `aef_human_gates` | the approval for one operation (1:1) | `UNIQUE(operation_id)`, bound `binding_hash` + `policy_version` |
| `aef_receipts` | the final, server-issued receipt (1:1, terminal only) | `UNIQUE(operation_id)`, `receipt_hash = sha256(receipt)`, append-only |
| `aef_audit_events` | minimized, hash-chained audit trail per subject | `UNIQUE(subject_id, seq)`, `event_hash` checked on insert, append-only |
| `aef_audit_heads` | chain head per subject (append serialization) | advances by exactly one verified event |

Stored: ids, hashes, codes, timestamps. **Never stored:** payload,
parameters, prompt, intent text, JWT, credential, approval secret, e-mail.
Idempotency keys are stored as `sha256('aef-idem/1:' || subject || ':' || key)`.

## Hashes

| Hash | Computed by | Content |
|---|---|---|
| `payload_hash` | service (`canonical.ts`) | canonical JSON of `{intent, parameters, constraints, quant_execution_tier, context_ref}` — everything the tool can observe |
| `binding_hash` | database | `jsonb_build_array('aef-binding/1', subject, domain, action, tool, class, resource_type, resource_id, payload_hash, policy_version, risk_version, requires_gate)` |
| `receipt_hash` | database | `sha256(receipt::text)` (jsonb text is deterministic) |
| `event_hash` | database | `jsonb_build_array('aef-audit/1', subject, seq, op, type, from, to, reason, ref_hash, ts, prev_hash)` |

## Functions (EXECUTE: service_role only)

| Function | Effect |
|---|---|
| `aef_register_operation` | create or idempotently replay; conflict on a different binding; resource ownership; initial gate |
| `aef_decide_gate` | bound APPROVE/REJECT by the operation's subject |
| `aef_claim_execution` | the only path to `EXECUTING`: consumes the gate, `attempt_count 0→1`, issues a token and a lease |
| `aef_complete_execution` | token-checked terminal transition + receipt |
| `aef_cancel_operation` | before execution only; no compensation |
| `aef_recover` | expired approvals → `EXPIRED`; lease-expired executions → `UNKNOWN_OUTCOME` (`FOR UPDATE SKIP LOCKED`) |
| `aef_get_operation`, `aef_record_denial`, `aef_verify_receipt`, `aef_verify_audit_chain` | read / audit / integrity |

Every function takes exactly one jsonb object and rejects unknown keys and
wrong JSON types (`ARGUMENT_REJECTED`) — no mass assignment. Functions are
`SECURITY INVOKER` with a pinned `search_path`: no `SECURITY DEFINER`
anywhere, so no privilege expansion.

## Concurrency

- Idempotent registration: `INSERT … ON CONFLICT DO NOTHING` on the unique
  key; the losing transaction waits for the winner, then reads its row.
- Transitions: `SELECT … FOR UPDATE` on the operation row; lock order is
  always operation → gate → audit head (no cycles; recovery uses `SKIP LOCKED`).
- Execution: exactly one claim can move `AUTHORIZED → EXECUTING`
  (`attempt_count` is a `CHECK (0,1)` column, re-checked by the guard trigger).
- Proven with 40 parallel connections (tests PG-07..PG-10): one operation,
  one gate decision, one tool invocation, one receipt.

**Guarantee claimed:** *at most one* tool invocation per operation, and a
durable, truthful record of what is known about it. **Not claimed:**
exactly-once side effects — a crash between the tool's effect and the
completion write is recorded as `UNKNOWN_OUTCOME`, not resolved.

## Performance notes

- All hot paths are primary-key or unique-index lookups; open-operation
  sweep uses a partial index on non-terminal states.
- The audit head serializes writes **per subject** only (not globally).
- One registration = 1 insert + 1–2 audit appends; one execution =
  claim + complete ≈ 6 row writes. No table scans in the request path.
- `aef_verify_audit_chain` is O(events of one subject) — an audit tool,
  not a request-path call.
- Test transport spawns one `psql` per call (test-only); production goes
  through PostgREST `rpc` with a service_role client.

## Retention / erasure

Operations, gates, receipts and audit events are never deleted by the
application (triggers refuse DELETE/TRUNCATE). They carry no foreign key to
`auth.users`, so deleting a user does not cascade into — or get blocked by —
the audit trail. A privacy-erasure procedure for AEF records is **deferred**
(needs an explicit retention decision; see AEF_SECURITY_MODEL.md).

## Rollback

The migration is additive (new tables/functions only). Rollback on a
database where it was applied = drop the five `aef_*` tables and the
`aef_*` functions; nothing else references them. The guard triggers block
`TRUNCATE`/`DELETE`, so rollback requires `DROP TABLE` by the owner — a
deliberate, reviewable act.
