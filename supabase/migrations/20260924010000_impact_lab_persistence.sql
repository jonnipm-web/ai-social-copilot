-- IV-IMPACT-I1-PERSISTENCE-RLS-01 — InsightValues Impact Lab persistence.
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
--
-- Model (docs/impact/IMPACT_PERSISTENCE_MODEL.md): one owner-scoped
-- investigation (single subject organization, identity kept on the row),
-- and child records keyed by a per-investigation domain ref:
--   impact_sources · impact_claims · impact_evidence · impact_verifications
--   (append-only, versioned) · impact_conflicts (append-only, expanded from
--   each verification) · impact_disputes · impact_audit_events (append-only,
--   hash-chained, written ONLY by triggers).
--
-- Security (docs/impact/IMPACT_RLS_MODEL.md):
--   * RLS on every table. authenticated may only SELECT rows of investigations
--     it owns (child tables check ownership through the parent). No
--     INSERT/UPDATE/DELETE privilege or policy exists for anon/authenticated:
--     a client can never write a claim, forge a verification status or an
--     audit event directly through PostgREST.
--   * Writes happen only in the impact-lab Edge Function via service_role,
--     AFTER authentication, server-side entitlement and an RLS-bound
--     ownership read (defense in depth).
--   * Invariants hold even for service_role: composite FKs
--     (investigation_id, ref) make cross-investigation links impossible;
--     claims must be about the investigation subject; project links must
--     belong to the investigation owner; claims/evidence/verifications/
--     conflicts/audit are append-only; direct DELETE is refused for every
--     table (rows only disappear through account erasure, i.e. the
--     auth.users → investigations cascade); the audit chain is produced by
--     triggers in the same transaction as the write it records.
--   * No column can hold a verdict, score, "trusted" or "fraud" flag, and a
--     persisted verification must carry isFindingOfWrongdoing = false.
--   * Codex I1 Gate 1 (I1G1-01): audit events and conflicts are written ONLY
--     by SECURITY DEFINER triggers (service_role has no INSERT/UPDATE on them
--     and cannot call the appender); every child row's created_by/updated_by
--     must be the investigation owner; PROVIDER provenance must name a provider
--     of the server allowlist with its declared type/jurisdiction and carry a
--     snapshot; verification columns must equal the engine result JSON.
--     Residual (escalated): a holder of the service_role key can still write
--     internally consistent rows — see docs/impact/IMPACT_RLS_MODEL.md §6.
--
-- Domain timestamps (retrievedAt, publishedAt, periods, …) are stored as the
-- canonical ISO text the engine hashed, so re-reading them reproduces the same
-- evidenceSetHash; triggers validate them.
--
-- Rollback (Lab): DROP TABLE public.impact_audit_events, public.impact_disputes,
--   public.impact_conflicts, public.impact_verifications, public.impact_evidence,
--   public.impact_claims, public.impact_sources, public.impact_investigations CASCADE;
--   then DROP the impact_* functions. Nothing outside impact_* depends on them.
--
-- Idempotent: safe to re-run.

