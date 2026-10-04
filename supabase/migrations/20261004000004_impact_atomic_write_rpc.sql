-- IV-IMPACT-MACRO-08 TOCTOU fix — atomic entitlement + write RPCs for Impact.
--
-- PURPOSE
--   The separate check_impact_access → service-role write sequence had a
--   TOCTOU window: the caller's role could be downgraded between the
--   entitlement check and the DB write.
--
--   These SECURITY DEFINER functions re-verify the caller's entitlement
--   INSIDE the same transaction as the write, eliminating the window.
--
--   Callers: impact-lab Edge Function, via the authenticated caller's JWT
--   client (NOT service role).  auth.uid() resolves to the real caller;
--   the entitlement re-check reads the live profiles row in the same
--   transaction that performs the insert.
--
-- ANTI-PAY-TO-RANK
--   These functions never alter trust scores, rankings or evidence
--   credibility.  They only gate feature access (can/cannot write).
--
-- PRODUCTION PROTECTION
--   NOT applied to production. Requires Agente Martins + Paulo gate.

SET search_path = public, extensions;

-- ─── helpers ────────────────────────────────────────────────────────────────

-- Re-derives the caller's tier from the live profiles row.
-- Matches check_impact_access() logic exactly.
CREATE OR REPLACE FUNCTION public._impact_caller_tier()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth
AS $$
  SELECT CASE
    WHEN COALESCE(role, 'free') IN ('admin')         THEN 'admin'
    WHEN COALESCE(role, 'free') IN ('pro', 'premium') THEN 'pro'
    ELSE 'free'
  END
  FROM public.profiles
  WHERE id = auth.uid()
$$;

REVOKE ALL ON FUNCTION public._impact_caller_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public._impact_caller_tier() TO authenticated;

-- ─── impact_atomic_create_investigation ─────────────────────────────────────
--
-- Atomically:
--   1. Re-verifies the caller is authenticated and entitled to create_investigation.
--   2. Checks the per-owner investigation count limit (100).
--   3. Inserts the impact_investigations row.
--   4. Returns the new investigation id, or a denial reason.
--
-- Returns TABLE:
--   investigation_id  — uuid of the new row (NULL if denied or error)
--   subject_org_ref   — echoes back p_subject_ref
--   denied            — true when entitlement or limit blocked the write
--   denied_reason     — 'no_session' | 'pro_required' | 'limit_exceeded' | 'ok'

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

  v_tier := public._impact_caller_tier();

  IF v_tier NOT IN ('admin', 'pro') THEN
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'pro_required'::text;
    RETURN;
  END IF;

  -- Count ACTIVE investigations owned by this caller (project-hidden rows
  -- still count toward the limit, matching the service-role count in
  -- supabase_store.ts countOwnedInvestigations).
  SELECT COUNT(*) INTO v_count
  FROM public.impact_investigations
  WHERE owner_id = v_user_id;

  IF v_count >= 100 THEN  -- LAB_LIMITS.maxInvestigationsPerOwner
    RETURN QUERY SELECT NULL::uuid, p_subject_ref, TRUE, 'limit_exceeded'::text;
    RETURN;
  END IF;

  -- Atomically insert — same transaction, no TOCTOU window.
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
  'IV-IMPACT-MACRO-08 TOCTOU fix: atomically re-checks entitlement and '
  'inserts impact_investigations in one transaction. Called via caller JWT. '
  'PRODUCTION PROTECTION: not applied without Agente Martins + Paulo gate.';

-- ─── impact_atomic_insert_verification ──────────────────────────────────────
--
-- Atomically:
--   1. Re-verifies the caller is authenticated and entitled to run_verification.
--   2. Verifies the investigation is owned by the caller (equivalent to RLS).
--   3. Inserts the impact_verifications row (version assigned by trigger).
--   4. Returns the stored version, or a denial reason.
--
-- Returns TABLE:
--   version        — the DB-assigned version (NULL if denied or error)
--   denied         — true when entitlement or ownership blocked the write
--   denied_reason  — 'no_session' | 'pro_required' | 'not_owner' | 'ok'

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

  v_tier := public._impact_caller_tier();

  IF v_tier NOT IN ('admin', 'pro') THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'pro_required'::text;
    RETURN;
  END IF;

  -- Ownership check: the investigation must be owned by this caller.
  SELECT owner_id INTO v_owner_id
  FROM public.impact_investigations
  WHERE id = p_investigation_id;

  IF v_owner_id IS DISTINCT FROM v_user_id THEN
    RETURN QUERY SELECT NULL::integer, TRUE, 'not_owner'::text;
    RETURN;
  END IF;

  -- Idempotency: if the key already exists, return the stored version.
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

  -- Atomically insert — same transaction, no TOCTOU window.
  -- version is assigned by the impact_verifications_version trigger.
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
  'IV-IMPACT-MACRO-08 TOCTOU fix: atomically re-checks entitlement + ownership '
  'and inserts impact_verifications in one transaction. Called via caller JWT. '
  'PRODUCTION PROTECTION: not applied without Agente Martins + Paulo gate.';
