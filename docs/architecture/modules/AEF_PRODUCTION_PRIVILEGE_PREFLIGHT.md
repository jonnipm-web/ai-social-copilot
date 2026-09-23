# AEF Production Privilege Preflight

Mission `IV-AEF-HARDENING-01`. **Status: NOT_VERIFIED.**

## Why not verified

Reading production catalogs requires a connection to the production project.
In this environment the production read path (Supabase MCP) was refused by
the session permission policy in an earlier mission and must not be retried
automatically; no other production credential exists here, and none may be
added. Nothing about production was observed, so nothing is claimed.

## How to verify (Owner, read-only, ~1 minute)

1. Open the production project's SQL editor.
2. Paste `supabase/preflight/aef_privilege_preflight.sql` and run it. It is
   a `BEGIN TRANSACTION READ ONLY … ROLLBACK` block with catalog `SELECT`s
   only: it cannot change grants, schema, RLS or data.
3. Return the output; the deltas below are then filled in.

## Expected vs observed

| # | Check | EXPECTED (what the AEF migrations assume) | OBSERVED | DELTA | RISK if different | FUTURE REMEDIATION |
|---|---|---|---|---|---|---|
| P01 | roles | `service_role` BYPASSRLS, `anon`/`authenticated` not superuser, migrations run as `postgres` | NOT_VERIFIED | — | definer functions would be owned by an unexpected role | apply migrations only as `postgres`; re-check ownership after apply |
| P02 | `public` CREATE | no CREATE for anon/authenticated/service_role | NOT_VERIFIED | — | low: every AEF function pins `search_path = pg_catalog, pg_temp` and schema-qualifies every object | revoke CREATE on public from API roles if present (separate, approved mission) |
| P03 | default privileges | defaults may grant ALL on new tables/functions to anon/authenticated/service_role (Supabase default) | NOT_VERIFIED | — | none for AEF: both migrations explicitly REVOKE ALL from PUBLIC/anon/authenticated/service_role and re-grant the minimum | none required; keep explicit revokes in every future AEF migration |
| P04 | existing `aef_*` objects | none | NOT_VERIFIED | — | name collision / pre-existing grants | stop and investigate before applying |
| P05 | dependencies | `public.projects(id uuid, user_id uuid)`, `public.subject_roles`, `auth.users`, `sha256(bytea)`, `gen_random_uuid()` | NOT_VERIFIED | — | migration fails (safe: transactional) | apply `20260923000000_entitlement_subject_roles` first |
| P06 | SECURITY DEFINER in public | known list, all with pinned search_path, none executable by anon unintentionally | NOT_VERIFIED | — | pre-existing definer exposure (outside AEF) | separate hardening mission |
| P07 | functions executable by PUBLIC | only intended ones | NOT_VERIFIED | — | inherited EXECUTE on unrelated functions | separate hardening mission |
| P08 | role search_path settings | none that put a writable schema first | NOT_VERIFIED | — | none for AEF (pinned per function) | — |
| P09 | RLS on `projects`, `subject_roles` | enabled | NOT_VERIFIED | — | AEF reads them as owner (definer), unaffected; relevant to the rest of the app | — |
| P10 | migration history | ends before `20260923000000` (Lab migrations not applied) | NOT_VERIFIED | — | drift between Lab and production | reconcile history before any apply |

## Disposable-database baseline (observed, for comparison)

On the disposable PostgreSQL 17 with Supabase stubs (which reproduce the
Supabase default privileges) the privilege catalog is asserted by tests
T14p (persistence) and H01 (hardening): no write privilege for any API role
on any AEF table, EXECUTE only for service_role on the 13 RPCs, no EXECUTE on
any `aef__*` helper, every AEF function pinned to `pg_catalog, pg_temp`.
