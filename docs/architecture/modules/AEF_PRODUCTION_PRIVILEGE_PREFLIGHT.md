# AEF Production Privilege Preflight

Mission `IV-AEF-HARDENING-01`. **Status: EXECUTED READ-ONLY on 2026-09-24** (Owner authorization: read-only
preflight only, no production change). Project `ai-social-copilot`
(`nzngvbajrnruknpzzjbf`, PostgreSQL 17.6). One catalog-only `SELECT` inside
`BEGIN TRANSACTION READ ONLY … ROLLBACK`; nothing was written, granted,
applied or deployed.

## Expected vs observed

| # | Check | EXPECTED | OBSERVED | DELTA | RISK | FUTURE REMEDIATION |
|---|---|---|---|---|---|---|
| P01 | roles | migrations run as `postgres`; `service_role` BYPASSRLS; API roles not superuser | `postgres` (not superuser, BYPASSRLS), `service_role` BYPASSRLS, `anon`/`authenticated` no login, no super | none | — | apply AEF migrations as `postgres` (definer owner) |
| P02 | `public` CREATE | no CREATE for API roles | anon/authenticated/service_role: CREATE = false on public, auth, extensions | none | — | — |
| P03 | default privileges | defaults grant ALL to API roles (Supabase default) | tables `arwdDxtm`, functions `X`, **sequences `rwU`** to anon/authenticated/service_role (grantors postgres and supabase_admin) | **sequences**: the disposable stubs do not reproduce sequence defaults, and the AEF migrations do not revoke on `aef_audit_events_id_seq` | an API role could call `nextval`/`setval` on the audit identity sequence: no data exposure, but `setval` backwards would make audit inserts fail (availability; AEF fails closed) | future Lab migration: `REVOKE ALL ON SEQUENCE public.aef_audit_events_id_seq FROM PUBLIC, anon, authenticated, service_role`; add sequence defaults to the test stubs and a catalog test |
| P04 | existing `aef_*` objects | none | none (tables and functions) | none | — | — |
| P05 | dependencies | `projects(id uuid, user_id uuid)`, `subject_roles`, `auth.users`, `sha256`, `gen_random_uuid`, `hashtextextended` | all present **except `public.subject_roles`** | **`subject_roles` missing** (Entitlement migration `20260923000000` not applied in production) | `aef_reconcile` (operator path) references it at run time | apply order must be `20260923…` → `20260924…` → `20260925…` → `20260926…`; never apply AEF alone |
| P06 | SECURITY DEFINER in public | pinned search_path, not callable by anon unless intended | 10 pre-existing definer functions with `search_path=public`; anon EXECUTE on `get_current_user_role`, `handle_new_user`, `is_admin_user`, `validate_asset_*`; authenticated on `cleanup_old_diagnostic_sessions`, `try_reserve_ai_quota`, `refund_ai_quota` | pre-existing, outside AEF | privilege exposure depends on each function body (not reviewed here) | separate hardening mission for pre-existing definer functions (not AEF) |
| P07 | functions executable by PUBLIC | only intended | 13 pre-existing functions (triggers/helpers incl. the definer ones above) | pre-existing, outside AEF | same as P06 | same mission as P06 |
| P08 | role search_path | none putting a writable schema first for API roles | `postgres`: `"$user", public, extensions`; API roles: timeouts only | none for AEF (every AEF function pins `pg_catalog, pg_temp`) | — | — |
| P09 | RLS | `projects`, `subject_roles` RLS on | `projects` RLS on (not forced); `subject_roles` absent | see P05 | — | — |
| P10 | migration history | ends before the Lab migrations | last applied `20260917205611`; ids are apply-time timestamps, not the repo file names | ids do not map 1:1 to repo files | drift is not provable from ids alone | before any apply: reconcile production history against repo migrations (schema diff), in its own gated mission |

### Follow-up — IV-AEF-PRE-RUNTIME-CLOSURE-01 (2026-09-25)

| # | Status |
|---|---|
| P03 | **CLOSED** in the Lab: `20260927000000_aef_sequence_privileges.sql` + production-parity sequence default in the stubs (`AEF_SEQUENCE_PRIVILEGE_MODEL.md`). Not applied in production. |
| P05 | **RECONCILED**: fail-fast preconditions in every AEF migration; manifest order `20260923 → (20260924) → 20260925 → 20260926 → 20260927` (`AEF_PRODUCTION_DEPLOYMENT_PRECONDITIONS.md`). |
| P06 / P07 | **DEFERRED_SECURITY_BACKLOG** — not modified; AEF does not depend on them. |
| P10 | **RECONCILED**: history keyed by name, 16/16 MATCHED, chain NOT_PRESENT, 0 drift (`AEF_PRODUCTION_MIGRATION_RECONCILIATION.md`); READ-ONLY deploy preflight `supabase/preflight/aef_deploy_preflight.sql`. |

### Conclusion

Production is compatible with the AEF migrations' privilege model (no
CREATE on public for API roles, explicit revokes override the permissive
defaults) with **two deltas to close before any future apply**: the audit
identity sequence privileges (P03) and the missing Entitlement dependency
`subject_roles` (P05). Pre-existing definer functions (P06/P07) are outside
AEF and deserve their own hardening mission. Nothing was changed.

## Disposable-database baseline (observed, for comparison)

On the disposable PostgreSQL 17 with Supabase stubs (which reproduce the
Supabase default privileges — tables, functions and, since
IV-AEF-PRE-RUNTIME-CLOSURE-01, sequences) the privilege catalog is asserted by tests
T14p (persistence) and H01 (hardening): no write privilege for any API role
on any AEF table, EXECUTE only for service_role on the 13 RPCs, no EXECUTE on
any `aef__*` helper, every AEF function pinned to `pg_catalog, pg_temp`.
