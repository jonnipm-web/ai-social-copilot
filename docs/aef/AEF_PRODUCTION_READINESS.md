# AEF Production Readiness

Mission `IV-IVE-AEF-RUNTIME-INTEGRATION-01`. **Production deploy: BLOCKED.**

This document records what is now closed and what still blocks a production
deployment gate. Nothing here authorizes a deploy, a production migration, real
tools or a production runtime.

## F-01 — migration content integrity: CLOSED (repository side)

`supabase/migration_manifest.tsv` holds the sha256 of the canonical content
(CRLF → LF) of every migration, with a status:
- **APPLIED_PRODUCTION**: the 16 predecessors, frozen;
- **LAB**: the chain 23–27.

`scripts/ci/migration_manifest.sh --check` fails closed on:
- a changed content under the same name;
- a rename or a deletion;
- an unexpected file;
- a duplicate or malformed row, or an unknown status;
- a missing or empty manifest.

`--write` never rewrites a frozen digest and never drops a vanished file.
The manifest's APPLIED_PRODUCTION and LAB lists must equal the deploy
preflight's predecessor and chain lists (tested).
Evidence: `MIGRATION_MANIFEST_TESTS: PASS` (15 scenarios) and mutants MF1a–MF1d.

**Residual (documented, not claimed).** Production's
`supabase_migrations.schema_migrations` stores names and apply-time versions,
not content digests. For rows applied by the CLI it also stores the statements,
which this mission did not read. The manifest proves the **repository** did not
change. On the database side, the equivalence evidence remains the deploy
preflight's structural fingerprints of the chain. Nothing proves that
production's 16 predecessor bodies equal the repository files: their functional
markers were verified read-only (`AEF_PRODUCTION_MIGRATION_RECONCILIATION.md`),
their bodies were not.

## F-03 — future AEF sequence safety: CLOSED

Four layers, none relying on the author remembering the rule:
1. **Database-time proof in CI** — `supabase/tests/aef_sequence_catalog_scan.sql`
   runs on the fully migrated, production-parity schema. It checks every AEF
   sequence (named `aef_*` **or** owned by an `aef_*` table), for every API role
   and privilege, plus PUBLIC.
2. **Adversarial test** — a "future migration" that creates an identity column
   and an `OWNED BY` sequence without the REVOKE **must** fail both the scan and
   the lint. The same migration with the canonical block must pass
   (`AEF_FUTURE_SEQUENCE_GUARD: PASS`).
3. **Author-time lint** — `scripts/ci/aef_sequence_lint.sh`.
4. **Deploy-time** — the preflight scans every AEF sequence, and `20260927`'s
   postcondition does the same.

Global default privileges were **not** changed: that would alter every future
sequence of the project and is an architectural decision.

## F-04 — disposable runner resources: CLOSED

`scripts/ci/lib_disposable.sh` is used by the DB runner, the fingerprint tool
and the executor experiment:
- each run has a unique identity (time + pid + 48 random bits);
- a resource is registered only after this run's CREATE succeeded, so a
  collision is never adopted;
- every resource carries an ownership marker (`COMMENT … 'aef-disposable:<run-id>'`);
- cleanup runs on EXIT, INT and TERM and drops only resources whose marker still
  matches;
- a cleanup failure is reported and fails the run, and the exit code is
  preserved.

Tested: normal run, failure, SIGTERM, SIGINT, collision, foreign database/role
with the same prefix, tampered marker, cleanup failure, and 30 parallel
identities (`DISPOSABLE_CLEANUP_TESTS: PASS`).

## Transactional executor — `PRODUCTION_EXECUTOR_TRANSACTIONAL: NOT_VERIFIED` → deploy BLOCKED

`scripts/ci/executor_transaction_experiment.sh` runs on a local/CI disposable
database only. The canary is DDL A → DDL B → error → DDL C. A non-atomic
control must be detected, or the experiment fails (no false PASS).

| Executor | Result |
|---|---|
| `psql -f` (plain) — control | **NOT_ATOMIC** (A and B survive) — detected |
| `psql --single-transaction -f` | **ATOMIC** |
| Supabase CLI 2.118.0 `db push --db-url`, one file | **ATOMIC**, no history row after the failure |
| CLI, two files (first OK, second fails) | per-file atomic: the first file stays applied and recorded |
| CLI, the real `20260926` failing late (~1300 lines, DO blocks) | **ATOMIC** |
| CLI against a **production-like history** (apply-time versions ≠ file prefixes, as observed read-only in production) | **REFUSED** — `DbPushMissingLocalError`; the CLI proposes `supabase migration repair`, a history rewrite that policy forbids |
| MCP `apply_migration` (the path that produced production's apply-time versions) | **NOT_VERIFIED** — remote-only; never exercised |

Conclusions:
- The CLI is transactional per file, but it **cannot** deploy onto production's
  current history without a forbidden repair.
- `psql -1` is transactional, but it does not record history.
- MCP is unverified.

**ARCHITECTURAL DECISION REQUIRED (Agente Martins / Owner): which executor a
future production deploy uses, and how the history is recorded.** Until then,
production deploy stays BLOCKED.

## Production readiness summary

| Item | Status |
|---|---|
| Runtime (LAB) | PASS — mock tools only; not deployable |
| F-01 | CLOSED (repository); production content equivalence = structural only |
| F-03 | CLOSED |
| F-04 | CLOSED |
| Executor transactional semantics | psql -1 / CLI per-file atomic (local); CLI incompatible with production history; MCP NOT_VERIFIED |
| `READY_FOR_PRODUCTION_DEPLOYMENT_GATE` | **NO** — executor decision pending |