-- ── helpers ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.impact_is_ref(v text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT v IS NOT NULL AND v ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'
$$;

CREATE OR REPLACE FUNCTION public.impact_is_iso(v text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT v IS NOT NULL
     AND v ~ '^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}:\d{2}))?$'
$$;

-- Parses canonical ISO text; raises on impossible calendar dates (2025-02-30).
CREATE OR REPLACE FUNCTION public.impact_ts(v text) RETURNS timestamptz
LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE d date;
BEGIN
  IF v IS NULL THEN RETURN NULL; END IF;
  IF NOT public.impact_is_iso(v) THEN RAISE EXCEPTION 'IMPACT_INVALID_TIMESTAMP: %', v USING ERRCODE = '22007'; END IF;
  d := make_date(substr(v, 1, 4)::int, substr(v, 6, 2)::int, substr(v, 9, 2)::int);
  IF length(v) = 10 THEN RETURN d::timestamp AT TIME ZONE 'UTC'; END IF;
  RETURN v::timestamptz;
EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN
  RAISE EXCEPTION 'IMPACT_INVALID_TIMESTAMP: %', v USING ERRCODE = '22007';
END $$;

-- Server provider allowlist (MUST equal trustedProviderRefs() in
-- supabase/functions/_shared/impact/provider_registry.ts — drift-tested).
-- BEGIN_IMPACT_PROVIDER_ALLOWLIST
CREATE OR REPLACE FUNCTION public.impact_trusted_provider(p_id text, p_type text, p_country text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT (p_id, p_type, p_country) IN (
    ('fixture-xa-charity-registry', 'OFFICIAL_REGISTRY', 'XA')
  )
$$;
-- END_IMPACT_PROVIDER_ALLOWLIST

-- Source authority cells that can count as corroboration (AUTHORITATIVE /
-- INDEPENDENT), mirrored from source_authority.ts (impact-source-authority/3)
-- and drift-tested against authorityFor() (Codex I1F-01). Every other
-- (type, kind, genre) is non-independent and can never be counted.
-- BEGIN_IMPACT_AUTHORITY_TABLE
CREATE OR REPLACE FUNCTION public.impact_independent_authority(p_type text, p_kind text, p_genre text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT a.scope FROM (VALUES
    ('OFFICIAL_REGISTRY', 'LEGAL_REGISTRATION', NULL, 'AUTHORITATIVE'),
    ('OFFICIAL_REGISTRY', 'OPERATING_HISTORY', NULL, 'INDEPENDENT'),
    ('OFFICIAL_REGISTRY', 'GOVERNANCE', NULL, 'INDEPENDENT'),
    ('OFFICIAL_REGISTRY', 'REGULATORY_STATUS', NULL, 'AUTHORITATIVE'),
    ('GOVERNMENT_RECORD', 'LEGAL_REGISTRATION', NULL, 'INDEPENDENT'),
    ('GOVERNMENT_RECORD', 'OPERATING_HISTORY', NULL, 'INDEPENDENT'),
    ('GOVERNMENT_RECORD', 'FINANCIAL', NULL, 'INDEPENDENT'),
    ('GOVERNMENT_RECORD', 'IMPACT_OUTPUT', NULL, 'INDEPENDENT'),
    ('GOVERNMENT_RECORD', 'IMPACT_OUTCOME', NULL, 'INDEPENDENT'),
    ('GOVERNMENT_RECORD', 'BENEFICIARY_COUNT', NULL, 'INDEPENDENT'),
    ('AUDITED_REPORT', 'FINANCIAL', NULL, 'INDEPENDENT'),
    ('COURT_RECORD', 'REGULATORY_STATUS', NULL, 'AUTHORITATIVE'),
    ('REGULATOR', 'LEGAL_REGISTRATION', NULL, 'AUTHORITATIVE'),
    ('REGULATOR', 'GOVERNANCE', NULL, 'INDEPENDENT'),
    ('REGULATOR', 'REGULATORY_STATUS', NULL, 'AUTHORITATIVE'),
    ('NEWS', 'OPERATING_HISTORY', 'REPORTING', 'INDEPENDENT'),
    ('NEWS', 'IMPACT_OUTPUT', 'REPORTING', 'INDEPENDENT'),
    ('NEWS', 'IMPACT_OUTCOME', 'REPORTING', 'INDEPENDENT'),
    ('NEWS', 'BENEFICIARY_COUNT', 'REPORTING', 'INDEPENDENT'),
    ('NEWS', 'AFFILIATION', 'REPORTING', 'INDEPENDENT'),
    ('NEWS', 'GOVERNANCE', 'REPORTING', 'INDEPENDENT'),
    ('ACADEMIC', 'IMPACT_OUTPUT', NULL, 'INDEPENDENT'),
    ('ACADEMIC', 'IMPACT_OUTCOME', NULL, 'INDEPENDENT'),
    ('ACADEMIC', 'BENEFICIARY_COUNT', NULL, 'INDEPENDENT')
  ) AS a(source_type, claim_kind, news_genre, scope)
  WHERE a.source_type = p_type AND a.claim_kind = p_kind AND a.news_genre IS NOT DISTINCT FROM p_genre
$$;
-- END_IMPACT_AUTHORITY_TABLE

-- ── investigations ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_investigations (
  id                uuid        NOT NULL DEFAULT gen_random_uuid(),
  owner_id          uuid        NOT NULL,
  project_id        uuid        NULL,
  subject_org_ref   text        NOT NULL,
  subject_org_type  text        NOT NULL,
  subject_identity  jsonb       NOT NULL DEFAULT '{}'::jsonb,
  status            text        NOT NULL DEFAULT 'ACTIVE',
  audit_seq         integer     NOT NULL DEFAULT 0,
  audit_head        text        NOT NULL DEFAULT repeat('0', 64),
  updated_by        uuid        NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_investigations_pkey PRIMARY KEY (id),
  CONSTRAINT impact_investigations_subject_key UNIQUE (id, subject_org_ref),
  CONSTRAINT impact_investigations_owner_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT impact_investigations_project_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL,
  CONSTRAINT impact_investigations_ref_check CHECK (public.impact_is_ref(subject_org_ref)),
  CONSTRAINT impact_investigations_type_check CHECK (subject_org_type IN (
    'CHARITY','NGO','NONPROFIT','FOUNDATION','SOCIAL_ENTERPRISE','RELIGIOUS_ORGANIZATION',
    'COMMUNITY_PROJECT','CROWDFUNDING_CAMPAIGN','INFORMAL_INITIATIVE','OTHER')),
  CONSTRAINT impact_investigations_identity_check CHECK (jsonb_typeof(subject_identity) = 'object'),
  CONSTRAINT impact_investigations_status_check CHECK (status IN ('ACTIVE','ARCHIVED')),
  CONSTRAINT impact_investigations_audit_check CHECK (audit_seq >= 0 AND audit_head ~ '^[0-9a-f]{64}$')
);
CREATE INDEX IF NOT EXISTS impact_investigations_owner_idx ON public.impact_investigations (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS impact_investigations_project_idx ON public.impact_investigations (project_id) WHERE project_id IS NOT NULL;
COMMENT ON TABLE public.impact_investigations IS
  'Impact Lab investigation: one owner, one subject organization (identity snapshot). Written only by the impact-lab Edge Function (service_role).';

-- ── sources ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_sources (
  id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id        uuid        NOT NULL,
  ref                     text        NOT NULL,
  source_type             text        NOT NULL,
  publisher               text        NOT NULL,
  publisher_org_ref       text        NULL,
  uri                     text        NULL,
  retrieved_at            text        NOT NULL,
  published_at            text        NULL,
  jurisdiction_country    text        NULL,
  jurisdiction_registry   text        NULL,
  news_genre              text        NULL,
  status                  text        NOT NULL DEFAULT 'ACTIVE',
  retention               text        NOT NULL,
  content_hash            text        NULL,
  acquisition_method      text        NOT NULL,
  acquisition_provider_id text        NULL,
  syndicated_from         text        NULL,
  user_submitted          boolean     NOT NULL DEFAULT false,
  snapshot                jsonb       NULL,
  created_by              uuid        NOT NULL,
  updated_by              uuid        NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_sources_pkey PRIMARY KEY (id),
  CONSTRAINT impact_sources_ref_key UNIQUE (investigation_id, ref),
  CONSTRAINT impact_sources_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_sources_ref_check CHECK (public.impact_is_ref(ref)),
  CONSTRAINT impact_sources_type_check CHECK (source_type IN (
    'OFFICIAL_REGISTRY','ORGANIZATION_WEBSITE','GOVERNMENT_RECORD','FINANCIAL_REPORT','AUDITED_REPORT',
    'COURT_RECORD','REGULATOR','NEWS','ACADEMIC','NGO_DATABASE','SOCIAL_MEDIA','USER_DOCUMENT','OTHER')),
  CONSTRAINT impact_sources_publisher_check CHECK (length(btrim(publisher)) BETWEEN 1 AND 300),
  CONSTRAINT impact_sources_publisher_org_check CHECK (publisher_org_ref IS NULL OR public.impact_is_ref(publisher_org_ref)),
  CONSTRAINT impact_sources_uri_check CHECK (uri IS NULL OR (length(uri) <= 2048 AND uri ~* '^https?://')),
  CONSTRAINT impact_sources_retrieved_check CHECK (public.impact_is_iso(retrieved_at)),
  CONSTRAINT impact_sources_published_check CHECK (published_at IS NULL OR public.impact_is_iso(published_at)),
  CONSTRAINT impact_sources_country_check CHECK (jurisdiction_country IS NULL OR jurisdiction_country ~ '^[A-Z]{2}$'),
  CONSTRAINT impact_sources_genre_check CHECK (news_genre IS NULL OR (source_type = 'NEWS'
    AND news_genre IN ('REPORTING','OPINION','ALLEGATION','CORRECTION'))),
  CONSTRAINT impact_sources_status_check CHECK (status IN ('ACTIVE','UPDATED','RETRACTED','UNAVAILABLE')),
  CONSTRAINT impact_sources_retention_check CHECK (retention IN ('REFERENCE_ONLY','HASH_ONLY','EXCERPT_AND_HASH','SNAPSHOT')),
  CONSTRAINT impact_sources_hash_check CHECK (
    (content_hash IS NULL OR content_hash ~ '^[0-9a-f]{64}$')
    AND (retention = 'REFERENCE_ONLY' OR content_hash IS NOT NULL)
    AND (retention <> 'REFERENCE_ONLY' OR uri IS NOT NULL)),
  CONSTRAINT impact_sources_acquisition_check CHECK (
    acquisition_method IN ('PROVIDER','USER_UPLOAD','ANALYST_ENTRY')
    AND ((acquisition_method = 'PROVIDER') = (acquisition_provider_id IS NOT NULL))
    AND (acquisition_provider_id IS NULL OR public.impact_is_ref(acquisition_provider_id))),
  CONSTRAINT impact_sources_syndication_check CHECK (syndicated_from IS NULL OR length(btrim(syndicated_from)) BETWEEN 1 AND 300),
  CONSTRAINT impact_sources_snapshot_check CHECK (snapshot IS NULL OR (retention = 'SNAPSHOT' AND jsonb_typeof(snapshot) = 'object')),
  -- PROVIDER provenance only for an allowlisted provider, with its declared
  -- type and jurisdiction and the provider snapshot; nothing else has a snapshot.
  CONSTRAINT impact_sources_provider_check CHECK (
    CASE WHEN acquisition_method = 'PROVIDER'
      THEN snapshot IS NOT NULL AND retention = 'SNAPSHOT'
           AND public.impact_trusted_provider(acquisition_provider_id, source_type, jurisdiction_country)
           AND jurisdiction_registry = acquisition_provider_id
      ELSE snapshot IS NULL END)
);
CREATE INDEX IF NOT EXISTS impact_sources_investigation_idx ON public.impact_sources (investigation_id, created_at);

-- ── claims ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_claims (
  id                    uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id      uuid        NOT NULL,
  ref                   text        NOT NULL,
  kind                  text        NOT NULL,
  claim_text            text        NOT NULL,
  text_language         text        NULL,
  quantity_metric       text        NULL,
  quantity_value        numeric     NULL,
  quantity_unit         text        NULL,
  impact_level          text        NULL,
  claimant_org_ref      text        NULL,
  claimant_label        text        NULL,
  subject_org_ref       text        NOT NULL,
  subject_project_ref   text        NULL,
  subject_campaign_ref  text        NULL,
  period_from           text        NULL,
  period_to             text        NULL,
  source_ref            text        NOT NULL,
  extracted_at          text        NOT NULL,
  origin                text        NOT NULL,
  created_by            uuid        NOT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_claims_pkey PRIMARY KEY (id),
  CONSTRAINT impact_claims_ref_key UNIQUE (investigation_id, ref),
  CONSTRAINT impact_claims_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  -- CF-01 at the database: a claim can only be about the investigation subject.
  CONSTRAINT impact_claims_subject_fkey FOREIGN KEY (investigation_id, subject_org_ref)
    REFERENCES public.impact_investigations(id, subject_org_ref) ON DELETE CASCADE,
  CONSTRAINT impact_claims_source_fkey FOREIGN KEY (investigation_id, source_ref)
    REFERENCES public.impact_sources(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_claims_ref_check CHECK (public.impact_is_ref(ref)),
  CONSTRAINT impact_claims_kind_check CHECK (kind IN (
    'LEGAL_REGISTRATION','OPERATING_HISTORY','FINANCIAL','IMPACT_OUTPUT','IMPACT_OUTCOME',
    'BENEFICIARY_COUNT','AFFILIATION','GOVERNANCE','REGULATORY_STATUS','OTHER')),
  CONSTRAINT impact_claims_text_check CHECK (length(btrim(claim_text)) BETWEEN 1 AND 4000),
  CONSTRAINT impact_claims_language_check CHECK (text_language IS NULL OR text_language ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  CONSTRAINT impact_claims_quantity_check CHECK (
    (quantity_metric IS NULL AND quantity_value IS NULL AND quantity_unit IS NULL)
    OR (quantity_metric IS NOT NULL AND quantity_value IS NOT NULL AND quantity_unit IS NOT NULL
        AND quantity_value >= 0 AND length(quantity_metric) <= 100 AND length(quantity_unit) <= 50)),
  CONSTRAINT impact_claims_level_check CHECK (impact_level IS NULL OR impact_level IN ('INPUT','ACTIVITY','OUTPUT','OUTCOME','IMPACT')),
  CONSTRAINT impact_claims_refs_check CHECK (
    (claimant_org_ref IS NULL OR public.impact_is_ref(claimant_org_ref))
    AND (subject_project_ref IS NULL OR public.impact_is_ref(subject_project_ref))
    AND (subject_campaign_ref IS NULL OR public.impact_is_ref(subject_campaign_ref))
    AND (claimant_label IS NULL OR length(claimant_label) <= 300)),
  CONSTRAINT impact_claims_period_check CHECK (
    (period_from IS NULL OR public.impact_is_iso(period_from)) AND (period_to IS NULL OR public.impact_is_iso(period_to))),
  CONSTRAINT impact_claims_extracted_check CHECK (public.impact_is_iso(extracted_at)),
  CONSTRAINT impact_claims_origin_check CHECK (origin IN ('MANUAL','STRUCTURED_IMPORT','LLM_EXTRACTED'))
);
CREATE INDEX IF NOT EXISTS impact_claims_investigation_idx ON public.impact_claims (investigation_id, created_at);
COMMENT ON TABLE public.impact_claims IS
  'Claims are assertions, never facts. There is deliberately no status column: status exists only in impact_verifications, produced by the Verification Engine.';

-- ── evidence ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_evidence (
  id                   uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id     uuid        NOT NULL,
  ref                  text        NOT NULL,
  claim_ref            text        NOT NULL,
  source_ref           text        NOT NULL,
  about_org_ref        text        NOT NULL,
  relationship         text        NOT NULL,
  relationship_basis   text        NOT NULL,
  reported_metric      text        NULL,
  reported_value       numeric     NULL,
  reported_unit        text        NULL,
  impact_level         text        NULL,
  observed_from        text        NULL,
  observed_to          text        NULL,
  excerpt              text        NULL,
  excerpt_hash         text        NULL,
  locator              jsonb       NULL,
  personal_data        text        NOT NULL,
  legal_stage          text        NULL,
  added_at             text        NOT NULL,
  created_by           uuid        NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_evidence_pkey PRIMARY KEY (id),
  CONSTRAINT impact_evidence_ref_key UNIQUE (investigation_id, ref),
  CONSTRAINT impact_evidence_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_claim_fkey FOREIGN KEY (investigation_id, claim_ref)
    REFERENCES public.impact_claims(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_source_fkey FOREIGN KEY (investigation_id, source_ref)
    REFERENCES public.impact_sources(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_ref_check CHECK (public.impact_is_ref(ref) AND public.impact_is_ref(about_org_ref)),
  CONSTRAINT impact_evidence_relationship_check CHECK (relationship IN ('SUPPORTS','CONTRADICTS','CONTEXTUALIZES')),
  CONSTRAINT impact_evidence_basis_check CHECK (relationship_basis IN ('STRUCTURED_MATCH','HUMAN_ASSESSED','LLM_SUGGESTED')),
  CONSTRAINT impact_evidence_quantity_check CHECK (
    (reported_metric IS NULL AND reported_value IS NULL AND reported_unit IS NULL)
    OR (reported_metric IS NOT NULL AND reported_value IS NOT NULL AND reported_unit IS NOT NULL AND reported_value >= 0)),
  CONSTRAINT impact_evidence_level_check CHECK (impact_level IS NULL OR impact_level IN ('INPUT','ACTIVITY','OUTPUT','OUTCOME','IMPACT')),
  CONSTRAINT impact_evidence_period_check CHECK (
    (observed_from IS NULL OR public.impact_is_iso(observed_from)) AND (observed_to IS NULL OR public.impact_is_iso(observed_to))),
  CONSTRAINT impact_evidence_excerpt_check CHECK (
    (excerpt IS NULL OR (length(excerpt) <= 2000 AND excerpt_hash IS NOT NULL))
    AND (excerpt_hash IS NULL OR excerpt_hash ~ '^[0-9a-f]{64}$')),
  CONSTRAINT impact_evidence_locator_check CHECK (locator IS NULL OR jsonb_typeof(locator) = 'object'),
  -- Privacy boundary at the database: personal, sensitive and minors' data are never stored.
  CONSTRAINT impact_evidence_personal_data_check CHECK (personal_data IN ('NONE','AGGREGATED','PUBLIC_OFFICIAL_ROLE')),
  CONSTRAINT impact_evidence_legal_stage_check CHECK (legal_stage IS NULL OR legal_stage IN (
    'INVESTIGATION_OPENED','CHARGED','CONVICTED','ACQUITTED','DISMISSED','SANCTIONED','SETTLED',
    'UNDER_APPEAL','OVERTURNED','CLOSED_NO_ACTION')),
  CONSTRAINT impact_evidence_added_check CHECK (public.impact_is_iso(added_at))
);
CREATE INDEX IF NOT EXISTS impact_evidence_claim_idx ON public.impact_evidence (investigation_id, claim_ref);
CREATE INDEX IF NOT EXISTS impact_evidence_source_idx ON public.impact_evidence (investigation_id, source_ref);

-- ── verifications (append-only, versioned) ──────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_verifications (
  id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id    uuid        NOT NULL,
  claim_ref           text        NOT NULL,
  version             integer     NOT NULL DEFAULT 0,
  result_id           text        NOT NULL,
  status              text        NOT NULL,
  underlying_status   text        NOT NULL,
  sufficiency         text        NOT NULL,
  display_class       text        NOT NULL,
  review_state        text        NOT NULL,
  policy_version      text        NOT NULL,
  evidence_set_hash   text        NOT NULL,
  review_binding_hash text        NOT NULL,
  evaluated_at        text        NOT NULL,
  rules_applied       text[]      NOT NULL DEFAULT '{}',
  gaps                text[]      NOT NULL DEFAULT '{}',
  conflict_count      integer     NOT NULL DEFAULT 0,
  result              jsonb       NOT NULL,
  idempotency_key     uuid        NULL,
  created_by          uuid        NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_verifications_pkey PRIMARY KEY (id),
  CONSTRAINT impact_verifications_version_key UNIQUE (investigation_id, claim_ref, version),
  CONSTRAINT impact_verifications_result_key UNIQUE (investigation_id, result_id),
  CONSTRAINT impact_verifications_idempotency_key UNIQUE (investigation_id, idempotency_key),
  CONSTRAINT impact_verifications_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_verifications_claim_fkey FOREIGN KEY (investigation_id, claim_ref)
    REFERENCES public.impact_claims(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_verifications_status_check CHECK (
    status IN ('UNVERIFIED','SUPPORTED','PARTIALLY_SUPPORTED','CONTRADICTED','INCONCLUSIVE','OUTDATED','DISPUTED')
    AND underlying_status IN ('UNVERIFIED','SUPPORTED','PARTIALLY_SUPPORTED','CONTRADICTED','INCONCLUSIVE','OUTDATED','DISPUTED')),
  CONSTRAINT impact_verifications_sufficiency_check CHECK (sufficiency IN (
    'NO_EVIDENCE','SELF_REPORTED','SINGLE_SOURCE','INDEPENDENT_SUPPORT','MULTI_SOURCE_SUPPORT','CONFLICTING_EVIDENCE')),
  CONSTRAINT impact_verifications_class_check CHECK (display_class IN (
    'FACT','CLAIM','EVIDENCE','INFERENCE','ALLEGATION','CONFLICT','UNKNOWN','ABSENCE_OF_EVIDENCE')),
  CONSTRAINT impact_verifications_review_check CHECK (review_state IN ('AUTOMATED','REVIEW_REQUIRED','HUMAN_REVIEWED')),
  CONSTRAINT impact_verifications_hash_check CHECK (
    evidence_set_hash ~ '^[0-9a-f]{64}$' AND review_binding_hash ~ '^[0-9a-f]{64}$' AND result_id ~ '^vr_[0-9a-f]{32}$'),
  CONSTRAINT impact_verifications_evaluated_check CHECK (public.impact_is_iso(evaluated_at)),
  CONSTRAINT impact_verifications_result_check CHECK (
    jsonb_typeof(result) = 'object'
    AND result->'isFindingOfWrongdoing' = 'false'::jsonb
    AND result->'absenceOfEvidenceIsNotEvidenceOfWrongdoing' = 'true'::jsonb
    AND result->>'resultId' = result_id
    AND result->>'status' = status
    AND result->>'underlyingStatus' = underlying_status
    AND result->>'sufficiency' = sufficiency
    AND result->>'displayClass' = display_class
    AND result->>'reviewState' = review_state
    AND result->>'policyVersion' = policy_version
    AND result->>'evidenceSetHash' = evidence_set_hash
    AND result->>'reviewBindingHash' = review_binding_hash
    AND result->>'evaluatedAt' = evaluated_at
    AND result->>'claimId' = claim_ref
    AND result->>'investigationId' = investigation_id::text
    AND jsonb_typeof(coalesce(result->'conflicts', '[]'::jsonb)) = 'array'
    AND jsonb_array_length(coalesce(result->'conflicts', '[]'::jsonb)) = conflict_count),
  -- Engine invariants: only an authoritative SUPPORTED result is a FACT; a
  -- DISPUTED result is always shown as a CONFLICT.
  CONSTRAINT impact_verifications_semantics_check CHECK (
    (display_class <> 'FACT' OR status = 'SUPPORTED')
    AND (status <> 'DISPUTED' OR display_class = 'CONFLICT')),
  CONSTRAINT impact_verifications_conflicts_check CHECK (conflict_count >= 0)
);
CREATE INDEX IF NOT EXISTS impact_verifications_claim_idx ON public.impact_verifications (investigation_id, claim_ref, version DESC);

-- ── conflicts (append-only; expanded from each verification by trigger) ─────

CREATE TABLE IF NOT EXISTS public.impact_conflicts (
  id               uuid        NOT NULL DEFAULT gen_random_uuid(),
  verification_id  uuid        NOT NULL,
  investigation_id uuid        NOT NULL,
  claim_ref        text        NOT NULL,
  kind             text        NOT NULL,
  basis            text        NOT NULL,
  positions        jsonb       NOT NULL,
  resolution       text        NOT NULL DEFAULT 'UNRESOLVED',
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_conflicts_pkey PRIMARY KEY (id),
  CONSTRAINT impact_conflicts_verification_fkey FOREIGN KEY (verification_id)
    REFERENCES public.impact_verifications(id) ON DELETE CASCADE,
  CONSTRAINT impact_conflicts_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_conflicts_kind_check CHECK (kind IN ('QUANTITY_DISAGREEMENT','SUPPORT_VS_CONTRADICTION')),
  CONSTRAINT impact_conflicts_basis_check CHECK (basis IN ('INDEPENDENT_SOURCES','SAME_PUBLISHER','SELF_REPORTED_ONLY')),
  CONSTRAINT impact_conflicts_positions_check CHECK (jsonb_typeof(positions) = 'array'),
  CONSTRAINT impact_conflicts_resolution_check CHECK (resolution = 'UNRESOLVED')
);
CREATE INDEX IF NOT EXISTS impact_conflicts_investigation_idx ON public.impact_conflicts (investigation_id, claim_ref);

-- ── disputes ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_disputes (
  id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id        uuid        NOT NULL,
  ref                     text        NOT NULL,
  claim_ref               text        NOT NULL,
  kind                    text        NOT NULL,
  opened_at               text        NOT NULL,
  submitted_evidence_refs text[]      NOT NULL DEFAULT '{}',
  resolution              text        NULL,
  resolved_at             text        NULL,
  created_by              uuid        NOT NULL,
  updated_by              uuid        NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_disputes_pkey PRIMARY KEY (id),
  CONSTRAINT impact_disputes_ref_key UNIQUE (investigation_id, ref),
  CONSTRAINT impact_disputes_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_disputes_claim_fkey FOREIGN KEY (investigation_id, claim_ref)
    REFERENCES public.impact_claims(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_disputes_ref_check CHECK (public.impact_is_ref(ref)),
  CONSTRAINT impact_disputes_kind_check CHECK (kind IN ('ORGANIZATION_RESPONSE','CORRECTION_REQUEST','RETRACTION_REQUEST','SOURCE_UPDATE')),
  CONSTRAINT impact_disputes_resolution_check CHECK (
    (resolution IS NULL AND resolved_at IS NULL)
    OR (resolution IN ('CORRECTED','UPHELD','WITHDRAWN','SOURCE_RETRACTED') AND public.impact_is_iso(resolved_at))),
  CONSTRAINT impact_disputes_opened_check CHECK (public.impact_is_iso(opened_at)),
  CONSTRAINT impact_disputes_refs_check CHECK (cardinality(submitted_evidence_refs) <= 50)
);
CREATE INDEX IF NOT EXISTS impact_disputes_claim_idx ON public.impact_disputes (investigation_id, claim_ref);

-- ── audit events (append-only, hash-chained, trigger-written) ───────────────

CREATE TABLE IF NOT EXISTS public.impact_audit_events (
  investigation_id uuid        NOT NULL,
  seq              integer     NOT NULL,
  at_text          text        NOT NULL,
  event_type       text        NOT NULL,
  actor_ref        text        NOT NULL,
  refs             text[]      NOT NULL DEFAULT '{}',
  codes            text[]      NOT NULL DEFAULT '{}',
  prev_hash        text        NOT NULL,
  hash             text        NOT NULL,
  CONSTRAINT impact_audit_events_pkey PRIMARY KEY (investigation_id, seq),
  CONSTRAINT impact_audit_events_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_audit_events_type_check CHECK (event_type IN (
    'INVESTIGATION_CREATED','INVESTIGATION_ARCHIVED','SOURCE_ADDED','CLAIM_CREATED','EVIDENCE_ADDED',
    'VERIFICATION_RUN','STATUS_CHANGED','CONFLICT_DETECTED','MANUAL_REVIEW','DISPUTE_OPENED',
    'DISPUTE_RESOLVED','SOURCE_STATUS_CHANGED','CORRECTION')),
  CONSTRAINT impact_audit_events_hash_check CHECK (prev_hash ~ '^[0-9a-f]{64}$' AND hash ~ '^[0-9a-f]{64}$' AND seq >= 1)
);

-- ── invariants (apply to every writer, including service_role) ─────────────

-- Append-only: no UPDATE, ever.
CREATE OR REPLACE FUNCTION public.impact_guard_append_only() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'IMPACT_APPEND_ONLY: % rows cannot be modified', TG_TABLE_NAME USING ERRCODE = '42501';
END $$;

-- No direct DELETE for anyone: rows only disappear through the cascade from
-- auth.users (account erasure), never by deleting history directly.
CREATE OR REPLACE FUNCTION public.impact_guard_no_direct_delete() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF pg_trigger_depth() <= 1 THEN
    RAISE EXCEPTION 'IMPACT_NO_DIRECT_DELETE: % history is preserved', TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN OLD;
END $$;

-- Audit events and conflicts can only be inserted from inside the Impact
-- triggers (nested trigger depth), never by a direct INSERT — by any role.
CREATE OR REPLACE FUNCTION public.impact_guard_trigger_only() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF pg_trigger_depth() < 2 THEN
    RAISE EXCEPTION 'IMPACT_TRIGGER_ONLY: % rows are written by the database only', TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- Appends one hash-chained audit event. Serialized per investigation by the
-- row lock on the investigation (concurrent writers queue, never fork the chain).
CREATE OR REPLACE FUNCTION public.impact_append_audit(
  p_investigation uuid, p_type text, p_actor text, p_refs text[], p_codes text[]
) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_seq  integer;
  v_prev text;
  v_at   text := to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
  v_hash text;
BEGIN
  SELECT audit_seq, audit_head INTO v_seq, v_prev
  FROM public.impact_investigations WHERE id = p_investigation FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'IMPACT_AUDIT_NO_INVESTIGATION'; END IF;
  v_seq := v_seq + 1;
  v_hash := encode(sha256(convert_to(concat_ws('|',
    v_seq::text, v_at, p_type, p_actor, p_investigation::text,
    array_to_string(coalesce(p_refs, '{}'), ','), array_to_string(coalesce(p_codes, '{}'), ','), v_prev), 'UTF8')), 'hex');
  INSERT INTO public.impact_audit_events (investigation_id, seq, at_text, event_type, actor_ref, refs, codes, prev_hash, hash)
  VALUES (p_investigation, v_seq, v_at, p_type, p_actor, coalesce(p_refs, '{}'), coalesce(p_codes, '{}'), v_prev, v_hash);
  UPDATE public.impact_investigations SET audit_seq = v_seq, audit_head = v_hash, updated_at = now()
  WHERE id = p_investigation;
END $$;

-- Recomputes the chain; any edited, dropped or reordered event → false.
-- SECURITY INVOKER: a caller can only verify chains it can read (RLS).
CREATE OR REPLACE FUNCTION public.impact_audit_chain_ok(p_investigation uuid) RETURNS boolean
LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  r record;
  v_prev text := repeat('0', 64);
  v_expected integer := 1;
  v_head text;
  v_seq integer;
BEGIN
  SELECT audit_head, audit_seq INTO v_head, v_seq FROM public.impact_investigations WHERE id = p_investigation;
  IF NOT FOUND THEN RETURN false; END IF;
  FOR r IN SELECT * FROM public.impact_audit_events WHERE investigation_id = p_investigation ORDER BY seq LOOP
    IF r.seq <> v_expected OR r.prev_hash <> v_prev THEN RETURN false; END IF;
    IF r.hash <> encode(sha256(convert_to(concat_ws('|',
         r.seq::text, r.at_text, r.event_type, r.actor_ref, r.investigation_id::text,
         array_to_string(r.refs, ','), array_to_string(r.codes, ','), r.prev_hash), 'UTF8')), 'hex') THEN
      RETURN false;
    END IF;
    v_prev := r.hash;
    v_expected := v_expected + 1;
  END LOOP;
  RETURN v_prev = v_head AND v_expected - 1 = v_seq;
END $$;

-- Investigations: owner/subject/identity are immutable; project may only be
-- detached (NULL) or set to a project the OWNER owns; status/audit move.
CREATE OR REPLACE FUNCTION public.impact_investigations_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.id <> OLD.id OR NEW.owner_id <> OLD.owner_id OR NEW.subject_org_ref <> OLD.subject_org_ref
       OR NEW.subject_org_type <> OLD.subject_org_type OR NEW.subject_identity <> OLD.subject_identity
       OR NEW.created_at <> OLD.created_at THEN
      RAISE EXCEPTION 'IMPACT_IMMUTABLE_FIELD: investigation identity/ownership cannot change' USING ERRCODE = '42501';
    END IF;
    IF NEW.audit_seq < OLD.audit_seq THEN
      RAISE EXCEPTION 'IMPACT_AUDIT_REWIND' USING ERRCODE = '42501';
    END IF;
    IF (NEW.audit_seq <> OLD.audit_seq OR NEW.audit_head <> OLD.audit_head) AND pg_trigger_depth() < 2 THEN
      RAISE EXCEPTION 'IMPACT_TRIGGER_ONLY: the audit head is written by the database only' USING ERRCODE = '42501';
    END IF;
    IF OLD.status = 'ARCHIVED' AND NEW.status <> 'ARCHIVED' THEN
      RAISE EXCEPTION 'IMPACT_ARCHIVED_IS_FINAL' USING ERRCODE = '42501';
    END IF;
    -- Codex I1G2-04: a lifecycle change must be made by the owner.
    IF NEW.status <> OLD.status AND NEW.updated_by IS DISTINCT FROM NEW.owner_id THEN
      RAISE EXCEPTION 'IMPACT_ACTOR_NOT_OWNER' USING ERRCODE = '42501';
    END IF;
  END IF;
  IF NEW.project_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.project_id IS DISTINCT FROM OLD.project_id)
     AND NOT EXISTS (SELECT 1 FROM public.projects p WHERE p.id = NEW.project_id AND p.user_id = NEW.owner_id) THEN
    RAISE EXCEPTION 'IMPACT_PROJECT_NOT_OWNED' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- Sources: only status (and who/when) may change after insert.
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
  IF (to_jsonb(NEW) - ARRAY['status','updated_by','updated_at']) <> (to_jsonb(OLD) - ARRAY['status','updated_by','updated_at']) THEN
    RAISE EXCEPTION 'IMPACT_IMMUTABLE_FIELD: only source status can change' USING ERRCODE = '42501';
  END IF;
  IF NEW.updated_by IS NULL THEN RAISE EXCEPTION 'IMPACT_ACTOR_REQUIRED' USING ERRCODE = '23502'; END IF;
  -- Codex I1G2-05: every accepted write is audited, so a no-op write is refused.
  IF NEW.status = OLD.status THEN RAISE EXCEPTION 'IMPACT_NOOP: status unchanged' USING ERRCODE = '22023'; END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.impact_claims_validate() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  PERFORM public.impact_ts(NEW.extracted_at);
  IF NEW.period_from IS NOT NULL AND NEW.period_to IS NOT NULL
     AND public.impact_ts(NEW.period_from) > public.impact_ts(NEW.period_to) THEN
    RAISE EXCEPTION 'IMPACT_TEMPORAL: reversed claim period' USING ERRCODE = '22007';
  END IF;
  PERFORM public.impact_ts(NEW.period_from);
  PERFORM public.impact_ts(NEW.period_to);
  RETURN NEW;
END $$;

-- Evidence: an observed period must lie at or before the source's retrieval.
CREATE OR REPLACE FUNCTION public.impact_evidence_validate() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_retrieved timestamptz;
BEGIN
  SELECT public.impact_ts(s.retrieved_at) INTO v_retrieved
  FROM public.impact_sources s WHERE s.investigation_id = NEW.investigation_id AND s.ref = NEW.source_ref;
  PERFORM public.impact_ts(NEW.added_at);
  IF NEW.observed_from IS NOT NULL AND NEW.observed_to IS NOT NULL
     AND public.impact_ts(NEW.observed_from) > public.impact_ts(NEW.observed_to) THEN
    RAISE EXCEPTION 'IMPACT_TEMPORAL: reversed observed period' USING ERRCODE = '22007';
  END IF;
  IF (NEW.observed_from IS NOT NULL AND public.impact_ts(NEW.observed_from) > v_retrieved)
     OR (NEW.observed_to IS NOT NULL AND public.impact_ts(NEW.observed_to) > v_retrieved) THEN
    RAISE EXCEPTION 'IMPACT_TEMPORAL: observed period extends past retrieval' USING ERRCODE = '22007';
  END IF;
  RETURN NEW;
END $$;

-- Verifications: version assigned by the database under the investigation
-- lock (no lost update between concurrent runs).
CREATE OR REPLACE FUNCTION public.impact_verifications_version() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  PERFORM 1 FROM public.impact_investigations WHERE id = NEW.investigation_id FOR UPDATE;
  SELECT coalesce(max(v.version), 0) + 1 INTO NEW.version
  FROM public.impact_verifications v WHERE v.investigation_id = NEW.investigation_id AND v.claim_ref = NEW.claim_ref;
  PERFORM public.impact_ts(NEW.evaluated_at);
  RETURN NEW;
END $$;

-- Codex I1G2-06: the stored engine result must be internally consistent with
-- the investigation it is stored in. Every evidence item it cites must be
-- evidence of THIS claim; counted (supporting / partial / contradicting) items
-- must come from PROVIDER sources (independence requires trusted provenance);
-- the status must be backed by items of the matching kind; a FACT needs an
-- AUTHORITATIVE supporting item; an unconfirmed identity cannot yield a
-- supported/contradicted underlying status; gaps/rules/kind/subject match.
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
  -- Codex I1F-01: every COUNTED item is re-derived from the stored evidence and
  -- source rows — authority from the mirrored table, trusted PROVIDER
  -- provenance, ACTIVE source, not self-published, not user-submitted, not an
  -- LLM suggestion, about the subject, and an effective relationship that the
  -- stored relationship/basis/quantities actually produce (a non-final legal
  -- stage never contradicts).
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

-- Disputes: cited evidence must belong to the disputed claim; a dispute can
-- only be resolved once and nothing else changes.
CREATE OR REPLACE FUNCTION public.impact_disputes_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.impact_ts(NEW.opened_at);
    IF EXISTS (
      SELECT 1 FROM unnest(NEW.submitted_evidence_refs) AS r(ref)
      WHERE NOT EXISTS (SELECT 1 FROM public.impact_evidence e
                        WHERE e.investigation_id = NEW.investigation_id AND e.ref = r.ref AND e.claim_ref = NEW.claim_ref)) THEN
      RAISE EXCEPTION 'IMPACT_DISPUTE_EVIDENCE_NOT_OF_CLAIM' USING ERRCODE = '23503';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD.resolution IS NOT NULL THEN RAISE EXCEPTION 'IMPACT_DISPUTE_ALREADY_RESOLVED' USING ERRCODE = '42501'; END IF;
  IF (to_jsonb(NEW) - ARRAY['resolution','resolved_at','updated_by']) <> (to_jsonb(OLD) - ARRAY['resolution','resolved_at','updated_by']) THEN
    RAISE EXCEPTION 'IMPACT_IMMUTABLE_FIELD: only the resolution can be recorded' USING ERRCODE = '42501';
  END IF;
  IF NEW.resolution IS NULL OR NEW.updated_by IS NULL THEN
    RAISE EXCEPTION 'IMPACT_DISPUTE_RESOLUTION_REQUIRED' USING ERRCODE = '23502';
  END IF;
  PERFORM public.impact_ts(NEW.resolved_at);
  RETURN NEW;
END $$;

-- Audit producers (same transaction as the write they record).
CREATE OR REPLACE FUNCTION public.impact_audit_writes() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_prev_status text;
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

-- Child writes: the investigation must be ACTIVE (inserts AND updates) and
-- the recorded actor must be the investigation owner — a service-layer bug
-- that writes into another user's investigation is refused here.
CREATE OR REPLACE FUNCTION public.impact_require_active() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_status text;
  v_owner uuid;
  v_actor uuid;
BEGIN
  SELECT status, owner_id INTO v_status, v_owner FROM public.impact_investigations WHERE id = NEW.investigation_id;
  IF v_status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'IMPACT_INVESTIGATION_NOT_ACTIVE' USING ERRCODE = '42501';
  END IF;
  v_actor := CASE WHEN TG_OP = 'INSERT' THEN (to_jsonb(NEW)->>'created_by')::uuid ELSE (to_jsonb(NEW)->>'updated_by')::uuid END;
  IF v_actor IS DISTINCT FROM v_owner THEN
    RAISE EXCEPTION 'IMPACT_ACTOR_NOT_OWNER' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- ── trigger wiring (idempotent) ─────────────────────────────────────────────

DROP TRIGGER IF EXISTS impact_investigations_guard ON public.impact_investigations;
CREATE TRIGGER impact_investigations_guard BEFORE INSERT OR UPDATE ON public.impact_investigations
  FOR EACH ROW EXECUTE FUNCTION public.impact_investigations_guard();
DROP TRIGGER IF EXISTS impact_sources_guard ON public.impact_sources;
CREATE TRIGGER impact_sources_guard BEFORE INSERT OR UPDATE ON public.impact_sources
  FOR EACH ROW EXECUTE FUNCTION public.impact_sources_guard();
DROP TRIGGER IF EXISTS impact_claims_validate ON public.impact_claims;
CREATE TRIGGER impact_claims_validate BEFORE INSERT ON public.impact_claims
  FOR EACH ROW EXECUTE FUNCTION public.impact_claims_validate();
DROP TRIGGER IF EXISTS impact_evidence_validate ON public.impact_evidence;
CREATE TRIGGER impact_evidence_validate BEFORE INSERT ON public.impact_evidence
  FOR EACH ROW EXECUTE FUNCTION public.impact_evidence_validate();
DROP TRIGGER IF EXISTS impact_verifications_version ON public.impact_verifications;
CREATE TRIGGER impact_verifications_version BEFORE INSERT ON public.impact_verifications
  FOR EACH ROW EXECUTE FUNCTION public.impact_verifications_version();
DROP TRIGGER IF EXISTS impact_verifications_validate ON public.impact_verifications;
CREATE TRIGGER impact_verifications_validate BEFORE INSERT ON public.impact_verifications
  FOR EACH ROW EXECUTE FUNCTION public.impact_verifications_validate();
DROP TRIGGER IF EXISTS impact_disputes_guard ON public.impact_disputes;
CREATE TRIGGER impact_disputes_guard BEFORE INSERT OR UPDATE ON public.impact_disputes
  FOR EACH ROW EXECUTE FUNCTION public.impact_disputes_guard();

DO $$
DECLARE t text;
BEGIN
  -- append-only tables
  FOREACH t IN ARRAY ARRAY['impact_claims','impact_evidence','impact_verifications','impact_conflicts','impact_audit_events'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_append_only ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_append_only BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_guard_append_only()', t);
  END LOOP;
  -- no direct delete anywhere
  FOREACH t IN ARRAY ARRAY['impact_investigations','impact_sources','impact_claims','impact_evidence',
                           'impact_verifications','impact_conflicts','impact_disputes','impact_audit_events'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_no_direct_delete ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_no_direct_delete BEFORE DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_guard_no_direct_delete()', t);
  END LOOP;
  -- child writes need an ACTIVE investigation and the owner as actor
  FOREACH t IN ARRAY ARRAY['impact_claims','impact_evidence','impact_verifications'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_require_active ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_require_active BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_require_active()', t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['impact_sources','impact_disputes'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_require_active ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_require_active BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_require_active()', t);
  END LOOP;
  -- database-only tables
  FOREACH t IN ARRAY ARRAY['impact_audit_events','impact_conflicts'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_trigger_only ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_trigger_only BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_guard_trigger_only()', t);
  END LOOP;
  -- audit producers
  FOREACH t IN ARRAY ARRAY['impact_investigations','impact_sources','impact_claims','impact_evidence','impact_verifications','impact_disputes'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_audit_writes ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_audit_writes AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_audit_writes()', t);
  END LOOP;
END $$;

-- ── RLS + privileges ────────────────────────────────────────────────────────

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['impact_investigations','impact_sources','impact_claims','impact_evidence',
                           'impact_verifications','impact_conflicts','impact_disputes','impact_audit_events'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    -- NO FORCE: the table owner is only used by migrations and the SECURITY
    -- DEFINER audit writer; clients never act as the owner.
    EXECUTE format('ALTER TABLE public.%I NO FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon', t);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC', t);
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.%I FROM authenticated', t);
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO authenticated', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS impact_investigations_select_own ON public.impact_investigations;
CREATE POLICY impact_investigations_select_own ON public.impact_investigations
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid()
         AND (project_id IS NULL OR EXISTS (
           SELECT 1 FROM public.projects p WHERE p.id = impact_investigations.project_id AND p.user_id = auth.uid())));

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['impact_sources','impact_claims','impact_evidence','impact_verifications',
                           'impact_conflicts','impact_disputes','impact_audit_events'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_own', t);
    EXECUTE format($p$CREATE POLICY %I ON public.%I FOR SELECT TO authenticated
      USING (EXISTS (SELECT 1 FROM public.impact_investigations i
                     WHERE i.id = %I.investigation_id AND i.owner_id = auth.uid()))$p$, t || '_select_own', t, t);
  END LOOP;
END $$;

-- service_role writes (Edge Function). FORCE RLS does not affect BYPASSRLS roles.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['impact_investigations','impact_sources','impact_claims','impact_evidence',
                           'impact_verifications','impact_disputes'] LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM service_role', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE public.%I TO service_role', t);
  END LOOP;
  -- audit and conflicts: database-written only
  FOREACH t IN ARRAY ARRAY['impact_audit_events','impact_conflicts'] LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM service_role', t);
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO service_role', t);
  END LOOP;
END $$;

-- Helper functions: internal only, except the chain verifier (invoker rights).
REVOKE ALL ON FUNCTION public.impact_append_audit(uuid, text, text, text[], text[]) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.impact_audit_writes() FROM PUBLIC, anon, authenticated, service_role;

-- Latest verification per claim (I1G1-02): complete regardless of history
-- length. security_invoker → the caller's RLS applies.
CREATE OR REPLACE VIEW public.impact_latest_verifications WITH (security_invoker = true) AS
  SELECT DISTINCT ON (v.investigation_id, v.claim_ref) v.*
  FROM public.impact_verifications v
  ORDER BY v.investigation_id, v.claim_ref, v.version DESC;
REVOKE ALL ON public.impact_latest_verifications FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.impact_latest_verifications TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.impact_audit_chain_ok(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.impact_audit_chain_ok(uuid) TO authenticated, service_role;
