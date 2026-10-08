-- IV-IMPACT-MACRO-08 HARDENING — migration 007
-- is_active gate + RLS module-access guard on dossier/AEF tables.
--
-- PROBLEMS (Codex CLASS D FAIL 2026-10-06):
--
--   P1-1 (is_active gate missing from DB layer):
--     impact_has_module_access(), check_impact_access(), _impact_caller_tier(),
--     and both atomic RPCs do NOT check profiles.is_active. A deactivated admin
--     retains full Impact DB access even after account suspension. The Edge
--     Function (requireModuleAccess) already checks is_active in JS; this adds
--     defense-in-depth at the DB layer so it holds even if the JS path changes.
--
--   P2 (module-access guard missing from dossier/AEF SELECT policies):
--     impact_dossier_snapshots and all 4 impact_aef_* tables lack
--     AND public.impact_has_module_access() on their SELECT policies. A
--     deactivated or non-entitled user can still read these tables directly via
--     the Supabase REST API, bypassing the Edge Function entirely.
--
-- FIXES:
--   1. impact_has_module_access() — add AND is_active = true to profiles WHERE.
--   2. check_impact_access()       — same.
--   3. _impact_caller_tier()       — same (returns NULL for deactivated → denied).
--   4. impact_atomic_create_investigation() — AND is_active = true in FOR UPDATE.
--   5. impact_atomic_insert_verification() — same.
--   6. impact_dossier_snapshots_select_own — add impact_has_module_access().
--   7. All 4 impact_aef_* SELECT policies  — same.
--
-- PRESERVED verbatim from prior migrations:
--   SECURITY DEFINER, pinned search_path = pg_catalog/public/auth,
--   REVOKE PUBLIC/anon, authenticated-only EXECUTE, fail-closed semantics,
--   FOR UPDATE TOCTOU fix, quota lock, idempotency, NOT FOUND → no_profile,
--   EXPERIMENTAL admin-only comment + commercial gate instructions.
--
-- PRODUCTION PROTECTION:
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate.

SET search_path = public, extensions;

-- ─── 1. impact_has_module_access() ──────────────────────────────────────────

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
  'IV-IMPACT-MACRO-08 Fix 1 (007 P1-1): blocks direct reads for non-entitled '
  'or deactivated users. EXPERIMENTAL: admin-only. '
  'Extend to pro/premium/free when commercialEnabled=true (AM+Paulo gate).';

-- ─── 2. check_impact_access(text) ───────────────────────────────────────────

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
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'unauthenticated'::text, 'no_session'::text;
    RETURN;
  END IF;

  SELECT COALESCE(role, 'free')
  INTO v_role
  FROM public.profiles
  WHERE id = v_user_id
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'free'::text, 'no_profile'::text;
    RETURN;
  END IF;

  v_tier := CASE
    WHEN v_role IN ('admin')          THEN 'admin'
    WHEN v_role IN ('pro', 'premium') THEN 'pro'
    ELSE                                   'free'
  END;

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
  'IV-IMPACT-MACRO-08 007 P1-1: server-side Impact entitlement check. '
  'EXPERIMENTAL: admin-only (experimental_gate for free/pro/deactivated). '
  'Extend to pro/free when commercialEnabled=true via corrective migration (AM+Paulo gate). '
  'Never alters trust or ranking. '
  'PRODUCTION PROTECTION: not applied without Agente Martins + Paulo gate.';

-- ─── 3. _impact_caller_tier() ───────────────────────────────────────────────
-- Returns NULL for deactivated accounts (no active profile row found).
-- Callers treat NULL as denied (v_tier IS NULL OR v_tier != 'admin').

CREATE OR REPLACE FUNCTION public._impact_caller_tier()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth
AS $$
  SELECT CASE
    WHEN COALESCE(role, 'free') IN ('admin')          THEN 'admin'
    WHEN COALESCE(role, 'free') IN ('pro', 'premium') THEN 'pro'
    ELSE 'free'
  END
  FROM public.profiles
  WHERE id = auth.uid()
    AND is_active = true
$$;

REVOKE ALL ON FUNCTION public._impact_caller_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public._impact_caller_tier() TO authenticated;

-- ─── 4. impact_atomic_create_investigation ──────────────────────────────────

