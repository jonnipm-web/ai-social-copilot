-- IV-IMPACT-I1-PERSISTENCE-RLS-01 — RLS, privilege and invariant tests for
-- the Impact Lab tables (migration 20260924010000). Runs against a DISPOSABLE
-- database with every migration applied (never production). Every check
-- RAISEs on failure; a clean run ends with 'IMPACT_LAB_RLS: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

CREATE TEMP TABLE impact_test_log (n serial, label text);
GRANT ALL ON impact_test_log TO PUBLIC;
GRANT ALL ON SEQUENCE impact_test_log_n_seq TO PUBLIC;

-- expect_fail(label, sql, pattern): the statement MUST fail, and its message
-- or SQLSTATE must match `pattern` (a failure for the wrong reason is not a pass).
CREATE FUNCTION pg_temp.expect_fail(p_label text, p_sql text, p_pattern text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN others THEN
    IF SQLERRM ~* p_pattern OR SQLSTATE ~* p_pattern THEN
      INSERT INTO impact_test_log (label) VALUES (p_label);
      RETURN;
    END IF;
    RAISE EXCEPTION '% failed for the WRONG reason: [%] %', p_label, SQLSTATE, SQLERRM;
  END;
  RAISE EXCEPTION '% was expected to FAIL but succeeded', p_label;
END $$;

CREATE FUNCTION pg_temp.expect_eq(p_label text, p_actual bigint, p_expected bigint) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_actual IS DISTINCT FROM p_expected THEN
    RAISE EXCEPTION '% expected % got %', p_label, p_expected, p_actual;
  END IF;
  INSERT INTO impact_test_log (label) VALUES (p_label);
END $$;

CREATE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(uid, ''), false);
  PERFORM set_config('request.jwt.claim.role', CASE WHEN uid IS NULL THEN 'anon' ELSE 'authenticated' END, false);
END $$;

-- ids
\set UA '''aaaaaaaa-0000-0000-0000-00000000000a'''
\set UB '''bbbbbbbb-0000-0000-0000-00000000000b'''
\set IA '''a2222222-0000-0000-0000-00000000000a'''
\set IB '''b2222222-0000-0000-0000-00000000000b'''

-- ── parity vector: SQL audit hash format == lab_store.ts auditHash() ────────
SELECT pg_temp.expect_eq('H01 audit hash parity with TypeScript',
  (SELECT (encode(sha256(convert_to(concat_ws('|', 1::text, '2026-09-23T00:00:00.000000Z', 'INVESTIGATION_CREATED', 'u',
     '00000000-0000-0000-0000-000000000000'::uuid::text, array_to_string(ARRAY['org-x','r2'], ','), array_to_string(ARRAY['A'], ','),
     repeat('0', 64)), 'UTF8')), 'hex') = 'b811626c996e5ca8cb396747421edcaf32a43a178f575b16b8f5bb40d1d48fbf')::int), 1);

-- ── fixtures (superuser) ────────────────────────────────────────────────────
INSERT INTO auth.users (id, email) VALUES
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'user-a@test.invalid'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'user-b@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.projects (id, user_id, name) VALUES
  ('a1111111-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a', 'Project A'),
  ('b1111111-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-00000000000b', 'Project B')
ON CONFLICT (id) DO NOTHING;

-- ── writes exactly as the Edge Function performs them: service_role ─────────
SET ROLE service_role;

INSERT INTO public.impact_investigations (id, owner_id, project_id, subject_org_ref, subject_org_type, subject_identity)
VALUES (:IA, :UA, 'a1111111-0000-0000-0000-00000000000a', 'org-hopebridge', 'FOUNDATION', '{"legalName":"HopeBridge Foundation"}'),
       (:IB, :UB, NULL, 'org-northstar', 'NGO', '{"legalName":"Northstar Relief Initiative"}');

INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, publisher_org_ref, retrieved_at, retention,
  content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, snapshot, created_by) VALUES
  (:IA, 'src-web', 'ORGANIZATION_WEBSITE', 'HopeBridge Foundation', 'org-hopebridge', '2026-09-01T00:00:00Z',
   'EXCERPT_AND_HASH', repeat('b', 64), 'ANALYST_ENTRY', NULL, NULL, NULL, :UA),
  (:IA, 'src-reg', 'OFFICIAL_REGISTRY', 'Exampleland Charity Registry (fixture)', NULL, '2026-09-01T00:00:00Z',
   'SNAPSHOT', repeat('a', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', '{"registrationNumber":"XA1234567"}', :UA),
  (:IB, 'src-web', 'ORGANIZATION_WEBSITE', 'Northstar Relief Initiative', 'org-northstar', '2026-09-01T00:00:00Z',
   'EXCERPT_AND_HASH', repeat('c', 64), 'ANALYST_ENTRY', NULL, NULL, NULL, :UB);

INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, created_by) VALUES
  (:IA, 'c1', 'LEGAL_REGISTRATION', 'HopeBridge is a registered charity.', 'org-hopebridge', 'src-web', '2026-09-02T00:00:00Z', 'MANUAL', :UA),
  (:IA, 'c2', 'IMPACT_OUTPUT', 'We built 20 wells.', 'org-hopebridge', 'src-web', '2026-09-02T00:00:00Z', 'MANUAL', :UA),
  (:IB, 'c1', 'LEGAL_REGISTRATION', 'Northstar is registered.', 'org-northstar', 'src-web', '2026-09-02T00:00:00Z', 'MANUAL', :UB);

INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis,
  observed_to, personal_data, added_at, created_by) VALUES
  (:IA, 'e1', 'c1', 'src-reg', 'org-hopebridge', 'SUPPORTS', 'HUMAN_ASSESSED', '2026-09-01', 'NONE', '2026-09-02T00:00:00Z', :UA),
  (:IA, 'e2', 'c2', 'src-web', 'org-hopebridge', 'SUPPORTS', 'HUMAN_ASSESSED', NULL, 'AGGREGATED', '2026-09-02T00:00:00Z', :UA),
  (:IB, 'e1', 'c1', 'src-web', 'org-northstar', 'SUPPORTS', 'HUMAN_ASSESSED', NULL, 'NONE', '2026-09-02T00:00:00Z', :UB);

INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency,
  display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, conflict_count, result, created_by) VALUES
  (:IA, 'c1', 'vr_' || repeat('1', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'impact-verification/7',
   repeat('d', 64), repeat('e', 64), '2026-09-23T00:00:00Z', 0,
   jsonb_build_object('resultId', 'vr_' || repeat('1', 32), 'status', 'SUPPORTED', 'claimId', 'c1',
     'isFindingOfWrongdoing', false, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true, 'conflicts', '[]'::jsonb), :UA),
  (:IB, 'c1', 'vr_' || repeat('2', 32), 'UNVERIFIED', 'UNVERIFIED', 'SELF_REPORTED', 'CLAIM', 'AUTOMATED', 'impact-verification/7',
   repeat('d', 64), repeat('e', 64), '2026-09-23T00:00:00Z', 0,
   jsonb_build_object('resultId', 'vr_' || repeat('2', 32), 'status', 'UNVERIFIED', 'claimId', 'c1',
     'isFindingOfWrongdoing', false, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true, 'conflicts', '[]'::jsonb), :UB);

INSERT INTO public.impact_disputes (investigation_id, ref, claim_ref, kind, opened_at, submitted_evidence_refs, created_by) VALUES
  (:IB, 'd1', 'c1', 'ORGANIZATION_RESPONSE', '2026-09-23T00:00:00Z', ARRAY['e1'], :UB);

-- ── S: service-side invariants (hold even for service_role) ─────────────────
SELECT pg_temp.expect_fail('S01 project of another user cannot be linked',
  $$INSERT INTO public.impact_investigations (owner_id, project_id, subject_org_ref, subject_org_type)
    VALUES ('aaaaaaaa-0000-0000-0000-00000000000a', 'b1111111-0000-0000-0000-00000000000b', 'org-x', 'NGO')$$, 'IMPACT_PROJECT_NOT_OWNED');
SELECT pg_temp.expect_fail('S02 nonexistent project fails closed',
  $$INSERT INTO public.impact_investigations (owner_id, project_id, subject_org_ref, subject_org_type)
    VALUES ('aaaaaaaa-0000-0000-0000-00000000000a', 'c1111111-0000-0000-0000-00000000000c', 'org-x', 'NGO')$$, 'IMPACT_PROJECT_NOT_OWNED|23503');
SELECT pg_temp.expect_fail('S03 relinking an investigation to a foreign project',
  $$UPDATE public.impact_investigations SET project_id = 'b1111111-0000-0000-0000-00000000000b'
    WHERE id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_PROJECT_NOT_OWNED');
SELECT pg_temp.expect_fail('S04 owner reassignment (hijack) is refused',
  $$UPDATE public.impact_investigations SET owner_id = 'bbbbbbbb-0000-0000-0000-00000000000b'
    WHERE id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_IMMUTABLE_FIELD');
SELECT pg_temp.expect_fail('S05 subject reassignment is refused',
  $$UPDATE public.impact_investigations SET subject_org_ref = 'org-other' WHERE id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_IMMUTABLE_FIELD|23503');
SELECT pg_temp.expect_fail('S06 evidence cannot link a claim of another investigation (composite FK)',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'e9', 'c9', 'src-web', 'org-hopebridge', 'SUPPORTS', 'HUMAN_ASSESSED', 'NONE', '2026-09-02', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23503');
SELECT pg_temp.expect_fail('S07 child row pointing at a foreign investigation''s source (composite FK)',
  $$INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, created_by)
    VALUES ('b2222222-0000-0000-0000-00000000000b', 'c9', 'OTHER', 'x', 'org-northstar', 'src-reg', '2026-09-02', 'MANUAL', 'bbbbbbbb-0000-0000-0000-00000000000b')$$, '23503');
SELECT pg_temp.expect_fail('S08 claim about another organization (CF-01 at the DB)',
  $$INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c9', 'OTHER', 'x', 'org-northstar', 'src-web', '2026-09-02', 'MANUAL', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23503');
SELECT pg_temp.expect_fail('S09 moving a source to another investigation is refused',
  $$UPDATE public.impact_sources SET investigation_id = 'b2222222-0000-0000-0000-00000000000b', updated_by = 'aaaaaaaa-0000-0000-0000-00000000000a'
    WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a' AND ref = 'src-web'$$, 'IMPACT_IMMUTABLE_FIELD|23503|23505');
SELECT pg_temp.expect_fail('S10 source provenance fields are immutable',
  $$UPDATE public.impact_sources SET publisher = 'Official Government', updated_by = 'aaaaaaaa-0000-0000-0000-00000000000a'
    WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a' AND ref = 'src-web'$$, 'IMPACT_IMMUTABLE_FIELD');
SELECT pg_temp.expect_fail('S11 acquisition cannot be upgraded to PROVIDER afterwards',
  $$UPDATE public.impact_sources SET acquisition_method = 'PROVIDER', acquisition_provider_id = 'fake-government', updated_by = 'aaaaaaaa-0000-0000-0000-00000000000a'
    WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a' AND ref = 'src-web'$$, 'IMPACT_IMMUTABLE_FIELD');
SELECT pg_temp.expect_fail('S12 PROVIDER acquisition without provider id',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'src-x', 'OFFICIAL_REGISTRY', 'X', '2026-09-01', 'HASH_ONLY', repeat('f', 64), 'PROVIDER', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('S13 claims are append-only (no status/text rewrite)',
  $$UPDATE public.impact_claims SET claim_text = 'rewritten' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY');
SELECT pg_temp.expect_fail('S14 evidence is append-only',
  $$UPDATE public.impact_evidence SET relationship = 'CONTRADICTS' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY');
SELECT pg_temp.expect_fail('S15 verification history cannot be rewritten',
  $$UPDATE public.impact_verifications SET status = 'CONTRADICTED' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY');
SELECT pg_temp.expect_fail('S16 audit events cannot be rewritten',
  $$UPDATE public.impact_audit_events SET codes = '{}' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY');
SELECT pg_temp.expect_fail('S17 direct DELETE of audit history is refused',
  $$DELETE FROM public.impact_audit_events WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE');
SELECT pg_temp.expect_fail('S18 direct DELETE of verification history is refused',
  $$DELETE FROM public.impact_verifications WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE');
SELECT pg_temp.expect_fail('S19 direct DELETE of an investigation (would cascade history) is refused',
  $$DELETE FROM public.impact_investigations WHERE id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE');
SELECT pg_temp.expect_fail('S20 a persisted verification must be a non-finding of wrongdoing',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('3', 32), 'CONTRADICTED', 'CONTRADICTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'REVIEW_REQUIRED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      jsonb_build_object('resultId', 'vr_' || repeat('3', 32), 'status', 'CONTRADICTED', 'claimId', 'c2', 'isFindingOfWrongdoing', true, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('S21 status column must match the engine result (no status forgery)',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('4', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      jsonb_build_object('resultId', 'vr_' || repeat('4', 32), 'status', 'UNVERIFIED', 'claimId', 'c2', 'isFindingOfWrongdoing', false, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('S22 minors'' data cannot be stored',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'e9', 'c2', 'src-web', 'org-hopebridge', 'SUPPORTS', 'HUMAN_ASSESSED', 'MINOR', '2026-09-02', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('S23 personal data cannot be stored',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'e9', 'c2', 'src-web', 'org-hopebridge', 'SUPPORTS', 'HUMAN_ASSESSED', 'PERSONAL', '2026-09-02', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('S24 source retrieved in the future',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'src-f', 'NEWS', 'Paper', '2099-01-01T00:00:00Z', 'HASH_ONLY', repeat('f', 64), 'ANALYST_ENTRY', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_TEMPORAL');
SELECT pg_temp.expect_fail('S25 published after retrieval',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, published_at, retention, content_hash, acquisition_method, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'src-f', 'NEWS', 'Paper', '2026-01-01', '2026-02-01', 'HASH_ONLY', repeat('f', 64), 'ANALYST_ENTRY', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_TEMPORAL');
SELECT pg_temp.expect_fail('S26 impossible calendar date',
  $$INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, created_by, period_from)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c9', 'OTHER', 'x', 'org-hopebridge', 'src-web', '2026-09-02', 'MANUAL', 'aaaaaaaa-0000-0000-0000-00000000000a', '2025-02-30')$$, 'IMPACT_INVALID_TIMESTAMP');
SELECT pg_temp.expect_fail('S27 reversed claim period',
  $$INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, created_by, period_from, period_to)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c9', 'OTHER', 'x', 'org-hopebridge', 'src-web', '2026-09-02', 'MANUAL', 'aaaaaaaa-0000-0000-0000-00000000000a', '2025-12-31', '2025-01-01')$$, 'IMPACT_TEMPORAL');
SELECT pg_temp.expect_fail('S28 observed period extending past retrieval',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, observed_to, personal_data, added_at, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'e9', 'c2', 'src-web', 'org-hopebridge', 'SUPPORTS', 'HUMAN_ASSESSED', '2026-12-31', 'NONE', '2026-09-02', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_TEMPORAL');
SELECT pg_temp.expect_fail('S29 unknown enum value',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'e9', 'c2', 'src-web', 'org-hopebridge', 'PROVES_FRAUD', 'HUMAN_ASSESSED', 'NONE', '2026-09-02', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('S30 dispute citing evidence of another claim',
  $$INSERT INTO public.impact_disputes (investigation_id, ref, claim_ref, kind, opened_at, submitted_evidence_refs, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'd9', 'c1', 'CORRECTION_REQUEST', '2026-09-23', ARRAY['e2'], 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_DISPUTE_EVIDENCE_NOT_OF_CLAIM');
SELECT pg_temp.expect_fail('S31 duplicate ref (retry of the same ingestion) is refused, never duplicated',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'src-web', 'NEWS', 'Paper', '2026-09-01', 'HASH_ONLY', repeat('f', 64), 'ANALYST_ENTRY', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23505');

-- versioning: a second verification of c1 gets version 2, status change audited, conflicts expanded
INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency,
  display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, conflict_count, result, idempotency_key, created_by)
VALUES (:IA, 'c1', 'vr_' || repeat('5', 32), 'INCONCLUSIVE', 'INCONCLUSIVE', 'CONFLICTING_EVIDENCE', 'CONFLICT', 'REVIEW_REQUIRED',
  'impact-verification/7', repeat('d', 64), repeat('e', 64), '2026-09-24T00:00:00Z', 1,
  jsonb_build_object('resultId', 'vr_' || repeat('5', 32), 'status', 'INCONCLUSIVE', 'claimId', 'c1',
    'isFindingOfWrongdoing', false, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true,
    'conflicts', jsonb_build_array(jsonb_build_object('kind', 'QUANTITY_DISAGREEMENT', 'basis', 'INDEPENDENT_SOURCES',
      'positions', '[]'::jsonb, 'resolution', 'UNRESOLVED'))),
  '11111111-2222-3333-4444-555555555555', :UA);
SELECT pg_temp.expect_eq('S32 versions are 1,2 (history kept)',
  (SELECT count(*) FROM public.impact_verifications WHERE investigation_id = :IA AND claim_ref = 'c1' AND version IN (1, 2)), 2);
SELECT pg_temp.expect_eq('S33 status change is audited',
  (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IA AND event_type = 'STATUS_CHANGED'), 1);
SELECT pg_temp.expect_eq('S34 conflicts expanded from the verification',
  (SELECT count(*) FROM public.impact_conflicts WHERE investigation_id = :IA AND claim_ref = 'c1'), 1);
SELECT pg_temp.expect_fail('S35 idempotent retry of a verification is refused (no duplicate history)',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, idempotency_key, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_' || repeat('6', 32), 'INCONCLUSIVE', 'INCONCLUSIVE', 'CONFLICTING_EVIDENCE', 'CONFLICT', 'REVIEW_REQUIRED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-24',
      jsonb_build_object('resultId', 'vr_' || repeat('6', 32), 'status', 'INCONCLUSIVE', 'claimId', 'c1', 'isFindingOfWrongdoing', false, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true),
      '11111111-2222-3333-4444-555555555555', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23505');

-- source correction: status changes, history preserved, re-verification required
UPDATE public.impact_sources SET status = 'RETRACTED', updated_by = :UA, updated_at = now()
WHERE investigation_id = :IA AND ref = 'src-reg';
SELECT pg_temp.expect_eq('S36 source status change audited with REVERIFICATION_REQUIRED',
  (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IA AND event_type = 'SOURCE_STATUS_CHANGED'
     AND 'REVERIFICATION_REQUIRED' = ANY (codes)), 1);
SELECT pg_temp.expect_eq('S37 older verifications survive a source correction',
  (SELECT count(*) FROM public.impact_verifications WHERE investigation_id = :IA), 2);

-- disputes: resolve once; CORRECTED adds a CORRECTION event; second resolution refused
UPDATE public.impact_disputes SET resolution = 'CORRECTED', resolved_at = '2026-09-24T00:00:00Z', updated_by = :UB
WHERE investigation_id = :IB AND ref = 'd1';
SELECT pg_temp.expect_eq('S38 dispute resolution + correction audited',
  (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IB AND event_type IN ('DISPUTE_RESOLVED', 'CORRECTION')), 2);
SELECT pg_temp.expect_fail('S39 a dispute is resolved only once',
  $$UPDATE public.impact_disputes SET resolution = 'UPHELD', resolved_at = '2026-09-25', updated_by = 'bbbbbbbb-0000-0000-0000-00000000000b'
    WHERE investigation_id = 'b2222222-0000-0000-0000-00000000000b' AND ref = 'd1'$$, 'IMPACT_DISPUTE_ALREADY_RESOLVED');

-- audit chain intact for both investigations
SELECT pg_temp.expect_eq('S40 audit chain A verifies', (SELECT public.impact_audit_chain_ok(:IA))::int, 1);
SELECT pg_temp.expect_eq('S41 audit chain B verifies', (SELECT public.impact_audit_chain_ok(:IB))::int, 1);
SELECT pg_temp.expect_eq('S42 every write of A was audited (created, 2 sources, 2 claims, 2 evidence, 2 runs, status, conflict, source status)',
  (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IA), 12);

RESET ROLE;

-- ── A: authenticated user A vs user B (RLS) ────────────────────────────────
SELECT pg_temp.act_as('aaaaaaaa-0000-0000-0000-00000000000a');
SET ROLE authenticated;

SELECT pg_temp.expect_eq('A01 A sees exactly its own investigation', (SELECT count(*) FROM public.impact_investigations), 1);
SELECT pg_temp.expect_eq('A02 A cannot select B by id', (SELECT count(*) FROM public.impact_investigations WHERE id = :IB), 0);
SELECT pg_temp.expect_eq('A03 sources of B are invisible', (SELECT count(*) FROM public.impact_sources WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('A04 claims of B are invisible', (SELECT count(*) FROM public.impact_claims WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('A05 evidence of B is invisible', (SELECT count(*) FROM public.impact_evidence WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('A06 verifications of B are invisible', (SELECT count(*) FROM public.impact_verifications WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('A07 conflicts of B are invisible', (SELECT count(*) FROM public.impact_conflicts WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('A08 disputes of B are invisible', (SELECT count(*) FROM public.impact_disputes WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('A09 audit of B is invisible', (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('A10 unfiltered child reads return only A''s rows',
  (SELECT count(*) FROM public.impact_claims) + (SELECT count(*) FROM public.impact_evidence) + (SELECT count(*) FROM public.impact_sources), 6);
SELECT pg_temp.expect_eq('A11 A can read its own audit trail', (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IA), 12);
SELECT pg_temp.expect_eq('A12 A can verify its own chain', (SELECT public.impact_audit_chain_ok(:IA))::int, 1);
SELECT pg_temp.expect_eq('A13 B''s chain is not even visible to A', (SELECT public.impact_audit_chain_ok(:IB))::int, 0);

SELECT pg_temp.expect_fail('A14 A cannot insert an investigation (even for itself)',
  $$INSERT INTO public.impact_investigations (owner_id, subject_org_ref, subject_org_type) VALUES ('aaaaaaaa-0000-0000-0000-00000000000a', 'org-x', 'NGO')$$, '42501');
SELECT pg_temp.expect_fail('A15 A cannot insert a child row into B',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, created_by)
    VALUES ('b2222222-0000-0000-0000-00000000000b', 'src-x', 'NEWS', 'Paper', '2026-09-01', 'HASH_ONLY', repeat('f', 64), 'ANALYST_ENTRY', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '42501');
SELECT pg_temp.expect_fail('A16 A cannot link evidence in B',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('b2222222-0000-0000-0000-00000000000b', 'e9', 'c1', 'src-web', 'org-northstar', 'CONTRADICTS', 'HUMAN_ASSESSED', 'NONE', '2026-09-02', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '42501');
SELECT pg_temp.expect_fail('A17 A cannot write its OWN claim directly (engine/EF is the only writer)',
  $$INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c9', 'OTHER', 'x', 'org-hopebridge', 'src-web', '2026-09-02', 'MANUAL', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '42501');
SELECT pg_temp.expect_fail('A18 A cannot forge a SUPPORTED verification for itself',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('7', 32), 'SUPPORTED', 'SUPPORTED', 'MULTI_SOURCE_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      jsonb_build_object('resultId', 'vr_' || repeat('7', 32), 'status', 'SUPPORTED', 'claimId', 'c2', 'isFindingOfWrongdoing', false, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '42501');
SELECT pg_temp.expect_fail('A19 A cannot forge an audit event',
  $$INSERT INTO public.impact_audit_events (investigation_id, seq, at_text, event_type, actor_ref, prev_hash, hash)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 99, 'x', 'MANUAL_REVIEW', 'x', repeat('0', 64), repeat('0', 64))$$, '42501');
SELECT pg_temp.expect_fail('A20 A cannot call the audit appender',
  $$SELECT public.impact_append_audit('a2222222-0000-0000-0000-00000000000a', 'MANUAL_REVIEW', 'x', '{}', '{}')$$, '42501');
SELECT pg_temp.expect_fail('A21 A cannot update B',
  $$UPDATE public.impact_investigations SET status = 'ARCHIVED' WHERE id = 'b2222222-0000-0000-0000-00000000000b'$$, '42501');
SELECT pg_temp.expect_fail('A22 A cannot update its own investigation directly (ownership swap)',
  $$UPDATE public.impact_investigations SET owner_id = 'bbbbbbbb-0000-0000-0000-00000000000b' WHERE id = 'a2222222-0000-0000-0000-00000000000a'$$, '42501');
SELECT pg_temp.expect_fail('A23 A cannot move a claim A→B (investigation_id swap)',
  $$UPDATE public.impact_claims SET investigation_id = 'b2222222-0000-0000-0000-00000000000b' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, '42501');
SELECT pg_temp.expect_fail('A24 A cannot delete B',
  $$DELETE FROM public.impact_investigations WHERE id = 'b2222222-0000-0000-0000-00000000000b'$$, '42501');
SELECT pg_temp.expect_fail('A25 A cannot delete its own audit trail',
  $$DELETE FROM public.impact_audit_events WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, '42501');
SELECT pg_temp.expect_fail('A26 A cannot truncate',
  $$TRUNCATE public.impact_verifications$$, '42501');
RESET ROLE;

-- ── N: anonymous ────────────────────────────────────────────────────────────
SELECT pg_temp.act_as(NULL);
SET ROLE anon;
SELECT pg_temp.expect_fail('N01 anon cannot read investigations', $$SELECT count(*) FROM public.impact_investigations$$, '42501');
SELECT pg_temp.expect_fail('N02 anon cannot read audit', $$SELECT count(*) FROM public.impact_audit_events$$, '42501');
SELECT pg_temp.expect_fail('N03 anon cannot insert',
  $$INSERT INTO public.impact_investigations (owner_id, subject_org_ref, subject_org_type) VALUES ('aaaaaaaa-0000-0000-0000-00000000000a', 'org-x', 'NGO')$$, '42501');
RESET ROLE;

-- ── P: cross-project ────────────────────────────────────────────────────────
-- If project A is handed to user B, A loses visibility of the investigation
-- bound to it (project clause in the policy), and B gains nothing (owner clause).
UPDATE public.projects SET user_id = :UB WHERE id = 'a1111111-0000-0000-0000-00000000000a';
SELECT pg_temp.act_as('aaaaaaaa-0000-0000-0000-00000000000a');
SET ROLE authenticated;
SELECT pg_temp.expect_eq('P01 cross-project: A no longer sees an investigation in a project it lost', (SELECT count(*) FROM public.impact_investigations), 0);
SELECT pg_temp.expect_eq('P02 cross-project: children follow', (SELECT count(*) FROM public.impact_claims), 0);
RESET ROLE;
SELECT pg_temp.act_as('bbbbbbbb-0000-0000-0000-00000000000b');
SET ROLE authenticated;
SELECT pg_temp.expect_eq('P03 new project owner does not inherit the investigation', (SELECT count(*) FROM public.impact_investigations WHERE id = :IA), 0);
RESET ROLE;
UPDATE public.projects SET user_id = :UA WHERE id = 'a1111111-0000-0000-0000-00000000000a';

-- ── R: archive lifecycle ────────────────────────────────────────────────────
SET ROLE service_role;
UPDATE public.impact_investigations SET status = 'ARCHIVED' WHERE id = :IB;
SELECT pg_temp.expect_fail('R01 archived investigations accept no new records',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, created_by)
    VALUES ('b2222222-0000-0000-0000-00000000000b', 'src-x', 'NEWS', 'Paper', '2026-09-01', 'HASH_ONLY', repeat('f', 64), 'ANALYST_ENTRY', 'bbbbbbbb-0000-0000-0000-00000000000b')$$, 'IMPACT_INVESTIGATION_NOT_ACTIVE');
SELECT pg_temp.expect_fail('R02 archive is final',
  $$UPDATE public.impact_investigations SET status = 'ACTIVE' WHERE id = 'b2222222-0000-0000-0000-00000000000b'$$, 'IMPACT_ARCHIVED_IS_FINAL');
SELECT pg_temp.expect_eq('R03 archive audited',
  (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IB AND event_type = 'INVESTIGATION_ARCHIVED'), 1);
RESET ROLE;

-- ── T: tamper detection (superuser bypasses the append-only trigger) ────────
ALTER TABLE public.impact_audit_events DISABLE TRIGGER impact_append_only;
UPDATE public.impact_audit_events SET codes = ARRAY['FORGED'] WHERE investigation_id = :IA AND seq = 3;
ALTER TABLE public.impact_audit_events ENABLE TRIGGER impact_append_only;
SELECT pg_temp.expect_eq('T01 a tampered audit event is detected', (SELECT public.impact_audit_chain_ok(:IA))::int, 0);

-- ── V: schema carries no verdict surface ────────────────────────────────────
SELECT pg_temp.expect_eq('V01 no verdict/score/trust/fraud column exists',
  (SELECT count(*) FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name LIKE 'impact\_%'
     AND column_name ~* '(verdict|score|rank|trust|fraud|scam|guilt|corrupt)'), 0);
SELECT pg_temp.expect_eq('V02 claims table has no status column (engine is the authority)',
  (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'impact_claims' AND column_name = 'status'), 0);
SELECT pg_temp.expect_eq('V03 RLS enabled and forced on all 8 impact tables',
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname LIKE 'impact\_%' AND c.relkind = 'r' AND c.relrowsecurity AND c.relforcerowsecurity), 8);
SELECT pg_temp.expect_eq('V04 authenticated holds no write privilege on any impact table',
  (SELECT count(*) FROM information_schema.table_privileges
   WHERE table_schema = 'public' AND table_name LIKE 'impact\_%' AND grantee IN ('authenticated', 'anon', 'PUBLIC')
     AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')), 0);

-- ── E: account erasure is the only deletion path, and it is complete ────────
DELETE FROM auth.users WHERE id = :UB;
SELECT pg_temp.expect_eq('E01 erasing user B removes all of B''s impact data',
  (SELECT count(*) FROM public.impact_investigations WHERE id = :IB)
  + (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IB)
  + (SELECT count(*) FROM public.impact_claims WHERE investigation_id = :IB), 0);
SELECT pg_temp.expect_eq('E02 A is untouched by B''s erasure', (SELECT count(*) FROM public.impact_claims WHERE investigation_id = :IA), 2);

SELECT 'IMPACT_LAB_RLS: PASS ' || count(*) || ' checks' FROM impact_test_log;
