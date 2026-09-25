-- IV-AEF-PRE-RUNTIME-CLOSURE-01 — AEF sequence privileges (P03). DISPOSABLE database only.
--   -v phase=before  a database in the pre-fix state (runner: every migration except
--                    20260927000000, audit sequence carrying the grants it inherited
--                    under the earlier 20260925 revision): P03 reproduced (must be exposed)
--   -v phase=after   with 20260927000000: contract, adversarial attempts, catalog,
--                    legitimate flows, SECURITY DEFINER boundary
\set ON_ERROR_STOP 1
SET search_path = public, extensions;
SELECT (:'phase' = 'before') AS is_before, (:'phase' = 'after') AS is_after \gset

-- S00 the fixture reproduces production's permissive sequence defaults for
-- every API role and every sequence privilege (rwU); otherwise every check
-- below could pass on a stricter-than-production DB (Codex G1-04).
DO $$
DECLARE r text; p text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    FOREACH p IN ARRAY ARRAY['USAGE', 'SELECT', 'UPDATE'] LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace, aclexplode(d.defaclacl) a
                      WHERE n.nspname = 'public' AND d.defaclobjtype = 'S'
                        -- defaults of the role that runs the migrations (defaults apply per creating role; Codex G1V-01)
                        AND d.defaclrole = current_user::regrole
                        AND a.grantee = r::regrole AND a.privilege_type = p) THEN
        RAISE EXCEPTION 'S00 fixture does not reproduce production sequence defaults for % (% % on new sequences)', current_user, r, p;
      END IF;
    END LOOP;
  END LOOP;
END $$;

\if :is_before
-- S01a root cause: any identity sequence created in public inherits rwU for the API roles.
CREATE TABLE public.p03_probe (id bigint GENERATED ALWAYS AS IDENTITY);
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    IF NOT (has_sequence_privilege(r, pg_get_serial_sequence('public.p03_probe', 'id'), 'USAGE')
            AND has_sequence_privilege(r, pg_get_serial_sequence('public.p03_probe', 'id'), 'UPDATE')) THEN
      RAISE EXCEPTION 'S01a new identity sequences do not inherit the API-role defaults for %', r;
    END IF;
  END LOOP;
END $$;
DROP TABLE public.p03_probe;
-- S01 root cause reproduced: without 20260927 the audit sequence inherits the defaults.
DO $$ BEGIN
  IF NOT has_sequence_privilege('anon', 'public.aef_audit_events_id_seq', 'UPDATE') THEN
    RAISE EXCEPTION 'S01 P03 not reproduced: anon has no UPDATE on the audit sequence';
  END IF;
END $$;
-- S02 impact: an API role rewinds the sequence and legitimate audit appends break.
INSERT INTO auth.users (id, email) VALUES ('c8000000-0000-4000-8000-00000000000c', 'seq@test.invalid') ON CONFLICT DO NOTHING;
SET ROLE service_role;
DO $$ BEGIN
  PERFORM public.aef_record_denial('{"subject_id":"c8000000-0000-4000-8000-00000000000c","reason_code":"UNKNOWN_TOOL"}');
  PERFORM public.aef_record_denial('{"subject_id":"c8000000-0000-4000-8000-00000000000c","reason_code":"UNKNOWN_TOOL"}');
END $$;
RESET ROLE;
SET ROLE anon;
SELECT setval('public.aef_audit_events_id_seq', 1) AS anon_rewound_sequence;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT last_value FROM public.aef_audit_events_id_seq) <> 1 THEN
    RAISE EXCEPTION 'S02 the anon setval did not take effect';
  END IF;