CREATE OR REPLACE FUNCTION public.impact_atomic_create_investigation(
  p_subject_ref      text,
  p_subject_type     text,
  p_subject_identity jsonb,
  p_project_id       uuid DEFAULT NULL
)
RETURNS TABLE(
  investigation_id  uuid,
  subject_org_ref   text,
  denied            boolean,
  denied_reason     text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_user_id uuid;
  v_tier    text;
  v_count   bigint;
  v_inv_id  uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'no_session'::text;
    RETURN;
  END IF;

  -- Lock the caller's active profile row for the transaction duration to
  -- prevent a concurrent role downgrade or account deactivation from committing
  -- between the entitlement read and the INSERT (TOCTOU fix + P1-1).
  PERFORM id FROM public.profiles WHERE id = v_user_id AND is_active = true FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'no_profile'::text;
    RETURN;
  END IF;

  v_tier := public._impact_caller_tier();

  IF v_tier IS NULL OR v_tier != 'admin' THEN
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'experimental_gate'::text;
    RETURN;
  END IF;

  IF p_project_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.projects
      WHERE id = p_project_id AND user_id = v_user_id
    ) THEN
      RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'not_owner'::text;
      RETURN;
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('impact_inv_quota:' || v_user_id::text, 0));

  SELECT COUNT(*) INTO v_count
  FROM public.impact_investigations
  WHERE owner_id = v_user_id;

  IF v_count >= 100 THEN
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'limit_exceeded'::text;
    RETURN;
  END IF;

  INSERT INTO public.impact_investigations(
    owner_id, project_id, subject_org_ref, subject_org_type, subject_identity
  ) VALUES (
    v_user_id, p_project_id, p_subject_ref, p_subject_type, p_subject_identity
  )
  RETURNING id INTO v_inv_id;

  RETURN QUERY SELECT v_inv_id, p_subject_ref, FALSE, 'ok'::text;
END;
$$;

REVOKE ALL ON FUNCTION public.impact_atomic_create_investigation(text, text, jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.impact_atomic_create_investigation(text, text, jsonb, uuid) TO authenticated;

COMMENT ON FUNCTION public.impact_atomic_create_investigation(text, text, jsonb, uuid) IS
  'IV-IMPACT-MACRO-08 007 P1-1: atomically re-checks entitlement (admin-only '
  'EXPERIMENTAL for active accounts), project ownership, quota, and inserts '
  'impact_investigations. PRODUCTION PROTECTION: not applied without AM+Paulo gate.';

-- ─── 5. impact_atomic_insert_verification ───────────────────────────────────

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
  'IV-IMPACT-MACRO-08 007 P1-1: atomically re-checks entitlement (admin-only '
  'EXPERIMENTAL for active accounts), ownership, and inserts impact_verifications. '
  'PRODUCTION PROTECTION: not applied without AM+Paulo gate.';

-- ─── 6. impact_dossier_snapshots — add module-access guard ──────────────────

DROP POLICY IF EXISTS impact_dossier_snapshots_select_own ON public.impact_dossier_snapshots;
CREATE POLICY impact_dossier_snapshots_select_own ON public.impact_dossier_snapshots
  FOR SELECT TO authenticated
  USING (
    public.impact_has_module_access()
    AND EXISTS (
      SELECT 1 FROM public.impact_investigations i
      WHERE i.id = impact_dossier_snapshots.investigation_id
        AND i.owner_id = auth.uid()
    )
  );

-- ─── 7. AEF tables — add module-access guard to SELECT policies ──────────────

-- impact_aef_requests
DROP POLICY IF EXISTS impact_aef_requests_select ON public.impact_aef_requests;
CREATE POLICY impact_aef_requests_select ON public.impact_aef_requests
  FOR SELECT TO authenticated
  USING (
    public.impact_has_module_access()
    AND caller_user_id = (SELECT auth.uid())
  );

-- impact_aef_decisions
DROP POLICY IF EXISTS impact_aef_decisions_select ON public.impact_aef_decisions;
CREATE POLICY impact_aef_decisions_select ON public.impact_aef_decisions
  FOR SELECT TO authenticated
  USING (
    public.impact_has_module_access()
    AND request_id IN (
      SELECT request_id FROM public.impact_aef_requests
      WHERE caller_user_id = (SELECT auth.uid())
    )
  );

-- impact_aef_gates
DROP POLICY IF EXISTS impact_aef_gates_select ON public.impact_aef_gates;
CREATE POLICY impact_aef_gates_select ON public.impact_aef_gates
  FOR SELECT TO authenticated
  USING (
    public.impact_has_module_access()
    AND request_id IN (
      SELECT request_id FROM public.impact_aef_requests
      WHERE caller_user_id = (SELECT auth.uid())
    )
  );

-- impact_aef_receipts
DROP POLICY IF EXISTS impact_aef_receipts_select ON public.impact_aef_receipts;
CREATE POLICY impact_aef_receipts_select ON public.impact_aef_receipts
  FOR SELECT TO authenticated
  USING (
    public.impact_has_module_access()
    AND caller_user_id = (SELECT auth.uid())
  );
