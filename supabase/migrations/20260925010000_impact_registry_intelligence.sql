-- IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01 — Registry Intelligence for the Impact Lab.
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
-- Minimal extension of 20260924010000 (docs/impact/IMPACT_REGISTRY_INTELLIGENCE.md):
--   * provider allowlist: three SYNTHETIC registries (XA charity, XA company,
--     XB charity) — must equal provider_registry.ts (drift-tested);
--   * impact_sources: server-derived lineage signals (derived_from, content
--     fingerprint, MinHash sketch, syndication markers) and a canonical
--     organization id generated from the provider snapshot, which must be
--     internally consistent (country:scheme:NUMBER) and carry no people data;
--     one row per (investigation, provider, record, data hash) → idempotent
--     re-ingestion, a changed registry record is a NEW row (history kept);
--   * evidence basis REGISTRY_RECORD: only the provider record supporting the
--     registry statement generated from that same record;
--   * impact_registry_conflicts: written ONLY by the audit trigger when two
--     ACTIVE snapshots of the same organization (shared canonical id,
--     different provider record) disagree on name or status. No winner is
--     chosen and a conflict is never a finding (constant
--     is_finding_of_wrongdoing = false);
--   * two audit event types: REGISTRY_SNAPSHOT_RECORDED, REGISTRY_CONFLICT_RECORDED.
--
-- SERVICE_ROLE_TRUST_GATE = LAB_ONLY (Owner + Agente Martins): service_role
-- stays privileged infrastructure root; RLS does not restrict it; the
-- invariants below hold for it anyway. Options A/B must be re-evaluated
-- before any Alpha, non-admin user, public deploy, real sensitive data,
-- automated publication or consequential external integration
-- (docs/impact/IMPACT_RLS_MODEL.md §6).
--
-- Rollback (Lab): DROP TABLE public.impact_registry_conflicts; restore the
-- I1 definitions of impact_trusted_provider, impact_evidence_validate,
-- impact_verifications_validate, impact_audit_writes and the audit type /
-- evidence basis checks; ALTER TABLE public.impact_sources DROP the I2
-- columns/constraints/index. Nothing outside impact_* depends on them.
--
-- Idempotent: safe to re-run.

