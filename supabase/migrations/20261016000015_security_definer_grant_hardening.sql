-- IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — PRODUCTION_SECURITY_BOUNDARY_GATE
-- Security hardening: REVOKE EXECUTE from PUBLIC/anon/authenticated for SECURITY DEFINER
-- functions that should never be called directly via the PostgREST REST API.
--
-- Background: PostgreSQL grants EXECUTE to PUBLIC by default for any new function.
-- Supabase exposes SECURITY DEFINER functions via /rest/v1/rpc/<name> to any role
-- with EXECUTE. This migration closes that surface for trigger-only and internal-only
-- functions that have no business being callable from the REST layer.
--
-- Classification of affected functions:
--   INTERNAL_DB_ONLY (trigger): handle_new_user, validate_asset_id_ownership,
--     validate_asset_parent_ownership, validate_asset_resource_ownership
--   INTERNAL_DB_ONLY (SQL helper): is_admin_user
--   AUTHENTICATED_USER_RPC (remove anon only): get_current_user_role
--   SERVER_ONLY (admin-scheduled maintenance): cleanup_old_diagnostic_sessions
--
-- Idempotent: REVOKE is a no-op if the role does not hold the grant.
--             GRANT is a no-op if the role already holds the grant.

-- ── Group A: Trigger functions (INTERNAL_DB_ONLY) ──────────────────────────
-- Trigger invocations bypass EXECUTE checks; only direct REST calls are affected.
-- These functions are called exclusively by database triggers, never via the API.

REVOKE EXECUTE ON FUNCTION public.handle_new_user()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.validate_asset_id_ownership()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.validate_asset_parent_ownership()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.validate_asset_resource_ownership()
  FROM PUBLIC, anon, authenticated;

-- ── Group B: Internal SQL helper (INTERNAL_DB_ONLY) ────────────────────────
-- is_admin_user() is called from within other SECURITY DEFINER functions (which
-- run as their owner, i.e. postgres) — never from the REST layer directly.

REVOKE EXECUTE ON FUNCTION public.is_admin_user()
  FROM PUBLIC, anon, authenticated;

-- ── Group C: User-facing RPC — authenticated only, remove anon ────────────
-- get_current_user_role() is a valid user RPC but anonymous sessions have no
-- profile row; calling it as anon is meaningless and exposes function existence.
-- Re-grant to authenticated explicitly in case PUBLIC was its sole source.

REVOKE EXECUTE ON FUNCTION public.get_current_user_role()
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_current_user_role()
  TO authenticated;

-- ── Group D: Admin-only scheduled maintenance (SERVER_ONLY) ───────────────
-- cleanup_old_diagnostic_sessions already checks is_admin_user() internally,
-- but revoking from authenticated removes the REST exposure entirely.
-- service_role and postgres retain access for pg_cron / manual admin ops.

REVOKE EXECUTE ON FUNCTION public.cleanup_old_diagnostic_sessions(integer)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.cleanup_old_diagnostic_sessions(integer)
  TO service_role;
