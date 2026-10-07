-- IV-IMPACT-MACRO-08 HARDENING — migration 009
-- Child-table ownership gate (P1-2) + AEF caller binding (P1-3) +
-- _impact_caller_tier STABLE→VOLATILE (P2-A).
--
-- P1-2 (TOCTOU service_role writes):
--   All writes to child impact_* tables use service_role (which bypasses RLS),
--   issued after an RLS-bound ownership read in the Edge Function. A triggered
--   BEFORE INSERT/UPDATE function now re-verifies that the actor (created_by /
--   updated_by) matches the investigation owner at the DB transaction boundary,
--   eliminating the cross-tenant write window and making service_role writes
--   fail-closed on ownership violations.
--
-- P1-3 (AEF caller binding):
--   aef_submit_action() accepted p_caller_user_id without verifying it against
--   investigation.owner_id. A service_role caller could pass any UUID. The
--   function now performs a SELECT against impact_investigations and returns
--   AEF_CALLER_NOT_OWNER if the investigation is not found or not owned by
--   p_caller_user_id. Callers must handle this new code.
--
-- P2-A (_impact_caller_tier STABLE → VOLATILE):
--   _impact_caller_tier() was declared STABLE but reads from profiles, a mutable
--   table. Correctness is preserved by the FOR UPDATE lock that precedes each
--   call, but the STABLE declaration could allow planner caching in edge contexts.
--   Change to VOLATILE eliminates the theoretical caching risk.
--
-- PRESERVED:
--   All existing trigger functions, their validation logic, and REVOKE/GRANT.
--   Migration 008 function bodies are unchanged.
--
-- PRODUCTION PROTECTION:
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate.

SET search_path = public, extensions;

-- ─── P1-2: child-table ownership gate ────────────────────────────────────────
--
-- Fires BEFORE INSERT OR UPDATE on every impact_* child table. On INSERT,
-- asserts created_by = investigation.owner_id. On UPDATE, asserts updated_by
-- = investigation.owner_id. Raises IMPACT_ACTOR_NOT_OWNER on violation.
--
-- This makes every service_role write fail-closed: the actor field the Edge
-- Function derives from the caller's verified JWT must match the investigation
-- owner recorded in the DB. A TOCTOU race that changed ownership between the
-- Edge Function read and the service_role write is caught here.

CREATE OR REPLACE FUNCTION public.impact_child_ownership_gate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_owner_id uuid;
  v_actor_id uuid;
BEGIN
  SELECT owner_id INTO v_owner_id
  FROM public.impact_investigations
  WHERE id = NEW.investigation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'IMPACT_INVESTIGATION_NOT_FOUND' USING ERRCODE = '23503';
  END IF;

  v_actor_id := CASE
    WHEN TG_OP = 'INSERT' THEN NEW.created_by
    ELSE NEW.updated_by
  END;

  IF v_actor_id IS DISTINCT FROM v_owner_id THEN
    RAISE EXCEPTION 'IMPACT_ACTOR_NOT_OWNER' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- INSERT gate: sources, claims, evidence, disputes, artifacts,
-- evidence_candidates, dossier_snapshots.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'impact_sources', 'impact_claims', 'impact_evidence',
    'impact_disputes', 'impact_artifacts', 'impact_evidence_candidates',
    'impact_dossier_snapshots'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_child_ownership_gate ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER impact_child_ownership_gate BEFORE INSERT ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.impact_child_ownership_gate()', t);
  END LOOP;
END $$;

-- UPDATE gate: sources (status change), disputes (resolution), candidates (review).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'impact_sources', 'impact_disputes', 'impact_evidence_candidates'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_child_ownership_gate_update ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER impact_child_ownership_gate_update BEFORE UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.impact_child_ownership_gate()', t);
  END LOOP;
END $$;

-- ─── P1-3: aef_submit_action — investigation ownership binding ────────────────
--
-- Adds a SELECT against impact_investigations to verify p_caller_user_id owns
-- the investigation. Returns AEF_CALLER_NOT_OWNER when the check fails so the
-- caller can distinguish the owner-mismatch case from a persistence failure.
-- Full function rewrite — signature and all other logic are unchanged from
-- migration 20261003000000_impact_aef_atomic_rpc.sql.

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
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- ── parameter validation (unchanged from migration 000) ───────────────────
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

  -- ── P1-3: verify caller owns the investigation ────────────────────────────
  -- The service_role caller passes p_caller_user_id; verify it is the actual
  -- owner so a misconfigured caller cannot record AEF audit trails on behalf
  -- of a user who does not own the investigation.
  IF NOT EXISTS (
    SELECT 1 FROM public.impact_investigations
    WHERE id = p_investigation_id
      AND owner_id = p_caller_user_id
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'AEF_CALLER_NOT_OWNER');
  END IF;

  -- ── 1. request ──────────────────────────────────────────────────────────
  INSERT INTO public.impact_aef_requests (
    request_id, correlation_id, caller_user_id, project_id, service_id,
    intent_kind, investigation_id, idempotency_key, classification, requested_at
  ) VALUES (
    p_request_id, p_correlation_id, p_caller_user_id, p_project_id, p_service_id,
    p_intent_kind, p_investigation_id, p_idempotency_key, p_classification, p_requested_at
  );

  -- ── 2. policy decision ───────────────────────────────────────────────────
  INSERT INTO public.impact_aef_decisions (
    request_id, outcome, policy_version, reason, decided_at
  ) VALUES (
    p_request_id, p_policy_outcome, p_policy_version, p_policy_reason, p_issued_at
  );

  -- ── 3. human gate (conditional) ──────────────────────────────────────────
  IF p_gate_id IS NOT NULL THEN
    INSERT INTO public.impact_aef_gates (
      gate_id, request_id, status, expires_at
    ) VALUES (
      p_gate_id, p_request_id, 'PENDING', p_gate_expires_at
    );
  END IF;

  -- ── 4. receipt ───────────────────────────────────────────────────────────
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

-- ─── P2-A: _impact_caller_tier() STABLE → VOLATILE ──────────────────────────
--
-- profiles.role can change between calls within the same transaction if the
-- row is not locked. Although the atomic RPCs always lock the profiles row
-- before calling this function, VOLATILE is the correct declaration for a
-- function that reads mutable state.

CREATE OR REPLACE FUNCTION public._impact_caller_tier()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
VOLATILE
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

COMMENT ON FUNCTION public._impact_caller_tier() IS
  'IV-IMPACT-MACRO-08 009 P2-A: re-derives caller tier from live profiles row. '
  'VOLATILE (was STABLE) — profiles.role is mutable. '
  'Callers MUST lock the profiles row (FOR UPDATE) before calling this function.';
