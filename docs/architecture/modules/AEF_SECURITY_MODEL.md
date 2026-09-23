# AEF Security Model (persistent)

Mission `IV-AEF-PERSISTENCE-01`. Threat → control → proof (executed test).
SQL tests: `supabase/tests/aef_persistence_rls_test.sql` (T00..T17d, T14s).
Integration: `aef/persistence/governance_pg_test.ts` (PG-01..21, real
PostgreSQL). Unit: `governance_unit_test.ts` (GU), `canonical_test.ts` (CJ),
`ive_intent_mapping_test.ts` (IM).

## Identities

| Identity | Access | Notes |
|---|---|---|
| `anon` | nothing (no grant on tables or functions) | T01 |
| `authenticated` (owner) | SELECT own operations (minus `execution_token`), gates, receipts, audit events | RLS `subject_id = auth.uid()`; T02/T03 |
| `authenticated` (foreign) | sees nothing of another subject | T02 |
| `service_role` | EXECUTE on the thirteen `aef_*` RPCs (10 + `aef_reconcile`, `aef_purge`, `aef_erase_subject`); SELECT on tables; **no** INSERT/UPDATE/DELETE, **no** `aef__*` helpers | privileged infrastructure identity; RLS does not restrict it, privileges do: it can change state only through the RPCs (T14s) |
| table owner / superuser | can disable triggers | out of the application trust boundary. Tampering that does not recompute the chain is detected (T17b, T17c/d, H05g, H11); an owner who recomputes every hash — or forges a pruning checkpoint and the head together — can make a chain verify (Codex HG3-01). Closing that requires anchoring chain heads outside the database (e.g. periodic signed/published head hashes): DEFERRED |
| SERVICE / SYSTEM actors | `UNSUPPORTED_BY_V0` | no service identity exists; unchanged from v0 |

## Threats

| # | Threat | Control | Proof |
|---|---|---|---|
| 1 | Client claims another user | subject = verified GoTrue identity; actor.id must match | PG-06, GU-06 |
| 2 | Client self-approves via request fields | `human_gate_ref` refused; prohibited fields | PG-06, IM-02 |
| 3 | Another user approves | approver = subject (function + trigger), no oracle | T09a, T14c, PG-04 |
| 4 | Approval reused for a changed operation | binding hash (subject/action/tool/resource/payload/policy/risk) | T08b, T09b, PG-03, PG-06 |
| 5 | Approval reused after policy change | policy version checked at decision and claim → INVALIDATED | T12, T12b, PG-18 |
| 6 | Approval reused twice | gate consumed on claim; `attempt_count ≤ 1` | T10c/d, PG-01 |
| 7 | Double execution under concurrency | unique key + row lock + single claim | PG-07..10 (40 connections) |
| 8 | Idempotency leak across users | key namespaced by subject | T00, PG-04 |
| 9 | Replay of a request id | `UNIQUE(request_id)` | T08c, PG-03 |
| 10 | Foreign / unknown project | ownership checked in SQL; same code for both | T07a/b, PG-05, PG-17 |
| 11 | Mass assignment into RPCs | one jsonb arg, key allowlist, JSON type checks | T06a..f, GU-09 |
| 12 | End user writes tables | no INSERT/UPDATE/DELETE grant | T04 |
| 13 | service_role skips a state / inserts an operation / forges audit via helpers | no direct write grant, no helper EXECUTE; RPCs are the only path | T14s-a..h |
| 13b | owner skips a state / reverts a terminal / rewrites bound columns | guard triggers (apply to the owner) | T14a..j |
| 14 | Forged receipt | DB-issued only, insert-consistency trigger, verify = exact match + hash + intact anchor + intact chain | T11, T14h, T17c/d, PG-16 |
| 14b | Tool input differs from the approved binding | tool request rebuilt from the hashed payload + bound + server-owned fields only | PG-19 |
| 15 | Receipt / audit altered after the fact | append-only triggers (even for the owner) | T14g, T15a..c |
| 16 | Audit altered with triggers disabled | per-subject hash chain verification | T17b |
| 17 | Invented success after crash / timeout / store failure | UNKNOWN_OUTCOME; OUTCOME_UNCONFIRMED; no retry | PG-11..13, GU-05 |
| 18 | Late success rewriting history | completion requires state EXECUTING + token | T16c, PG-12 |
| 19 | Store down or replying garbage | fail closed; tool never runs without a claim | GU-01..04 |
| 20 | IVE intent as authority | strict mapping, subject from credential, no approval | IM-*, PG-17 |
| 20b | Authority aliases in the payload (`owner_id`, `risk`, `tool_allowed`…) | refused at any depth, normalized names | PG-06, IM-09 |
| 21 | Payload ambiguity | canonical JSON, no coercion, no normalization, bounded | CJ-01..05 |
| 22 | Oversized input / resource exhaustion | payload ≤ 16 KiB, depth ≤ 8, ≤ 1000 nodes; TTL ≤ 24 h; gate ≤ 1 h; lease ≤ 5 min; ≤ 50 open operations per subject (soft) | CJ-04, T06d, PG-06, T18, PG-21 |
| 23 | Secrets / PII in storage or logs | only ids, hashes, codes; no logging added | schema review |
| 24 | Tool reaches real systems | only mock tools registered; real IVE actions have no tool | PG-17, tool registry |
| 25 | Privilege expansion through functions | SECURITY DEFINER only on the ten RPCs (pinned search_path, no dynamic SQL, EXECUTE only service_role); helpers/triggers not executable by any API role | T01, T05, T14s |

