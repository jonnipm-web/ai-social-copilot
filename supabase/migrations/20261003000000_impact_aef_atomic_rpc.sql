-- IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01 — AEF atomic RPC + security hardening.
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
--
-- Closes:
--   P1-01 — Non-atomic AEF persistence: adds aef_submit_action() PL/pgSQL
--            SECURITY DEFINER function that inserts request + decision + gate +
--            receipt atomically in a single transaction (or rolls back entirely).
--   P2-03 — Investigation cascade: changes ON DELETE CASCADE to ON DELETE RESTRICT
--            on impact_aef_requests.investigation_id so AEF audit records are
--            retained even if the parent investigation is deleted.
--            Classification: AUDIT_RETENTION_REQUIRED.
--   P3-01 — Public grants: explicit REVOKE ALL from PUBLIC on all AEF tables.
--
-- Idempotent: safe to re-run.

-- ── P3-01: revoke PUBLIC grants on all AEF tables ────────────────────────────
-- Supabase default grants PUBLIC USAGE on public schema. Ensure the AEF tables
-- cannot be touched by any role other than those explicitly granted.

REVOKE ALL ON public.impact_aef_requests  FROM PUBLIC;
REVOKE ALL ON public.impact_aef_decisions FROM PUBLIC;
REVOKE ALL ON public.impact_aef_gates     FROM PUBLIC;
REVOKE ALL ON public.impact_aef_receipts  FROM PUBLIC;

-- Re-grant the minimum the RLS policies need for authenticated reads.
GRANT SELECT ON public.impact_aef_requests  TO authenticated;
GRANT SELECT ON public.impact_aef_decisions TO authenticated;
GRANT SELECT ON public.impact_aef_gates     TO authenticated;
GRANT SELECT ON public.impact_aef_receipts  TO authenticated;

-- ── P2-03: AUDIT_RETENTION_REQUIRED — restrict investigation deletion ─────────
-- AEF receipts are consequential-action audit records. Silently losing them
-- when an investigation is deleted violates audit-retention requirements.
-- Change ON DELETE CASCADE → ON DELETE RESTRICT on the investigation FK.
-- Any attempt to delete an investigation that has AEF records will fail with
-- a foreign-key violation, forcing the caller to handle retention explicitly.

DO $$
DECLARE
  v_constraint text;
BEGIN
  SELECT conname INTO v_constraint
  FROM pg_constraint
  WHERE conrelid = 'public.impact_aef_requests'::regclass
    AND confrelid = 'public.impact_investigations'::regclass
    AND contype = 'f';
  IF v_constraint IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.impact_aef_requests DROP CONSTRAINT %I', v_constraint);
  END IF;
  ALTER TABLE public.impact_aef_requests
    ADD CONSTRAINT impact_aef_requests_investigation_fk
      FOREIGN KEY (investigation_id)
      REFERENCES public.impact_investigations(id)
      ON DELETE RESTRICT;
END;
$$;

-- ── P1-01: atomic AEF submit RPC ─────────────────────────────────────────────
--
-- aef_submit_action() inserts the four AEF records (request, policy decision,
-- optional human gate, receipt) in a single Postgres transaction. If any insert
-- fails the whole operation is rolled back — no orphaned requests, no stranded
-- idempotency keys, no partial state.
--
-- Security:
--   * SECURITY DEFINER: runs as the function owner, not the calling role.
--   * SET search_path: prevents schema-hijacking attacks.
--   * No dynamic SQL: all table/column names are constants.
--   * No user-supplied identifiers interpolated into SQL strings.
--   * Validates format of key parameters before touching any table.
--   * REVOKE from PUBLIC, anon, authenticated; GRANT only to service_role.
--   * Caller identity is derived externally (JWT-verified CallerContext) and
--     passed as parameters — the function trusts the backend, not the client.
--   * The unique_violation for the idempotency key is caught and returned as a
--     structured JSON response rather than re-raised, so the caller can
--     distinguish a duplicate from a real persistence failure.

CREATE OR REPLACE FUNCTION public.aef_submit_action(
  p_request_id        uuid,
  p_correlation_id    text,
  p_caller_user_id    uuid,
  p_project_id        uuid,          -- nullable; derived from investigation
  p_service_id        text,
  p_intent_kind       text,
  p_investigation_id  uuid,
  p_idempotency_key   uuid,
  p_classification    text,
  p_requested_at      timestamptz,
  -- policy decision
  p_policy_outcome    text,
  p_policy_version    text,
  p_policy_reason     text,
  -- human gate (NULL when not CONSEQUENTIAL/IRREVERSIBLE)
  p_gate_id           uuid,
  p_gate_expires_at   timestamptz,
  -- receipt
  p_receipt_id        uuid,
  p_receipt_hash      text,
  p_execution_outcome text,
  p_issued_at         timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- ── parameter validation ──────────────────────────────────────────────────
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

  -- ── 1. request ──────────────────────────────────────────────────────────────
  INSERT INTO public.impact_aef_requests (
    request_id, correlation_id, caller_user_id, project_id, service_id,
    intent_kind, investigation_id, idempotency_key, classification, requested_at
  ) VALUES (
    p_request_id, p_correlation_id, p_caller_user_id, p_project_id, p_service_id,
    p_intent_kind, p_investigation_id, p_idempotency_key, p_classification, p_requested_at
  );

  -- ── 2. policy decision ──────────────────────────────────────────────────────
  INSERT INTO public.impact_aef_decisions (
    request_id, outcome, policy_version, reason, decided_at
  ) VALUES (
    p_request_id, p_policy_outcome, p_policy_version, p_policy_reason, p_issued_at
  );

  -- ── 3. human gate (conditional) ─────────────────────────────────────────────
  IF p_gate_id IS NOT NULL THEN
    INSERT INTO public.impact_aef_gates (
      gate_id, request_id, status, expires_at
    ) VALUES (
      p_gate_id, p_request_id, 'PENDING', p_gate_expires_at
    );
  END IF;

  -- ── 4. receipt ──────────────────────────────────────────────────────────────
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
    -- Idempotency key already exists: caller determines the correct response.
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_EXISTS');
  -- All other errors propagate: Postgres rolls back the implicit transaction.
END;
$$;

-- ── Restrict RPC access ───────────────────────────────────────────────────────
-- No public, anon, or authenticated access. Only service_role (used by the
-- impact-lab Edge Function) may call this function.

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
