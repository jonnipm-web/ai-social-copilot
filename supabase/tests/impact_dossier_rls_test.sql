-- IV-IMPACT-I4-VERIFICATION-DOSSIER-01 — atomic artifact ingestion (I3F-03),
-- dossier snapshot register, RLS and privileges (migration 20260927010000).
-- Runs against a DISPOSABLE database with every migration applied (never
-- production). Every check RAISEs on failure; a clean run ends with
-- 'IMPACT_DOSSIER_RLS: PASS'. Synthetic data only.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

CREATE TEMP TABLE i4_log (n serial, label text);
GRANT ALL ON i4_log TO PUBLIC;
GRANT ALL ON SEQUENCE i4_log_n_seq TO PUBLIC;

CREATE FUNCTION pg_temp.expect_fail(p_label text, p_sql text, p_pattern text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN others THEN
    IF SQLERRM ~* p_pattern OR SQLSTATE ~* p_pattern THEN
      INSERT INTO i4_log (label) VALUES (p_label);
      RETURN;
    END IF;
    RAISE EXCEPTION '% failed for the WRONG reason: [%] %', p_label, SQLSTATE, SQLERRM;
  END;
  RAISE EXCEPTION '% was expected to FAIL but succeeded', p_label;
END $$;

CREATE FUNCTION pg_temp.expect_eq(p_label text, p_actual text, p_expected text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_actual IS DISTINCT FROM p_expected THEN
    RAISE EXCEPTION '% expected [%] got [%]', p_label, p_expected, p_actual;
  END IF;
  INSERT INTO i4_log (label) VALUES (p_label);
END $$;

CREATE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(uid, ''), false);
  PERFORM set_config('request.jwt.claim.role', CASE WHEN uid IS NULL THEN 'anon' ELSE 'authenticated' END, false);
END $$;

-- Rows exactly as supabase_store.ts maps them (source / artifact / candidate).
CREATE FUNCTION pg_temp.src(p_inv text, p_ref text, p_hash_char text, p_owner text) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('investigation_id', p_inv, 'ref', p_ref, 'source_type', 'USER_DOCUMENT', 'publisher', 'User upload',
    'retrieved_at', '2026-09-20T00:00:00Z', 'retention', 'HASH_ONLY', 'content_hash', repeat(p_hash_char, 64),
    'acquisition_method', 'USER_UPLOAD', 'user_submitted', true, 'syndication_markers', '[]'::jsonb, 'created_by', p_owner) $$;
CREATE FUNCTION pg_temp.art(p_inv text, p_ref text, p_hash_char text, p_owner text) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('investigation_id', p_inv, 'ref', p_ref, 'source_ref', p_ref, 'artifact_type', 'TEXT', 'origin_type', 'USER_UPLOAD',
    'original_filename', 'r.txt', 'media_type', 'text/plain', 'size_bytes', 10, 'file_hash', repeat(p_hash_char, 64),
    'hash_algorithm', 'SHA-256', 'version', 1, 'extraction_status', 'SUCCESS', 'extractor_version', 'impact-extractor/1',
    'extraction_summary', jsonb_build_object('type', 'TEXT', 'status', 'SUCCESS', 'extractorVersion', 'impact-extractor/1', 'lines', 2, 'segments', 2, 'notes', '[]'::jsonb),
    'ingested_at', '2026-09-20T00:00:00Z', 'created_by', p_owner) $$;
CREATE FUNCTION pg_temp.cand(p_inv text, p_ref text, p_art text, p_hash_char text, p_line int, p_owner text) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('investigation_id', p_inv, 'ref', p_ref, 'artifact_ref', p_art, 'artifact_hash', repeat(p_hash_char, 64),
    'locator', jsonb_build_object('kind', 'TEXT_LINES', 'lineStart', p_line, 'lineEnd', p_line), 'excerpt', 'Line text.',
    'excerpt_hash', encode(sha256(convert_to('Line text.', 'UTF8')), 'hex'), 'generation_method', 'ANALYST_LOCATOR',
    'review_reasons', '["SUBJECT_NOT_MENTIONED"]'::jsonb, 'created_by', p_owner) $$;
GRANT EXECUTE ON FUNCTION pg_temp.src(text, text, text, text), pg_temp.art(text, text, text, text), pg_temp.cand(text, text, text, text, int, text) TO PUBLIC;

\set UG '''99999999-0000-0000-0000-000000000009'''
\set UH '''88888888-0000-0000-0000-000000000008'''
\set IG '''90000000-0000-0000-0000-000000000009'''
\set IH '''80000000-0000-0000-0000-000000000008'''

INSERT INTO auth.users (id, email) VALUES
  ('99999999-0000-0000-0000-000000000009', 'user-g@test.invalid'),
  ('88888888-0000-0000-0000-000000000008', 'user-h@test.invalid')
ON CONFLICT (id) DO NOTHING;

SET ROLE service_role;
INSERT INTO public.impact_investigations (id, owner_id, subject_org_ref, subject_org_type, subject_identity) VALUES
  (:IG, :UG, 'org-riverbend', 'NGO', '{"legalName":"Riverbend Relief"}'),
  (:IH, :UH, 'org-riverbend', 'NGO', '{"legalName":"Riverbend Relief"}');

-- ── I3F-03: one transaction for source + artifact + candidates ─────────────
SELECT public.impact_ingest_artifact(:IG, pg_temp.src(:IG, 'art-a', 'a', :UG), pg_temp.art(:IG, 'art-a', 'a', :UG),
  jsonb_build_array(pg_temp.cand(:IG, 'k-a1', 'art-a', 'a', 1, :UG), pg_temp.cand(:IG, 'k-a2', 'art-a', 'a', 2, :UG)));
RESET ROLE;
SELECT pg_temp.expect_eq('D4-01 atomic ingestion wrote source + artifact + 2 candidates',
  (SELECT (SELECT count(*) FROM impact_sources WHERE investigation_id = :IG AND ref = 'art-a') || '/' ||
          (SELECT count(*) FROM impact_artifacts WHERE investigation_id = :IG) || '/' ||
          (SELECT count(*) FROM impact_evidence_candidates WHERE investigation_id = :IG)), '1/1/2');
SELECT pg_temp.expect_eq('D4-02 array columns survive the JSON bundle (review_reasons)',
  (SELECT review_reasons::text FROM impact_evidence_candidates WHERE investigation_id = :IG AND ref = 'k-a1'), '{SUBJECT_NOT_MENTIONED}');

SET ROLE service_role;
SELECT pg_temp.expect_fail('D4-03 a candidate failing its trigger rolls back the WHOLE bundle (no orphan source)',
  $$SELECT public.impact_ingest_artifact('90000000-0000-0000-0000-000000000009', pg_temp.src('90000000-0000-0000-0000-000000000009', 'art-b', 'b', '99999999-0000-0000-0000-000000000009'),
      pg_temp.art('90000000-0000-0000-0000-000000000009', 'art-b', 'b', '99999999-0000-0000-0000-000000000009'),
      jsonb_build_array(pg_temp.cand('90000000-0000-0000-0000-000000000009', 'k-b1', 'art-b', 'b', 99, '99999999-0000-0000-0000-000000000009')))$$, 'IMPACT_LOCATOR_INVALID');
SELECT pg_temp.expect_fail('D4-04 an artifact failing its trigger rolls back its source too',
  $$SELECT public.impact_ingest_artifact('90000000-0000-0000-0000-000000000009', pg_temp.src('90000000-0000-0000-0000-000000000009', 'art-c', 'c', '99999999-0000-0000-0000-000000000009'),
      pg_temp.art('90000000-0000-0000-0000-000000000009', 'art-c', 'a', '99999999-0000-0000-0000-000000000009'), '[]'::jsonb)$$, 'IMPACT_ARTIFACT_SOURCE_INVALID|23505');
SELECT pg_temp.expect_fail('D4-05 a bundle mixing investigations is refused',
  $$SELECT public.impact_ingest_artifact('90000000-0000-0000-0000-000000000009', pg_temp.src('80000000-0000-0000-0000-000000000008', 'art-x', 'd', '88888888-0000-0000-0000-000000000008'),
      pg_temp.art('90000000-0000-0000-0000-000000000009', 'art-x', 'd', '99999999-0000-0000-0000-000000000009'), '[]'::jsonb)$$, 'IMPACT_ARTIFACT_INVALID');
SELECT pg_temp.expect_fail('D4-06 an unknown column cannot be smuggled into the bundle',
  $$SELECT public.impact_ingest_artifact('90000000-0000-0000-0000-000000000009', NULL,
      pg_temp.art('90000000-0000-0000-0000-000000000009', 'art-y', 'e', '99999999-0000-0000-0000-000000000009') || '{"owner_id":"x"}', '[]'::jsonb)$$, 'IMPACT_ARTIFACT_INVALID');
SELECT pg_temp.expect_fail('D4-07 the row helper only writes the three ingestion tables',
  $$SELECT public.impact_insert_row('impact_audit_events', '{"investigation_id":"90000000-0000-0000-0000-000000000009"}'::jsonb)$$, 'IMPACT_ARTIFACT_INVALID');
SELECT pg_temp.expect_fail('D4-08 a bundle in the name of a non-owner is refused',
  $$SELECT public.impact_ingest_artifact('90000000-0000-0000-0000-000000000009', pg_temp.src('90000000-0000-0000-0000-000000000009', 'art-z', 'f', '88888888-0000-0000-0000-000000000008'),
      pg_temp.art('90000000-0000-0000-0000-000000000009', 'art-z', 'f', '88888888-0000-0000-0000-000000000008'), '[]'::jsonb)$$, 'IMPACT_ACTOR_NOT_OWNER');
RESET ROLE;
SELECT pg_temp.expect_eq('D4-09 no failed bundle left any row (no orphan sources)',
  (SELECT count(*)::text FROM impact_sources WHERE investigation_id = :IG AND ref IN ('art-b', 'art-c', 'art-x', 'art-y', 'art-z')), '0');
SELECT pg_temp.expect_eq('D4-10 failed bundles left no audit events',
  (SELECT count(*)::text FROM impact_audit_events WHERE investigation_id = :IG AND 'art-b' = ANY(refs)), '0');

-- ── dossier snapshot register ──────────────────────────────────────────────
\set HX '''1111111111111111111111111111111111111111111111111111111111111111'''
SET ROLE service_role;
INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, as_of, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
SELECT :IG, 'dossier-' || left(:HX, 24), 'impact-dossier/1', :HX, '2026-09-20T00:00:00.000Z', 'INCOMPLETE', 0, e.seq, e.hash, '2026-09-24T00:00:00Z', :UG
FROM public.impact_audit_events e WHERE e.investigation_id = :IG ORDER BY e.seq DESC LIMIT 1;
RESET ROLE;
SELECT pg_temp.expect_eq('D4-11 a dossier export is audited (DOSSIER_EXPORTED) and the chain stays intact',
  (SELECT count(*) || '/' || public.impact_audit_chain_ok(:IG) FROM impact_audit_events WHERE investigation_id = :IG AND event_type = 'DOSSIER_EXPORTED'), '1/true');

SET ROLE service_role;
SELECT pg_temp.expect_fail('D4-12 the same content exported twice is ONE registration',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    SELECT '90000000-0000-0000-0000-000000000009', 'dossier-' || repeat('1', 24), 'impact-dossier/1', repeat('1', 64), 'INCOMPLETE', 0, 1, e.hash, '2026-09-24T00:00:00Z', '99999999-0000-0000-0000-000000000009'
    FROM public.impact_audit_events e WHERE e.investigation_id = '90000000-0000-0000-0000-000000000009' AND e.seq = 1$$, '23505');
SELECT pg_temp.expect_fail('D4-13 a snapshot bound to a forged audit head is refused',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    VALUES ('90000000-0000-0000-0000-000000000009', 'dossier-' || repeat('2', 24), 'impact-dossier/1', repeat('2', 64), 'INCOMPLETE', 0, 1, repeat('f', 64), '2026-09-24T00:00:00Z', '99999999-0000-0000-0000-000000000009')$$, 'IMPACT_DOSSIER_INVALID');
SELECT pg_temp.expect_fail('D4-14 a snapshot at a non-existent audit position is refused',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    VALUES ('90000000-0000-0000-0000-000000000009', 'dossier-' || repeat('3', 24), 'impact-dossier/1', repeat('3', 64), 'INCOMPLETE', 0, 9999, repeat('f', 64), '2026-09-24T00:00:00Z', '99999999-0000-0000-0000-000000000009')$$, 'IMPACT_DOSSIER_INVALID|23503');
SELECT pg_temp.expect_fail('D4-15 the ref must be derived from the content hash',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    SELECT '90000000-0000-0000-0000-000000000009', 'dossier-forged', 'impact-dossier/1', repeat('4', 64), 'INCOMPLETE', 0, 1, e.hash, '2026-09-24T00:00:00Z', '99999999-0000-0000-0000-000000000009'
    FROM public.impact_audit_events e WHERE e.investigation_id = '90000000-0000-0000-0000-000000000009' AND e.seq = 1$$, '23514');
SELECT pg_temp.expect_fail('D4-16 a dossier status that judges the organization does not exist',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    SELECT '90000000-0000-0000-0000-000000000009', 'dossier-' || repeat('5', 24), 'impact-dossier/1', repeat('5', 64), 'TRUSTED', 0, 1, e.hash, '2026-09-24T00:00:00Z', '99999999-0000-0000-0000-000000000009'
    FROM public.impact_audit_events e WHERE e.investigation_id = '90000000-0000-0000-0000-000000000009' AND e.seq = 1$$, '23514');
SELECT pg_temp.expect_fail('D4-17 a snapshot registered in the name of a non-owner',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    SELECT '90000000-0000-0000-0000-000000000009', 'dossier-' || repeat('6', 24), 'impact-dossier/1', repeat('6', 64), 'INCOMPLETE', 0, 1, e.hash, '2026-09-24T00:00:00Z', '88888888-0000-0000-0000-000000000008'
    FROM public.impact_audit_events e WHERE e.investigation_id = '90000000-0000-0000-0000-000000000009' AND e.seq = 1$$, 'IMPACT_ACTOR_NOT_OWNER');
SELECT pg_temp.expect_fail('D4-18 a snapshot of investigation G bound to investigation H''s chain',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    SELECT '90000000-0000-0000-0000-000000000009', 'dossier-' || repeat('7', 24), 'impact-dossier/1', repeat('7', 64), 'INCOMPLETE', 0, 1, e.hash, '2026-09-24T00:00:00Z', '99999999-0000-0000-0000-000000000009'
    FROM public.impact_audit_events e WHERE e.investigation_id = '80000000-0000-0000-0000-000000000008' AND e.seq = 1$$, 'IMPACT_DOSSIER_INVALID');
SELECT pg_temp.expect_fail('D4-19 snapshots are append-only',
  $$UPDATE public.impact_dossier_snapshots SET dossier_status = 'COMPLETE'$$, '42501|IMPACT_');
SELECT pg_temp.expect_fail('D4-20 service_role cannot delete a snapshot',
  $$DELETE FROM public.impact_dossier_snapshots$$, '42501');
RESET ROLE;

-- ── RLS / privileges for clients ───────────────────────────────────────────
SET ROLE authenticated;
SELECT pg_temp.act_as('99999999-0000-0000-0000-000000000009');
SELECT pg_temp.expect_eq('D4-21 owner reads its snapshot register', (SELECT count(*)::text FROM public.impact_dossier_snapshots), '1');
SELECT pg_temp.expect_fail('D4-22 authenticated cannot register a snapshot',
  $$INSERT INTO public.impact_dossier_snapshots (investigation_id, ref, schema_version, content_hash, dossier_status, claim_count, audit_seq, audit_head, exported_at, created_by)
    VALUES ('90000000-0000-0000-0000-000000000009', 'dossier-' || repeat('8', 24), 'impact-dossier/1', repeat('8', 64), 'COMPLETE', 0, 1, repeat('f', 64), '2026-09-24T00:00:00Z', '99999999-0000-0000-0000-000000000009')$$, '42501');
SELECT pg_temp.expect_fail('D4-23 authenticated cannot call the ingestion RPC',
  $$SELECT public.impact_ingest_artifact('90000000-0000-0000-0000-000000000009', NULL, '{}'::jsonb, '[]'::jsonb)$$, '42501');
SELECT pg_temp.expect_fail('D4-24 authenticated cannot call the row helper',
  $$SELECT public.impact_insert_row('impact_sources', '{}'::jsonb)$$, '42501');
SELECT pg_temp.act_as('88888888-0000-0000-0000-000000000008');
SELECT pg_temp.expect_eq('D4-25 cross-user: H sees none of G''s snapshots', (SELECT count(*)::text FROM public.impact_dossier_snapshots), '0');
RESET ROLE;
SET ROLE anon;
SELECT pg_temp.act_as(NULL);
SELECT pg_temp.expect_fail('D4-26 anon cannot read the snapshot register', $$SELECT count(*) FROM public.impact_dossier_snapshots$$, '42501');
SELECT pg_temp.expect_fail('D4-27 anon cannot call the ingestion RPC',
  $$SELECT public.impact_ingest_artifact('90000000-0000-0000-0000-000000000009', NULL, '{}'::jsonb, '[]'::jsonb)$$, '42501');
RESET ROLE;

SELECT pg_temp.expect_eq('D4-28 service_role holds no UPDATE / DELETE / TRUNCATE on the register (LAB_ONLY, not expanded)',
  (SELECT count(*)::text FROM information_schema.table_privileges WHERE table_schema = 'public' AND table_name = 'impact_dossier_snapshots'
     AND grantee = 'service_role' AND privilege_type IN ('UPDATE', 'DELETE', 'TRUNCATE')), '0');
SELECT pg_temp.expect_eq('D4-29 the register stores no dossier content and no verdict column',
  (SELECT count(*)::text FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'impact_dossier_snapshots'
     AND column_name ~* '(content$|body|payload|json|verdict|score|trust|fraud|rank)'), '0');
SELECT pg_temp.expect_eq('D4-30 ingestion functions are SECURITY INVOKER (no privilege expansion)',
  (SELECT string_agg(proname || ':' || prosecdef, ',' ORDER BY proname COLLATE "C") FROM pg_proc
   WHERE proname IN ('impact_ingest_artifact', 'impact_insert_row') AND pronamespace = 'public'::regnamespace), 'impact_ingest_artifact:false,impact_insert_row:false');
SELECT pg_temp.expect_eq('D4-31 audit chains intact after all I4 writes',
  (public.impact_audit_chain_ok(:IG) AND public.impact_audit_chain_ok(:IH))::text, 'true');

SELECT 'IMPACT_DOSSIER_RLS: PASS ' || count(*) || ' checks' FROM i4_log;
