-- IV-AEF-HARDENING-01 — receipt v1 backward compatibility and the
-- UP → DOWN → UP cycle of migration 20260926000000. DISPOSABLE database only.
--   -v phase=seed    persistence only: create v1 receipts and chains
--   -v phase=verify  after the hardening UP: v1 untouched and verifiable, new receipts v1.1
--   -v phase=down    after the hardening DOWN: everything still verifiable, service works
\set ON_ERROR_STOP 1
SET search_path = public, extensions;
SELECT (:'phase' = 'seed') AS is_seed, (:'phase' = 'verify') AS is_verify, (:'phase' = 'down') AS is_down \gset

CREATE OR REPLACE FUNCTION pg_temp.run_op(p_subject text, p_key text, p_result text) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE r jsonb; c jsonb;
BEGIN
  r := public.aef_register_operation(jsonb_build_object(
    'subject_id', p_subject, 'request_id', gen_random_uuid()::text, 'idempotency_key', p_key,
    'domain', 'internal', 'action', 'internal.mock_effect_reversible', 'tool_id', 'internal.mock_effect_reversible',
    'action_class', 'REVERSIBLE', 'payload_hash', repeat('a', 64), 'payload_bytes', 10,
    'policy_version', 'aef-policy/2026-09-25.1', 'risk_version', 'aef-risk/2026-09-25.1',
    'requires_human_gate', false));
  IF (r ->> 'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'register failed %', r; END IF;
  c := public.aef_claim_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', p_subject, 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60));
  RETURN public.aef_complete_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'execution_token', c ->> 'execution_token', 'result', p_result));
END $$;

\if :is_seed
CREATE TABLE public.aef_legacy_probe (label text PRIMARY KEY, receipt jsonb NOT NULL);
GRANT SELECT, INSERT ON public.aef_legacy_probe TO service_role;
SET ROLE service_role;
INSERT INTO public.aef_legacy_probe
SELECT 'v1_success', pg_temp.run_op('c7000000-0000-4000-8000-00000000000c', 'legacy-1', 'SUCCEEDED') #> '{receipt,receipt}';
INSERT INTO public.aef_legacy_probe
SELECT 'v1_unknown', pg_temp.run_op('c7000000-0000-4000-8000-00000000000c', 'legacy-2', 'UNKNOWN_OUTCOME') #> '{receipt,receipt}';
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.aef_legacy_probe WHERE receipt ->> 'receipt_version' = 'aef-receipt/1') <> 2 THEN
    RAISE EXCEPTION 'L00 seed did not produce v1 receipts';
  END IF;
END $$;
SELECT 'AEF_LEGACY: SEEDED';
\endif

\if :is_verify
SET ROLE service_role;
DO $$
DECLARE p record; v jsonb;
BEGIN
  FOR p IN SELECT * FROM public.aef_legacy_probe LOOP
    -- stored v1 receipts are never rewritten or reinterpreted
    IF (SELECT receipt FROM public.aef_receipts WHERE id = (p.receipt ->> 'receipt_id')::uuid) <> p.receipt
       OR p.receipt ->> 'receipt_version' <> 'aef-receipt/1' OR p.receipt ? 'receipt_kind' THEN
      RAISE EXCEPTION 'L01 v1 receipt % changed', p.label;
    END IF;
    v := public.aef_verify_receipt(jsonb_build_object('receipt', p.receipt));
    IF (v ->> 'valid')::boolean IS NOT TRUE OR v ->> 'receipt_version' <> 'aef-receipt/1' THEN
      RAISE EXCEPTION 'L02 v1 receipt % no longer verifies: %', p.label, v;
    END IF;
  END LOOP;
  IF (public.aef_verify_audit_chain('{"subject_id":"c7000000-0000-4000-8000-00000000000c"}') ->> 'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'L03 pre-hardening chain invalid';
  END IF;
  v := pg_temp.run_op('c7000000-0000-4000-8000-00000000000c', 'legacy-3', 'SUCCEEDED');
  IF v #>> '{receipt,receipt,receipt_version}' <> 'aef-receipt/1.1' THEN RAISE EXCEPTION 'L04 new receipt not v1.1'; END IF;
  IF (public.aef_verify_audit_chain('{"subject_id":"c7000000-0000-4000-8000-00000000000c"}') ->> 'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'L05 mixed v1/v1.1 chain invalid';
  END IF;
END $$;
RESET ROLE;
SELECT 'AEF_LEGACY: PASS';
\endif

\if :is_down
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = 'public' AND c.relname IN ('aef_reconciliations', 'aef_idempotency_tombstones',
                'aef_audit_checkpoints', 'aef_audit_coalesced', 'aef_audit_pending', 'aef_audit_windows', 'aef_erasures',
                'aef_reconciliation_verifiers', 'aef_legal_holds', 'aef_retention_policy'))
     OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND p.proname IN ('aef_reconcile', 'aef_purge', 'aef_erase_subject',
                   'aef__maintenance', 'aef__chain_append', 'aef__flush_window', 'aef__coalesced_ref'))
     OR (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_') <> 36 THEN
    RAISE EXCEPTION 'L10 hardening objects left after rollback';
  END IF;
END $$;
SET ROLE service_role;
DO $$
DECLARE r record; v jsonb;
BEGIN
  FOR r IN SELECT receipt FROM public.aef_receipts WHERE subject_id = 'c7000000-0000-4000-8000-00000000000c' LOOP
    IF (public.aef_verify_receipt(jsonb_build_object('receipt', r.receipt)) ->> 'valid')::boolean IS NOT TRUE THEN
      RAISE EXCEPTION 'L11 receipt % does not verify after rollback', r.receipt ->> 'receipt_version';
    END IF;
  END LOOP;
  IF (public.aef_verify_audit_chain('{"subject_id":"c7000000-0000-4000-8000-00000000000c"}') ->> 'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'L12 chain invalid after rollback';
  END IF;
  v := pg_temp.run_op('c7000000-0000-4000-8000-00000000000c', 'legacy-4', 'SUCCEEDED');
  IF v #>> '{receipt,receipt,receipt_version}' <> 'aef-receipt/1' THEN RAISE EXCEPTION 'L13 persistence behavior not restored'; END IF;
END $$;
RESET ROLE;
SELECT 'AEF_LEGACY: DOWN_OK';
\endif