## Hardening (IV-AEF-HARDENING-01)

Trust boundary, unchanged: service_role is the AEF service itself. It can
call the RPCs with any subject id (the RPCs trust the service for identity
and policy); it cannot write any AEF table, call internal helpers, delete
evidence, forge a tombstone/erasure record or reconcile without an
authorized reconciler. Retention and erasure deletes happen only inside
`aef_purge` / `aef_erase_subject`.

| # | Threat | Control | Proof |
|---|---|---|---|
| H1 | Purge lets a key/request id run again | idempotency tombstone, checked before and after insert | H03j/k, HP-08, mutant HM05 |
| H2 | Premature purge / purge of open, unknown or held operations | policy days, terminal only, UNKNOWN only when reconciled, legal hold | H03a..e, HM07, HM08 |
| H3 | Purge breaks verifiability | OPERATION_PURGED event, checkpoint-based chain verification, live evidence never pruned | H03h, H04a..e |
| H4 | Erasure of another subject / damage to other chains | subject-scoped deletes; per-subject chains | H08k, HP-09, HM09 |
| H5 | Erasure while evidence is still needed | account must be deleted; hold, in-flight execution, unreconciled unknown block it | H08a..e, HM10 |
| H6 | Erased operator identity lingers | reconciler_id nulled, receipt holds only a hash | H08l..o |
| H7 | Audit flooding (own chain or victim's via approval spam) | per-subject window, coalesced durable counters, no drop | H05, H09, HP-10, HM01 |
| H8 | Silencing security events via quota | counts preserved per code and anchored in the chain | H05d/g, HM02, HM11 |
| H9 | Reconciliation without authority / by the subject | registered verifier for the tool, or admin operator ≠ subject | H06a..c, HP-03/04, HM03 |
| H10 | UNKNOWN_OUTCOME turned into success / history rewritten | append-only record, operation & original receipt immutable, verdict set closed | H06i..p, RV-02, HM04 |
| H11 | Forged / unbound reconciliation receipt | insert guard, verification (stored equality + hash + anchor + chain), bound to original receipt hash | H06m, HM06, RV-02 |
| H12 | Deleting evidence with the maintenance flag | no API role holds DELETE; flag is transaction-local inside the two definer RPCs | H07a..i, HM12 |
| H13 | Legacy v1 receipts reinterpreted | stored as issued; validator refuses a v1 receipt with a kind | L01/L02, RV-02 |
| H14 | Rollback silently destroying evidence or control state | hardening rollback refuses when tombstones/checkpoints/erasures/reconciliations/counters, active legal holds, registered verifiers or a changed policy exist | AEF_HARDENING_ROLLBACK_REFUSAL, runner hold check |
| H15 | Hold placed while purge/erasure runs (race) | per-subject advisory lock: hold trigger exclusive, erasure exclusive + re-check, purge try-lock + re-check | HP-11, HP-15 (deterministic), HM15 |
| H16 | Recovery vs erasure deadlock | one lock order everywhere: window → head | HP-12, HP-14 (deterministic), HM14 |
| H17 | Erased subject re-created / key reused after erasure | registration shared lock + `SUBJECT_ERASED`; denial recording refused | H10a..d, HP-13, HM16 |
| H18 | Unbounded pending counters via invented codes | closed code set; unknown → `UNLISTED` | H10e/f, HM17 |
| H19 | Erased or deleted operator reconciles | operator must exist in auth.users and not be erased | H08m, HM18 |
| H20 | Reconciliation re-pointed at another receipt | guard + verification bind to the original receipt id/hash | H11, HM19 |

## v1 restrictions (fail closed)

- Delegation (`delegation_ref`) → `DELEGATION_UNSUPPORTED`.
- Resources: only `project` (or none) → `RESOURCE_TYPE_UNSUPPORTED`.
- Idempotency key required for every operation.
- Quant / Impact non-read actions → `POLICY_DENIED` (service and SQL).
- Only the subject approves.

## Residual risks (documented, not closed here)

- service_role compromise = can call the RPCs with any subject it chooses
  (the RPCs trust the service for identity and policy); it can no longer
  write tables or forge audit events directly. Inherent to a server-side
  identity; mitigated, not prevented.
- Retention periods are provisional defaults (365 / 730 days) pending the
  Owner's legal decision; the mechanism is implemented (IV-AEF-HARDENING-01).
- `UNKNOWN_OUTCOME` has no reconciliation workflow yet. A tool that
  ignores the abort can still apply its effect after AEF recorded
  `UNKNOWN_OUTCOME` (PG-20): the record stays truthful ("unknown"), the
  effect is not prevented. Real tools must honor the abort signal and be
  idempotent on the operation id.
- Audit growth is bounded per subject and window (coalescing,
  IV-AEF-HARDENING-01); request-level throttling belongs to the future
  runtime endpoint.
- Reconciliation verifiers exist only as test mocks; with no verifier
  registered, only an admin operator can reconcile (by design).
- Self-approval is the only approval mode (no four-eyes).
- The audit trail grows with refused attempts of verified users (bounded
  per request; no rate limit in this layer).
- Not deployed; production behavior NOT_VERIFIED.

## Codex gates — findings and dispositions

All reviews READ-ONLY, new thread each, no-write snapshot verified before/after.

| Gate | Verdict | Finding | Sev | Disposition |
|---|---|---|---|---|
| G1 persistence/authorization (on 3f753d5) | FAIL | G1-01 tool input not fully bound | P1 | ACCEPTED — fixed 027d286 (PG-19) |
| | | G1-02 service_role direct writes | P1 | ACCEPTED — fixed 027d286 (T14s, T14p) |
| | | G1-03 service_role could call aef__* helpers | P1 | ACCEPTED — fixed 027d286 (T14s, T14p) |
| | | G1-04 receipt verify ignored anchor/chain | P2 | ACCEPTED — fixed 027d286 (T17c/d) |
| | | G1-05 rollback not executable | P2 | ACCEPTED — fixed 027d286 (AEF_ROLLBACK) |
| | | G1-06 no retention/erasure | P2 | DEFERRED — Owner/architect retention decision |
| G1 fix verification (on 027d286) | PASS WITH FINDINGS | G1-01..05 FIXED, G1-06 documented | — | — |
| | | G1V-01 PG-19 not executed by reviewer | P2 | ACCEPTED — executed locally and in CI |
| | | G1V-02 definer search_path included public | P2 | ACCEPTED — every AEF function pinned to `pg_catalog, pg_temp`, asserted (T14p, mutant M19) |
| | | G1V-03 retention | P3 | DEFERRED (same as G1-06) |
| G2 concurrency/failure (on 027d286) | PASS WITH FINDINGS | G2-01 concurrency tests lacked overlap proof | P2 | ACCEPTED — overlap instrumentation, peak ≥ 20 of 40 asserted (PG-07..10) |
| | | G2-02 abort-ignoring tool crossing the lease untested | P2 | ACCEPTED — PG-20 + documented residual |
| | | G2-03 unbounded denial audit growth | P2 | DEFERRED — AEF hardening (rate limit / retention) |
| G3 IVE/AEF boundary (on 027d286) | PASS WITH FINDINGS | G3-01 action map shallow-frozen, override unenforced | P2 | ACCEPTED — `defineIveActionTable` (IM-08) |
| | | G3-02 authority aliases allowed in parameters | P2 | ACCEPTED — alias denylist in mapping and AEF (IM-09, PG-06, mutant M20) |
| FINAL full diff 2197759..d77367f | PASS WITH FINDINGS (no P0/P1; A1–A10, A13–A15 HOLD) | CF-01 no admission / retention bounds | P2 | PARTIALLY ACCEPTED — open-operation cap 50/subject (T18, mutant M21); audit retention / rate limit DEFERRED to AEF hardening |
| | | CF-02 rollback not migration-scoped | P2 | ACCEPTED — rollback drops only the 5 tables + 36 functions by exact name; runner proves an unrelated `aef_*` object survives |
| CF fix verification (on 99f0c8f) | PASS WITH FINDINGS | CF-01 PARTIALLY FIXED (retention deferred), CF-02 FIXED | — | — |
| | | CFV-01 admission pre-check could refuse a concurrent replay | P2 | ACCEPTED — admission moved after conflict resolution, inside a subtransaction (PG-21, mutant M21) |

Mutation proof: 21/21 mutants killed (M01–M21: idempotency conflict,
ownership, claim state, binding, policy version, recovery outcome, RLS,
audit hash, late completion, foreign approver, client approval, undeclared
failure, timeout, claim-less execution, payload echo, helper EXECUTE, raw
tool input, chain check in receipt verification, search_path, authority
aliases, open-operation cap).
