-- IV-IMPACT-MACRO-08 POST-MERGE HARDENING — corrects atomic write RPCs (004).
--
-- PROBLEMS (20261004000004_impact_atomic_write_rpc.sql):
--
--   1. TIER GATE: Both RPCs check `v_tier NOT IN ('admin', 'pro')`, allowing
--      PRO users to create investigations and insert verifications while Impact
--      is EXPERIMENTAL and commercialEnabled=false.  Only 'admin' must pass.
--
--   2. PROJECT OWNERSHIP: impact_atomic_create_investigation accepts p_project_id
--      without verifying the caller owns that project.  An authenticated admin
--      could associate an investigation with any project (cross-tenant write).
--      FIX: when p_project_id IS NOT NULL, require
--           EXISTS (SELECT 1 FROM public.projects
--                   WHERE id = p_project_id AND user_id = v_user_id).
--           If the check fails → denied='not_owner' (fail-closed).
--
-- PRESERVED (verbatim from 004):
--   auth.uid() fail-closed, FOR UPDATE on profiles + NOT FOUND → no_profile,
--   _impact_caller_tier(), pg_advisory_xact_lock(hashtextextended(...)),
--   COUNT >= 100 quota limit, INSERT atomicity (no TOCTOU window),
--   investigation ownership check, idempotency SELECT + RETURNING version,
--   SECURITY DEFINER, pinned search_path, REVOKE PUBLIC/anon,
--   authenticated-only EXECUTE.
--
-- PRODUCTION PROTECTION:
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate.

SET search_path = public, extensions;

-- ─── impact_atomic_create_investigation ─────────────────────────────────────

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

  -- Lock the caller's profile row for the transaction duration to prevent a
  -- concurrent role downgrade from committing between the entitlement read and
  -- the INSERT (Codex CLASS D P1-Q16).  NOT FOUND = no profiles row = deny.
  PERFORM id FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'no_profile'::text;
    RETURN;
  END IF;

  v_tier := public._impact_caller_tier();

  -- EXPERIMENTAL gate: only admin may create investigations while
  -- commercialEnabled=false.  When promoted, extend via a NEW corrective
  -- migration (Agente Martins + Paulo gate required).
  IF v_tier IS NULL OR v_tier != 'admin' THEN
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'experimental_gate'::text;
    RETURN;
  END IF;

  -- Project ownership: if a project is specified, the caller must own it.
  -- Fail-closed: missing project or wrong owner → not_owner.
  IF p_project_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.projects
      WHERE id = p_project_id AND user_id = v_user_id
    ) THEN
      RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'not_owner'::text;
      RETURN;
    END IF;
  END IF;

  -- Serialize per-owner quota enforcement across concurrent transactions.
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
  'IV-IMPACT-MACRO-08 HARDENING: atomically re-checks entitlement (admin-only EXPERIMENTAL), '
  'project ownership, quota, and inserts impact_investigations. '
  'PRODUCTION PROTECTION: not applied without Agente Martins + Paulo gate.';

-- ─── impact_atomic_insert_verification ──────────────────────────────────────

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

  -- Lock the caller's profile row (P1-Q16 TOCTOU fix, preserved from 004).
  PERFORM id FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'no_profile'::text;
    RETURN;
  END IF;

  v_tier := public._impact_caller_tier();

  -- EXPERIMENTAL gate: only admin may insert verifications while
  -- commercialEnabled=false.  When promoted, extend via a NEW corrective
  -- migration (Agente Martins + Paulo gate required).
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
  'IV-IMPACT-MACRO-08 HARDENING: atomically re-checks entitlement (admin-only EXPERIMENTAL), '
  'ownership, and inserts impact_verifications. '
  'PRODUCTION PROTECTION: not applied without Agente Martins + Paulo gate.';
