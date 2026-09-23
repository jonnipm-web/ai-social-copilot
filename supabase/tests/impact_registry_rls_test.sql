-- IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01 — registry intelligence invariants,
-- RLS and privileges (migration 20260925010000). Runs against a DISPOSABLE
-- database with every migration applied (never production). Every check
-- RAISEs on failure; a clean run ends with 'IMPACT_REGISTRY_RLS: PASS'.
-- Synthetic data only (XA / XB fixture registries).
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

CREATE TEMP TABLE i2_log (n serial, label text);
GRANT ALL ON i2_log TO PUBLIC;
GRANT ALL ON SEQUENCE i2_log_n_seq TO PUBLIC;

CREATE FUNCTION pg_temp.expect_fail(p_label text, p_sql text, p_pattern text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN others THEN
    IF SQLERRM ~* p_pattern OR SQLSTATE ~* p_pattern THEN
      INSERT INTO i2_log (label) VALUES (p_label);
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
  INSERT INTO i2_log (label) VALUES (p_label);
END $$;

CREATE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(uid, ''), false);
  PERFORM set_config('request.jwt.claim.role', CASE WHEN uid IS NULL THEN 'anon' ELSE 'authenticated' END, false);
END $$;

-- Canonical snapshot as the server builds it (provider.ts normalizeRegistryRecord).
CREATE FUNCTION pg_temp.snap(p_provider text, p_record text, p_country text, p_scheme text, p_number text, p_name_key text,
  p_status text, p_hash_char text, p_cross jsonb DEFAULT '[]'::jsonb, p_retrieved text DEFAULT '2026-09-01T00:00:00Z') RETURNS jsonb
LANGUAGE sql AS $$
  SELECT jsonb_build_object('providerId', p_provider, 'recordId', p_record, 'registrationNumber', p_number, 'scheme', p_scheme,
    'jurisdiction', jsonb_build_object('country', p_country, 'registry', p_provider),
    'canonicalOrgId', public.impact_canonical_org_id(p_country, p_scheme, p_number),
    'canonicalIds', jsonb_build_array(public.impact_canonical_org_id(p_country, p_scheme, p_number)) || p_cross,
    'nameKey', p_name_key, 'name', p_name_key, 'status', p_status, 'dataHash', repeat(p_hash_char, 64), 'retrievedAt', p_retrieved)
$$;

\set UC '''cccccccc-0000-0000-0000-00000000000c'''
\set UD '''dddddddd-0000-0000-0000-00000000000d'''
\set IC '''c2222222-0000-0000-0000-00000000000c'''
\set ID '''d2222222-0000-0000-0000-00000000000d'''

INSERT INTO auth.users (id, email) VALUES
  ('cccccccc-0000-0000-0000-00000000000c', 'user-c@test.invalid'),
  ('dddddddd-0000-0000-0000-00000000000d', 'user-d@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.impact_investigations (id, owner_id, subject_org_ref, subject_org_type, subject_identity) VALUES
  (:IC, :UC, 'org-northstar', 'COMMUNITY_PROJECT', '{"legalName":"Northstar Relief"}'),
  (:ID, :UD, 'org-northstar', 'COMMUNITY_PROJECT', '{"legalName":"Northstar Relief"}');

-- ── parity vector with organization_identity.ts canonicalOrgId ─────────────
SELECT pg_temp.expect_eq('I2-01 canonical id SQL == TS vector',
  public.impact_canonical_org_id('xa', ' Charity Number ', 'XA1234567'), 'XA:charity-number:XA1234567');

-- ── snapshots: consistency, minimality, idempotency (service_role) ─────────
SET ROLE service_role;
INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash,
  acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by) VALUES
  (:IC, 'src-ch', 'OFFICIAL_REGISTRY', 'Exampleland Charity Registry (fixture)', '2026-09-01T00:00:00Z', 'SNAPSHOT', repeat('1', 64),
   'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
   pg_temp.snap('fixture-xa-charity-registry', 'xa-9990001', 'XA', 'charity-number', 'XA9990001', 'northstar relief', 'REMOVED', '1',
     '["XA:company-number:XAC990001"]'), :UC);
INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash,
  acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by) VALUES
  (:IC, 'src-co', 'OFFICIAL_REGISTRY', 'Exampleland Company Registry (fixture)', '2026-09-02T00:00:00Z', 'SNAPSHOT', repeat('2', 64),
   'PROVIDER', 'fixture-xa-company-registry', 'XA', 'fixture-xa-company-registry',
   pg_temp.snap('fixture-xa-company-registry', 'xa-c-990001', 'XA', 'company-number', 'XAC990001', 'northstar relief', 'REGISTERED', '2',
     '["XA:charity-number:XA9990001"]', '2026-09-02T00:00:00Z'), :UC);
RESET ROLE;

SELECT pg_temp.expect_eq('I2-02 cross-referenced registries that disagree on status → exactly one STATUS_MISMATCH, no winner',
  (SELECT string_agg(kind || ':' || source_ref || '>' || other_source_ref || ':' || canonical_org_id || ':' || resolution, ' ')
   FROM public.impact_registry_conflicts WHERE investigation_id = :IC),
  'STATUS_MISMATCH:src-co>src-ch:XA:charity-number:XA9990001:UNRESOLVED');
SELECT pg_temp.expect_eq('I2-03 a registry conflict is never a finding of wrongdoing',
  (SELECT count(*)::text FROM public.impact_registry_conflicts WHERE is_finding_of_wrongdoing), '0');
SELECT pg_temp.expect_eq('I2-04 snapshot + conflict are audited (hash-chained)',
  (SELECT string_agg(event_type || '[' || array_to_string(codes, ',') || ']', ' ' ORDER BY seq) FROM public.impact_audit_events
   WHERE investigation_id = :IC AND event_type LIKE 'REGISTRY_%'),
  'REGISTRY_SNAPSHOT_RECORDED[XA:charity-number:XA9990001,REMOVED,NEW] REGISTRY_SNAPSHOT_RECORDED[XA:company-number:XAC990001,REGISTERED,NEW] REGISTRY_CONFLICT_RECORDED[STATUS_MISMATCH,XA:charity-number:XA9990001]');
SELECT pg_temp.expect_eq('I2-05 audit chain intact', public.impact_audit_chain_ok(:IC)::text, 'true');

SET ROLE service_role;
SELECT pg_temp.expect_fail('I2-06 identical registry data twice (retry) is ONE row',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-ch-dup', 'OFFICIAL_REGISTRY', 'X', '2026-09-01T00:00:00Z', 'SNAPSHOT', repeat('1', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
      pg_temp.snap('fixture-xa-charity-registry', 'xa-9990001', 'XA', 'charity-number', 'XA9990001', 'northstar relief', 'REMOVED', '1', '["XA:company-number:XAC990001"]'), 'cccccccc-0000-0000-0000-00000000000c')$$, '23505');
