-- IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — Migration 00014
-- EA-02 resolution: harden aef_submit_action trust boundary per AM+Paulo decisions.
--
-- PROBLEM (Codex CLASS D adversarial finding, EA-02, 2026-10-09):
--   aef_submit_action validates parameter shapes and checks investigation ownership (P1-3),
--   but does NOT verify:
--   1. That the caller's account is active (is_active=true in profiles).
--      A deactivated account can still submit AEF actions via service path.
--   2. That the caller has a product entitlement for 'impact'
--      (product_subscriptions.product='impact', status IN ('active','trialing')).
--      Any authenticated user whose session reaches service_role path can
--      consume AEF capacity without an Impact subscription.
--
-- DECISION (Agente Martins + Paulo, 2026-10-09 — EA-02):
--   DB must recompute/validate independently:
--   - actor/user binding (already done: investigation ownership)
--   - is_active/status invariants (NEW: profiles.is_active check)
--   - product entitlement/capability (NEW: product_subscriptions check)
--   policy_outcome/execution_outcome are AUDIT METADATA only — they must never
--   serve as authorization authority or bypass the above checks.
--
-- ADVERSARIAL TESTS required (see companion test file):
--   - authenticated direct RPC → DENY (GRANT only to service_role)
--   - anon direct RPC → DENY (REVOKE FROM anon, authenticated)
--   - caller with is_active=false → AEF_CALLER_INACTIVE
--   - caller with no Impact entitlement → AEF_NO_IMPACT_ENTITLEMENT
--   - caller with wrong investigation ownership → AEF_CALLER_NOT_OWNER (existing)
--   - valid service_role + active + entitlement + owns investigation → ok=true
--
-- SECURITY PROPERTIES:
--   - All checks are server-side DB recomputation, not trusting caller params.
--   - policy_outcome parameter is accepted for audit metadata storage only;
--     it is recorded, not used for access decisions.
--   - Fail closed: missing profile → AEF_CALLER_INACTIVE (no profile = no access).
--   - Entitlement check uses product_subscriptions (same table as rest of system).
--
-- IDEMPOTENT: safe to re-run (CREATE OR REPLACE).
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

SET search_path = public, pg_catalog, pg_temp;

