-- IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01 — Gate resolution atomicity.
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
--
-- Closes:
--   P1-03(a) — Gate resolution non-atomic: adds aef_resolve_gate() PL/pgSQL
--              SECURITY DEFINER function that atomically validates, updates the
--              gate AND inserts the resolution receipt in a single Postgres
--              transaction. Rollback on any failure → no gate terminal without
--              receipt, no orphaned gate update.
--
-- Idempotent: safe to re-run (CREATE OR REPLACE).

-- ── aef_resolve_gate: atomic gate resolution RPC ─────────────────────────────
--
-- Executes atomically:
--   1. Lock gate row (FOR UPDATE)
--   2. Validate status = PENDING
--   3. Validate expiry
--   4. Validate parameters
--   5. Update gate status, approver_ref, binding_hash, resolved_at
--   6. Insert resolution receipt
--   7. Commit (implicit on RETURN)
--
-- On any failure: ROLLBACK — gate stays PENDING, no receipt inserted.
--
-- Security:
--   * SECURITY DEFINER: runs as function owner.
--   * SET search_path: prevents schema-hijacking.
--   * No dynamic SQL.
--   * FOR UPDATE on gate prevents concurrent double-resolution.
--   * REVOKE from PUBLIC, anon, authenticated; GRANT only to service_role.

CREATE OR REPLACE FUNCTION public.aef_resolve_gate(
  p_request_id    uuid,
  p_resolution    text,         -- 'APPROVED' or 'REJECTED'
  p_approver_ref  text,         -- opaque approver reference (max 64 chars)
  p_binding_hash  text,         -- 64-char hex (pre-verified by kernel, stored for audit)
  p_receipt_id    uuid,
  p_receipt_hash  text,         -- 64-char hex commitment
  p_policy_version text,
  p_issued_at     timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_gate    public.impact_aef_gates%ROWTYPE;
  v_request public.impact_aef_requests%ROWTYPE;
  v_policy_outcome  text;
  v_exec_outcome    text;
BEGIN
  -- ── parameter validation ──────────────────────────────────────────────────
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

  -- ── 1. lock gate row ──────────────────────────────────────────────────────
  -- FOR UPDATE prevents concurrent resolution of the same gate.
  SELECT * INTO v_gate
  FROM public.impact_aef_gates
  WHERE request_id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'GATE_NOT_FOUND');
  END IF;

  -- ── 2. validate status ────────────────────────────────────────────────────
  IF v_gate.status <> 'PENDING' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'GATE_ALREADY_RESOLVED', 'status', v_gate.status);
  END IF;

  -- ── 3. validate expiry ────────────────────────────────────────────────────
  -- >= to reject resolution exactly at the expiry instant (consistent with kernel).
  IF p_issued_at >= v_gate.expires_at THEN
    -- Atomically expire the gate; no receipt for EXPIRED (system timeout, not resolution).
    UPDATE public.impact_aef_gates
    SET status = 'EXPIRED', resolved_at = p_issued_at
    WHERE gate_id = v_gate.gate_id;
    RETURN jsonb_build_object('ok', false, 'code', 'GATE_EXPIRED');
  END IF;

  -- ── 4. load associated request ───────────────────────────────────────────
  SELECT * INTO v_request
  FROM public.impact_aef_requests
  WHERE request_id = p_request_id;

  IF NOT FOUND THEN
    -- Should never happen (FK enforces this), but fail safely.
    RETURN jsonb_build_object('ok', false, 'code', 'REQUEST_NOT_FOUND');
  END IF;

  -- ── 5. update gate ───────────────────────────────────────────────────────
  -- The impact_aef_gate_transitions trigger enforces PENDING→terminal and
  -- requires resolved_at to be set. Both conditions are satisfied here.
  UPDATE public.impact_aef_gates
  SET
    status       = p_resolution,
    approver_ref = p_approver_ref,
    binding_hash = p_binding_hash,
    resolved_at  = p_issued_at
  WHERE gate_id = v_gate.gate_id;

  -- ── 6. insert resolution receipt ─────────────────────────────────────────
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
    v_request.caller_user_id,   -- requester UUID (not approver_ref)
    v_request.project_id,
    'aef-gate-resolver',
    v_request.intent_kind,
    v_request.investigation_id,
    v_gate.gate_id,             -- gate_id as idempotency_key for resolution receipt
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
    -- Receipt PK collision: entire transaction rolls back (gate update reverted).
    RETURN jsonb_build_object('ok', false, 'code', 'RECEIPT_ALREADY_EXISTS');
  -- All other errors propagate: Postgres rolls back the implicit transaction.
END;
$$;

-- ── Restrict RPC access ───────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.aef_resolve_gate(
  uuid, text, text, text, uuid, text, text, timestamptz
) FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.aef_resolve_gate(
  uuid, text, text, text, uuid, text, text, timestamptz
) FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.aef_resolve_gate(
  uuid, text, text, text, uuid, text, text, timestamptz
) TO service_role;
