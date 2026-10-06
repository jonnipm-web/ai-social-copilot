-- IV-IMPACT-MACRO-08 HARDENING — migration 010
-- Fix search_path pinning for aef_submit_action and aef_resolve_gate.
--
-- PROBLEM (Codex G1V-02 / T14p CI gate):
--   aef_submit_action (introduced in 20261003000000) and aef_resolve_gate
--   (20261003000001) both declare SET search_path = public, pg_catalog.
--   The T14p privilege-catalog test enforces that every aef_* function pins
--   its search_path to pg_catalog, pg_temp — no function may resolve
--   unqualified names through a writable schema. Both functions use
--   fully-qualified public.* references throughout, so changing the
--   search_path is safe and does not alter behavior.
--
-- FIX:
--   Re-creates both functions with SET search_path = pg_catalog, pg_temp.
--   aef_submit_action body carries migration 009's P1-3 ownership check
--   (see 20261007000001_impact_ownership_gate_and_aef_binding.sql).
--
-- PRODUCTION PROTECTION:
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate.

-- ─── aef_resolve_gate ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.aef_resolve_gate(
  p_request_id    uuid,
  p_resolution    text,
  p_approver_ref  text,
  p_binding_hash  text,
  p_receipt_id    uuid,
  p_receipt_hash  text,
  p_policy_version text,
  p_issued_at     timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_gate            public.impact_aef_gates%ROWTYPE;
  v_request         public.impact_aef_requests%ROWTYPE;
  v_policy_outcome  text;
  v_exec_outcome    text;
  v_now             timestamptz;
BEGIN
  v_now := clock_timestamp();

  IF p_resolution NOT IN ('APPROVED', 'REJECTED') THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: resolution must be APPROVED or REJECTED';
  END IF;
  IF p_approver_ref IS NULL OR length(p_approver_ref) < 1 OR length(p_approver_ref) > 64 THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: approver_ref';
  END IF;
  IF NOT public.impact_aef_is_hex64(p_binding_hash) THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: binding_hash';
  END IF;
  IF NOT public.impact_aef_is_hex64(p_receipt_hash) THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: receipt_hash';
  END IF;
  IF p_policy_version IS NULL OR length(p_policy_version) < 1 OR length(p_policy_version) > 128 THEN
    RAISE EXCEPTION 'AEF_INVALID_PARAM: policy_version';
  END IF;

  SELECT * INTO v_gate
  FROM public.impact_aef_gates
  WHERE request_id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'GATE_NOT_FOUND');
  END IF;

  IF v_gate.status <> 'PENDING' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'GATE_ALREADY_RESOLVED', 'status', v_gate.status);
  END IF;

  IF v_now >= v_gate.expires_at THEN
    UPDATE public.impact_aef_gates
    SET status = 'EXPIRED', resolved_at = v_now
    WHERE gate_id = v_gate.gate_id;
    RETURN jsonb_build_object('ok', false, 'code', 'GATE_EXPIRED');
  END IF;

  SELECT * INTO v_request
  FROM public.impact_aef_requests
  WHERE request_id = p_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'REQUEST_NOT_FOUND');
  END IF;

  UPDATE public.impact_aef_gates
  SET
    status       = p_resolution,
    approver_ref = p_approver_ref,
    binding_hash = p_binding_hash,
    resolved_at  = v_now
  WHERE gate_id = v_gate.gate_id;

  v_policy_outcome := CASE WHEN p_resolution = 'APPROVED' THEN 'AUTHORIZED' ELSE 'DENIED' END;
  v_exec_outcome   := CASE WHEN p_resolution = 'APPROVED' THEN 'AUTHORIZED' ELSE 'DENIED' END;

  INSERT INTO public.impact_aef_receipts (
    receipt_id,          request_id,           correlation_id,
    caller_user_id,      project_id,           service_id,
    intent_kind,         investigation_id,     idempotency_key,
    classification,      policy_version,       policy_outcome,
    execution_outcome,   human_gate_id,        receipt_hash,
    issued_at
  ) VALUES (
    p_receipt_id,
    p_request_id,
    v_request.correlation_id,
    v_request.caller_user_id,
    v_request.project_id,
    'aef-gate-resolver',
    v_request.intent_kind,
    v_request.investigation_id,
    v_gate.gate_id,
    v_request.classification,
    p_policy_version,
    v_policy_outcome,
    v_exec_outcome,
    v_gate.gate_id,
    p_receipt_hash,
    p_issued_at
  );

  RETURN jsonb_build_object(
    'ok',         true,
    'receipt_id', p_receipt_id,
    'request_id', p_request_id,
    'gate_id',    v_gate.gate_id
  );

EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'code', 'RECEIPT_ALREADY_EXISTS');
END;
$$;

REVOKE ALL ON FUNCTION public.aef_resolve_gate(
  uuid, text, text, text, uuid, text, text, timestamptz
) FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.aef_resolve_gate(
  uuid, text, text, text, uuid, text, text, timestamptz
) FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.aef_resolve_gate(
  uuid, text, text, text, uuid, text, text, timestamptz
) TO service_role;

-- ─── aef_submit_action ────────────────────────────────────────────────────────
-- Body from migration 009 (P1-3 ownership check included).

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
BEGIN
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

  -- P1-3: verify caller owns the investigation (migration 009).
  IF NOT EXISTS (
    SELECT 1 FROM public.impact_investigations
    WHERE id = p_investigation_id
      AND owner_id = p_caller_user_id
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'AEF_CALLER_NOT_OWNER');
  END IF;

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
  'IV-IMPACT-MACRO-08 010: search_path pinned to pg_catalog,pg_temp (T14p/G1V-02). '
  'P1-3 ownership check from migration 009. '
  'PRODUCTION PROTECTION: not applied without AM+Paulo gate.';

COMMENT ON FUNCTION public.aef_resolve_gate(
  uuid, text, text, text, uuid, text, text, timestamptz
) IS
  'IV-IMPACT-MACRO-08 010: search_path pinned to pg_catalog,pg_temp (T14p/G1V-02). '
  'PRODUCTION PROTECTION: not applied without AM+Paulo gate.';