SELECT pg_temp.expect_fail('I2-07 forged canonical id (not derived from country/scheme/number)',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-f1', 'OFFICIAL_REGISTRY', 'X', '2026-09-01T00:00:00Z', 'SNAPSHOT', repeat('3', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
      pg_temp.snap('fixture-xa-charity-registry', 'xa-1', 'XA', 'charity-number', 'XA1', 'n', 'REGISTERED', '3') || '{"canonicalOrgId":"XA:charity-number:XA9990001"}', 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
SELECT pg_temp.expect_fail('I2-08 a snapshot carrying people (trustees) is refused — PII minimization',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-f2', 'OFFICIAL_REGISTRY', 'X', '2026-09-01T00:00:00Z', 'SNAPSHOT', repeat('4', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
      pg_temp.snap('fixture-xa-charity-registry', 'xa-2', 'XA', 'charity-number', 'XA2', 'n', 'REGISTERED', '4') || '{"trustees":[{"name":"Synthetic Person"}]}', 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
SELECT pg_temp.expect_fail('I2-09 snapshot of ANOTHER provider under an allowlisted provider id',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-f3', 'OFFICIAL_REGISTRY', 'X', '2026-09-01T00:00:00Z', 'SNAPSHOT', repeat('5', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
      pg_temp.snap('fixture-xa-company-registry', 'xa-3', 'XA', 'company-number', 'XA3', 'n', 'REGISTERED', '5'), 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
SELECT pg_temp.expect_fail('I2-10 cross-jurisdiction: an XB record under the XA provider',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-f4', 'OFFICIAL_REGISTRY', 'X', '2026-09-01T00:00:00Z', 'SNAPSHOT', repeat('6', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
      pg_temp.snap('fixture-xa-charity-registry', 'xb-4', 'XB', 'charity-number', 'XB4', 'n', 'REGISTERED', '6'), 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
SELECT pg_temp.expect_fail('I2-11 snapshot retrieval time that differs from the row (stale presented as fresh)',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-f5', 'OFFICIAL_REGISTRY', 'X', '2026-09-05T00:00:00Z', 'SNAPSHOT', repeat('7', 64), 'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
      pg_temp.snap('fixture-xa-charity-registry', 'xa-5', 'XA', 'charity-number', 'XA5', 'n', 'REGISTERED', '7'), 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
SELECT pg_temp.expect_fail('I2-12 lineage: unknown syndication marker',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, content_fingerprint, similarity_sketch, syndication_markers, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'n1', 'NEWS', 'Paper', '2026-09-01T00:00:00Z', 'HASH_ONLY', repeat('8', 64), 'ANALYST_ENTRY', repeat('a', 64), repeat('b', 256), ARRAY['INDEPENDENT'], 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
SELECT pg_temp.expect_fail('I2-13 lineage: fingerprint without its sketch',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, content_fingerprint, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'n2', 'NEWS', 'Paper', '2026-09-01T00:00:00Z', 'HASH_ONLY', repeat('8', 64), 'ANALYST_ENTRY', repeat('a', 64), 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
SELECT pg_temp.expect_fail('I2-14 lineage: markers without a fingerprinted text',
  $$INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method, syndication_markers, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'n3', 'NEWS', 'Paper', '2026-09-01T00:00:00Z', 'HASH_ONLY', repeat('8', 64), 'ANALYST_ENTRY', ARRAY['WIRE_AP'], 'cccccccc-0000-0000-0000-00000000000c')$$, '23514');
INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash, acquisition_method,
  content_fingerprint, similarity_sketch, syndication_markers, derived_from, created_by)
VALUES (:IC, 'n-ok', 'NEWS', 'Paper', '2026-09-01T00:00:00Z', 'HASH_ONLY', repeat('8', 64), 'ANALYST_ENTRY',
  repeat('a', 64), repeat('b', 256), ARRAY['WIRE_REUTERS'], 'Wire', :UC);
SELECT pg_temp.expect_fail('I2-15 lineage signals are immutable after insert',
  $$UPDATE public.impact_sources SET content_fingerprint = repeat('c', 64), updated_by = 'cccccccc-0000-0000-0000-00000000000c' WHERE investigation_id = 'c2222222-0000-0000-0000-00000000000c' AND ref = 'n-ok'$$, 'IMPACT_IMMUTABLE_FIELD|42501');
SELECT pg_temp.expect_fail('I2-16 the canonical id column cannot be written',
  $$UPDATE public.impact_sources SET canonical_org_id = 'XA:x:1' WHERE investigation_id = 'c2222222-0000-0000-0000-00000000000c' AND ref = 'src-ch'$$, '428C9|generated|42501');
SELECT pg_temp.expect_fail('I2-17 service_role cannot INSERT a registry conflict',
  $$INSERT INTO public.impact_registry_conflicts (investigation_id, source_ref, other_source_ref, kind, canonical_org_id) VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-ch', 'src-co', 'NAME_MISMATCH', 'x')$$, '42501');
SELECT pg_temp.expect_fail('I2-18 service_role cannot UPDATE a registry conflict',
  $$UPDATE public.impact_registry_conflicts SET resolution = 'UNRESOLVED'$$, '42501');
SELECT pg_temp.expect_fail('I2-19 service_role cannot DELETE a registry conflict',
  $$DELETE FROM public.impact_registry_conflicts$$, '42501');

-- status change on a snapshot source still works (generated column vs guard)
UPDATE public.impact_sources SET status = 'RETRACTED', updated_by = :UC, updated_at = now() WHERE investigation_id = :IC AND ref = 'src-co';
RESET ROLE;
SELECT pg_temp.expect_eq('I2-20 a snapshot source status can still change (only status)',
  (SELECT status FROM public.impact_sources WHERE investigation_id = :IC AND ref = 'src-co'), 'RETRACTED');

-- A newer snapshot of the SAME record is an update (history kept), never a conflict with itself.
SET ROLE service_role;
INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash,
  acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by) VALUES
  (:IC, 'src-ch-v2', 'OFFICIAL_REGISTRY', 'Exampleland Charity Registry (fixture)', '2026-09-03T00:00:00Z', 'SNAPSHOT', repeat('9', 64),
   'PROVIDER', 'fixture-xa-charity-registry', 'XA', 'fixture-xa-charity-registry',
   pg_temp.snap('fixture-xa-charity-registry', 'xa-9990001', 'XA', 'charity-number', 'XA9990001', 'northstar relief', 'REGISTERED', '9',
     '["XA:company-number:XAC990001"]', '2026-09-03T00:00:00Z'), :UC);
RESET ROLE;
SELECT pg_temp.expect_eq('I2-21 changed registry data = new version (UPDATE), old snapshot kept, no self-conflict; RETRACTED company snapshot ignored',
  (SELECT (SELECT count(*) FROM public.impact_sources WHERE investigation_id = :IC AND snapshot->>'recordId' = 'xa-9990001')::text
     || ':' || (SELECT count(*) FROM public.impact_registry_conflicts WHERE investigation_id = :IC)::text
     || ':' || (SELECT codes[3] FROM public.impact_audit_events WHERE investigation_id = :IC AND event_type = 'REGISTRY_SNAPSHOT_RECORDED' ORDER BY seq DESC LIMIT 1)),
  '2:1:UPDATE');

-- Superuser (table owner) is still stopped by the trigger-only / append-only guards.
SELECT pg_temp.expect_fail('I2-22 even the table owner cannot INSERT a registry conflict directly',
  $$INSERT INTO public.impact_registry_conflicts (investigation_id, source_ref, other_source_ref, kind, canonical_org_id) VALUES ('c2222222-0000-0000-0000-00000000000c', 'src-ch', 'src-co', 'NAME_MISMATCH', 'x')$$, 'IMPACT_TRIGGER_ONLY');
SELECT pg_temp.expect_fail('I2-23 even the table owner cannot rewrite a registry conflict',
  $$UPDATE public.impact_registry_conflicts SET kind = 'NAME_MISMATCH'$$, 'IMPACT_APPEND_ONLY');
SELECT pg_temp.expect_fail('I2-24 even the table owner cannot delete a registry conflict directly',
  $$DELETE FROM public.impact_registry_conflicts$$, 'IMPACT_NO_DIRECT_DELETE');

-- ── REGISTRY_RECORD evidence ───────────────────────────────────────────────
SET ROLE service_role;
INSERT INTO public.impact_claims (investigation_id, ref, kind, claim_text, subject_org_ref, source_ref, extracted_at, origin, period_from, period_to, created_by) VALUES
  (:IC, 'c-stmt', 'LEGAL_REGISTRATION', 'Registry lists charity-number XA9990001 with status REMOVED as of 2025-01-15.', 'org-northstar', 'src-ch', '2026-09-02T00:00:00Z', 'STRUCTURED_IMPORT', '2025-01-15', '2025-01-15', :UC),
  (:IC, 'c-man', 'LEGAL_REGISTRATION', 'Northstar is registered.', 'org-northstar', 'src-ch', '2026-09-02T00:00:00Z', 'MANUAL', NULL, NULL, :UC),
  (:IC, 'c-news', 'LEGAL_REGISTRATION', 'Northstar is registered.', 'org-northstar', 'n-ok', '2026-09-02T00:00:00Z', 'STRUCTURED_IMPORT', NULL, NULL, :UC);
SELECT pg_temp.expect_fail('I2-25 REGISTRY_RECORD evidence from a non-provider source',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'e-x1', 'c-news', 'n-ok', 'org-northstar', 'SUPPORTS', 'REGISTRY_RECORD', 'NONE', '2026-09-02T00:00:00Z', 'cccccccc-0000-0000-0000-00000000000c')$$, 'IMPACT_REGISTRY_RECORD_INVALID');
SELECT pg_temp.expect_fail('I2-26 REGISTRY_RECORD evidence cannot CONTRADICT',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'e-x2', 'c-stmt', 'src-ch', 'org-northstar', 'CONTRADICTS', 'REGISTRY_RECORD', 'NONE', '2026-09-02T00:00:00Z', 'cccccccc-0000-0000-0000-00000000000c')$$, 'IMPACT_REGISTRY_RECORD_INVALID');
SELECT pg_temp.expect_fail('I2-27 REGISTRY_RECORD evidence for a manually written claim',
  $$INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, personal_data, added_at, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'e-x3', 'c-man', 'src-ch', 'org-northstar', 'SUPPORTS', 'REGISTRY_RECORD', 'NONE', '2026-09-02T00:00:00Z', 'cccccccc-0000-0000-0000-00000000000c')$$, 'IMPACT_REGISTRY_RECORD_INVALID');
INSERT INTO public.impact_evidence (investigation_id, ref, claim_ref, source_ref, about_org_ref, relationship, relationship_basis, observed_from, observed_to, personal_data, added_at, created_by)
VALUES (:IC, 'c-stmt.rec', 'c-stmt', 'src-ch', 'org-northstar', 'SUPPORTS', 'REGISTRY_RECORD', '2025-01-15', '2025-01-15', 'NONE', '2026-09-02T00:00:00Z', :UC);
SELECT pg_temp.expect_fail('I2-28 a stored result cannot count a REGISTRY_RECORD item as a contradiction',
  $$INSERT INTO public.impact_verifications (investigation_id, claim_ref, result_id, status, underlying_status, sufficiency, display_class, review_state, policy_version, evidence_set_hash, review_binding_hash, evaluated_at, result, created_by)
    VALUES ('c2222222-0000-0000-0000-00000000000c', 'c-stmt', 'vr_' || repeat('c', 32), 'CONTRADICTED', 'CONTRADICTED', 'INDEPENDENT_SUPPORT', 'CLAIM', 'AUTOMATED', 'p', repeat('d', 64), repeat('e', 64), '2026-09-23',
      jsonb_build_object('resultId', 'vr_' || repeat('c', 32), 'investigationId', 'c2222222-0000-0000-0000-00000000000c', 'claimId', 'c-stmt', 'status', 'CONTRADICTED',
        'underlyingStatus', 'CONTRADICTED', 'sufficiency', 'INDEPENDENT_SUPPORT', 'displayClass', 'CLAIM', 'reviewState', 'AUTOMATED', 'policyVersion', 'p',
        'evidenceSetHash', repeat('d', 64), 'reviewBindingHash', repeat('e', 64), 'evaluatedAt', '2026-09-23', 'conflicts', '[]'::jsonb,
        'isFindingOfWrongdoing', false, 'absenceOfEvidenceIsNotEvidenceOfWrongdoing', true, 'supporting', '[]'::jsonb, 'partiallySupporting', '[]'::jsonb,
        'contradicting', jsonb_build_array(jsonb_build_object('evidenceId', 'c-stmt.rec', 'sourceId', 'src-ch', 'authority', 'AUTHORITATIVE', 'effectiveRelationship', 'CONTRADICTS')),
        'contextual', '[]'::jsonb, 'excluded', '[]'::jsonb, 'gaps', '[]'::jsonb, 'rulesApplied', '[]'::jsonb, 'subjectIdentity', 'CONFIRMED',
        'claimKind', 'LEGAL_REGISTRATION', 'subjectOrganizationId', 'org-northstar'), 'cccccccc-0000-0000-0000-00000000000c')$$, 'IMPACT_RESULT_INCONSISTENT');

-- Cross-investigation: the same organization in D's investigation never conflicts with C's snapshots.
INSERT INTO public.impact_sources (investigation_id, ref, source_type, publisher, retrieved_at, retention, content_hash,
  acquisition_method, acquisition_provider_id, jurisdiction_country, jurisdiction_registry, snapshot, created_by) VALUES
  (:ID, 'src-co', 'OFFICIAL_REGISTRY', 'Exampleland Company Registry (fixture)', '2026-09-02T00:00:00Z', 'SNAPSHOT', repeat('2', 64),
   'PROVIDER', 'fixture-xa-company-registry', 'XA', 'fixture-xa-company-registry',
   pg_temp.snap('fixture-xa-company-registry', 'xa-c-990001', 'XA', 'company-number', 'XAC990001', 'northstar relief', 'REGISTERED', '2',
     '["XA:charity-number:XA9990001"]', '2026-09-02T00:00:00Z'), :UD);
RESET ROLE;
SELECT pg_temp.expect_eq('I2-29 conflict detection never crosses investigations',
  (SELECT count(*)::text FROM public.impact_registry_conflicts WHERE investigation_id = :ID), '0');

-- ── RLS / privileges for clients ───────────────────────────────────────────
SET ROLE authenticated;
SELECT pg_temp.act_as('cccccccc-0000-0000-0000-00000000000c');
SELECT pg_temp.expect_eq('I2-30 owner reads its registry conflicts', (SELECT count(*)::text FROM public.impact_registry_conflicts), '1');
SELECT pg_temp.expect_eq('I2-31 cross-user: C cannot see D''s snapshots', (SELECT count(*)::text FROM public.impact_sources WHERE investigation_id = 'd2222222-0000-0000-0000-00000000000d'), '0');
SELECT pg_temp.act_as('dddddddd-0000-0000-0000-00000000000d');
SELECT pg_temp.expect_eq('I2-32 cross-user: D cannot see C''s registry conflicts', (SELECT count(*)::text FROM public.impact_registry_conflicts), '0');
SELECT pg_temp.expect_fail('I2-33 authenticated cannot write a registry conflict',
  $$INSERT INTO public.impact_registry_conflicts (investigation_id, source_ref, other_source_ref, kind, canonical_org_id) VALUES ('d2222222-0000-0000-0000-00000000000d', 'src-co', 'src-co', 'NAME_MISMATCH', 'x')$$, '42501');
SELECT pg_temp.expect_fail('I2-34 authenticated cannot forge lineage on a source',
  $$UPDATE public.impact_sources SET derived_from = NULL WHERE investigation_id = 'd2222222-0000-0000-0000-00000000000d'$$, '42501');
RESET ROLE;
SET ROLE anon;
SELECT pg_temp.act_as(NULL);
SELECT pg_temp.expect_fail('I2-35 anon cannot read registry conflicts', $$SELECT count(*) FROM public.impact_registry_conflicts$$, '42501');
RESET ROLE;

SELECT pg_temp.expect_eq('I2-36 no verdict/score/trust/fraud column in I2 tables',
  (SELECT count(*)::text FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name IN ('impact_registry_conflicts', 'impact_sources')
     AND column_name ~* '(verdict|score|rank|trust|fraud|scam|guilt|corrupt|independent)'), '0');
SELECT pg_temp.expect_eq('I2-37 RLS on impact_registry_conflicts', (SELECT relrowsecurity::text FROM pg_class WHERE relname = 'impact_registry_conflicts'), 'true');
SELECT pg_temp.expect_eq('I2-38 audit chains intact after all I2 writes',
  (public.impact_audit_chain_ok(:IC) AND public.impact_audit_chain_ok(:ID))::text, 'true');

SELECT 'IMPACT_REGISTRY_RLS: PASS ' || count(*) || ' checks' FROM i2_log;