-- ── provider allowlist (supersedes 20260924010000) ─────────────────────────
-- MUST equal trustedProviderRefs() in
-- supabase/functions/_shared/impact/provider_registry.ts (drift-tested; the
-- latest migration's block is the effective definition).
-- BEGIN_IMPACT_PROVIDER_ALLOWLIST
CREATE OR REPLACE FUNCTION public.impact_trusted_provider(p_id text, p_type text, p_country text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT (p_id, p_type, p_country) IN (
    ('fixture-xa-charity-registry', 'OFFICIAL_REGISTRY', 'XA'),
    ('fixture-xa-company-registry', 'OFFICIAL_REGISTRY', 'XA'),
    ('fixture-xb-charity-registry', 'OFFICIAL_REGISTRY', 'XB')
  )
$$;
-- END_IMPACT_PROVIDER_ALLOWLIST

-- Canonical organization id: COUNTRY:scheme:NUMBER (organization_identity.ts
-- canonicalOrgId; the number arrives already normalized by the server).
CREATE OR REPLACE FUNCTION public.impact_canonical_org_id(p_country text, p_scheme text, p_number text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT upper(btrim(p_country)) || ':' || regexp_replace(lower(btrim(p_scheme)), '[^a-z0-9-]+', '-', 'g') || ':' || p_number
$$;

-- Registry status → comparable class (organization_identity.ts registryStatusClass).
CREATE OR REPLACE FUNCTION public.impact_registry_status_class(p_status text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT CASE p_status WHEN 'REGISTERED' THEN 'ACTIVE' WHEN 'REMOVED' THEN 'INACTIVE' WHEN 'DISSOLVED' THEN 'INACTIVE'
                       WHEN 'SUSPENDED' THEN 'SUSPENDED' ELSE 'UNKNOWN' END
$$;

-- ── sources: lineage signals + canonical identity ──────────────────────────

ALTER TABLE public.impact_sources ADD COLUMN IF NOT EXISTS derived_from text NULL;
ALTER TABLE public.impact_sources ADD COLUMN IF NOT EXISTS content_fingerprint text NULL;
ALTER TABLE public.impact_sources ADD COLUMN IF NOT EXISTS similarity_sketch text NULL;
ALTER TABLE public.impact_sources ADD COLUMN IF NOT EXISTS syndication_markers text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.impact_sources ADD COLUMN IF NOT EXISTS canonical_org_id text
  GENERATED ALWAYS AS (snapshot->>'canonicalOrgId') STORED;

ALTER TABLE public.impact_sources DROP CONSTRAINT IF EXISTS impact_sources_lineage_check;
ALTER TABLE public.impact_sources ADD CONSTRAINT impact_sources_lineage_check CHECK (
  (derived_from IS NULL OR length(btrim(derived_from)) BETWEEN 1 AND 300)
  AND (content_fingerprint IS NULL OR content_fingerprint ~ '^[0-9a-f]{64}$')
  AND (similarity_sketch IS NULL OR (length(similarity_sketch) = 256 AND similarity_sketch ~ '^[0-9a-f]+$')) -- PG regex repetition max is 255
  -- fingerprint, sketch and markers are derived together from one submitted text
  AND ((content_fingerprint IS NULL) = (similarity_sketch IS NULL))
  AND (content_fingerprint IS NOT NULL OR cardinality(syndication_markers) = 0)
  -- BEGIN_IMPACT_SYNDICATION_MARKERS
  AND syndication_markers <@ ARRAY['ORIGINALLY_PUBLISHED','REPUBLISHED_FROM','VIA_CREDIT','WIRE_AFP','WIRE_AP','WIRE_REUTERS']::text[]
  -- END_IMPACT_SYNDICATION_MARKERS
);

-- A provider snapshot must be internally consistent and minimal: its canonical
-- id is derived from its own country/scheme/number, it belongs to the row's
-- provider and jurisdiction, and it never carries people (officers,
-- trustees, directors, beneficiaries) — PII minimization at the database.
ALTER TABLE public.impact_sources DROP CONSTRAINT IF EXISTS impact_sources_snapshot_identity_check;
ALTER TABLE public.impact_sources ADD CONSTRAINT impact_sources_snapshot_identity_check CHECK (
  snapshot IS NULL OR (
    snapshot->>'registrationNumber' ~ '^[A-Z0-9_:]{1,60}$'
    AND snapshot->>'canonicalOrgId' = public.impact_canonical_org_id(snapshot->'jurisdiction'->>'country', snapshot->>'scheme', snapshot->>'registrationNumber')
    AND snapshot->>'canonicalOrgId' ~ '^[A-Za-z0-9_.:-]{1,128}$'
    AND jsonb_typeof(snapshot->'canonicalIds') = 'array'
    AND snapshot->'canonicalIds'->>0 = snapshot->>'canonicalOrgId'
    AND snapshot->>'providerId' = acquisition_provider_id
    AND snapshot->'jurisdiction'->>'country' = jurisdiction_country
    AND snapshot->>'retrievedAt' = retrieved_at
    AND snapshot->>'dataHash' ~ '^[0-9a-f]{64}$'
    AND public.impact_is_ref(snapshot->>'recordId')
    AND length(coalesce(snapshot->>'nameKey', '')) BETWEEN 1 AND 300
    AND snapshot->>'status' IN ('REGISTERED','REMOVED','DISSOLVED','SUSPENDED','UNKNOWN')
    AND NOT (snapshot ?| ARRAY['trustees','officers','directors','persons','people','beneficiaries','contacts','email','phone'])
  )
);

-- Sources guard (20260924010000) — unchanged semantics: only status may change.
-- canonical_org_id is a GENERATED column, which PostgreSQL leaves NULL in NEW
-- inside BEFORE triggers; it is excluded from the comparison because it is a
-- pure function of `snapshot`, which IS compared.
CREATE OR REPLACE FUNCTION public.impact_sources_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_retrieved timestamptz;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_retrieved := public.impact_ts(NEW.retrieved_at);
    IF v_retrieved > now() + interval '5 minutes' THEN
      RAISE EXCEPTION 'IMPACT_TEMPORAL: retrieved_at in the future' USING ERRCODE = '22007';
    END IF;
    IF NEW.published_at IS NOT NULL AND public.impact_ts(NEW.published_at) > v_retrieved THEN
      RAISE EXCEPTION 'IMPACT_TEMPORAL: published after retrieval' USING ERRCODE = '22007';
    END IF;
    RETURN NEW;
  END IF;
  IF (to_jsonb(NEW) - ARRAY['status','updated_by','updated_at','canonical_org_id'])
     <> (to_jsonb(OLD) - ARRAY['status','updated_by','updated_at','canonical_org_id']) THEN
    RAISE EXCEPTION 'IMPACT_IMMUTABLE_FIELD: only source status can change' USING ERRCODE = '42501';
  END IF;
  IF NEW.updated_by IS NULL THEN RAISE EXCEPTION 'IMPACT_ACTOR_REQUIRED' USING ERRCODE = '23502'; END IF;
  IF NEW.status = OLD.status THEN RAISE EXCEPTION 'IMPACT_NOOP: status unchanged' USING ERRCODE = '22023'; END IF;
  RETURN NEW;
END $$;

-- Idempotent re-ingestion: identical registry data is ONE row; changed data is a new row.
CREATE UNIQUE INDEX IF NOT EXISTS impact_sources_snapshot_key ON public.impact_sources
  (investigation_id, acquisition_provider_id, (snapshot->>'recordId'), (snapshot->>'dataHash'))
  WHERE snapshot IS NOT NULL;
CREATE INDEX IF NOT EXISTS impact_sources_canonical_idx ON public.impact_sources (investigation_id, canonical_org_id)
  WHERE canonical_org_id IS NOT NULL;

-- ── evidence: REGISTRY_RECORD basis ────────────────────────────────────────

ALTER TABLE public.impact_evidence DROP CONSTRAINT IF EXISTS impact_evidence_basis_check;
ALTER TABLE public.impact_evidence ADD CONSTRAINT impact_evidence_basis_check
  CHECK (relationship_basis IN ('STRUCTURED_MATCH','HUMAN_ASSESSED','LLM_SUGGESTED','REGISTRY_RECORD'));

CREATE OR REPLACE FUNCTION public.impact_evidence_validate() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_retrieved timestamptz;
  v_src public.impact_sources%ROWTYPE;
  v_claim public.impact_claims%ROWTYPE;
BEGIN
  SELECT * INTO v_src FROM public.impact_sources s WHERE s.investigation_id = NEW.investigation_id AND s.ref = NEW.source_ref;
  v_retrieved := public.impact_ts(v_src.retrieved_at);
  PERFORM public.impact_ts(NEW.added_at);
  IF NEW.observed_from IS NOT NULL AND NEW.observed_to IS NOT NULL
     AND public.impact_ts(NEW.observed_from) > public.impact_ts(NEW.observed_to) THEN
    RAISE EXCEPTION 'IMPACT_TEMPORAL: reversed observed period' USING ERRCODE = '22007';
  END IF;
  IF (NEW.observed_from IS NOT NULL AND public.impact_ts(NEW.observed_from) > v_retrieved)
     OR (NEW.observed_to IS NOT NULL AND public.impact_ts(NEW.observed_to) > v_retrieved) THEN
    RAISE EXCEPTION 'IMPACT_TEMPORAL: observed period extends past retrieval' USING ERRCODE = '22007';
  END IF;
  -- I2: registry-record evidence is only the provider record supporting the
  -- registry statement generated from that same record.
  IF NEW.relationship_basis = 'REGISTRY_RECORD' THEN
    SELECT * INTO v_claim FROM public.impact_claims c WHERE c.investigation_id = NEW.investigation_id AND c.ref = NEW.claim_ref;
    IF v_src.acquisition_method IS DISTINCT FROM 'PROVIDER' OR v_src.snapshot IS NULL
       OR NEW.relationship <> 'SUPPORTS' OR NEW.personal_data <> 'NONE'
       OR v_claim.source_ref IS DISTINCT FROM NEW.source_ref OR v_claim.origin IS DISTINCT FROM 'STRUCTURED_IMPORT'
       OR v_claim.kind IS DISTINCT FROM 'LEGAL_REGISTRATION' THEN
      RAISE EXCEPTION 'IMPACT_REGISTRY_RECORD_INVALID: not the provider record of its own registry statement' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- ── verification validation: REGISTRY_RECORD items ─────────────────────────
-- Identical to 20260924010000 plus one rule: a counted REGISTRY_RECORD item
-- can only be SUPPORTS.
CREATE OR REPLACE FUNCTION public.impact_verifications_validate() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  r jsonb := NEW.result;
  v_kind text;
  v_subject text;
  v_n_sup int := jsonb_array_length(coalesce(r->'supporting', '[]'::jsonb));
  v_n_par int := jsonb_array_length(coalesce(r->'partiallySupporting', '[]'::jsonb));
  v_n_con int := jsonb_array_length(coalesce(r->'contradicting', '[]'::jsonb));
BEGIN
  SELECT c.kind INTO v_kind FROM public.impact_claims c WHERE c.investigation_id = NEW.investigation_id AND c.ref = NEW.claim_ref;
  SELECT i.subject_org_ref INTO v_subject FROM public.impact_investigations i WHERE i.id = NEW.investigation_id;
  IF r->>'claimKind' IS DISTINCT FROM v_kind OR r->>'subjectOrganizationId' IS DISTINCT FROM v_subject
     OR coalesce(r->'gaps', '[]'::jsonb) <> to_jsonb(NEW.gaps) OR coalesce(r->'rulesApplied', '[]'::jsonb) <> to_jsonb(NEW.rules_applied) THEN
    RAISE EXCEPTION 'IMPACT_RESULT_INCONSISTENT: kind/subject/gaps/rules' USING ERRCODE = '23514';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(
      coalesce(r->'supporting', '[]') || coalesce(r->'partiallySupporting', '[]') || coalesce(r->'contradicting', '[]')
      || coalesce(r->'contextual', '[]') || coalesce(r->'excluded', '[]')) AS it(x)
    WHERE NOT EXISTS (SELECT 1 FROM public.impact_evidence e WHERE e.investigation_id = NEW.investigation_id
                        AND e.ref = x->>'evidenceId' AND e.claim_ref = NEW.claim_ref)) THEN
    RAISE EXCEPTION 'IMPACT_RESULT_INCONSISTENT: cites evidence that is not of this claim' USING ERRCODE = '23514';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM (SELECT x, 'SUPPORTS' AS tag FROM jsonb_array_elements(coalesce(r->'supporting', '[]')) AS a(x)
          UNION ALL SELECT x, 'PARTIALLY_SUPPORTS' FROM jsonb_array_elements(coalesce(r->'partiallySupporting', '[]')) AS b(x)
          UNION ALL SELECT x, 'CONTRADICTS' FROM jsonb_array_elements(coalesce(r->'contradicting', '[]')) AS c(x)) AS it
    LEFT JOIN public.impact_evidence e ON e.investigation_id = NEW.investigation_id AND e.ref = it.x->>'evidenceId' AND e.claim_ref = NEW.claim_ref
    LEFT JOIN public.impact_sources s ON s.investigation_id = e.investigation_id AND s.ref = e.source_ref
    LEFT JOIN public.impact_claims cl ON cl.investigation_id = NEW.investigation_id AND cl.ref = NEW.claim_ref
    WHERE e.ref IS NULL OR s.ref IS NULL
       OR it.x->>'sourceId' IS DISTINCT FROM s.ref
       OR it.x->>'effectiveRelationship' IS DISTINCT FROM it.tag
       OR s.acquisition_method <> 'PROVIDER' OR s.status <> 'ACTIVE' OR s.user_submitted
       OR s.publisher_org_ref IS NOT DISTINCT FROM v_subject
       OR e.relationship_basis = 'LLM_SUGGESTED' OR e.about_org_ref IS DISTINCT FROM v_subject
       OR it.x->>'authority' IS DISTINCT FROM public.impact_independent_authority(s.source_type, cl.kind, s.news_genre)
       OR (it.tag = 'CONTRADICTS' AND e.legal_stage IN ('INVESTIGATION_OPENED', 'CHARGED', 'UNDER_APPEAL'))
       OR (e.relationship_basis = 'HUMAN_ASSESSED' AND it.tag IS DISTINCT FROM
             CASE e.relationship WHEN 'SUPPORTS' THEN 'SUPPORTS' WHEN 'CONTRADICTS' THEN 'CONTRADICTS' END)
       OR (e.relationship_basis = 'REGISTRY_RECORD' AND it.tag IS DISTINCT FROM 'SUPPORTS')
       -- I2 entity-spoofing guard: a registry snapshot counts only for the
       -- organization it identifies — one of its canonical ids must be a
       -- registration declared for the investigation subject.
       OR (s.snapshot IS NOT NULL AND NOT EXISTS (
             SELECT 1 FROM public.impact_investigations inv,
                  jsonb_array_elements(coalesce(inv.subject_identity->'registrations', '[]'::jsonb)) AS reg(r)
             WHERE inv.id = NEW.investigation_id
               AND (s.snapshot->'canonicalIds') ? public.impact_canonical_org_id(
                     reg.r->'jurisdiction'->>'country', reg.r->>'scheme',
                     upper(regexp_replace(normalize(reg.r->>'value', NFKC), '[[:space:]./-]', '', 'g')))))
       OR (e.relationship_basis = 'STRUCTURED_MATCH' AND (
             cl.quantity_metric IS DISTINCT FROM e.reported_metric OR cl.quantity_unit IS DISTINCT FROM e.reported_unit
             OR it.tag IS DISTINCT FROM CASE
               WHEN e.reported_value >= cl.quantity_value THEN 'SUPPORTS'
               WHEN e.reported_value = 0 THEN 'CONTRADICTS'
               ELSE 'PARTIALLY_SUPPORTS' END))
  ) THEN
    RAISE EXCEPTION 'IMPACT_RESULT_INCONSISTENT: counted evidence not derivable from stored evidence' USING ERRCODE = '23514';
  END IF;
  IF (NEW.underlying_status = 'SUPPORTED' AND v_n_sup = 0)
     OR (NEW.underlying_status = 'PARTIALLY_SUPPORTED' AND v_n_par = 0)
     OR (NEW.underlying_status = 'CONTRADICTED' AND v_n_con = 0)
     OR (NEW.underlying_status IN ('UNVERIFIED', 'OUTDATED') AND v_n_sup + v_n_par + v_n_con > 0) THEN
    RAISE EXCEPTION 'IMPACT_RESULT_INCONSISTENT: status not backed by matching evidence' USING ERRCODE = '23514';
  END IF;
  IF NEW.display_class = 'FACT' AND NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(coalesce(r->'supporting', '[]')) AS it(x) WHERE x->>'authority' = 'AUTHORITATIVE') THEN
    RAISE EXCEPTION 'IMPACT_RESULT_INCONSISTENT: FACT without an authoritative source' USING ERRCODE = '23514';
  END IF;
  IF r->>'subjectIdentity' IS DISTINCT FROM 'CONFIRMED'
     AND NEW.underlying_status IN ('SUPPORTED', 'PARTIALLY_SUPPORTED', 'CONTRADICTED') THEN
    RAISE EXCEPTION 'IMPACT_RESULT_INCONSISTENT: unconfirmed identity cannot support or contradict' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;

-- ── registry conflicts (database-written only) ─────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_registry_conflicts (
  seq                      bigint      GENERATED ALWAYS AS IDENTITY,
  investigation_id         uuid        NOT NULL,
  source_ref               text        NOT NULL,
  other_source_ref         text        NOT NULL,
  kind                     text        NOT NULL,
  canonical_org_id         text        NOT NULL,
  resolution               text        NOT NULL DEFAULT 'UNRESOLVED',
  is_finding_of_wrongdoing boolean     NOT NULL DEFAULT false,
  created_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_registry_conflicts_pkey PRIMARY KEY (seq),
  CONSTRAINT impact_registry_conflicts_key UNIQUE (investigation_id, source_ref, other_source_ref, kind),
  CONSTRAINT impact_registry_conflicts_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_registry_conflicts_source_fkey FOREIGN KEY (investigation_id, source_ref)
    REFERENCES public.impact_sources(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_registry_conflicts_other_fkey FOREIGN KEY (investigation_id, other_source_ref)
    REFERENCES public.impact_sources(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_registry_conflicts_kind_check CHECK (kind IN ('NAME_MISMATCH','STATUS_MISMATCH')),
  CONSTRAINT impact_registry_conflicts_resolution_check CHECK (resolution = 'UNRESOLVED'),
  -- A registry disagreement is timing, lag, a rename, another legal scope or
  -- data quality — never wrongdoing (IMPACT_ORGANIZATION_IDENTITY.md §6).
  CONSTRAINT impact_registry_conflicts_not_finding_check CHECK (is_finding_of_wrongdoing = false),
  CONSTRAINT impact_registry_conflicts_refs_check CHECK (source_ref <> other_source_ref)
);
COMMENT ON TABLE public.impact_registry_conflicts IS
  'Two ACTIVE registry snapshots of one organization disagree (name/status). Database-written only; never a finding.';

-- ── audit event types ──────────────────────────────────────────────────────

ALTER TABLE public.impact_audit_events DROP CONSTRAINT IF EXISTS impact_audit_events_type_check;
ALTER TABLE public.impact_audit_events ADD CONSTRAINT impact_audit_events_type_check CHECK (event_type IN (
  'INVESTIGATION_CREATED','INVESTIGATION_ARCHIVED','SOURCE_ADDED','CLAIM_CREATED','EVIDENCE_ADDED',
  'VERIFICATION_RUN','STATUS_CHANGED','CONFLICT_DETECTED','MANUAL_REVIEW','DISPUTE_OPENED',
  'DISPUTE_RESOLVED','SOURCE_STATUS_CHANGED','CORRECTION',
  'REGISTRY_SNAPSHOT_RECORDED','REGISTRY_CONFLICT_RECORDED'));

-- ── audit producers (20260924010000 + registry snapshot / conflicts) ───────

CREATE OR REPLACE FUNCTION public.impact_audit_writes() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_prev_status text;
  v_other record;
  v_shared text;
  v_a text;
  v_b text;
BEGIN
  IF TG_TABLE_NAME = 'impact_investigations' THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM public.impact_append_audit(NEW.id, 'INVESTIGATION_CREATED', NEW.owner_id::text, ARRAY[NEW.subject_org_ref], '{}');
    ELSIF NEW.status = 'ARCHIVED' AND OLD.status <> 'ARCHIVED' THEN
      PERFORM public.impact_append_audit(NEW.id, 'INVESTIGATION_ARCHIVED', NEW.updated_by::text, '{}', ARRAY['ARCHIVED']);
    END IF;
  ELSIF TG_TABLE_NAME = 'impact_sources' THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'SOURCE_ADDED', NEW.created_by::text,
        ARRAY[NEW.ref], ARRAY[NEW.source_type, NEW.acquisition_method]);
      IF NEW.snapshot IS NOT NULL THEN
        -- I2: snapshot event (NEW, or UPDATE when this provider record was seen before) …
        PERFORM public.impact_append_audit(NEW.investigation_id, 'REGISTRY_SNAPSHOT_RECORDED', NEW.created_by::text,
          ARRAY[NEW.ref], ARRAY[NEW.snapshot->>'canonicalOrgId', NEW.snapshot->>'status',
            CASE WHEN EXISTS (SELECT 1 FROM public.impact_sources o
                              WHERE o.investigation_id = NEW.investigation_id AND o.ref <> NEW.ref
                                AND o.acquisition_provider_id = NEW.acquisition_provider_id
                                AND o.snapshot->>'recordId' = NEW.snapshot->>'recordId')
                 THEN 'UPDATE' ELSE 'NEW' END]);
        -- … then one conflict row + event per disagreement with another ACTIVE
        -- snapshot of the same organization (order = organization_identity.ts registryConflicts).
        FOR v_other IN
          SELECT o.ref, o.snapshot FROM public.impact_sources o
          WHERE o.investigation_id = NEW.investigation_id AND o.ref <> NEW.ref AND o.snapshot IS NOT NULL AND o.status = 'ACTIVE'
            AND NOT (o.acquisition_provider_id = NEW.acquisition_provider_id AND o.snapshot->>'recordId' = NEW.snapshot->>'recordId')
            AND (o.snapshot->'canonicalIds') ?| ARRAY(SELECT jsonb_array_elements_text(NEW.snapshot->'canonicalIds'))
          ORDER BY o.ref COLLATE "C"
        LOOP
          SELECT min(x COLLATE "C") INTO v_shared
          FROM jsonb_array_elements_text(NEW.snapshot->'canonicalIds') AS t(x)
          WHERE (v_other.snapshot->'canonicalIds') ? x;
          IF v_other.snapshot->>'nameKey' IS DISTINCT FROM NEW.snapshot->>'nameKey' THEN
            INSERT INTO public.impact_registry_conflicts (investigation_id, source_ref, other_source_ref, kind, canonical_org_id)
            VALUES (NEW.investigation_id, NEW.ref, v_other.ref, 'NAME_MISMATCH', v_shared);
            PERFORM public.impact_append_audit(NEW.investigation_id, 'REGISTRY_CONFLICT_RECORDED', NEW.created_by::text,
              ARRAY[NEW.ref, v_other.ref], ARRAY['NAME_MISMATCH', v_shared]);
          END IF;
          v_a := public.impact_registry_status_class(NEW.snapshot->>'status');
          v_b := public.impact_registry_status_class(v_other.snapshot->>'status');
          IF v_a <> 'UNKNOWN' AND v_b <> 'UNKNOWN' AND v_a <> v_b THEN
            INSERT INTO public.impact_registry_conflicts (investigation_id, source_ref, other_source_ref, kind, canonical_org_id)
            VALUES (NEW.investigation_id, NEW.ref, v_other.ref, 'STATUS_MISMATCH', v_shared);
            PERFORM public.impact_append_audit(NEW.investigation_id, 'REGISTRY_CONFLICT_RECORDED', NEW.created_by::text,
              ARRAY[NEW.ref, v_other.ref], ARRAY['STATUS_MISMATCH', v_shared]);
          END IF;
        END LOOP;
      END IF;
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'SOURCE_STATUS_CHANGED', NEW.updated_by::text,
        ARRAY[NEW.ref], ARRAY[NEW.status, 'REVERIFICATION_REQUIRED']);
    END IF;
  ELSIF TG_TABLE_NAME = 'impact_claims' THEN
    PERFORM public.impact_append_audit(NEW.investigation_id, 'CLAIM_CREATED', NEW.created_by::text,
      ARRAY[NEW.ref, NEW.source_ref], ARRAY[NEW.kind, NEW.origin]);
  ELSIF TG_TABLE_NAME = 'impact_evidence' THEN
    PERFORM public.impact_append_audit(NEW.investigation_id, 'EVIDENCE_ADDED', NEW.created_by::text,
      ARRAY[NEW.ref, NEW.claim_ref, NEW.source_ref], ARRAY[NEW.relationship, NEW.relationship_basis]);
  ELSIF TG_TABLE_NAME = 'impact_verifications' THEN
    SELECT v.status INTO v_prev_status FROM public.impact_verifications v
    WHERE v.investigation_id = NEW.investigation_id AND v.claim_ref = NEW.claim_ref AND v.version = NEW.version - 1;
    PERFORM public.impact_append_audit(NEW.investigation_id, 'VERIFICATION_RUN', NEW.created_by::text,
      ARRAY[NEW.claim_ref, NEW.result_id], ARRAY[NEW.status, NEW.policy_version]);
    IF v_prev_status IS NOT NULL AND v_prev_status <> NEW.status THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'STATUS_CHANGED', NEW.created_by::text,
        ARRAY[NEW.claim_ref, NEW.result_id], ARRAY[v_prev_status, NEW.status]);
    END IF;
    IF NEW.conflict_count > 0 THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'CONFLICT_DETECTED', NEW.created_by::text,
        ARRAY[NEW.claim_ref, NEW.result_id], '{}');
    END IF;
    IF NEW.review_state = 'HUMAN_REVIEWED' THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'MANUAL_REVIEW', NEW.created_by::text,
        ARRAY[NEW.claim_ref, NEW.result_id], ARRAY['HUMAN_REVIEWED']);
    END IF;
    INSERT INTO public.impact_conflicts (verification_id, investigation_id, claim_ref, kind, basis, positions)
    SELECT NEW.id, NEW.investigation_id, NEW.claim_ref, c->>'kind', c->>'basis', c->'positions'
    FROM jsonb_array_elements(coalesce(NEW.result->'conflicts', '[]'::jsonb)) AS c;
  ELSIF TG_TABLE_NAME = 'impact_disputes' THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'DISPUTE_OPENED', NEW.created_by::text,
        ARRAY[NEW.ref, NEW.claim_ref] || NEW.submitted_evidence_refs, ARRAY[NEW.kind]);
    ELSE
      PERFORM public.impact_append_audit(NEW.investigation_id, 'DISPUTE_RESOLVED', NEW.updated_by::text,
        ARRAY[NEW.ref, NEW.claim_ref], ARRAY[NEW.resolution, 'REVERIFICATION_REQUIRED']);
      IF NEW.resolution = 'CORRECTED' THEN
        PERFORM public.impact_append_audit(NEW.investigation_id, 'CORRECTION', NEW.updated_by::text,
          ARRAY[NEW.claim_ref], ARRAY['CORRECTED']);
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.impact_audit_writes() FROM PUBLIC, anon, authenticated, service_role;

