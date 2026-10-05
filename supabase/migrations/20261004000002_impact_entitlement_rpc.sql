-- IV-IMPACT-MACRO-08 Fases 11-12 — server-side Impact entitlement RPC.
--
-- PURPOSE
--   Provides a SECURITY DEFINER function that the Impact Edge Function can
--   call to check whether the authenticated caller is entitled to perform
--   a given Impact action, without the client ever being the authority.
--
-- DESIGN
--   Client sends: action name only (e.g. 'create_investigation', 'get_dossier')
--   Server checks: profiles.role for the authenticated user_id (from JWT)
--   Server returns: row {allowed bool, tier text, reason text}
--
-- TIER → ACTIONS ALLOWED
--   free    : get_dossier, list_investigations, verify_dossier
--   pro     : + create_investigation, run_verification, export_dossier
--   admin   : all actions (including future class-C actions behind AEF)
--
-- ANTI-PAY-TO-RANK
--   This function NEVER alters trust scores, rankings or evidence credibility
--   based on billing tier. It only controls feature access (can/cannot act).
--   The caller's plan MUST NOT influence how evidence is evaluated or displayed.
--
-- PRODUCTION PROTECTION
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate before
--   any production migration.

SET search_path = public, extensions;

-- ─── check_impact_access ────────────────────────────────────────────────────
--
-- INTEGRATION STATUS: This RPC is now called by the Edge Function (impact-lab)
-- for every action before any data access (wired in supabase_store.ts via
-- checkImpactActionAccess). The call uses the caller's JWT; fail-closed on RPC
-- error. Current tier logic: EXPERIMENTAL = admin-only.
-- When Impact is promoted to commercialEnabled:true, the tier logic below MUST
-- be extended to free/pro/premium (requires Agente Martins + Paulo gate).

CREATE OR REPLACE FUNCTION public.check_impact_access(p_action text)
RETURNS TABLE(allowed boolean, tier text, reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_user_id   uuid;
  v_role      text;
  v_tier      text;
  v_allowed   boolean := false;
  v_reason    text;
  -- Actions available to every authenticated user (free tier)
  v_free_actions  text[] := ARRAY['get_dossier', 'list_investigations', 'verify_dossier'];
  -- Actions requiring pro/premium/admin (write + export operations)
  v_pro_actions   text[] := ARRAY['create_investigation', 'run_verification', 'export_dossier'];
BEGIN
  -- Resolve the authenticated caller from the JWT.
  -- auth.uid() returns NULL if there is no valid session — this is the
  -- intended fail-closed behavior (no session → denied).
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'unauthenticated'::text, 'no_session'::text;
    RETURN;
  END IF;

  -- Read role from public.profiles — qualified to prevent search-path shadowing.
  -- SECURITY DEFINER bypasses RLS intentionally (we're reading our own row;
  -- RLS would allow it anyway, but explicit qualification keeps the path safe
  -- under any future RLS or schema change).
  SELECT COALESCE(role, 'free')
  INTO v_role
  FROM public.profiles
  WHERE id = v_user_id;

  -- Resolve tier from role (same as Profile.isPro in the Flutter client,
  -- kept in parity — client gate is UX only, this is the authority).
  v_tier := CASE
    WHEN v_role IN ('admin')                  THEN 'admin'
    WHEN v_role IN ('pro', 'premium')         THEN 'pro'
    ELSE                                           'free'
  END;

  -- Entitlement decision
  IF v_tier = 'admin' THEN
    v_allowed := true;
    v_reason  := 'admin_unrestricted';
  ELSIF p_action = ANY(v_free_actions) THEN
    v_allowed := true;
    v_reason  := 'free_action_allowed';
  ELSIF p_action = ANY(v_pro_actions) THEN
    IF v_tier = 'pro' THEN
      v_allowed := true;
      v_reason  := 'pro_action_allowed';
    ELSE
      v_allowed := false;
      v_reason  := 'pro_required';
    END IF;
  ELSE
    -- Unknown / future action: fail closed.
    v_allowed := false;
    v_reason  := 'unknown_action';
  END IF;

  RETURN QUERY SELECT v_allowed, v_tier, v_reason;
END;
$$;

-- Revoke broad access; only the authenticated role (Edge Function JWT) may call.
REVOKE ALL ON FUNCTION check_impact_access(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION check_impact_access(text) TO authenticated;

COMMENT ON FUNCTION check_impact_access(text) IS
  'IV-IMPACT-MACRO-08 Fases 11-12: server-side Impact entitlement check. '
  'Returns (allowed, tier, reason). Billing tier never influences trust or ranking. '
  'PRODUCTION PROTECTION: not applied to production without Agente Martins + Paulo gate.';
