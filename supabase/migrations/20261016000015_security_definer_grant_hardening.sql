-- IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — PRODUCTION_SECURITY_BOUNDARY_GATE
-- Security hardening: REVOKE EXECUTE from PUBLIC/anon/authenticated for SECURITY DEFINER
-- trigger functions that should never be directly callable via the PostgREST REST API.
--
-- SCOPE RATIONALE (Codex D, R1-R4 adversarial iterations):
--
-- Trigger functions (handle_new_user, validate_*):
--   SAFE to revoke from ALL roles. PostgreSQL does NOT check EXECUTE grants for
--   trigger invocations — triggers always fire their function regardless of grants.
--   Revoking only closes the /rest/v1/rpc/<name> REST surface. These functions
--   should NEVER be called directly; revoking all roles is correct.
--
-- is_admin_user():
--   CANNOT safely revoke anon or authenticated. The baseline migration and
--   diagnostic_logger define RLS policies with NO 'TO' clause (applies to all
--   roles), calling is_admin_user() in USING expressions. PostgreSQL evaluates
--   the policy for every querying role — if the role lacks EXECUTE, the query
--   fails with 42501 (not a safe empty result). Removing anon or authenticated
--   access would break all table queries on knowledge_items, campaigns, personas,
--   knowledge_analysis, knowledge_strategies, diagnostic_sessions, etc.
--   The function returns false for all non-admin callers, so the REST exposure
--   (anon calling /rpc/is_admin_user → false) is an acceptably low risk.
--   STATUS: NO CHANGE. Supabase advisor warning is informational; runtime guard
--   makes exploitation impossible.
--
-- get_current_user_role():
--   CANNOT safely revoke anon. At least one RLS policy (line 1182 of baseline)
--   calls this function with no 'TO' clause restriction. Same 42501 failure mode
--   applies. Returns null for anon (no profile), so REST exposure is harmless.
--   STATUS: NO CHANGE.
--
-- cleanup_old_diagnostic_sessions(integer):
--   No change needed. Function checks is_admin_user() on entry — non-admin
--   authenticated and service_role callers always fail the internal guard.
--   STATUS: NO CHANGE.
--
-- Idempotent: REVOKE is a no-op if the role does not hold the grant.

-- ── Trigger functions (INTERNAL_DB_ONLY) ─────────────────────────────────────
-- Trigger invocations bypass EXECUTE checks; these REVOKEs close only the
-- direct /rest/v1/rpc/<name> REST exposure, which has no legitimate use case.

REVOKE EXECUTE ON FUNCTION public.handle_new_user()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.validate_asset_id_ownership()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.validate_asset_parent_ownership()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.validate_asset_resource_ownership()
  FROM PUBLIC, anon, authenticated;
