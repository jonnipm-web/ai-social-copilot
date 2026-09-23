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

CREATE FUNCTION pg_temp.vres(p_inv text, p_claim text, p_rid text, p_status text, p_under text, p_suff text, p_class text,
  p_review text, p_policy text, p_eval text, p_conflicts jsonb DEFAULT '[]'::jsonb, p_supporting jsonb DEFAULT '[]'::jsonb,
  p_identity text DEFAULT 'CONFIRMED') RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('resultId', p_rid, 'investigationId', p_inv, 'claimId', p_claim, 'status', p_status,
    'underlyingStatus', p_under, 'sufficiency', p_suff, 'displayClass', p_class, 'reviewState', p_review,
    'policyVersion', p_policy, 'evidenceSetHash', repeat('d', 64), 'reviewBindingHash', repeat('e', 64),
    'evaluatedAt', p_eval, 'conflicts', p_conflicts, 'isFindingOfWrongdoing', false,
    'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true, 'supporting', p_supporting, 'partiallySupporting', '[]'::jsonb,
    'contradicting', '[]'::jsonb, 'contextual', '[]'::jsonb, 'excluded', '[]'::jsonb, 'gaps', '[]'::jsonb, 'rulesApplied', '[]'::jsonb,
    'subjectIdentity', p_identity,
    'claimKind', (SELECT kind FROM public.impact_claims WHERE investigation_id = p_inv::uuid AND ref = p_claim),
    'subjectOrganizationId', (SELECT subject_org_ref FROM public.impact_investigations WHERE id = p_inv::uuid))
$$;
CREATE FUNCTION pg_temp.item(p_ev text, p_src text, p_auth text) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('evidenceId', p_ev, 'sourceId', p_src, 'authority', p_auth, 'effectiveRelationship', 'SUPPORTS')
$$;

CREATE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(uid, ''), false);
  PERFORM set_config('request.jwt.claim.role', CASE WHEN uid IS NULL THEN 'anon' ELSE 'authenticated' END, false);
END $$;

-- I2 (20260925010000): a provider snapshot must be the canonical record the
-- server builds (consistent canonical id, provider, jurisdiction, retrieval).
CREATE FUNCTION pg_temp.snap(p_record text, p_hash_char text, p_status text DEFAULT 'REGISTERED') RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('providerId', 'fixture-xa-charity-registry', 'recordId', p_record,
    'registrationNumber', 'XA1234567', 'scheme', 'charity-number',
    'jurisdiction', jsonb_build_object('country', 'XA', 'registry', 'fixture-xa-charity-registry'),
    'canonicalOrgId', 'XA:charity-number:XA1234567', 'canonicalIds', jsonb_build_array('XA:charity-number:XA1234567'),
    'nameKey', 'hopebridge foundation', 'name', 'HopeBridge Foundation', 'status', p_status,
    'dataHash', repeat(p_hash_char, 64), 'retrievedAt', '2026-09-01T00:00:00Z')
