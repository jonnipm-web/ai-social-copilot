# 11 — Supabase Architecture

One Supabase project serves Web and Android. Its project ref is hardcoded in
`scripts/ci/resolve_deploy_selection.sh`, `.github/workflows/deploy-selftest.yml` and
`.github/workflows/x4r-authorization-matrix.yml` (as a *refuse-if-seen* guard). The value is not
repeated in this manual.

## 1. Auth and JWT

| Concern | Implementation | Status |
|---|---|---|
| Identity provider | Supabase GoTrue: email/password + Google OAuth (`auth_service.dart`, `google_sign_in`) | `IMPLEMENTED` |
| Profile bootstrap | Trigger `on_auth_user_created` → `handle_new_user()` (SECURITY DEFINER) inserts `profiles(id, email)` | `IMPLEMENTED` |
| Platform JWT gate | `verify_jwt = true` for 19 functions; `false` only for `stripe-webhook` (`supabase/config.toml`, `.github/deploy-allowlist.tsv`) | `VERIFIED` |
| Real user gate | `resolveAuthenticatedUser()` (`supabase/functions/_shared/auth.ts`) calls `auth.getUser(token)`; rejects the anon/publishable key (which passes `verify_jwt`) and any non-session JWT; throws, never returns null | `VERIFIED`, `TESTED` (11 static tests) |
| Client session | `supabase_flutter` (pinned `<2.15.0` to avoid a web passkeys crash, `pubspec.yaml`) | `IMPLEMENTED` |

## 2. Roles and entitlements in the database

- Postgres roles used: `anon`, `authenticated` (both NOLOGIN), `service_role` (BYPASSRLS).
- Application role: `profiles.role` (`free | pro | premium | beta_tester | admin`) + `profiles.monthly_limit`.
- Helper functions: `is_admin_user()` (SECURITY DEFINER, STABLE, search_path hardened by migration `20260907120001`), `get_current_user_role()` (SECURITY DEFINER, `search_path=public`).
- Anti-self-promotion: `prevent_self_privilege_escalation()` — SECURITY **INVOKER** trigger, BEFORE INSERT OR UPDATE on `profiles`; blocks changes to `role/monthly_limit/is_active` unless `service_role` or admin. INSERT compares against defaults (`free`/5/true).
- Module entitlements: **not in the database on E-MAIN**. E-INT02 adds `subject_roles` and a server manifest (`_shared/entitlement.ts`, `module_policy.ts`, EF `module-access`).

## 3. RPCs and SECURITY DEFINER inventory (E-MAIN)

| Function | Security | search_path | Callable by | Purpose |
|---|---|---|---|---|
| `try_reserve_ai_quota()` / `try_reserve_ai_quota(uuid, text)` | DEFINER | `public` | `authenticated` (revoked from `anon`, PUBLIC) | Atomic monthly reservation; idempotent per `(key, operation, period)` |
| `refund_ai_quota()` / `refund_ai_quota(uuid)` | DEFINER | `public` | `authenticated` | Compensating refund by reservation id; returns boolean |
| `apply_stripe_subscription_state(...)` | DEFINER | `public` | `service_role` only | Atomic subscriptions + profiles write, ordered by Stripe `event.created` |
| `is_admin_user()` | DEFINER | hardened | RLS policies | Admin check |
| `get_current_user_role()` | DEFINER | `public` | RLS policies | Role lookup |
| `handle_new_user()` | DEFINER | hardened | trigger | Profile bootstrap |
| `validate_asset_id_ownership()`, `validate_asset_parent_ownership()`, `validate_asset_resource_ownership()` | DEFINER | `public, pg_catalog` | triggers | Asset ownership integrity |
| `cleanup_old_diagnostic_sessions(retention_days)` | DEFINER | `public` | `authenticated` (anon/PUBLIC revoked); body raises unless `is_admin_user()` | Diagnostics retention (1–3650 days) |
| `prevent_self_privilege_escalation()` | INVOKER | `public` | trigger | Role protection |
| `set_updated_at*`, `update_*_updated_at` | INVOKER | hardened (022) | triggers | Timestamps |

## 4. Migrations and governance

| Item | Evidence | Status |
|---|---|---|
| Canonical baseline | `20260907120000_baseline_production_pre_x4r.sql` — **captured from live production** via catalog queries (IVE-X4R-MB2), replacing 22 legacy files | `IMPLEMENTED` |
| Legacy migrations | `docs/legacy-migrations-archive/` (001–021 + duplicate 001): never replayed; documented divergence from live (recursive `profiles_admin_*` policies, duplicate version 001, undeclared objects, triggers declared but not live) | `DEPRECATED` |
| Post-baseline migrations on E-MAIN | 14 files `20260907120001` … `20260920000000` | `IMPLEMENTED` |
| Applied to production? | Several files state "NOT APPLIED" / "PROPOSED" at authoring time (`diagnostic_logger`, `project_resource_allocations`, …). Later application is recorded only in mission reports outside this repo's code. | `UNKNOWN` per file (see [24](24-verification-matrix.md)) |
| CI deploy path for migrations | **None.** No workflow runs `supabase db push`/`migration up` against production. | `VERIFIED` |
| Local verification | `x4r-authorization-matrix.yml` runs `supabase start` locally, applies baseline + 022, runs `supabase/tests/x4b_authorization_tests.sql` and `x4r_authorization_matrix_completion.sql`; trigger restricted to branch `claude/ive-x4-security-boundary-closure` + manual dispatch | `TESTED` (historically) |
| Least-privilege grants (H1) | All `public` tables grant `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER` to `anon`/`authenticated` via default privileges; not exploitable via PostgREST today; hardening proposed, not applied | Open backlog (`POST_BASELINE_HARDENING_BACKLOG.md`) |
| Out-of-band deploy | Dashboard / CLI / MCP / Management API bypass all repository governance; no drift detection | Documented P2 (`docs/ive/OUT_OF_BAND_DEPLOYMENT_THREAT_MODEL.md`) |
| E-INT02 duplicate timestamp | `20260924000000_ive_memory_governance.sql` and `20260924000000_quant_watchlists.sql` share a version prefix; E-INT02 Codex audit judged it non-colliding (disjoint tables, name-keyed manifest) | `CONFLICTING_EVIDENCE` risk — Supabase's migration ledger keys on version; see R-MIG-02 |

Historical production drift is real and acknowledged: the baseline exists precisely because the
legacy migration files did not describe production. Treat any statement "migration X is live" as
`UNKNOWN` unless a dated read-only production check is cited.

## 5. Storage

No `storage.buckets` creation or storage policy exists in any E-MAIN migration.
`knowledge_items.file_storage_path` exists as a column. Live bucket configuration: `UNKNOWN`.

## 6. Edge Functions

See [12 — Edge Functions](12-edge-functions.md).
