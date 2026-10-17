-- IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — Production dependency fix
-- impact_aef_is_hex64 was defined in migration 20261002010000_impact_aef_persistence (LAB)
-- but is required by aef_submit_action (migration 00014) which is APPLIED_PRODUCTION.
-- Applied 2026-10-17 as an out-of-band dependency fix.
-- Idempotent (CREATE OR REPLACE).
CREATE OR REPLACE FUNCTION public.impact_aef_is_hex64(v text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT v ~ '^[0-9a-f]{64}$'
$$;

REVOKE ALL     ON FUNCTION public.impact_aef_is_hex64(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.impact_aef_is_hex64(text) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.impact_aef_is_hex64(text) TO service_role;