END $$;
SET ROLE service_role;
DO $$
DECLARE v_con text;
BEGIN
  BEGIN
    PERFORM public.aef_record_denial('{"subject_id":"c8000000-0000-4000-8000-00000000000c","reason_code":"UNKNOWN_TOOL"}');
    RAISE EXCEPTION 'S02 expected the audit append to collide after an anon setval';
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
    -- the collision is on the identity primary key, i.e. caused by the rewound sequence
    IF v_con IS DISTINCT FROM 'aef_audit_events_pkey' THEN
      RAISE EXCEPTION 'S02 collision on % instead of aef_audit_events_pkey', v_con;
    END IF;
  END;
END $$;
RESET ROLE;
SELECT 'AEF_SEQUENCE: EXPOSED_BEFORE_FIX';
\endif

\if :is_after
-- S10 catalog contract: no API role, and not PUBLIC, holds anything on any AEF sequence.
DO $$
DECLARE s record; r text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                  WHERE n.nspname = 'public' AND c.relkind = 'S' AND c.relname = 'aef_audit_events_id_seq') THEN
    RAISE EXCEPTION 'S10 audit sequence missing';
  END IF;
  -- every sequence named aef_* OR owned by an aef_* table (same predicate as the migration)
  FOR s IN SELECT c.oid, c.relname, c.relowner, c.relacl FROM pg_class c WHERE c.oid IN (
           SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind = 'S'
              AND (left(c.relname, 4) = 'aef_' OR EXISTS (
                    SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
                     WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                       AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_'))) LOOP
    FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      IF has_sequence_privilege(r, s.oid, 'USAGE') OR has_sequence_privilege(r, s.oid, 'SELECT')
         OR has_sequence_privilege(r, s.oid, 'UPDATE') THEN
        RAISE EXCEPTION 'S10 % has a privilege on %', r, s.relname;
      END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM aclexplode(coalesce(s.relacl, acldefault('s', s.relowner))) a
                WHERE a.grantee <> s.relowner) THEN
      RAISE EXCEPTION 'S10 % grants something to a role other than its owner (incl. PUBLIC): %', s.relname, s.relacl;
    END IF;
  END LOOP;
  -- information_schema agrees
  IF EXISTS (SELECT 1 FROM information_schema.usage_privileges
              WHERE object_schema = 'public' AND object_type = 'SEQUENCE'
                AND object_name IN (SELECT c.relname FROM pg_class c WHERE c.oid IN (
           SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind = 'S'
              AND (left(c.relname, 4) = 'aef_' OR EXISTS (
                    SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
                     WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                       AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_'))))
                AND grantee IN ('PUBLIC', 'anon', 'authenticated', 'service_role')) THEN
    RAISE EXCEPTION 'S10 information_schema reports an API grant on an AEF sequence';
  END IF;
END $$;

-- S11 adversarial: every role, every sequence operation → denied
INSERT INTO auth.users (id, email) VALUES
  ('c8000000-0000-4000-8000-00000000000c', 'seq@test.invalid'),
  ('c9000000-0000-4000-8000-00000000000c', 'seq-foreign@test.invalid') ON CONFLICT DO NOTHING;
DO $$
DECLARE r text; q text; sq oid; n int := 0;
BEGIN
  FOR sq IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind = 'S'
              AND (left(c.relname, 4) = 'aef_' OR EXISTS (
                    SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
                     WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                       AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_')) LOOP
    n := n + 1;
    FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      FOREACH q IN ARRAY ARRAY[
        format('SELECT nextval(%L)', sq::regclass::text),
        format('SELECT setval(%L, 1)', sq::regclass::text),
        format('SELECT last_value FROM %s', sq::regclass),
        format('ALTER SEQUENCE %s RESTART WITH 1', sq::regclass)] LOOP
        BEGIN
          EXECUTE format('SET LOCAL ROLE %I', r);
          PERFORM set_config('request.jwt.claim.sub', 'c9000000-0000-4000-8000-00000000000c', true);
          EXECUTE q;
          RAISE EXCEPTION 'S11 % could run: %', r, q;
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
      END LOOP;
    END LOOP;
  END LOOP;
  IF n = 0 THEN RAISE EXCEPTION 'S11 no AEF sequence discovered'; END IF;
END $$;
-- currval needs the sequence in the session and USAGE/SELECT: denied as well
SET ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM currval('public.aef_audit_events_id_seq');
    RAISE EXCEPTION 'S11 authenticated could currval';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- direct INSERT into the audit table (would consume the sequence) → denied for every API role
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    BEGIN
      EXECUTE format('SET LOCAL ROLE %I', r);
      INSERT INTO public.aef_audit_events (subject_id, seq, event_type, occurred_at, prev_hash, event_hash)
      VALUES (gen_random_uuid(), 1, 'FORGED', now(), repeat('0', 64), repeat('1', 64));
      RAISE EXCEPTION 'S11 % inserted an audit event directly', r;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;
END $$;

-- S12 legitimate server-authoritative flows still consume the sequence
SET ROLE service_role;
DO $$
DECLARE r jsonb; c jsonb; v jsonb; v_before bigint; v_after bigint;
BEGIN
  SELECT max(id) INTO v_before FROM public.aef_audit_events;
  PERFORM public.aef_record_denial('{"subject_id":"c8000000-0000-4000-8000-00000000000c","reason_code":"UNKNOWN_TOOL"}');
  r := public.aef_register_operation(jsonb_build_object(
    'subject_id', 'c8000000-0000-4000-8000-00000000000c', 'request_id', gen_random_uuid(), 'idempotency_key', 'seq-legit-' || gen_random_uuid(),  -- re-runnable on the same database
    'domain', 'internal', 'action', 'internal.mock_effect_reversible', 'tool_id', 'internal.mock_effect_reversible',
    'action_class', 'REVERSIBLE', 'payload_hash', repeat('a', 64), 'payload_bytes', 10,
    'policy_version', 'aef-policy/2026-09-25.1', 'risk_version', 'aef-risk/2026-09-25.1', 'requires_human_gate', false));
  IF (r ->> 'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'S12 register failed: %', r; END IF;
  c := public.aef_claim_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'subject_id', 'c8000000-0000-4000-8000-00000000000c', 'binding_hash', r #>> '{operation,binding_hash}',
    'policy_version', 'aef-policy/2026-09-25.1', 'lease_seconds', 60));
  v := public.aef_complete_execution(jsonb_build_object('operation_id', r #>> '{operation,operation_id}',
    'execution_token', c ->> 'execution_token', 'result', 'SUCCEEDED'));
  IF (v #>> '{receipt,receipt,outcome}') IS DISTINCT FROM 'SUCCESS' THEN RAISE EXCEPTION 'S12 receipt not issued: %', v; END IF;
  IF (public.aef_verify_receipt(jsonb_build_object('receipt', v #> '{receipt,receipt}')) ->> 'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'S12 receipt does not verify';
  END IF;
  IF (public.aef_verify_audit_chain('{"subject_id":"c8000000-0000-4000-8000-00000000000c"}') ->> 'valid')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'S12 chain invalid';
  END IF;
  SELECT max(id) INTO v_after FROM public.aef_audit_events;
  IF v_after IS NULL OR v_after <= coalesce(v_before, 0) THEN RAISE EXCEPTION 'S12 sequence not consumed by the RPCs'; END IF;
  PERFORM public.aef_purge('{}'::jsonb);
  PERFORM public.aef_recover('{}'::jsonb);
END $$;
RESET ROLE;

-- S13 SECURITY DEFINER boundary: no AEF function relies on the pre-existing
-- definer functions flagged by the preflight (P06/P07).
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_'
                AND p.prosrc ~ '(get_current_user_role|handle_new_user|is_admin_user|validate_asset_)') THEN
    RAISE EXCEPTION 'S13 an AEF function references a pre-existing definer function (P06/P07)';
  END IF;
END $$;
SELECT 'AEF_SEQUENCE: PASS';
\endif