-- ── Hardened aef_submit_action ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef_submit_action(
  p_request_id        uuid,
  p_correlation_id    text,
  p_caller_user_id    uuid,
  p_project_id        uuid,
  p_service_id        text,
  p_intent_kind       text,
  p_investigation_id  uuid,
  p_idempotency_key   uuid,
  p_classification    text,
  p_requested_at      timestamptz,
  p_policy_outcome    text,
  p_policy_version    text,
  p_policy_reason     text,
  p_gate_id           uuid,
  p_gate_expires_at   timestamptz,
  p_receipt_id        uuid,
  p_receipt_hash      text,
  p_execution_outcome text,
  p_issued_at         timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_is_active boolean;
BEGIN
  -- Parameter shape validation (unchanged from migration 010)
  IF p_correlation_id IS NULL OR length(p_correlation_id) < 1 OR length(p_correlation_id) > 128 THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: correlation_id';
  END IF;
  IF p_service_id NOT IN ('impact-lab', 'impact-monitor') THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: service_id';
  END IF;
  IF p_intent_kind NOT IN (
    'REQUEST_MANUAL_VERIFICATION',
    'APPROVE_DOSSIER_PUBLICATION',
    'ACKNOWLEDGE_CONFLICT',
    'MARK_INVESTIGATION_REVIEWED'
  ) THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: intent_kind';
  END IF;
  IF p_classification NOT IN ('READ_ONLY','REVERSIBLE','CONSEQUENTIAL','IRREVERSIBLE') THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: classification';
  END IF;
  IF p_policy_outcome NOT IN ('AUTHORIZED','DENIED','REQUIRES_HUMAN_REVIEW') THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: policy_outcome';
  END IF;
  IF p_execution_outcome NOT IN ('AUTHORIZED','DENIED','REQUIRES_HUMAN_REVIEW','EXECUTED','FAILED','CANCELLED') THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: execution_outcome';
  END IF;
  IF NOT public.impact_aef_is_hex64(p_receipt_hash) THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: receipt_hash';
  END IF;
  IF p_gate_id IS NOT NULL AND p_gate_expires_at IS NULL THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: gate_expires_at required when gate_id is set';
  END IF;

  -- EA-02 gate 1: is_active check (DB recomputation, independent of caller params).
  -- Missing profile = fail closed (no row → inactive). is_active=NULL → inactive.
  SELECT COALESCE(is_active, false) INTO v_is_active
  FROM   public.profiles
  WHERE  id = p_caller_user_id;

  IF NOT FOUND OR NOT v_is_active THEN
    RETURN jsonb_build_object('ok', false, 'code', 'AEF_CALLER_INACTIVE');
  END IF;

  -- EA-02 gate 2: product entitlement check (DB recomputation, independent of caller params).
  -- Caller must have an active or trialing Impact subscription.
  -- policy_outcome/execution_outcome are AUDIT METADATA — they are NOT consulted here.
  IF NOT EXISTS (
    SELECT 1
    FROM   public.product_subscriptions
    WHERE  user_id = p_caller_user_id
      AND  product = 'impact'
      AND  status  IN ('active', 'trialing')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'AEF_NO_IMPACT_ENTITLEMENT');
  END IF;

  -- P1-3 gate 3: investigation ownership (from migration 009, unchanged).
  IF NOT EXISTS (
    SELECT 1 FROM public.impact_investigations
    WHERE id = p_investigation_id
      AND owner_id = p_caller_user_id
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'AEF_CALLER_NOT_OWNER');
  END IF;

  -- All gates passed: record the AEF action.
  INSERT INTO public.impact_aef_requests (
    request_id, correlation_id, caller_user_id, project_id, service_id,
    intent_kind, investigation_id, idempotency_key, classification, requested_at
  ) VALUES (
    p_request_id, p_correlation_id, p_caller_user_id, p_project_id, p_service_id,
    p_intent_kind, p_investigation_id, p_idempotency_key, p_classification, p_requested_at
  );

  INSERT INTO public.impact_aef_decisions (
    request_id, outcome, policy_version, reason, decided_at
  ) VALUES (
    -- policy_outcome is AUDIT METADATA stored here, not used for access decisions above.
    p_request_id, p_policy_outcome, p_policy_version, p_policy_reason, p_issued_at
  );

  IF p_gate_id IS NOT NULL THEN
    INSERT INTO public.impact_aef_gates (
      gate_id, request_id, status, expires_at
    ) VALUES (
      p_gate_id, p_request_id, 'PENDING', p_gate_expires_at
    );
  END IF;

  INSERT INTO public.impact_aef_receipts (
    receipt_id, request_id, correlation_id, caller_user_id, project_id, service_id,
    intent_kind, investigation_id, idempotency_key, classification, policy_version,
    policy_outcome, execution_outcome, human_gate_id, receipt_hash, issued_at
  ) VALUES (
    p_receipt_id, p_request_id, p_correlation_id, p_caller_user_id, p_project_id,
    p_service_id, p_intent_kind, p_investigation_id, p_idempotency_key,
    p_classification, p_policy_version, p_policy_outcome, p_execution_outcome,
    p_gate_id, p_receipt_hash, p_issued_at
  );

  RETURN jsonb_build_object(
    'ok',         true,
    'receipt_id', p_receipt_id,
    'request_id', p_request_id
  );

EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_EXISTS');
END;
$$;

-- ACL: service_role only (anon/authenticated cannot call directly)
REVOKE ALL ON FUNCTION public.aef_submit_action(
  uuid, text, uuid, uuid, text, text, uuid, uuid, text, timestamptz,
  text, text, text, uuid, timestamptz, uuid, text, text, timestamptz
) FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.aef_submit_action(
  uuid, text, uuid, uuid, text, text, uuid, uuid, text, timestamptz,
  text, text, text, uuid, timestamptz, uuid, text, text, timestamptz
) FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.aef_submit_action(
  uuid, text, uuid, uuid, text, text, uuid, uuid, text, timestamptz,
  text, text, text, uuid, timestamptz, uuid, text, text, timestamptz
) TO service_role;

COMMENT ON FUNCTION public.aef_submit_action(
  uuid, text, uuid, uuid, text, text, uuid, uuid, text, timestamptz,
  text, text, text, uuid, timestamptz, uuid, text, text, timestamptz
) IS
  'EA-02 (2026-10-09): added is_active check (profiles) + product entitlement check '
  '(product_subscriptions, product=impact, status active/trialing). '
  'All checks are DB-recomputed; policy_outcome is AUDIT METADATA only. '
  'Failure modes: AEF_CALLER_INACTIVE, AEF_NO_IMPACT_ENTITLEMENT, AEF_CALLER_NOT_OWNER. '
  'PRODUCTION PROTECTION: not applied without AM+Paulo gate.';
