-- IV-IMPACT-MACRO-08 POST-MERGE HARDENING — corrects check_impact_access (002).
--
-- PROBLEM (20261004000002_impact_entitlement_rpc.sql):
--   The comment says "EXPERIMENTAL = admin-only" but the tier logic allows
--   free users to pass actions in v_free_actions and pro users to pass
--   v_pro_actions.  While Impact is EXPERIMENTAL (commercialEnabled=false),
--   ONLY admin must receive allowed=true.  All other tiers must fail-closed.
--
-- FIX:
--   Remove the free_actions / pro_actions logic entirely while EXPERIMENTAL.
--   Only 'admin' tier → allowed=true.
--   All others → allowed=false, reason='experimental_gate'.
--
--   When commercialEnabled is promoted to true, a subsequent corrective
--   migration MUST restore the free/pro tier logic.
--   That change requires Agente Martins + Paulo gate.
--
-- PRESERVED (verbatim from 002):
--   SECURITY DEFINER, pinned search_path = pg_catalog/public/auth,
--   REVOKE PUBLIC/anon, authenticated-only EXECUTE,
--   auth.uid() fail-closed on NULL, tier derivation from profiles.role.
--
-- PRODUCTION PROTECTION:
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate.

SET search_path = public, extensions;

CREATE OR REPLACE FUNCTION public.check_impact_access(p_action text)
RETURNS TABLE(allowed boolean, tier text, reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_user_id  uuid;
  v_role     text;
  v_tier     text;
BEGIN
  -- Fail-closed: no valid session → denied.
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'unauthenticated'::text, 'no_session'::text;
    RETURN;
  END IF;

  -- Read role from profiles; qualified to prevent search-path shadowing.
  SELECT COALESCE(role, 'free')
  INTO v_role
  FROM public.profiles
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    -- No profile row = treat as unauthenticated (fail-closed).
    RETURN QUERY SELECT false, 'free'::text, 'no_profile'::text;
    RETURN;
  END IF;

  v_tier := CASE
    WHEN v_role IN ('admin')          THEN 'admin'
    WHEN v_role IN ('pro', 'premium') THEN 'pro'
    ELSE                                   'free'
  END;

  -- EXPERIMENTAL gate: only admin gets access while commercialEnabled=false.
  -- When Impact is promoted to commercialEnabled=true, a NEW corrective migration
  -- must extend this to free/pro/premium (Agente Martins + Paulo gate required).
  IF v_tier = 'admin' THEN
    RETURN QUERY SELECT true, 'admin'::text, 'admin_unrestricted'::text;
  ELSE
    RETURN QUERY SELECT false, v_tier, 'experimental_gate'::text;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.check_impact_access(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_impact_access(text) TO authenticated;

COMMENT ON FUNCTION public.check_impact_access(text) IS
  'IV-IMPACT-MACRO-08 HARDENING: server-side Impact entitlement check. '
  'EXPERIMENTAL: admin-only (experimental_gate for free/pro). '
  'Extend to pro/free when commercialEnabled=true via corrective migration (AM+Paulo gate). '
  'Never alters trust or ranking. '
  'PRODUCTION PROTECTION: not applied without Agente Martins + Paulo gate.';
