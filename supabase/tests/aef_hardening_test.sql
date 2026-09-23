-- IV-AEF-HARDENING-01 — retention, erasure, audit rate limit, reconciliation,
-- receipt v1.1 (migration 20260926000000). DISPOSABLE database only.
-- Every check RAISEs on failure; a clean run ends with 'AEF_HARDENING: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

-- Subjects: D retention · E rate limit · F erasure · G admin operator · H plain user · K holder
INSERT INTO auth.users (id, email) VALUES
  ('d1000000-0000-4000-8000-00000000000d', 'aef-d@test.invalid'),
  ('e1000000-0000-4000-8000-00000000000e', 'aef-e@test.invalid'),
  ('f1000000-0000-4000-8000-00000000000f', 'aef-f@test.invalid'),
  ('a7000000-0000-4000-8000-000000000007', 'aef-g@test.invalid'),
  ('a8000000-0000-4000-8000-000000000008', 'aef-h@test.invalid'),
  ('a9000000-0000-4000-8000-000000000009', 'aef-k@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.subject_roles (subject_type, subject_id, role, source)
VALUES ('user', 'a7000000-0000-4000-8000-000000000007', 'admin', 'operator_grant')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.expect(p_reply jsonb, p_code text, p_label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_code IS NULL THEN
    IF (p_reply ->> 'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION '% expected ok, got %', p_label, p_reply; END IF;
  ELSIF p_reply ->> 'code' IS DISTINCT FROM p_code THEN
    RAISE EXCEPTION '% expected %, got %', p_label, p_code, p_reply;
  END IF;
END $$;

-- Registers a no-gate REVERSIBLE operation; returns the register reply.
CREATE OR REPLACE FUNCTION pg_temp.reg(p_subject text, p_key text, p_request text DEFAULT NULL) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT public.aef_register_operation(jsonb_build_object(
    'subject_id', p_subject, 'request_id', coalesce(p_request, gen_random_uuid()::text), 'idempotency_key', p_key,
    'domain', 'internal', 'action', 'internal.mock_effect_reversible', 'tool_id', 'internal.mock_effect_reversible',
    'action_class', 'REVERSIBLE', 'payload_hash', repeat('a', 64), 'payload_bytes', 10,
    'policy_version', 'aef-policy/2026-09-25.1', 'risk_version', 'aef-risk/2026-09-25.1',
    'requires_human_gate', false))
$$;

-- Registers, claims and completes; returns the operation id.
CREATE OR REPLACE FUNCTION pg_temp.run_op(p_subject text, p_key text, p_result text) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE r jsonb; c jsonb;
BEGIN
  r := pg_temp.reg(p_subject, p_key);
  PERFORM pg_temp.expect(r, NULL, 'run_op register ' || p_key);
  c := public.aef_claim_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', p_subject, 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60));
  PERFORM pg_temp.expect(c, NULL, 'run_op claim ' || p_key);
  IF p_result IS NOT NULL THEN
    PERFORM pg_temp.expect(public.aef_complete_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
      'execution_token', c ->> 'execution_token', 'result', p_result)), NULL, 'run_op complete ' || p_key);
  END IF;
  RETURN (r #>> '{operation,operation_id}')::uuid;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.chain_ok(p_subject text) RETURNS boolean
LANGUAGE sql AS $$
  SELECT (public.aef_verify_audit_chain(jsonb_build_object('subject_id', p_subject)) ->> 'valid')::boolean
$$;

-- ── H01 privilege catalog for the new surface ───────────────────────────
DO $$
DECLARE t text; r text; f record;
BEGIN
  FOREACH t IN ARRAY ARRAY['aef_retention_policy', 'aef_legal_holds', 'aef_idempotency_tombstones',
                           'aef_reconciliation_verifiers', 'aef_reconciliations', 'aef_audit_windows',
                           'aef_audit_pending', 'aef_audit_coalesced', 'aef_audit_checkpoints', 'aef_erasures'] LOOP
    FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      IF has_table_privilege(r, 'public.' || t, 'INSERT,UPDATE,DELETE,TRUNCATE') THEN
        RAISE EXCEPTION 'H01 % has a write privilege on %', r, t;
      END IF;
    END LOOP;
    IF has_table_privilege('anon', 'public.' || t, 'SELECT') THEN RAISE EXCEPTION 'H01 anon can read %', t; END IF;
    IF t <> 'aef_reconciliations' AND has_table_privilege('authenticated', 'public.' || t, 'SELECT') THEN
      RAISE EXCEPTION 'H01 authenticated can read %', t;
    END IF;
  END LOOP;
  IF has_column_privilege('authenticated', 'public.aef_reconciliations', 'reconciler_id', 'SELECT') THEN
    RAISE EXCEPTION 'H01 end users can read the operator id';
  END IF;
  FOR f IN SELECT p.oid, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_' LOOP
    IF has_function_privilege('anon', f.oid, 'EXECUTE') OR has_function_privilege('authenticated', f.oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'H01 end-user role can execute %', f.proname;
    END IF;
    IF (left(f.proname, 5) = 'aef__') = has_function_privilege('service_role', f.oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'H01 wrong service_role EXECUTE on %', f.proname;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_proc p, unnest(p.proconfig) c WHERE p.oid = f.oid AND c = 'search_path=pg_catalog, pg_temp') THEN
      RAISE EXCEPTION 'H01 % does not pin search_path', f.proname;
    END IF;
  END LOOP;
  IF NOT has_function_privilege('service_role', 'public.aef_reconcile(jsonb)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.aef_purge(jsonb)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.aef_erase_subject(jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'H01 new RPCs not granted to service_role';
  END IF;
END $$;

-- ── H02 new receipts are aef-receipt/1.1 ────────────────────────────────
SET ROLE service_role;
DO $$
DECLARE v_op uuid;
BEGIN
  v_op := pg_temp.run_op('d1000000-0000-4000-8000-00000000000d', 'd-old-1', 'SUCCEEDED');
  PERFORM set_config('aef.t.d_old1', v_op::text, false);
  IF (SELECT receipt ->> 'receipt_version' FROM public.aef_receipts WHERE operation_id = v_op) <> 'aef-receipt/1.1'
     OR (SELECT receipt ->> 'receipt_kind' FROM public.aef_receipts WHERE operation_id = v_op) <> 'EXECUTION' THEN
    RAISE EXCEPTION 'H02 new receipt is not aef-receipt/1.1 EXECUTION';
  END IF;
  PERFORM set_config('aef.t.d_old1_receipt', (SELECT receipt::text FROM public.aef_receipts WHERE operation_id = v_op), false);
  PERFORM set_config('aef.t.d_old2', pg_temp.run_op('d1000000-0000-4000-8000-00000000000d', 'd-old-2', 'FAILED_NO_SIDE_EFFECT')::text, false);
  PERFORM set_config('aef.t.d_unknown', pg_temp.run_op('d1000000-0000-4000-8000-00000000000d', 'd-old-3', 'UNKNOWN_OUTCOME')::text, false);
  PERFORM set_config('aef.t.d_open', (pg_temp.reg('d1000000-0000-4000-8000-00000000000d', 'd-open') #>> '{operation,operation_id}'), false);
  PERFORM set_config('aef.t.d_recent', pg_temp.run_op('d1000000-0000-4000-8000-00000000000d', 'd-recent', 'SUCCEEDED')::text, false);
  PERFORM set_config('aef.t.k_old', pg_temp.run_op('a9000000-0000-4000-8000-000000000009', 'k-old', 'SUCCEEDED')::text, false);
END $$;
RESET ROLE;

-- ── H03 retention purge ─────────────────────────────────────────────────
INSERT INTO public.aef_legal_holds (subject_id, reason_code) VALUES ('a9000000-0000-4000-8000-000000000009', 'LITIGATION_HOLD');
SET session_replication_role = replica;  -- test clock: age the terminal operations past retention
UPDATE public.aef_operations SET completed_at = now() - interval '400 days', expires_at = now() - interval '399 days'
 WHERE id IN (current_setting('aef.t.d_old1')::uuid, current_setting('aef.t.d_old2')::uuid,
              current_setting('aef.t.d_unknown')::uuid, current_setting('aef.t.k_old')::uuid);
UPDATE public.aef_operations SET created_at = now() - interval '400 days' WHERE id = current_setting('aef.t.d_open')::uuid;
SET session_replication_role = origin;

SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  PERFORM pg_temp.expect(public.aef_purge('{"limit": 1000, "force": true}'::jsonb), 'ARGUMENT_REJECTED', 'H03 mass assignment');
  r := public.aef_purge('{}'::jsonb);
  PERFORM pg_temp.expect(r, NULL, 'H03 purge');
  IF EXISTS (SELECT 1 FROM public.aef_operations WHERE id IN (current_setting('aef.t.d_old1')::uuid, current_setting('aef.t.d_old2')::uuid)) THEN
    RAISE EXCEPTION 'H03a expired terminal operations not purged: %', r;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aef_operations WHERE id = current_setting('aef.t.d_unknown')::uuid) THEN
    RAISE EXCEPTION 'H03b unreconciled UNKNOWN_OUTCOME was purged';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aef_operations WHERE id = current_setting('aef.t.d_open')::uuid) THEN
    RAISE EXCEPTION 'H03c open operation was purged';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aef_operations WHERE id = current_setting('aef.t.d_recent')::uuid) THEN
    RAISE EXCEPTION 'H03d recent terminal operation was purged';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aef_operations WHERE id = current_setting('aef.t.k_old')::uuid) THEN
    RAISE EXCEPTION 'H03e operation under legal hold was purged';
  END IF;
  IF (SELECT count(*) FROM public.aef_idempotency_tombstones WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d') <> 2 THEN
    RAISE EXCEPTION 'H03f tombstones missing';
  END IF;
  IF (SELECT count(*) FROM public.aef_audit_events WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d'
        AND event_type = 'OPERATION_PURGED') <> 2 THEN
    RAISE EXCEPTION 'H03g purge not audited';
  END IF;
  IF NOT pg_temp.chain_ok('d1000000-0000-4000-8000-00000000000d') THEN RAISE EXCEPTION 'H03h chain broken by purge'; END IF;
  IF public.aef_verify_receipt(jsonb_build_object('receipt', current_setting('aef.t.d_old1_receipt')::jsonb)) ->> 'reason'
     IS DISTINCT FROM 'RECEIPT_UNKNOWN' THEN
    RAISE EXCEPTION 'H03i purged receipt still verifies';
  END IF;
  -- A retired key or request id can never start a new operation.
  PERFORM pg_temp.expect(pg_temp.reg('d1000000-0000-4000-8000-00000000000d', 'd-old-1'), 'IDEMPOTENCY_KEY_RETIRED', 'H03j retired key');
  PERFORM pg_temp.expect(pg_temp.reg('d1000000-0000-4000-8000-00000000000d', 'd-fresh',
    (SELECT request_id::text FROM public.aef_idempotency_tombstones WHERE operation_id = current_setting('aef.t.d_old1')::uuid)),
    'REQUEST_REPLAYED', 'H03k retired request id');
  -- purge is idempotent
  r := public.aef_purge('{}'::jsonb);
  IF (r ->> 'purged_operations')::int <> 0 THEN RAISE EXCEPTION 'H03l second purge purged again: %', r; END IF;
END $$;
RESET ROLE;

-- ── H04 audit prefix pruning behind a checkpoint ────────────────────────
SET session_replication_role = replica;
UPDATE public.aef_audit_events SET occurred_at = now() - interval '800 days'
 WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d';
SET session_replication_role = origin;
-- Aging the timestamps changes the hashed content: rebuild D's chain
-- hashes as the superuser (test setup only) so that it is valid again.
DO $$
DECLARE e record; v_prev text := repeat('0', 64); v_hash text;
BEGIN
  SET LOCAL session_replication_role = replica;
  FOR e IN SELECT * FROM public.aef_audit_events WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d' ORDER BY seq LOOP
    v_hash := public.aef__event_hash(e.subject_id, e.seq, e.operation_id, e.event_type, e.from_state, e.to_state,
                                     e.reason_code, e.ref_hash, e.occurred_at, v_prev);
    UPDATE public.aef_audit_events SET prev_hash = v_prev, event_hash = v_hash WHERE id = e.id;
    v_prev := v_hash;
  END LOOP;
  UPDATE public.aef_audit_heads SET last_hash = v_prev WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d';
END $$;
SET ROLE service_role;
DO $$
DECLARE r jsonb; v_before bigint; v_min bigint;
BEGIN
  IF NOT pg_temp.chain_ok('d1000000-0000-4000-8000-00000000000d') THEN RAISE EXCEPTION 'H04 setup chain invalid'; END IF;
  SELECT count(*) INTO v_before FROM public.aef_audit_events WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d';
  r := public.aef_purge('{}'::jsonb);
  IF (r ->> 'pruned_events')::int < 1 THEN RAISE EXCEPTION 'H04a nothing pruned: %', r; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aef_audit_checkpoints WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d') THEN
    RAISE EXCEPTION 'H04b no checkpoint';
  END IF;
  IF NOT pg_temp.chain_ok('d1000000-0000-4000-8000-00000000000d') THEN RAISE EXCEPTION 'H04c chain invalid after pruning'; END IF;
  -- Events of operations that still exist (open, unreconciled unknown, recent) are never pruned.
  SELECT min(seq) INTO v_min FROM public.aef_audit_events WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d';
  IF EXISTS (SELECT 1 FROM public.aef_audit_events e WHERE e.subject_id = 'd1000000-0000-4000-8000-00000000000d'
               AND e.operation_id IN (current_setting('aef.t.d_unknown')::uuid, current_setting('aef.t.d_open')::uuid)
               AND e.seq < v_min) OR NOT EXISTS (
             SELECT 1 FROM public.aef_audit_events e WHERE e.subject_id = 'd1000000-0000-4000-8000-00000000000d'
               AND e.operation_id = current_setting('aef.t.d_unknown')::uuid) THEN
    RAISE EXCEPTION 'H04d evidence of a live operation was pruned';
  END IF;
  -- Receipts of live operations still verify after pruning.
  IF (public.aef_verify_receipt(jsonb_build_object('receipt',
        (SELECT receipt FROM public.aef_receipts WHERE operation_id = current_setting('aef.t.d_recent')::uuid))) ->> 'valid')::boolean
     IS NOT TRUE THEN
    RAISE EXCEPTION 'H04e live receipt no longer verifies';
  END IF;
END $$;
RESET ROLE;

-- ── H05 audit rate limit: denials coalesced, never dropped ──────────────
SET ROLE service_role;
DO $$
DECLARE i int; v_individual bigint; v_pending bigint;
BEGIN
  FOR i IN 1..25 LOOP
    PERFORM pg_temp.expect(public.aef_record_denial(jsonb_build_object('subject_id', 'e1000000-0000-4000-8000-00000000000e',
      'reason_code', 'UNKNOWN_TOOL')), NULL, 'H05 denial ' || i);
  END LOOP;
  SELECT count(*) INTO v_individual FROM public.aef_audit_events
   WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e' AND event_type = 'REQUEST_DENIED';
  SELECT coalesce(sum(count), 0) INTO v_pending FROM public.aef_audit_pending WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e';
  IF v_individual <> 20 OR v_pending <> 5 THEN
    RAISE EXCEPTION 'H05a expected 20 individual + 5 pending, got % + %', v_individual, v_pending;
  END IF;
  -- Non-coalescible events are never throttled.
  PERFORM pg_temp.run_op('e1000000-0000-4000-8000-00000000000e', 'e-op', 'SUCCEEDED');
  IF NOT EXISTS (SELECT 1 FROM public.aef_audit_events WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e'
                   AND event_type = 'RECEIPT_ISSUED') THEN
    RAISE EXCEPTION 'H05b receipt event throttled';
  END IF;
END $$;
RESET ROLE;
UPDATE public.aef_audit_windows SET window_start = now() - interval '2 minutes'
 WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e';
SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.aef_recover('{}'::jsonb);
  IF (r ->> 'coalesced_flushed')::int < 1 THEN RAISE EXCEPTION 'H05c window not flushed: %', r; END IF;
  IF (SELECT count FROM public.aef_audit_coalesced WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e'
        AND reason_code = 'UNKNOWN_TOOL') <> 5 THEN
    RAISE EXCEPTION 'H05d coalesced count lost';
  END IF;
  IF EXISTS (SELECT 1 FROM public.aef_audit_pending WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e') THEN
    RAISE EXCEPTION 'H05e pending not cleared';
  END IF;
  IF NOT pg_temp.chain_ok('e1000000-0000-4000-8000-00000000000e') THEN RAISE EXCEPTION 'H05f chain invalid'; END IF;
END $$;
RESET ROLE;
-- Tampering with a coalesced count is detected.
SET session_replication_role = replica;
UPDATE public.aef_audit_coalesced SET count = 1 WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e';
SET session_replication_role = origin;
SET ROLE service_role;
DO $$ BEGIN
  IF public.aef_verify_audit_chain('{"subject_id":"e1000000-0000-4000-8000-00000000000e"}'::jsonb) ->> 'reason'
     IS DISTINCT FROM 'COALESCED_MISMATCH' THEN
    RAISE EXCEPTION 'H05g tampered coalesced count not detected';
  END IF;
END $$;
RESET ROLE;
SET session_replication_role = replica;
UPDATE public.aef_audit_coalesced SET count = 5 WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e';
SET session_replication_role = origin;

-- ── H06 reconciliation ──────────────────────────────────────────────────
SET ROLE service_role;
DO $$
DECLARE v_unknown uuid := current_setting('aef.t.d_unknown')::uuid; r jsonb; v_orig text; v_ok uuid;
  base jsonb;
BEGIN
  v_orig := (SELECT receipt_hash FROM public.aef_receipts WHERE operation_id = v_unknown);
  base := jsonb_build_object('operation_id', v_unknown, 'verdict', 'CONFIRMED_APPLIED', 'evidence_kind', 'EXTERNAL_STATE_QUERY',
    'evidence_ref', 'ticket-123', 'policy_version', 'aef-policy/2026-09-25.1', 'risk_version', 'aef-risk/2026-09-25.1');
  PERFORM pg_temp.expect(public.aef_reconcile(base || '{"reconciler_kind":"OPERATOR","reconciler_id":"d1000000-0000-4000-8000-00000000000d"}'),
    'RECONCILER_NOT_AUTHORIZED', 'H06a subject reconciles itself');
  PERFORM pg_temp.expect(public.aef_reconcile(base || '{"reconciler_kind":"OPERATOR","reconciler_id":"a8000000-0000-4000-8000-000000000008"}'),
    'RECONCILER_NOT_AUTHORIZED', 'H06b non-admin operator');
  PERFORM pg_temp.expect(public.aef_reconcile(base || '{"reconciler_kind":"VERIFIER","reconciler_id":"mock.verifier"}'),
    'RECONCILER_NOT_AUTHORIZED', 'H06c unregistered verifier');
  PERFORM pg_temp.expect(public.aef_reconcile(base || '{"reconciler_kind":"OPERATOR","reconciler_id":"a7000000-0000-4000-8000-000000000007","approved":true}'),
    'ARGUMENT_REJECTED', 'H06d mass assignment');
  PERFORM pg_temp.expect(public.aef_reconcile(base || jsonb_build_object('reconciler_kind', 'OPERATOR',
    'reconciler_id', 'a7000000-0000-4000-8000-000000000007', 'evidence_ref', repeat('x', 201))), 'ARGUMENT_REJECTED', 'H06e oversized evidence');
  PERFORM pg_temp.expect(public.aef_reconcile(base || '{"reconciler_kind":"OPERATOR","reconciler_id":"a7000000-0000-4000-8000-000000000007","verdict":"SUCCEEDED"}'),
    'ARGUMENT_REJECTED', 'H06f invented verdict');
  v_ok := current_setting('aef.t.d_recent')::uuid;
  PERFORM pg_temp.expect(public.aef_reconcile(jsonb_set(base, '{operation_id}', to_jsonb(v_ok::text))
    || '{"reconciler_kind":"OPERATOR","reconciler_id":"a7000000-0000-4000-8000-000000000007"}'),
    'NOT_RECONCILABLE', 'H06g reconcile a SUCCEEDED operation');

  r := public.aef_reconcile(base || '{"reconciler_kind":"OPERATOR","reconciler_id":"a7000000-0000-4000-8000-000000000007"}');
  PERFORM pg_temp.expect(r, NULL, 'H06h admin operator reconciles');
  IF r #>> '{operation,state}' <> 'UNKNOWN_OUTCOME' OR r #>> '{receipt,receipt,outcome}' <> 'UNKNOWN_OUTCOME'
     OR r #>> '{receipt,receipt_hash}' <> v_orig THEN
    RAISE EXCEPTION 'H06i reconciliation rewrote the operation or its receipt: %', r;
  END IF;
  IF r #>> '{reconciliation,receipt,receipt_kind}' <> 'RECONCILIATION'
     OR r #>> '{reconciliation,receipt,verdict}' <> 'CONFIRMED_APPLIED'
     OR r #>> '{reconciliation,receipt,original_receipt_hash}' <> v_orig
     OR r #>> '{reconciliation,receipt,receipt_version}' <> 'aef-receipt/1.1'
     OR (r #> '{reconciliation,receipt}')::text LIKE '%a7000000%'
     OR (r #> '{reconciliation,receipt}')::text LIKE '%ticket-123%' THEN
    RAISE EXCEPTION 'H06j reconciliation receipt wrong or not minimized: %', r;
  END IF;
  PERFORM set_config('aef.t.recon_receipt', r #>> '{reconciliation,receipt}', false);
  PERFORM pg_temp.expect(public.aef_reconcile(base || '{"reconciler_kind":"OPERATOR","reconciler_id":"a7000000-0000-4000-8000-000000000007","verdict":"CONFIRMED_NOT_APPLIED"}'),
    'ALREADY_RECONCILED', 'H06k second reconciliation');
  IF (public.aef_verify_receipt(jsonb_build_object('receipt', current_setting('aef.t.recon_receipt')::jsonb)) ->> 'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'H06l reconciliation receipt does not verify';
  END IF;
  IF public.aef_verify_receipt(jsonb_build_object('receipt',
       jsonb_set(current_setting('aef.t.recon_receipt')::jsonb, '{verdict}', '"CONFIRMED_NOT_APPLIED"'))) ->> 'reason' <> 'RECEIPT_MISMATCH' THEN
    RAISE EXCEPTION 'H06m forged reconciliation receipt accepted';
  END IF;
  -- Replay of the same key returns the reconciled record; nothing re-executes.
  r := pg_temp.reg('d1000000-0000-4000-8000-00000000000d', 'd-old-3');
  IF r ->> 'outcome' <> 'REPLAY' OR r #>> '{reconciliation,receipt,verdict}' <> 'CONFIRMED_APPLIED' THEN
    RAISE EXCEPTION 'H06n replay does not show the reconciliation: %', r;
  END IF;
  PERFORM pg_temp.expect(public.aef_claim_execution(jsonb_build_object('operation_id', v_unknown,
    'subject_id', 'd1000000-0000-4000-8000-00000000000d', 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60)), 'NOT_CLAIMABLE', 'H06o no second execution');
  IF (SELECT attempt_count FROM public.aef_operations WHERE id = v_unknown) <> 1 THEN RAISE EXCEPTION 'H06p re-executed'; END IF;
  IF NOT pg_temp.chain_ok('d1000000-0000-4000-8000-00000000000d') THEN RAISE EXCEPTION 'H06q chain invalid'; END IF;
END $$;
RESET ROLE;

-- Verifier path: only a verifier registered (owner-managed) for the tool.
INSERT INTO public.aef_reconciliation_verifiers (verifier_id, tool_id) VALUES ('mock.verifier', 'internal.mock_effect_reversible')
ON CONFLICT DO NOTHING;
INSERT INTO public.aef_reconciliation_verifiers (verifier_id, tool_id) VALUES ('other.verifier', 'internal.other_tool')
ON CONFLICT DO NOTHING;
SET ROLE service_role;
DO $$
DECLARE v uuid; r jsonb; base jsonb;
BEGIN
  v := pg_temp.run_op('a8000000-0000-4000-8000-000000000008', 'h-unknown', 'UNKNOWN_OUTCOME');
  base := jsonb_build_object('operation_id', v, 'verdict', 'CONFIRMED_NOT_APPLIED', 'evidence_kind', 'VERIFIER_CHECK',
    'evidence_ref', 'mock-ledger', 'policy_version', 'aef-policy/2026-09-25.1', 'risk_version', 'aef-risk/2026-09-25.1');
  PERFORM pg_temp.expect(public.aef_reconcile(base || '{"reconciler_kind":"VERIFIER","reconciler_id":"other.verifier"}'),
    'RECONCILER_NOT_AUTHORIZED', 'H06r verifier registered for another tool');
  r := public.aef_reconcile(base || '{"reconciler_kind":"VERIFIER","reconciler_id":"mock.verifier"}');
  PERFORM pg_temp.expect(r, NULL, 'H06s registered verifier');
  IF NOT EXISTS (SELECT 1 FROM public.aef_audit_events WHERE operation_id = v AND event_type = 'RECONCILIATION_RECORDED'
                   AND ref_hash = r #>> '{reconciliation,receipt_hash}') THEN
    RAISE EXCEPTION 'H06t reconciliation not anchored in the chain';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aef_audit_events WHERE subject_id = 'd1000000-0000-4000-8000-00000000000d'
                   AND event_type = 'RECONCILIATION_DENIED') THEN
    RAISE EXCEPTION 'H06u refused reconciliations not audited';
  END IF;
END $$;
RESET ROLE;

-- Owner sees own reconciliation (no operator id); foreign user sees none.
SELECT set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-00000000000d', false);
SET ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(id) FROM public.aef_reconciliations) <> 1 THEN RAISE EXCEPTION 'H06v owner cannot see own reconciliation'; END IF;
  BEGIN
    PERFORM reconciler_id FROM public.aef_reconciliations;
    RAISE EXCEPTION 'H06w operator id readable by the subject';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', 'e1000000-0000-4000-8000-00000000000e', false);
SET ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(id) FROM public.aef_reconciliations) <> 0 THEN RAISE EXCEPTION 'H06x foreign reconciliation visible'; END IF;
END $$;
RESET ROLE;

-- ── H07 guards: nobody deletes outside purge/erasure ───────────────────
SET ROLE service_role;
DO $$ BEGIN
  PERFORM set_config('aef.maintenance', 'on', true);
  BEGIN
    DELETE FROM public.aef_receipts;
    RAISE EXCEPTION 'H07a service_role deleted receipts with the maintenance flag';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.aef_idempotency_tombstones (subject_id, idempotency_key_hash, request_id, operation_id, final_state)
    VALUES (gen_random_uuid(), repeat('b', 64), gen_random_uuid(), gen_random_uuid(), 'SUCCEEDED');
    RAISE EXCEPTION 'H07b service_role wrote a tombstone';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.aef__flush_window('e1000000-0000-4000-8000-00000000000e');
    RAISE EXCEPTION 'H07c service_role called an internal helper';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  BEGIN
    DELETE FROM public.aef_reconciliations;
    RAISE EXCEPTION 'H07d owner deleted a reconciliation outside maintenance';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.aef_reconciliations SET verdict = 'CONFIRMED_NOT_APPLIED';
    RAISE EXCEPTION 'H07e owner rewrote a reconciliation';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    DELETE FROM public.aef_audit_events WHERE subject_id = 'e1000000-0000-4000-8000-00000000000e';
    RAISE EXCEPTION 'H07f owner deleted audit events outside maintenance';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    DELETE FROM public.aef_idempotency_tombstones;
    RAISE EXCEPTION 'H07g owner deleted tombstones outside maintenance';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    INSERT INTO public.aef_erasures (id, subject_ref, counts) VALUES (gen_random_uuid(), repeat('c', 64), '{}');
    RAISE EXCEPTION 'H07h forged erasure record';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
  BEGIN
    TRUNCATE public.aef_idempotency_tombstones;
    RAISE EXCEPTION 'H07i truncated tombstones';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'AEF_GUARD%' THEN RAISE; END IF; END;
END $$;

-- ── H08 erasure ─────────────────────────────────────────────────────────
SET ROLE service_role;
DO $$
DECLARE v uuid;
BEGIN
  PERFORM pg_temp.run_op('f1000000-0000-4000-8000-00000000000f', 'f-1', 'SUCCEEDED');
  PERFORM pg_temp.run_op('f1000000-0000-4000-8000-00000000000f', 'f-2', 'FAILED_AFTER_SIDE_EFFECT');
  PERFORM public.aef_record_denial('{"subject_id":"f1000000-0000-4000-8000-00000000000f","reason_code":"UNKNOWN_TOOL"}');
  PERFORM pg_temp.expect(public.aef_erase_subject('{"subject_id":"f1000000-0000-4000-8000-00000000000f"}'),
    'ERASURE_ACCOUNT_ACTIVE', 'H08a account still exists');
  PERFORM pg_temp.expect(public.aef_erase_subject('{"subject_id":"f1000000-0000-4000-8000-00000000000f","cascade":true}'),
    'ARGUMENT_REJECTED', 'H08b mass assignment');
  -- executing / unreconciled / hold blockers
  PERFORM set_config('aef.t.g_exec', pg_temp.run_op('a7000000-0000-4000-8000-000000000007', 'g-exec', NULL)::text, false);
  PERFORM set_config('aef.t.h_unknown2', pg_temp.run_op('a8000000-0000-4000-8000-000000000008', 'h-unknown-2', 'UNKNOWN_OUTCOME')::text, false);
END $$;
RESET ROLE;
DELETE FROM auth.users WHERE id IN ('f1000000-0000-4000-8000-00000000000f', 'a7000000-0000-4000-8000-000000000007',
                                    'a8000000-0000-4000-8000-000000000008', 'a9000000-0000-4000-8000-000000000009');
SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  PERFORM pg_temp.expect(public.aef_erase_subject('{"subject_id":"a7000000-0000-4000-8000-000000000007"}'),
    'ERASURE_BLOCKED_ACTIVE', 'H08c execution in flight');
  PERFORM pg_temp.expect(public.aef_erase_subject('{"subject_id":"a8000000-0000-4000-8000-000000000008"}'),
    'ERASURE_BLOCKED_UNRECONCILED', 'H08d unreconciled unknown outcome');
  PERFORM pg_temp.expect(public.aef_erase_subject('{"subject_id":"a9000000-0000-4000-8000-000000000009"}'),
    'ERASURE_BLOCKED_HOLD', 'H08e legal hold');

  r := public.aef_erase_subject('{"subject_id":"f1000000-0000-4000-8000-00000000000f"}');
  PERFORM pg_temp.expect(r, NULL, 'H08f erase');
  IF r ->> 'outcome' <> 'ERASED' OR (r #>> '{counts,operations}')::int <> 2 THEN RAISE EXCEPTION 'H08g counts %', r; END IF;
  IF EXISTS (SELECT 1 FROM public.aef_operations WHERE subject_id = 'f1000000-0000-4000-8000-00000000000f')
     OR EXISTS (SELECT 1 FROM public.aef_receipts WHERE subject_id = 'f1000000-0000-4000-8000-00000000000f')
     OR EXISTS (SELECT 1 FROM public.aef_audit_events WHERE subject_id = 'f1000000-0000-4000-8000-00000000000f')
     OR EXISTS (SELECT 1 FROM public.aef_audit_heads WHERE subject_id = 'f1000000-0000-4000-8000-00000000000f')
     OR EXISTS (SELECT 1 FROM public.aef_audit_windows WHERE subject_id = 'f1000000-0000-4000-8000-00000000000f') THEN
    RAISE EXCEPTION 'H08h subject data left behind';
  END IF;
  IF EXISTS (SELECT 1 FROM public.aef_erasures WHERE counts::text LIKE '%f1000000%') THEN
    RAISE EXCEPTION 'H08i erasure log contains the raw subject id';
  END IF;
  r := public.aef_erase_subject('{"subject_id":"f1000000-0000-4000-8000-00000000000f"}');
  IF r ->> 'outcome' <> 'ALREADY_ERASED' THEN RAISE EXCEPTION 'H08j erasure not idempotent: %', r; END IF;
  -- other subjects untouched and still verifiable
  IF NOT pg_temp.chain_ok('d1000000-0000-4000-8000-00000000000d') OR NOT pg_temp.chain_ok('e1000000-0000-4000-8000-00000000000e') THEN
    RAISE EXCEPTION 'H08k another subject''s chain broke';
  END IF;
END $$;
RESET ROLE;

-- Operator detachment: erase the admin G after its in-flight op finishes.
SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  PERFORM public.aef_complete_execution(jsonb_build_object('operation_id', current_setting('aef.t.g_exec'),
    'execution_token', (SELECT execution_token FROM public.aef_operations WHERE id = current_setting('aef.t.g_exec')::uuid),
    'result', 'SUCCEEDED'));
END $$;
RESET ROLE;
SET ROLE service_role;
DO $$
DECLARE r jsonb;
BEGIN
  r := public.aef_erase_subject('{"subject_id":"a7000000-0000-4000-8000-000000000007"}');
  PERFORM pg_temp.expect(r, NULL, 'H08l erase operator');
  IF (r #>> '{counts,operator_detachments}')::int <> 1 THEN RAISE EXCEPTION 'H08m operator not detached: %', r; END IF;
  IF (public.aef_verify_receipt(jsonb_build_object('receipt', current_setting('aef.t.recon_receipt')::jsonb)) ->> 'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'H08n reconciliation of another subject no longer verifies after operator erasure';
  END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.aef_reconciliations WHERE reconciler_id = 'a7000000-0000-4000-8000-000000000007') THEN
    RAISE EXCEPTION 'H08o erased operator id still stored';
  END IF;
END $$;

-- ── H09 abuse: thousands of denials stay bounded, counts exact ──────────
SET ROLE service_role;
DO $$
DECLARE i int; v_events bigint; v_total bigint;
BEGIN
  FOR i IN 1..3000 LOOP
    PERFORM public.aef_record_denial(jsonb_build_object('subject_id', 'b9000000-0000-4000-8000-00000000000b',
      'reason_code', CASE WHEN i % 2 = 0 THEN 'RESOURCE_FORBIDDEN' ELSE 'UNKNOWN_TOOL' END));
  END LOOP;
  SELECT count(*) INTO v_events FROM public.aef_audit_events WHERE subject_id = 'b9000000-0000-4000-8000-00000000000b';
  SELECT v_events + coalesce((SELECT sum(count) FROM public.aef_audit_pending WHERE subject_id = 'b9000000-0000-4000-8000-00000000000b'), 0)
    INTO v_total;
  IF v_events > 20 THEN RAISE EXCEPTION 'H09a % events stored for one window', v_events; END IF;
  IF v_total <> 3000 THEN RAISE EXCEPTION 'H09b denials lost: % of 3000 accounted', v_total; END IF;
END $$;
RESET ROLE;

SELECT 'AEF_HARDENING: PASS';
