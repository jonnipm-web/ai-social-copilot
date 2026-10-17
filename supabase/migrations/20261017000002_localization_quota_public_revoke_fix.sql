-- IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — ACL fix for migration 00012
-- Migration 00012 revoked EXECUTE from anon/authenticated but missed FROM PUBLIC.
-- In PostgreSQL, REVOKE from individual roles does NOT remove PUBLIC inheritance;
-- anon/authenticated can still call via /rpc because they inherit from PUBLIC.
-- Applied 2026-10-17 to close the REST /rpc/try_reserve_localization_slot surface.
-- Idempotent.
REVOKE ALL ON FUNCTION public.try_reserve_localization_slot(uuid, int) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.try_reserve_localization_slot(uuid, int)
  FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.try_reserve_localization_slot(uuid, int)
  TO service_role;
