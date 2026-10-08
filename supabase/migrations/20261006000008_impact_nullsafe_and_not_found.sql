-- IV-IMPACT-MACRO-08 HARDENING — migration 008
-- Codex CLASS B P2/P3 fixes for migration 007.
--
-- P2-1 (impact_has_module_access NULL contract):
--   SELECT INTO leaves v_role = NULL when no active profile row is found.
--   NULL IN ('admin') = NULL, not FALSE — violates RETURNS boolean contract
--   and is a footgun for callers using NOT impact_has_module_access().
--   Current RLS callers use AND ... in USING clauses (NULL = deny, safe),
--   but the contract violation is real. Fix: explicit IF NOT FOUND THEN
--   RETURN false; END IF before the RETURN.
--
-- P2-2 (impact_atomic_insert_verification not_owner masks not_found):
--   When p_investigation_id matches no row, SELECT owner_id INTO v_owner_id
--   leaves v_owner_id = NULL. NULL IS DISTINCT FROM v_user_id = TRUE →
--   returns 'not_owner', masking the real 'not_found' condition.
--   Fix: explicit IF NOT FOUND check before ownership comparison.
--   Client (supabase_store.ts) updated to map not_found → INVESTIGATION_NOT_FOUND.
--
-- P3-1 (dossier policy auth.uid() inconsistency):
--   impact_dossier_snapshots_select_own used bare auth.uid() inside EXISTS
--   subquery; all 4 AEF policies in migration 007 use (SELECT auth.uid()).
--   Fix: normalize to (SELECT auth.uid()) for per-query evaluation.
--
-- DEFERRED (not addressed here):
--   P2-A (_impact_caller_tier STABLE): pre-existing from migration 004;
--         requires architectural decision — Agente Martins gate.
--   P2-B (projects ownership FOR UPDATE): low-probability race in admin-only
--         EXPERIMENTAL context — architectural discussion deferred.
--   P3-A (double impact_has_module_access in decisions/gates): efficiency;
--         removing one call would change policy evaluation — deferred.
--
-- PRODUCTION PROTECTION:
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate.

SET search_path = public, extensions;

-- ─── P2-1: impact_has_module_access() — explicit NOT FOUND → false ──────────

CREATE OR REPLACE FUNCTION public.impact_has_module_access()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN RETURN false; END IF;

  SELECT COALESCE(role, 'free')
  INTO v_role
  FROM public.profiles
  WHERE id = auth.uid()
    AND is_active = true;

  IF NOT FOUND THEN RETURN false; END IF;

  -- EXPERIMENTAL phase: admin-only.
  -- When Impact is promoted to commercialEnabled=true, extend this to:
  --   RETURN v_role IN ('admin', 'pro', 'premium', 'free');
  -- Gate: Agente Martins + Paulo must authorize that change.
  RETURN v_role IN ('admin');
END;
$$;

REVOKE ALL ON FUNCTION public.impact_has_module_access() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.impact_has_module_access() TO authenticated;

COMMENT ON FUNCTION public.impact_has_module_access() IS
  'IV-IMPACT-MACRO-08 Fix 1 (008 P2-1): returns false (not NULL) for deactivated '
  'or missing profiles. EXPERIMENTAL: admin-only. '
  'Extend to pro/premium/free when commercialEnabled=true (AM+Paulo gate).';

-- ─── P2-2: impact_atomic_insert_verification — explicit not_found check ──────

CREATE OR REPLACE FUNCTION public.impact_atomic_insert_verification(
  p_investigation_id    uuid,
  p_claim_ref           text,
  p_result_id           text,
  p_status              text,
  p_underlying_status   text,
  p_sufficiency         text,
  p_display_class       text,
  p_review_state        text,
  p_policy_version      text,
  p_evidence_set_hash   text,
  p_review_binding_hash text,
  p_evaluated_at        text,
  p_rules_applied       text[],
  p_gaps                text[],
  p_conflict_count      integer,
  p_result              jsonb,
  p_idempotency_key     uuid DEFAULT NULL
)
RETURNS TABLE(
  stored_version integer,
  denied         boolean,
  denied_reason  text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_user_id   uuid;
  v_tier      text;
  v_owner_id  uuid;
  v_version   integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'no_session'::text;
    RETURN;
  END IF;

  -- Lock the caller's active profile row (TOCTOU fix + P1-1 deactivation gate).
  PERFORM id FROM public.profiles WHERE id = v_user_id AND is_active = true FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'no_profile'::text;
    RETURN;
  END IF;

  v_tier := public._impact_caller_tier();

  IF v_tier IS NULL OR v_tier != 'admin' THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'experimental_gate'::text;
    RETURN;
  END IF;

  SELECT owner_id INTO v_owner_id
  FROM public.impact_investigations
  WHERE id = p_investigation_id;

  -- P2-2 fix: distinguish not_found from not_owner.
  -- Previously NULL IS DISTINCT FROM v_user_id masked both cases as not_owner.
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'not_found'::text;
    RETURN;
  END IF;

  IF v_owner_id IS DISTINCT FROM v_user_id THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'not_owner'::text;
    RETURN;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT version INTO v_version
    FROM public.impact_verifications
    WHERE investigation_id = p_investigation_id
      AND idempotency_key = p_idempotency_key;
    IF FOUND THEN
      RETURN QUERY SELECT v_version, FALSE, 'ok'::text;
      RETURN;
    END IF;
  END IF;

  INSERT INTO public.impact_verifications(
    investigation_id, claim_ref, result_id, status, underlying_status,
    sufficiency, display_class, review_state, policy_version,
    evidence_set_hash, review_binding_hash, evaluated_at,
    rules_applied, gaps, conflict_count, result,
    idempotency_key, created_by
  ) VALUES (
    p_investigation_id, p_claim_ref, p_result_id, p_status, p_underlying_status,
    p_sufficiency, p_display_class, p_review_state, p_policy_version,
    p_evidence_set_hash, p_review_binding_hash, p_evaluated_at,
    p_rules_applied, p_gaps, p_conflict_count, p_result,
    p_idempotency_key, v_user_id
  )
  RETURNING version INTO v_version;

  RETURN QUERY SELECT v_version, FALSE, 'ok'::text;
END;
$$;

REVOKE ALL ON FUNCTION public.impact_atomic_insert_verification(
  uuid, text, text, text, text, text, text, text, text, text, text, text, text[], text[], integer, jsonb, uuid
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.impact_atomic_insert_verification(
  uuid, text, text, text, text, text, text, text, text, text, text, text, text[], text[], integer, jsonb, uuid
) TO authenticated;

COMMENT ON FUNCTION public.impact_atomic_insert_verification(
  uuid, text, text, text, text, text, text, text, text, text, text, text, text[], text[], integer, jsonb, uuid
) IS
  'IV-IMPACT-MACRO-08 008 P2-2: explicit not_found before not_owner — '
  'callers distinguish missing investigation from ownership violation. '
  'PRODUCTION PROTECTION: not applied without AM+Paulo gate.';

-- ─── P3-1: impact_dossier_snapshots — normalize (SELECT auth.uid()) ──────────

DROP POLICY IF EXISTS impact_dossier_snapshots_select_own ON public.impact_dossier_snapshots;
CREATE POLICY impact_dossier_snapshots_select_own ON public.impact_dossier_snapshots
  FOR SELECT TO authenticated
  USING (
    public.impact_has_module_access()
    AND EXISTS (
      SELECT 1 FROM public.impact_investigations i
      WHERE i.id = impact_dossier_snapshots.investigation_id
        AND i.owner_id = (SELECT auth.uid())
    )
  );