$$;

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
   'SNAPSHOT', repeat('a', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', pg_temp.snap('xa-1234567', 'a'), :UA),
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
   pg_temp.vres(:IA, 'c1', 'vr_' || repeat('1', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED',
     'impact-verification/7', '2026-09-23T00:00:00Z', '[]'::jsonb, jsonb_build_array(pg_temp.item('e1', 'src-reg', 'AUTHORITATIVE'))), :UA),
  (:IB, 'c1', 'vr_' || repeat('2', 32), 'UNVERIFIED', 'UNVERIFIED', 'SELF_REPORTED', 'CLAIM', 'AUTOMATED', 'impact-verification/7',
   repeat('d', 64), repeat('e', 64), '2026-09-23T00:00:00Z', 0,
   pg_temp.vres(:IB, 'c1', 'vr_' || repeat('2', 32), 'UNVERIFIED', 'UNVERIFIED', 'SELF_REPORTED', 'CLAIM', 'AUTOMATED',
     'impact-verification/7', '2026-09-23T00:00:00Z'), :UB);

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
    WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a' AND ref = 'src-web'$$, 'IMPACT_IMMUTABLE_FIELD|IMPACT_ACTOR_NOT_OWNER|23503|23505');
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
  $$UPDATE public.impact_claims SET claim_text = 'rewritten' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY|42501');
SELECT pg_temp.expect_fail('S14 evidence is append-only',
  $$UPDATE public.impact_evidence SET relationship = 'CONTRADICTS' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY|42501');
SELECT pg_temp.expect_fail('S15 verification history cannot be rewritten',
  $$UPDATE public.impact_verifications SET status = 'CONTRADICTED' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY|42501');
SELECT pg_temp.expect_fail('S16 audit events cannot be rewritten',
  $$UPDATE public.impact_audit_events SET codes = '{}' WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_APPEND_ONLY|42501');
SELECT pg_temp.expect_fail('S17 direct DELETE of audit history is refused',
  $$DELETE FROM public.impact_audit_events WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE|42501');
SELECT pg_temp.expect_fail('S18 direct DELETE of verification history is refused',
  $$DELETE FROM public.impact_verifications WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE|42501');
SELECT pg_temp.expect_fail('S19 direct DELETE of an investigation (would cascade history) is refused',
  $$DELETE FROM public.impact_investigations WHERE id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE|42501');
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
  pg_temp.vres(:IA, 'c1', 'vr_' || repeat('5', 32), 'INCONCLUSIVE', 'INCONCLUSIVE', 'CONFLICTING_EVIDENCE', 'CONFLICT', 'REVIEW_REQUIRED',
    'impact-verification/7', '2026-09-24T00:00:00Z',
    jsonb_build_array(jsonb_build_object('kind', 'QUANTITY_DISAGREEMENT', 'basis', 'INDEPENDENT_SOURCES',
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
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_' || repeat('6', 32), 'INCONCLUSIVE', 'INCONCLUSIVE', 'CONFLICTING_EVIDENCE', 'CONFLICT', 'REVIEW_REQUIRED', 'p', '2026-09-24'),
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
SELECT pg_temp.expect_eq('S42 every write of A was audited (created, 2 sources + I2 registry snapshot event, 2 claims, 2 evidence, 2 runs, status, conflict, source status)',
  (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IA), 13);

-- ── G: Codex I1 Gate 1 (I1G1-01) — even service_role cannot forge ─────────
SELECT pg_temp.expect_fail('G01 service_role cannot insert an audit event directly',
  $$INSERT INTO public.impact_audit_events (investigation_id, seq, at_text, event_type, actor_ref, prev_hash, hash)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 99, '2026-09-01T00:00:00.000000Z', 'CLAIM_CREATED', 'forged', repeat('0', 64), repeat('b', 64))$$, '42501');
SELECT pg_temp.expect_fail('G02 service_role cannot call the audit appender',
  $$SELECT public.impact_append_audit('a2222222-0000-0000-0000-00000000000a', 'MANUAL_REVIEW', 'forged', '{}', '{}')$$, '42501');
SELECT pg_temp.expect_fail('G03 service_role cannot insert a conflict directly',
  $$INSERT INTO public.impact_conflicts (verification_id, investigation_id, claim_ref, kind, basis, positions)
    SELECT id, investigation_id, claim_ref, 'SUPPORT_VS_CONTRADICTION', 'INDEPENDENT_SOURCES', '[]'::jsonb FROM public.impact_verifications LIMIT 1$$, '42501');
SELECT pg_temp.expect_fail('G04 service_role cannot move the audit head',
  $$UPDATE public.impact_investigations SET audit_seq = audit_seq + 1, audit_head = repeat('b', 64) WHERE id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_TRIGGER_ONLY');
SELECT pg_temp.expect_fail('G05 PROVIDER provenance for a provider outside the server allowlist',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'p1', 'OFFICIAL_REGISTRY', 'Fake', '2026-09-01', 'SNAPSHOT', repeat('a', 64), 'PROVIDER', 'not-server-ingested', 'XA', 'not-server-ingested', '{}', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('G06 allowlisted provider with a relabelled source type',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'p1', 'AUDITED_REPORT', 'Fake', '2026-09-01', 'SNAPSHOT', repeat('a', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry', '{}', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('G07 allowlisted provider in another jurisdiction',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'p1', 'OFFICIAL_REGISTRY', 'Fake', '2026-09-01', 'SNAPSHOT', repeat('a', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XB', 'fixture-xa-charity-registry', '{}', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('G08 PROVIDER provenance without the provider snapshot',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'p1', 'OFFICIAL_REGISTRY', 'Fake', '2026-09-01', 'SNAPSHOT', repeat('a', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('G09 an analyst source cannot carry a snapshot',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, snapshot, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'p1', 'OFFICIAL_REGISTRY', 'Fake', '2026-09-01', 'SNAPSHOT', repeat('a', 64), 'ANALYST_ENTRY', '{}', 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('G10 a write attributed to another user (service-layer bug) is refused',
  $$INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c9', 'OTHER', 'x', 'org-hopebridge', 'src-web', '2026-09-02', 'MANUAL', 'bbbbbbbb-0000-0000-0000-00000000000b')$$, 'IMPACT_ACTOR_NOT_OWNER');
SELECT pg_temp.expect_fail('G11 a status update attributed to another user is refused',
  $$UPDATE public.impact_sources SET status = 'UNAVAILABLE', updated_by = 'bbbbbbbb-0000-0000-0000-00000000000b'
    WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a' AND ref = 'src-web'$$, 'IMPACT_ACTOR_NOT_OWNER');
SELECT pg_temp.expect_fail('G12 a FACT that is not SUPPORTED is refused',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('8', 32), 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('8', 32), 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'FACT', 'AUTOMATED', 'p', '2026-09-23'), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('G13 columns that disagree with the engine result JSON (HUMAN_REVIEWED forged) are refused',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('9', 32), 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'CLAIM', 'HUMAN_REVIEWED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('9', 32), 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'CLAIM', 'REVIEW_REQUIRED', 'p', '2026-09-23'), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');
SELECT pg_temp.expect_fail('G14 a result JSON belonging to another investigation is refused',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('a', 32), 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('b2222222-0000-0000-0000-00000000000b', 'c2', 'vr_' || repeat('a', 32), 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'CLAIM', 'AUTOMATED', 'p', '2026-09-23'), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, '23514');

-- ── G2: Codex I1 Gate 2 ───────────────────────────────────────────────────
SELECT pg_temp.expect_fail('G2-05 a no-op source status write is refused (every write is audited)',
  $$UPDATE public.impact_sources SET status = 'ACTIVE', updated_by = 'aaaaaaaa-0000-0000-0000-00000000000a'
    WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a' AND ref = 'src-web'$$, 'IMPACT_NOOP');
SELECT pg_temp.expect_fail('G2-06a SUPPORTED without supporting items',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('b', 32), 'SUPPORTED', 'SUPPORTED', 'MULTI_SOURCE_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('b', 32), 'SUPPORTED', 'SUPPORTED', 'MULTI_SOURCE_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', '2026-09-23'), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('G2-06b counted evidence from an analyst (non-PROVIDER) source',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('c', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('c', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', '2026-09-23', '[]'::jsonb,
        jsonb_build_array(pg_temp.item('e2', 'src-web', 'INDEPENDENT'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('G2-06c a result citing evidence of another claim',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('d', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('d', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', '2026-09-23', '[]'::jsonb,
        jsonb_build_array(pg_temp.item('e1', 'src-reg', 'AUTHORITATIVE'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('G2-06d FACT backed only by an INDEPENDENT (non-authoritative) item',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_' || repeat('e', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_' || repeat('e', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', '2026-09-23', '[]'::jsonb,
        jsonb_build_array(pg_temp.item('e1', 'src-reg', 'INDEPENDENT'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('G2-06e an unconfirmed identity cannot yield SUPPORTED',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_' || repeat('f', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_' || repeat('f', 32), 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', '2026-09-23', '[]'::jsonb,
        jsonb_build_array(pg_temp.item('e1', 'src-reg', 'AUTHORITATIVE')), 'UNCERTAIN'), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('G2-06f a result whose claimKind disagrees with the stored claim',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('0', 31) || '1', 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || repeat('0', 31) || '1', 'UNVERIFIED', 'UNVERIFIED', 'NO_EVIDENCE', 'CLAIM', 'AUTOMATED', 'p', '2026-09-23') || '{"claimKind":"LEGAL_REGISTRATION"}'::jsonb,
      'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');

-- I1G1-02: the latest version is always available, however long the history is.
DO $$
DECLARE i int;
BEGIN
  FOR i IN 1..2001 LOOP
    INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency,
      display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || lpad(to_hex(i), 32, '0'), 'UNVERIFIED', 'UNVERIFIED', 'SELF_REPORTED', 'CLAIM',
      'AUTOMATED', 'impact-verification/7', repeat('d', 64), repeat('e', 64), '2026-09-23T00:00:00Z',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c2', 'vr_' || lpad(to_hex(i), 32, '0'), 'UNVERIFIED', 'UNVERIFIED', 'SELF_REPORTED', 'CLAIM', 'AUTOMATED', 'impact-verification/7', '2026-09-23T00:00:00Z'),
      'aaaaaaaa-0000-0000-0000-00000000000a');
  END LOOP;
END $$;
SELECT pg_temp.expect_eq('G15 latest view returns version 2001 after 2001 runs',
  (SELECT version FROM public.impact_latest_verifications WHERE investigation_id = :IA AND claim_ref = 'c2'), 2001);
SELECT pg_temp.expect_eq('G16 audit chain still verifies after 2001 runs', (SELECT public.impact_audit_chain_ok(:IA))::int, 1);

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
SELECT pg_temp.expect_eq('A11 A can read its own audit trail', (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IA), 13 + 2001);
SELECT pg_temp.expect_eq('A11b A sees its latest versions through the invoker view', (SELECT count(*) FROM public.impact_latest_verifications), 2);
SELECT pg_temp.expect_eq('A11c B''s latest versions are invisible through the view', (SELECT count(*) FROM public.impact_latest_verifications WHERE investigation_id = :IB), 0);
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
SELECT pg_temp.expect_fail('R00 archiving by a non-owner actor is refused (I1G2-04)',
  $$UPDATE public.impact_investigations SET status = 'ARCHIVED', updated_by = 'aaaaaaaa-0000-0000-0000-00000000000a' WHERE id = 'b2222222-0000-0000-0000-00000000000b'$$, 'IMPACT_ACTOR_NOT_OWNER');
SELECT pg_temp.expect_fail('R00b archiving without an actor is refused',
  $$UPDATE public.impact_investigations SET status = 'ARCHIVED' WHERE id = 'b2222222-0000-0000-0000-00000000000b'$$, 'IMPACT_ACTOR_NOT_OWNER');
UPDATE public.impact_investigations SET status = 'ARCHIVED', updated_by = :UB WHERE id = :IB;
SELECT pg_temp.expect_fail('R01 archived investigations accept no new records',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, created_by)
    VALUES ('b2222222-0000-0000-0000-00000000000b', 'src-x', 'NEWS', 'Paper', '2026-09-01', 'HASH_ONLY', repeat('f', 64), 'ANALYST_ENTRY', 'bbbbbbbb-0000-0000-0000-00000000000b')$$, 'IMPACT_INVESTIGATION_NOT_ACTIVE');
SELECT pg_temp.expect_fail('R02 archive is final',
  $$UPDATE public.impact_investigations SET status = 'ACTIVE' WHERE id = 'b2222222-0000-0000-0000-00000000000b'$$, 'IMPACT_ARCHIVED_IS_FINAL');
SELECT pg_temp.expect_eq('R03 archive audited',
  (SELECT count(*) FROM public.impact_audit_events WHERE investigation_id = :IB AND event_type = 'INVESTIGATION_ARCHIVED'), 1);
RESET ROLE;

-- ── D: even the table owner / superuser cannot delete history directly ─────
SELECT pg_temp.expect_fail('D01 superuser direct DELETE of verifications is refused',
  $$DELETE FROM public.impact_verifications WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE');
SELECT pg_temp.expect_fail('D02 superuser direct DELETE of audit is refused',
  $$DELETE FROM public.impact_audit_events WHERE investigation_id = 'a2222222-0000-0000-0000-00000000000a'$$, 'IMPACT_NO_DIRECT_DELETE');
SELECT pg_temp.expect_fail('D03 superuser direct INSERT of audit is refused (trigger-only)',
  $$INSERT INTO public.impact_audit_events (investigation_id, seq, at_text, event_type, actor_ref, prev_hash, hash)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 99999, 'x', 'CLAIM_CREATED', 'x', repeat('0', 64), repeat('0', 64))$$, 'IMPACT_TRIGGER_ONLY');


-- ── F: Codex I1 Final (I1F-01) — counted items are re-derived from stored rows ──
SET ROLE service_role;
INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash,
  acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
VALUES (:IA, 'src-reg2', 'OFFICIAL_REGISTRY', 'Exampleland Charity Registry (fixture)', '2026-09-01T00:00:00Z', 'SNAPSHOT', repeat('7', 64),
  'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry', pg_temp.snap('xa-1234567', '7'), :UA);
INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, observed_to, personal_data, added_at, created_by) VALUES
  (:IA, 'e3', 'c1', 'src-reg2', 'org-hopebridge', 'CONTEXTUALIZES', 'HUMAN_ASSESSED', '2026-09-01', 'NONE', '2026-09-02T00:00:00Z', :UA),
  (:IA, 'e4', 'c1', 'src-reg2', 'org-hopebridge', 'SUPPORTS', 'LLM_SUGGESTED', '2026-09-01', 'NONE', '2026-09-02T00:00:00Z', :UA),
  (:IA, 'e5', 'c1', 'src-reg2', 'org-other', 'SUPPORTS', 'HUMAN_ASSESSED', '2026-09-01', 'NONE', '2026-09-02T00:00:00Z', :UA),
  (:IA, 'e6', 'c1', 'src-reg2', 'org-hopebridge', 'SUPPORTS', 'HUMAN_ASSESSED', '2026-09-01', 'NONE', '2026-09-02T00:00:00Z', :UA);
SELECT pg_temp.expect_fail('F01 contextual evidence relabelled as authoritative support', $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000001', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000001', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', '2026-09-23') || jsonb_build_object('supporting', jsonb_build_array(jsonb_build_object('evidenceId', 'e3', 'sourceId', 'src-reg2', 'authority', 'AUTHORITATIVE', 'effectiveRelationship', 'SUPPORTS'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('F02 an LLM-suggested link counted as support', $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000002', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000002', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', '2026-09-23') || jsonb_build_object('supporting', jsonb_build_array(jsonb_build_object('evidenceId', 'e4', 'sourceId', 'src-reg2', 'authority', 'AUTHORITATIVE', 'effectiveRelationship', 'SUPPORTS'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('F03 evidence about another organization counted', $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000003', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000003', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', '2026-09-23') || jsonb_build_object('supporting', jsonb_build_array(jsonb_build_object('evidenceId', 'e5', 'sourceId', 'src-reg2', 'authority', 'AUTHORITATIVE', 'effectiveRelationship', 'SUPPORTS'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('F04 supporting evidence recast as a contradiction', $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000004', 'CONTRADICTED', 'CONTRADICTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000004', 'CONTRADICTED', 'CONTRADICTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', '2026-09-23') || jsonb_build_object('contradicting', jsonb_build_array(jsonb_build_object('evidenceId', 'e6', 'sourceId', 'src-reg2', 'authority', 'AUTHORITATIVE', 'effectiveRelationship', 'CONTRADICTS'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('F05 evidence from a RETRACTED source counted', $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000005', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000005', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', '2026-09-23') || jsonb_build_object('supporting', jsonb_build_array(jsonb_build_object('evidenceId', 'e1', 'sourceId', 'src-reg', 'authority', 'AUTHORITATIVE', 'effectiveRelationship', 'SUPPORTS'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
SELECT pg_temp.expect_fail('F06 wrong authority for the (type, kind) cell', $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000006', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000006', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', '2026-09-23') || jsonb_build_object('supporting', jsonb_build_array(jsonb_build_object('evidenceId', 'e6', 'sourceId', 'src-reg2', 'authority', 'INDEPENDENT', 'effectiveRelationship', 'SUPPORTS'))), 'aaaaaaaa-0000-0000-0000-00000000000a')$$, 'IMPACT_RESULT_INCONSISTENT');
-- positive control: the genuine derivation is accepted (the checks are not a blanket refusal)
INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000007', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      pg_temp.vres('a2222222-0000-0000-0000-00000000000a', 'c1', 'vr_f0000000000000000000000000000007', 'SUPPORTED', 'SUPPORTED', 'INDEPENDENT_SUPPORT', 'FACT', 'AUTOMATED', 'p', '2026-09-23') || jsonb_build_object('supporting', jsonb_build_array(jsonb_build_object('evidenceId', 'e6', 'sourceId', 'src-reg2', 'authority', 'AUTHORITATIVE', 'effectiveRelationship', 'SUPPORTS'))), 'aaaaaaaa-0000-0000-0000-00000000000a');
SELECT pg_temp.expect_eq('F07 a correctly derived FACT is accepted',
  (SELECT count(*) FROM public.impact_verifications WHERE result_id = 'vr_f0000000000000000000000000000007'), 1);
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
SELECT pg_temp.expect_eq('V03 RLS enabled on EVERY impact table (8 from I1 + impact_registry_conflicts from I2)',
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname LIKE 'impact\_%' AND c.relkind = 'r' AND NOT c.relrowsecurity), 0);
SELECT pg_temp.expect_eq('V03b impact table count (a new table must be added to this suite deliberately)',
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname LIKE 'impact\_%' AND c.relkind = 'r'), 9);
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
