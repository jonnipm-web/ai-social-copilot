# AEF Production Deployment Preconditions (runbook + manifest)

Mission `IV-AEF-PRE-RUNTIME-CLOSURE-01`. **Status: DOCUMENTED, NOT EXECUTED.**
This is not a deploy authorization. Deploying requires a dedicated mission
approved by Agente Martins **and** Paulo.

## Manifest (apply order, all in ONE change window)

| # | File | Required | Notes |
|---|---|---|---|
| 1 | `20260923000000_entitlement_subject_roles.sql` | yes (AEF hardening depends on it) | needs `profiles(id, role)` |
| 2 | `20260924000000_ive_memory_governance.sql` | no (independent of AEF) | may be applied in the same window, or in its own mission |
| 3 | `20260925000000_aef_persistence.sql` | yes | fails fast (`AEF_PRECONDITION`) if its dependencies are missing; revokes its own sequence (no exposure window) |
| 4 | `20260926000000_aef_hardening.sql` | yes | fails fast without `subject_roles` or without the complete persistence layer |
| 5 | `20260927000000_aef_sequence_privileges.sql` | yes, after 3 (before or after 4) | re-asserts P03; the postcondition fails the migration if any API role or PUBLIC keeps access |

**Every file is applied with client encoding UTF-8**
(`PGCLIENTENCODING=UTF8`; the post-apply preflight fingerprint detects a
double-encoded apply). **Every file is applied in a single transaction.** Examples: `psql -1 -f`, or an
executor that wraps each file in a transaction. The Lab proves atomicity with
`psql --single-transaction` (late-failure injection). The transactional
behaviour of the Supabase CLI / MCP `apply_migration` is **NOT_VERIFIED** in this
mission and must be confirmed before a deploy, or the deploy must use `psql -1`.

**Update (IV-IVE-AEF-RUNTIME-INTEGRATION-01, `docs/aef/AEF_PRODUCTION_READINESS.md`):**
measured on disposable databases, never on production:
- psql `-1` and Supabase CLI 2.118.0 are **atomic per file**;
- the CLI **refuses** to push onto a production-like history (apply-time
  versions ≠ file prefixes) unless the history is "repaired", which is
  forbidden;
- MCP `apply_migration` remains NOT_VERIFIED.

The choice of executor and of history recording is an **architectural decision**
pending with Agente Martins / Owner. Production deploy stays BLOCKED.

Rollbacks exist in `supabase/rollbacks/`. The rollback of `20260927` is a verified
no-op by design. The hardening rollback refuses to run once evidence exists (see
`AEF_RETENTION_ERASURE_MODEL.md`).

## Runbook (future, gated)

1. **PRECHECK**: run `supabase/preflight/aef_deploy_preflight.sql` against the
   target. Run it only as `psql -v ON_ERROR_STOP=1 -f`, with no wrapper that adds
   statements. It is READ-ONLY, runs inside `BEGIN TRANSACTION READ ONLY …
   ROLLBACK`, and reads metadata only. The expected result is
   `AEF_DEPLOY_PREFLIGHT: PASS — … remaining, in order: entitlement_subject_roles -> ive_memory_governance -> aef_persistence -> aef_hardening -> aef_sequence_privileges`.
   Any `FAIL` → STOP.
2. **RECONCILIATION**: re-confirm `AEF_PRODUCTION_MIGRATION_RECONCILIATION.md`.
   The 16 predecessors must be MATCHED, and the chain must be NOT_PRESENT or
   consistent. Any new DRIFTED or UNKNOWN row → STOP.
3. **DEPENDENCY**: confirm `profiles(id, role)`, `projects(id uuid, user_id uuid
   NOT NULL)`, `auth.users(id uuid)`, `sha256`, `gen_random_uuid` and
   `hashtextextended`. The preflight checks these, and the migrations re-check
   them (fail fast).
4. **ORDER**: apply in manifest order, as `postgres`, one transaction per file,
   in one window. Never apply AEF alone. If a rewind of the audit sequence is
   ever suspected, the owner runs
   `setval('public.aef_audit_events_id_seq', max(id))` after `20260927`.
5. **PRIVILEGE**: after applying, re-run the preflight. The expected result is
   `PASS … remaining, in order: (none)`. Then run the read-only catalog checks
   from `AEF_PRODUCTION_PRIVILEGE_PREFLIGHT.md`: no API role privilege on AEF
   sequences or tables beyond the contract, and EXECUTE only for service_role on
   the 13 RPCs.
6. **OWNER GATE**: Paulo approves on the evidence of steps 1–5 **before** step 4
   happens. The approval is recorded in the mission report.
7. **Future deploy**: Edge Functions and the IVE → AEF runtime integration are
   separate missions (`IV-IVE-AEF-RUNTIME-INTEGRATION-01`, not started).

## STOP conditions

- The preflight FAILs, or cannot run read-only.
- A predecessor is missing, or the history and the schema disagree
  (history without objects, objects without history).
- Stray `aef_*` objects exist without `aef_persistence` in the history.
- The sequence defaults are permissive and the plan does not include `20260927`.
- Any AEF sequence is exposed, or the privilege contract of an existing AEF
  install is violated (the preflight reports these).
- The migration executor cannot guarantee one transaction per file.
- Any migration raises `AEF_PRECONDITION` (AE010) or `AEF_POSTCONDITION` (AE011).
- The migration history appears to need a manual repair. Never insert, delete or
  rename rows in `supabase_migrations.schema_migrations` to "make it match".
- Any step would require a secret, or a privilege broader than the documented
  contract.

## Not in scope of this runbook

The pre-existing SECURITY DEFINER functions (P06/P07) are in
DEFERRED_SECURITY_BACKLOG. AEF does not depend on them: this is verified by
catalog test S13 and by the static check `AEF_DEFINER_BOUNDARY: PASS`.