-- ── registry conflicts: triggers, RLS, privileges ──────────────────────────

DROP TRIGGER IF EXISTS impact_append_only ON public.impact_registry_conflicts;
CREATE TRIGGER impact_append_only BEFORE UPDATE ON public.impact_registry_conflicts
  FOR EACH ROW EXECUTE FUNCTION public.impact_guard_append_only();
DROP TRIGGER IF EXISTS impact_no_direct_delete ON public.impact_registry_conflicts;
CREATE TRIGGER impact_no_direct_delete BEFORE DELETE ON public.impact_registry_conflicts
  FOR EACH ROW EXECUTE FUNCTION public.impact_guard_no_direct_delete();
DROP TRIGGER IF EXISTS impact_trigger_only ON public.impact_registry_conflicts;
CREATE TRIGGER impact_trigger_only BEFORE INSERT ON public.impact_registry_conflicts
  FOR EACH ROW EXECUTE FUNCTION public.impact_guard_trigger_only();

ALTER TABLE public.impact_registry_conflicts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.impact_registry_conflicts NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.impact_registry_conflicts FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.impact_registry_conflicts TO authenticated, service_role;
DROP POLICY IF EXISTS impact_registry_conflicts_select_own ON public.impact_registry_conflicts;
CREATE POLICY impact_registry_conflicts_select_own ON public.impact_registry_conflicts FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.impact_investigations i
                 WHERE i.id = impact_registry_conflicts.investigation_id AND i.owner_id = auth.uid()));

-- impact_canonical_org_id / impact_registry_status_class are pure IMMUTABLE
-- helpers used inside CHECK constraints: every writer role needs EXECUTE,
-- so (like impact_trusted_provider) they are deliberately not revoked.
