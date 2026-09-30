# AEF Production Readiness

Mission `IV-IVE-AEF-RUNTIME-INTEGRATION-01`. **Production deploy: BLOCKED.**

This document records what is now closed and what still blocks a production
deployment gate. Nothing here authorizes a deploy, a production migration, real
tools or a production runtime.

## F-01 — migration content integrity: CLOSED (repository side)

`supabase/migration_manifest.tsv` holds the sha256 of the canonical content of
every migration. Only a CR at the end of a line is dropped (CRLF → LF); a
standalone CR anywhere else is content (Codex RG3-01). Each row has a status:
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
   sequence, in **any schema** (Codex RG3-02). A sequence counts as an AEF
   sequence if it:
   - is named `aef_*` in `public`;
   - is owned (identity / serial / `OWNED BY`) by an `aef_*` table; or
   - is **used by a column default** of an `aef_*` table.

   Each is checked for every API role and privilege, plus PUBLIC, using
   effective privileges, so group roles and later grants count. The deploy
   preflight uses the same predicate.
2. **Adversarial test** — a "future migration" without the REVOKE **must** fail
   both the scan and the lint. It creates:
   - an identity column;
   - an `OWNED BY` sequence;
   - a sequence **not owned** but used by an AEF default;
   - a sequence in **another schema** used by an AEF default, with an explicit
     grant (PostgreSQL forbids `OWNED BY` across schemas).

   The same migration with the canonical block must pass
   (`AEF_FUTURE_SEQUENCE_GUARD: PASS`).
3. **Author-time lint** — `scripts/ci/aef_sequence_lint.sh`. The lint is a hint:
   it can be bypassed, for example by dynamic SQL. The catalog scan is the
   proof.
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
with the same prefix, tampered marker, cleanup failure, 30 parallel
identities, **SIGKILL + sweep**, and an atomic role marker
(`DISPOSABLE_CLEANUP_TESTS: PASS`).

After Codex RG3-03:
- A role and its ownership marker are created in **one transaction**.
- `CREATE DATABASE` cannot run inside a transaction. A database killed between
  CREATE and COMMENT stays **unmarked** and is never dropped automatically.
- Traps cannot run after SIGKILL or host loss. Leftovers that carry this
  library's marker are reclaimed by `scripts/ci/disposable_sweep.sh`, which:
  - is a dry-run by default;
  - is prefix-scoped;
  - drops only resources whose marker matches their own run id, and only
    after a minimum age;
  - reports unmarked resources and never drops them;
  - only ever puts into SQL a name that matches the library's exact grammar,
    and still identifier-quotes it (Codex RG3V-01). Tested with a crafted,
    marked name carrying SQL.

## Transactional executor — `PRODUCTION_EXECUTOR_TRANSACTIONAL: NOT_VERIFIED` → deploy BLOCKED

`scripts/ci/executor_transaction_experiment.sh` runs on a local/CI disposable
database only. The canary is DDL A → DDL B → error → DDL C.

Two controls must be detected, or the experiment fails (no false PASS):
- plain psql on the canary;
- plain psql on the **real** `20260926` failing late, judged by the
  whole-schema fingerprint (Codex RG3-04).

A coverage self-test (Codex RG3V-02) must see each covered object class move
the fingerprint, or the experiment fails. The classes are:
- views and materialized views;
- enums, domains, composite and range types;
- rules;
- the public schema ACL;
- extensions;
- columns (including column ACLs);
- policies (roles, command, USING, WITH CHECK);
- function metadata (language, parallel, strict, leakproof, cost, rows) —
  Codex RG3W-01;
- sequence parameters, relation options, replica identity, inheritance,
  extended statistics, comments, trigger enabled state, default privileges and
  event triggers — Codex RG3X-01.
- replica-identity and clustered index selection, column identity / generated /
  collation / storage / compression / statistics target, and the full
  extended-statistics definition and target — Codex RG3Y-01/02 (self-test
  case count 38 including this one; mutant MEX6 KILLED);
- constraint validation state (rendered as NOT VALID by pg_get_constraintdef;
  locked by a self-test case) — Codex RG3Z-02.

Comments are covered on public relations, columns, functions and types only;
comments on schemas, roles, extensions and other shared objects are a
documented P2 residual (Codex RG3Z-03).

The fingerprint does not cover data (including sequence current values, which
are not transactional anyway), publications/subscriptions, large objects, or
objects outside `public` other than extensions and the global default
privileges and event triggers. This is documented, not claimed.

Every expected CLI result is **asserted**: any deviation exits 1 with
`EXECUTOR_EVIDENCE_CHANGED` (Codex RG3-05). CI runs the psql parts. The CLI part
runs **locally only**, on a pinned version, because CI must not download and
execute it (Codex RG3-06). The recorded run is in
`docs/aef/evidence/executor_experiment_supabase_cli_2.118.0.txt`. It was
re-recorded on the final code with a clean tree (Codex RG3V-03). This is local
evidence obtained through `npx`, so it is not hermetic supply-chain evidence.

| Executor | Result |
|---|---|
| `psql -f` (plain) — control | **NOT_ATOMIC** (A and B survive) — detected |
| `psql --single-transaction -f` | **ATOMIC** (canary and the real `20260926` failing late) |
| `psql -f`, real `20260926` failing late — fingerprint control | **NOT_ATOMIC** — detected |
| Supabase CLI 2.118.0 `db push --db-url`, one file | **ATOMIC**, no history row after the failure |
| CLI, two files (first OK, second fails) | per-file atomic: the first file stays applied and recorded |
| CLI, the real `20260926` failing late (~1300 lines, DO blocks) | **ATOMIC** (whole-schema fingerprint unchanged, no history row) |
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
