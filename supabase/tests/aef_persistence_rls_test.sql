-- IV-AEF-PERSISTENCE-01 — RLS, privileges and state-machine guards for the
-- durable AEF (migration 20260925000000). DISPOSABLE database only.
-- Every check RAISEs on failure; a clean run ends with 'AEF_PERSISTENCE_RLS: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

-- ── fixtures (migration owner) ──────────────────────────────────────────
INSERT INTO auth.users (id, email) VALUES
  ('a1000000-0000-4000-8000-00000000000a', 'aef-a@test.invalid'),
  ('b1000000-0000-4000-8000-00000000000b', 'aef-b@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.projects (id, user_id, name) VALUES
  ('a2000000-0000-4000-8000-00000000000a', 'a1000000-0000-4000-8000-00000000000a', 'A project'),
  ('b2000000-0000-4000-8000-00000000000b', 'b1000000-0000-4000-8000-00000000000b', 'B project')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.reg(p_subject text, p_request text, p_key text, p_extra jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT public.aef_register_operation(jsonb_build_object(
    'subject_id', p_subject, 'request_id', p_request, 'idempotency_key', p_key,
    'domain', 'internal', 'action', 'internal.mock_effect_consequential', 'tool_id', 'internal.mock_effect_consequential',
    'action_class', 'CONSEQUENTIAL', 'resource_type', 'project', 'resource_id', 'a2000000-0000-4000-8000-00000000000a',
    'payload_hash', repeat('a', 64), 'payload_bytes', 10,
    'policy_version', 'aef-policy/2026-09-25.1', 'risk_version', 'aef-risk/2026-09-25.1',
    'requires_human_gate', true) || p_extra)
$$;
CREATE OR REPLACE FUNCTION pg_temp.expect(p_reply jsonb, p_code text, p_label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_code IS NULL THEN
    IF (p_reply ->> 'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION '% expected ok, got %', p_label, p_reply; END IF;
  ELSIF p_reply ->> 'code' IS DISTINCT FROM p_code THEN
    RAISE EXCEPTION '% expected %, got %', p_label, p_code, p_reply;
  END IF;
END $$;
CREATE OR REPLACE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', uid, false);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', false);
END $$;

-- ── as service_role: A registers a gated operation, B one of its own ────
SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000001', 'key-1');
  PERFORM pg_temp.expect(r, NULL, 'T00 register A');
  IF r #>> '{operation,state}' <> 'AWAITING_APPROVAL' OR r #>> '{gate,state}' <> 'REVIEW_REQUIRED' THEN
    RAISE EXCEPTION 'T00 unexpected initial state %', r;
  END IF;
  PERFORM set_config('aef.t.op_a', r #>> '{operation,operation_id}', false);
  PERFORM set_config('aef.t.gate_a', r #>> '{gate,gate_id}', false);
  PERFORM set_config('aef.t.bind_a', r #>> '{operation,binding_hash}', false);

  r := pg_temp.reg('b1000000-0000-4000-8000-00000000000b', 'b3000000-0000-4000-8000-000000000001', 'key-1',
                   jsonb_build_object('resource_id', 'b2000000-0000-4000-8000-00000000000b'));
  PERFORM pg_temp.expect(r, NULL, 'T00 register B (same key, other subject: namespaced)');
  IF r #>> '{operation,operation_id}' = current_setting('aef.t.op_a') THEN
    RAISE EXCEPTION 'T00 idempotency key not namespaced by subject';
  END IF;
  PERFORM set_config('aef.t.op_b', r #>> '{operation,operation_id}', false);
END $$;
RESET ROLE;

-- ── T01 anon: no table, no function ─────────────────────────────────────
SET ROLE anon;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['aef_operations', 'aef_human_gates', 'aef_receipts', 'aef_audit_events', 'aef_audit_heads'] LOOP
    BEGIN
      EXECUTE format('SELECT count(*) FROM public.%I', t);
      RAISE EXCEPTION 'T01 anon could read %', t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
  BEGIN
    PERFORM public.aef_get_operation('{}'::jsonb);
    RAISE EXCEPTION 'T01 anon could execute an AEF function';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- ── T02..T05 authenticated: own rows only, read-only, no functions ──────
SELECT pg_temp.act_as('a1000000-0000-4000-8000-00000000000a');
SET ROLE authenticated;
DO $$
DECLARE f text;
BEGIN
  IF (SELECT count(id) FROM public.aef_operations) <> 1 THEN RAISE EXCEPTION 'T02 owner should see exactly own operation'; END IF;
  IF EXISTS (SELECT 1 FROM public.aef_operations WHERE subject_id <> auth.uid()) THEN RAISE EXCEPTION 'T02 foreign operation visible'; END IF;
  IF (SELECT count(*) FROM public.aef_human_gates) <> 1 THEN RAISE EXCEPTION 'T02 owner gate count'; END IF;
  IF (SELECT count(*) FROM public.aef_audit_events WHERE subject_id <> auth.uid()) <> 0 THEN RAISE EXCEPTION 'T02 foreign audit visible'; END IF;
  IF (SELECT count(*) FROM public.aef_audit_events) < 2 THEN RAISE EXCEPTION 'T02 own audit trail not visible'; END IF;
  BEGIN
    PERFORM execution_token FROM public.aef_operations;
    RAISE EXCEPTION 'T03 execution_token readable by end user';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM count(*) FROM public.aef_audit_heads;
    RAISE EXCEPTION 'T03 audit heads readable by end user';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.aef_operations SET state = 'AUTHORIZED';
    RAISE EXCEPTION 'T04 end user updated an operation';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.aef_human_gates SET state = 'AUTHORIZED', approver_id = auth.uid();
    RAISE EXCEPTION 'T04 end user approved a gate directly';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.aef_receipts (id, operation_id, subject_id, receipt, receipt_hash)
    VALUES (gen_random_uuid(), current_setting('aef.t.op_a')::uuid, auth.uid(), '{}'::jsonb, repeat('0', 64));
    RAISE EXCEPTION 'T04 end user forged a receipt';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    DELETE FROM public.aef_audit_events;
    RAISE EXCEPTION 'T04 end user deleted audit events';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  FOREACH f IN ARRAY ARRAY['aef_register_operation', 'aef_decide_gate', 'aef_claim_execution', 'aef_complete_execution',
                           'aef_cancel_operation', 'aef_recover', 'aef_get_operation', 'aef_record_denial',
                           'aef_verify_receipt', 'aef_verify_audit_chain'] LOOP
    BEGIN
      EXECUTE format('SELECT public.%I(%L::jsonb)', f, '{}');
      RAISE EXCEPTION 'T05 authenticated could execute %', f;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
END $$;
RESET ROLE;

SELECT pg_temp.act_as('b1000000-0000-4000-8000-00000000000b');
SET ROLE authenticated;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.aef_operations WHERE id = current_setting('aef.t.op_a')::uuid) THEN
    RAISE EXCEPTION 'T02 foreign user sees A operation';
  END IF;
  IF EXISTS (SELECT 1 FROM public.aef_human_gates WHERE id = current_setting('aef.t.gate_a')::uuid) THEN
    RAISE EXCEPTION 'T02 foreign user sees A gate';
  END IF;
END $$;
RESET ROLE;

-- ── T06..T14 as service_role: RPC semantics ─────────────────────────────
SET ROLE service_role;
DO $$
DECLARE r jsonb; v_claim jsonb;
BEGIN
  -- T06 mass assignment / type confusion
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000009', 'k-ma',
                                     '{"state":"SUCCEEDED"}'), 'ARGUMENT_REJECTED', 'T06a extra key');
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000009', 'k-ma',
                                     '{"requires_human_gate":"true"}'), 'ARGUMENT_REJECTED', 'T06b string boolean');
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000009', 'k-ma',
                                     '{"requires_human_gate":false}'), 'ARGUMENT_REJECTED', 'T06c consequential without gate');
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000009', 'k-ma',
                                     '{"payload_bytes":99999}'), 'ARGUMENT_REJECTED', 'T06d oversized payload');
  PERFORM pg_temp.expect(public.aef_decide_gate(jsonb_build_object('gate_id', current_setting('aef.t.gate_a'),
    'approver_id', 'a1000000-0000-4000-8000-00000000000a', 'decision', 'APPROVE', 'binding_hash', current_setting('aef.t.bind_a'),
    'policy_version', 'aef-policy/2026-09-25.1', 'approved', true)), 'ARGUMENT_REJECTED', 'T06e decide extra key');
  PERFORM pg_temp.expect(public.aef_register_operation('[]'::jsonb), 'ARGUMENT_REJECTED', 'T06f non-object');

  -- T07 resource protection (server-side ownership, no existence oracle)
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000010', 'k-res1',
    '{"resource_id":"b2000000-0000-4000-8000-00000000000b"}'), 'RESOURCE_FORBIDDEN', 'T07a foreign project');
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000011', 'k-res2',
    '{"resource_id":"c2000000-0000-4000-8000-00000000000c"}'), 'RESOURCE_FORBIDDEN', 'T07b missing project');
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000012', 'k-res3',
    '{"resource_type":"file"}'), 'RESOURCE_TYPE_UNSUPPORTED', 'T07c unsupported resource type');
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000013', 'k-dom',
    '{"domain":"quant","action":"quant.paper.order","action_class":"REVERSIBLE"}'), 'POLICY_DENIED', 'T07d quant non-read');

  -- T08 idempotency: replay / conflict / request replay
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000002', 'key-1');
  PERFORM pg_temp.expect(r, NULL, 'T08a replay');
  IF r ->> 'outcome' <> 'REPLAY' OR r #>> '{operation,operation_id}' <> current_setting('aef.t.op_a') THEN
    RAISE EXCEPTION 'T08a replay did not return the original operation: %', r;
  END IF;
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000003', 'key-1',
    jsonb_build_object('payload_hash', repeat('b', 64))), 'IDEMPOTENCY_CONFLICT', 'T08b same key, other payload');
  PERFORM pg_temp.expect(pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000001', 'key-new'),
    'REQUEST_REPLAYED', 'T08c request_id reuse');

  -- T09 foreign approver, wrong binding, not-yet-approved claim
  PERFORM pg_temp.expect(public.aef_decide_gate(jsonb_build_object('gate_id', current_setting('aef.t.gate_a'),
    'approver_id', 'b1000000-0000-4000-8000-00000000000b', 'decision', 'APPROVE', 'binding_hash', current_setting('aef.t.bind_a'),
    'policy_version', 'aef-policy/2026-09-25.1')), 'GATE_NOT_FOUND', 'T09a foreign approver');
  PERFORM pg_temp.expect(public.aef_decide_gate(jsonb_build_object('gate_id', current_setting('aef.t.gate_a'),
    'approver_id', 'a1000000-0000-4000-8000-00000000000a', 'decision', 'APPROVE', 'binding_hash', repeat('c', 64),
    'policy_version', 'aef-policy/2026-09-25.1')), 'APPROVAL_BINDING_MISMATCH', 'T09b binding mismatch');
  PERFORM pg_temp.expect(public.aef_claim_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_a'),
    'subject_id', 'a1000000-0000-4000-8000-00000000000a', 'binding_hash', current_setting('aef.t.bind_a'),
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60)), 'NOT_CLAIMABLE', 'T09c claim before approval');
  IF (SELECT state FROM public.aef_human_gates WHERE id = current_setting('aef.t.gate_a')::uuid) <> 'REVIEW_REQUIRED' THEN
    RAISE EXCEPTION 'T09 gate changed after denied decisions';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aef_audit_events WHERE operation_id = current_setting('aef.t.op_a')::uuid
                  AND reason_code = 'APPROVER_NOT_AUTHORIZED') THEN
    RAISE EXCEPTION 'T09 foreign approval attempt not audited';
  END IF;

  -- T10 approve → claim (foreign subject cannot) → complete → receipt
  PERFORM pg_temp.expect(public.aef_decide_gate(jsonb_build_object('gate_id', current_setting('aef.t.gate_a'),
    'approver_id', 'a1000000-0000-4000-8000-00000000000a', 'decision', 'APPROVE', 'binding_hash', current_setting('aef.t.bind_a'),
    'policy_version', 'aef-policy/2026-09-25.1')), NULL, 'T10a approve');
  PERFORM pg_temp.expect(public.aef_claim_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_a'),
    'subject_id', 'b1000000-0000-4000-8000-00000000000b', 'binding_hash', current_setting('aef.t.bind_a'),
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60)), 'OPERATION_NOT_FOUND', 'T10b foreign claim');
  v_claim := public.aef_claim_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_a'),
    'subject_id', 'a1000000-0000-4000-8000-00000000000a', 'binding_hash', current_setting('aef.t.bind_a'),
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60));
  PERFORM pg_temp.expect(v_claim, NULL, 'T10c claim');
  IF v_claim #>> '{gate,state}' <> 'EXECUTED' THEN RAISE EXCEPTION 'T10c gate not consumed: %', v_claim; END IF;
  PERFORM pg_temp.expect(public.aef_claim_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_a'),
    'subject_id', 'a1000000-0000-4000-8000-00000000000a', 'binding_hash', current_setting('aef.t.bind_a'),
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60)), 'NOT_CLAIMABLE', 'T10d second claim');
  PERFORM pg_temp.expect(public.aef_complete_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_a'),
    'execution_token', gen_random_uuid(), 'result', 'SUCCEEDED')), 'EXECUTION_TOKEN_INVALID', 'T10e forged token');
  r := public.aef_complete_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_a'),
    'execution_token', v_claim ->> 'execution_token', 'result', 'SUCCEEDED'));
  PERFORM pg_temp.expect(r, NULL, 'T10f complete');
  IF r #>> '{receipt,receipt,outcome}' <> 'SUCCESS' OR r #>> '{receipt,receipt,approver_id}' <> 'a1000000-0000-4000-8000-00000000000a'
     OR r #>> '{receipt,receipt,policy_decision}' <> 'ALLOWED' THEN
    RAISE EXCEPTION 'T10f receipt wrong: %', r;
  END IF;
  PERFORM set_config('aef.t.receipt_a', r #>> '{receipt,receipt}', false);
  PERFORM pg_temp.expect(public.aef_complete_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_a'),
    'execution_token', v_claim ->> 'execution_token', 'result', 'FAILED_NO_SIDE_EFFECT')), 'EXECUTION_TOKEN_INVALID', 'T10g re-complete');
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000004', 'key-1');
  IF r ->> 'outcome' <> 'REPLAY' OR r #>> '{receipt,receipt,outcome}' <> 'SUCCESS' THEN
    RAISE EXCEPTION 'T10h replay after completion must return the persisted receipt: %', r;
  END IF;

  -- T11 receipt verification / forgery
  r := public.aef_verify_receipt(jsonb_build_object('receipt', current_setting('aef.t.receipt_a')::jsonb));
  IF (r ->> 'valid')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'T11a genuine receipt rejected: %', r; END IF;
  r := public.aef_verify_receipt(jsonb_build_object('receipt',
         jsonb_set(current_setting('aef.t.receipt_a')::jsonb, '{outcome}', '"PARTIAL"')));
  IF r ->> 'reason' <> 'RECEIPT_MISMATCH' THEN RAISE EXCEPTION 'T11b altered receipt accepted: %', r; END IF;
  r := public.aef_verify_receipt(jsonb_build_object('receipt',
         jsonb_set(current_setting('aef.t.receipt_a')::jsonb, '{receipt_id}', to_jsonb(gen_random_uuid()::text))));
  IF r ->> 'reason' <> 'RECEIPT_UNKNOWN' THEN RAISE EXCEPTION 'T11c invented receipt accepted: %', r; END IF;

  -- T12 policy version change invalidates a pending approval
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000020', 'key-pv');
  PERFORM pg_temp.expect(public.aef_decide_gate(jsonb_build_object('gate_id', r #>> '{gate,gate_id}',
    'approver_id', 'a1000000-0000-4000-8000-00000000000a', 'decision', 'APPROVE', 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-12-01.1')), 'POLICY_VERSION_CHANGED', 'T12 policy changed');
  IF (SELECT state FROM public.aef_operations WHERE id = (r #>> '{operation,operation_id}')::uuid) <> 'INVALIDATED' THEN
    RAISE EXCEPTION 'T12 operation not invalidated';
  END IF;
  -- T12b approved under version N, claimed under version N+1: invalidated, gate never consumed.
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000021', 'key-pv2');
  PERFORM pg_temp.expect(public.aef_decide_gate(jsonb_build_object('gate_id', r #>> '{gate,gate_id}',
    'approver_id', 'a1000000-0000-4000-8000-00000000000a', 'decision', 'APPROVE', 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-09-25.1')), NULL, 'T12b approve');
  PERFORM pg_temp.expect(public.aef_claim_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', 'a1000000-0000-4000-8000-00000000000a', 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-12-01.1', 'lease_seconds', 60)), 'POLICY_VERSION_CHANGED', 'T12b claim under new policy');
  IF (SELECT state FROM public.aef_human_gates WHERE operation_id = (r #>> '{operation,operation_id}')::uuid) <> 'INVALIDATED'
     OR (SELECT attempt_count FROM public.aef_operations WHERE id = (r #>> '{operation,operation_id}')::uuid) <> 0 THEN
    RAISE EXCEPTION 'T12b stale approval was consumed';
  END IF;

  -- T13 cancellation: pending ok, in-flight refused, foreign refused
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000030', 'key-cancel');
  PERFORM pg_temp.expect(public.aef_cancel_operation(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', 'b1000000-0000-4000-8000-00000000000b')), 'OPERATION_NOT_FOUND', 'T13a foreign cancel');
  r := public.aef_cancel_operation(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', 'a1000000-0000-4000-8000-00000000000a'));
  PERFORM pg_temp.expect(r, NULL, 'T13b cancel pending');
  IF r #>> '{operation,state}' <> 'CANCELLED' OR r #>> '{gate,state}' <> 'CANCELLED'
     OR r #>> '{receipt,receipt,outcome}' <> 'NOT_EXECUTED' THEN
    RAISE EXCEPTION 'T13b cancel result wrong: %', r;
  END IF;
  PERFORM pg_temp.expect(public.aef_cancel_operation(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', 'a1000000-0000-4000-8000-00000000000a')), 'OPERATION_TERMINAL', 'T13c cancel terminal');
END $$;

-- ── T14 guard triggers stop service_role from bypassing the state machine ─
DO $$
DECLARE r jsonb; v_op uuid;
BEGIN
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000040', 'key-guard');
  v_op := (r #>> '{operation,operation_id}')::uuid;
  BEGIN
    UPDATE public.aef_operations SET state = 'AUTHORIZED' WHERE id = v_op;
    RAISE EXCEPTION 'T14a authorized without an approved gate';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.aef_operations SET state = 'EXECUTING', attempt_count = 1, execution_token = gen_random_uuid(),
           lease_expires_at = now() + interval '1 minute' WHERE id = v_op;
    RAISE EXCEPTION 'T14b skipped approval straight to EXECUTING';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.aef_human_gates SET state = 'AUTHORIZED', approver_id = 'b1000000-0000-4000-8000-00000000000b'
     WHERE operation_id = v_op;
    RAISE EXCEPTION 'T14c foreign approver written directly';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.aef_operations SET state = 'AUTHORIZED' WHERE id = current_setting('aef.t.op_a')::uuid;
    RAISE EXCEPTION 'T14d terminal state reverted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.aef_operations SET payload_hash = repeat('d', 64) WHERE id = v_op;
    RAISE EXCEPTION 'T14e bound payload hash rewritten';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    DELETE FROM public.aef_operations WHERE id = v_op;
    RAISE EXCEPTION 'T14f operation deleted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.aef_receipts SET receipt_hash = repeat('0', 64);
    RAISE EXCEPTION 'T14g receipt updated';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.aef_receipts (id, operation_id, subject_id, receipt, receipt_hash)
    SELECT gen_random_uuid(), v_op, 'a1000000-0000-4000-8000-00000000000a', '{"outcome":"SUCCESS"}', repeat('0', 64);
    RAISE EXCEPTION 'T14h forged receipt for an open operation';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.aef_audit_heads SET last_seq = last_seq + 5;
    RAISE EXCEPTION 'T14i audit head moved';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    INSERT INTO public.aef_audit_events (subject_id, seq, event_type, occurred_at, prev_hash, event_hash)
    VALUES ('a1000000-0000-4000-8000-00000000000a', 999, 'FORGED', now(), repeat('0', 64), repeat('1', 64));
    RAISE EXCEPTION 'T14j forged audit event';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;

-- Even the table owner / superuser hits the append-only guards.
DO $$ BEGIN
  BEGIN
    UPDATE public.aef_receipts SET receipt_hash = repeat('0', 64);
    RAISE EXCEPTION 'T15a superuser updated a receipt';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    DELETE FROM public.aef_audit_events;
    RAISE EXCEPTION 'T15b superuser deleted audit events';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    TRUNCATE public.aef_audit_events;
    RAISE EXCEPTION 'T15c superuser truncated audit events';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
END $$;

-- ── T16 expiry + crash recovery (clock moved by the superuser only) ─────
SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000050', 'key-expire');
  PERFORM set_config('aef.t.op_exp', r #>> '{operation,operation_id}', false);
  PERFORM set_config('aef.t.gate_exp', r #>> '{gate,gate_id}', false);
  PERFORM set_config('aef.t.bind_exp', r #>> '{operation,binding_hash}', false);
  r := pg_temp.reg('a1000000-0000-4000-8000-00000000000a', 'a3000000-0000-4000-8000-000000000051', 'key-crash');
  PERFORM public.aef_decide_gate(jsonb_build_object('gate_id', r #>> '{gate,gate_id}',
    'approver_id', 'a1000000-0000-4000-8000-00000000000a', 'decision', 'APPROVE', 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-09-25.1'));
  r := public.aef_claim_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', 'a1000000-0000-4000-8000-00000000000a', 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60));
  PERFORM pg_temp.expect(r, NULL, 'T16 claim before crash');
  PERFORM set_config('aef.t.op_crash', r #>> '{operation,operation_id}', false);
  PERFORM set_config('aef.t.token_crash', r ->> 'execution_token', false);
END $$;
RESET ROLE;

SET session_replication_role = replica;  -- test clock: move deadlines into the past
UPDATE public.aef_human_gates SET expires_at = now() - interval '1 second' WHERE id = current_setting('aef.t.gate_exp')::uuid;
UPDATE public.aef_operations SET lease_expires_at = now() - interval '1 second' WHERE id = current_setting('aef.t.op_crash')::uuid;
SET session_replication_role = origin;

SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  PERFORM pg_temp.expect(public.aef_decide_gate(jsonb_build_object('gate_id', current_setting('aef.t.gate_exp'),
    'approver_id', 'a1000000-0000-4000-8000-00000000000a', 'decision', 'APPROVE', 'binding_hash', current_setting('aef.t.bind_exp'),
    'policy_version', 'aef-policy/2026-09-25.1')), 'GATE_EXPIRED', 'T16a approve after expiry');
  IF (SELECT state FROM public.aef_operations WHERE id = current_setting('aef.t.op_exp')::uuid) <> 'EXPIRED' THEN
    RAISE EXCEPTION 'T16a operation not expired';
  END IF;
  r := public.aef_recover('{}'::jsonb);
  IF (r ->> 'unknown_outcome')::int <> 1 THEN RAISE EXCEPTION 'T16b recovery result %', r; END IF;
  IF (SELECT state FROM public.aef_operations WHERE id = current_setting('aef.t.op_crash')::uuid) <> 'UNKNOWN_OUTCOME' THEN
    RAISE EXCEPTION 'T16b crashed execution not UNKNOWN_OUTCOME';
  END IF;
  IF (SELECT receipt ->> 'outcome' FROM public.aef_receipts WHERE operation_id = current_setting('aef.t.op_crash')::uuid) <> 'UNKNOWN_OUTCOME' THEN
    RAISE EXCEPTION 'T16b receipt does not say UNKNOWN_OUTCOME';
  END IF;
  PERFORM pg_temp.expect(public.aef_complete_execution(jsonb_build_object('operation_id', current_setting('aef.t.op_crash'),
    'execution_token', current_setting('aef.t.token_crash'), 'result', 'SUCCEEDED')), 'EXECUTION_TOKEN_INVALID', 'T16c late success after recovery');
  IF (SELECT attempt_count FROM public.aef_operations WHERE id = current_setting('aef.t.op_crash')::uuid) <> 1 THEN
    RAISE EXCEPTION 'T16d crashed execution was retried';
  END IF;

  -- T17 audit chains intact after everything above
  r := public.aef_verify_audit_chain(jsonb_build_object('subject_id', 'a1000000-0000-4000-8000-00000000000a'));
  IF (r ->> 'valid')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'T17a chain A invalid: %', r; END IF;
  r := public.aef_verify_audit_chain(jsonb_build_object('subject_id', 'b1000000-0000-4000-8000-00000000000b'));
  IF (r ->> 'valid')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'T17a chain B invalid: %', r; END IF;
END $$;
RESET ROLE;

-- T17b tampering (only possible for a superuser with triggers disabled) is detected.
SET session_replication_role = replica;
UPDATE public.aef_audit_events SET reason_code = 'TAMPERED'
 WHERE subject_id = 'b1000000-0000-4000-8000-00000000000b' AND seq = 1;
SET session_replication_role = origin;
SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.aef_verify_audit_chain(jsonb_build_object('subject_id', 'b1000000-0000-4000-8000-00000000000b'));
  IF (r ->> 'valid')::boolean IS NOT FALSE OR r ->> 'reason' <> 'EVENT_HASH_INVALID' THEN
    RAISE EXCEPTION 'T17b tampering not detected: %', r;
  END IF;
END $$;
RESET ROLE;

SELECT 'AEF_PERSISTENCE_RLS: PASS';
