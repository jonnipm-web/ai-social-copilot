# AEF Retention & Erasure Model

Mission `IV-AEF-HARDENING-01`. Migration `20260926000000_aef_hardening.sql`
(Module Lab only, **not applied anywhere**). Tests: `aef_hardening_test.sql`
H03/H04/H07/H08, `hardening_pg_test.ts` HP-08/HP-09.

## Principles

- **Minimization first.** AEF records carry ids, hashes, codes and
  timestamps only (no payload, prompt, JWT, credential or free text); the
  idempotency key is stored hashed, reconciliation evidence and operator
  identity are stored hashed in receipts.
- **Nothing disappears silently.** Every purge leaves an `OPERATION_PURGED`
  audit event and an idempotency tombstone; every audit pruning leaves a
  verifiable checkpoint; every erasure leaves a pseudonymous, count-only
  record.
- **The database decides.** Retention runs only through `aef_purge`,
  erasure only through `aef_erase_subject` (SECURITY DEFINER, service_role
  EXECUTE only). They are the only paths where the append-only guards allow
  DELETE (a transaction-local flag that no API role can exploit: no API role
  has any DELETE privilege).

## Retention policy (`aef_retention_policy`, owner-managed, one row)

| Setting | Default | Meaning |
|---|---|---|
| `terminal_retention_days` | 365 | terminal operations (+ gate, receipt, reconciliation) become purgeable |
| `audit_retention_days` | 730 (≥ terminal) | audit prefix becomes prunable |
| `denial_window_seconds` / `denial_window_limit` | 60 / 20 | audit rate limit (AEF_AUDIT_RATE_LIMIT.md) |
| `erasure_blocks_on_unreconciled` | true | erasure refused while an UNKNOWN_OUTCOME is unreconciled |
| `operator_reconciliation_enabled` | false | human (operator) reconciliation allowed at all (Owner decision; AEF_UNKNOWN_OUTCOME_RECONCILIATION.md) |
| `policy_ref` | `aef-retention/2026-09-26.1-provisional` | version of the policy in force (returned by every purge) |

**The periods are provisional engineering defaults, not legal periods.**
They are configurable without code changes (owner-only UPDATE), bounded by
CHECK constraints (30..3650 days). The legal/compliance periods are an
**Owner decision** (see "Owner decisions" below).

## Per category

| Category | Active | Terminal | Purge rule | What remains after purge |
|---|---|---|---|---|
| A. operations | never purged while open (AWAITING_APPROVAL/AUTHORIZED/EXECUTING) | `terminal_retention_days` after `completed_at` | not under legal hold; UNKNOWN_OUTCOME only once reconciled and the reconciliation is itself past retention | idempotency **tombstone** (subject, key hash, request id, op id, final state, receipt hash) + `OPERATION_PURGED` event |
| B. human gates | with their operation | with their operation | same as A | nothing (decision is in the audit chain) |
| C. receipts (+ reconciliations) | with their operation | with their operation | same as A | receipt hash in the tombstone and in the chain (`RECEIPT_ISSUED`, `OPERATION_PURGED`); `aef_verify_receipt` → `RECEIPT_UNKNOWN` |
| D. audit events | never pruned past an event of a live operation | `audit_retention_days` after `occurred_at` | prefix only, contiguous, stops at the first event that is recent or belongs to an operation that still exists; not under legal hold | **checkpoint** (last pruned seq + hash): verification restarts from it |
| E. audit heads | kept | kept | only erasure deletes a head | — |
| tombstones | kept for the subject's lifetime | — | only erasure deletes them; afterwards the subject itself is refused (`SUBJECT_ERASED`), so no key can be reused | — |

Why tombstones are kept: purging an operation must never let its idempotency
key or request id start a *new* operation (that would be a second execution
of an already-executed request). `aef_register_operation` refuses retired
keys (`IDEMPOTENCY_KEY_RETIRED`) and request ids (`REQUEST_REPLAYED`), also
when the purge commits while the registration is waiting on the unique index
(post-insert re-check, SQLSTATE AE003).

Legal / compliance hold: `aef_legal_holds` (owner-managed) blocks purge,
audit pruning and erasure for a subject. Holds, purge, erasure and
registration are serialized per subject with a transaction-scoped advisory
lock (Codex HG1-01, HG2-02): writing a hold takes it exclusively (trigger),
erasure takes it exclusively and re-checks, registration takes it shared,
purge only *tries* it and re-checks the hold (it never waits, so it cannot
deadlock). A hold committed before the purge/erasure reaches the subject is
always honored (HP-11).

## Erasure (`aef_erase_subject`)

Chosen strategy: **hard delete of the subject's AEF records + a minimized,
pseudonymous erasure record + refusal of the erased subject afterwards.**
Rationale:

- Per-subject hash chains mean deleting one subject's whole chain cannot
  affect any other subject's chain or receipt (tested: H08k, HP-09).
- Crypto-shredding would require per-subject keys and encryption of fields
  that are already only ids/hashes — added complexity with no real gain.
- Pseudonymizing the subject id inside the chain is impossible without
  breaking the hashes that commit to it.

Behavior:

| Condition | Result |
|---|---|
| auth user still exists | `ERASURE_ACCOUNT_ACTIVE` (erasure runs **after** account deletion, so an erased subject can never submit again → no key reuse) |
| legal hold | `ERASURE_BLOCKED_HOLD` |
| an execution in flight | `ERASURE_BLOCKED_ACTIVE` |
| unreconciled UNKNOWN_OUTCOME (policy flag) | `ERASURE_BLOCKED_UNRECONCILED` |
| otherwise | deletes operations, gates, receipts, reconciliations, audit events/head/window/pending/coalesced/checkpoint and tombstones of the subject; writes `aef_erasures` (sha256 subject ref, counts) → `ERASED`. Where the subject acted as operator on others' reconciliations nothing needs detaching: operator ids are never stored, only a hash in the receipt (Codex HG3-03), and an erased operator can never reconcile again (HG1-02) |
| repeated | `ALREADY_ERASED` (idempotent; concurrent calls: exactly one `ERASED`, HP-09) |

Server-authoritative: only the account-deletion pipeline (service_role)
calls it; there is no end-user entry point. After erasure the database
refuses the subject everywhere it could re-create data: registration
(`SUBJECT_ERASED`, also for a registration racing the erasure — HP-13),
`aef_record_denial` (`SUBJECT_ERASED`, serialized with the erasure by the
shared subject lock — HP-18), operator reconciliation
(`RECONCILER_NOT_AUTHORIZED`). Erasure locks window before head, like every
append; recovery never waits on windows or operations (SKIP LOCKED) and
skips a subject whose erasure holds the lock, so they cannot deadlock
(HG2-01, HP-12/14/16).

## Owner decisions (not blocking; safe defaults in place)

1. Legal retention periods for AEF operations and audit (replace the
   provisional 365 / 730 days).
2. Whether an unreconciled UNKNOWN_OUTCOME may block an erasure request
   (default: yes, block; alternative: erase and keep only the pseudonymous
   record).
3. Who may place/release legal holds and through which audited path (today:
   owner SQL only).
4. Whether to enable human (operator) reconciliation of UNKNOWN_OUTCOME
   (default: disabled; only registered verifiers reconcile).
