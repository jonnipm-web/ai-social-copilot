-- IV-IMPACT-I3-EVIDENCE-COLLECTION-01 — Evidence Collection for the Impact Lab.
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
-- Minimal extension of 20260924010000 + 20260925010000
-- (docs/impact/IMPACT_ARTIFACT_MODEL.md, IMPACT_EVIDENCE_COLLECTION.md):
--   * impact_artifacts: one row per ORIGINAL file of an investigation — the
--     SERVER-computed SHA-256 of the bytes, a content-free structure index
--     (pages / sheets / rows …) and provenance (origin, client-declared cloud
--     reference, version chain). Original bytes are NOT stored (minimization;
--     no storage bucket exists or is created). Dedup per investigation only
--     (UNIQUE (investigation_id, file_hash)) → no cross-investigation side
--     channel. Append-only; a changed file is a NEW version (supersedes_ref,
--     no forks). Its source is a USER_UPLOAD USER_DOCUMENT whose content_hash
--     is the file hash — never PROVIDER, never authority (CF-06).
--   * impact_evidence_candidates: extracted excerpts at a verifiable locator,
--     bound to the artifact hash, excerpt hash recomputed by the database.
--     Candidates are NOT evidence. Only the review fields may change, once
--     (PENDING / NEEDS_CONTEXT → ACCEPTED | REJECTED | NEEDS_CONTEXT), by the
--     owner. ACCEPTED requires the promoted evidence row to match the
--     candidate exactly (claim, source, excerpt, locator, relationship).
--   * evidence carrying an artifact locator can only be such a promotion.
--   * audit: ARTIFACT_INGESTED, ARTIFACT_VERSIONED, EXTRACTION_COMPLETED,
--     EVIDENCE_CANDIDATE_CREATED, EVIDENCE_CANDIDATE_REVIEWED, EVIDENCE_PROMOTED.
--
-- SERVICE_ROLE_TRUST_GATE = LAB_ONLY: the database cannot re-hash bytes it
-- does not store; the file hash is trusted from the impact-lab server path
-- (documented residual). Every other invariant here binds service_role too.
--
-- Rollback (Lab): DROP TABLE public.impact_evidence_candidates, public.impact_artifacts;
--   restore the 20260925010000 definitions of impact_evidence_validate and
--   impact_audit_writes and the audit type check.
--
-- Idempotent: safe to re-run.

-- ── helpers ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.impact_column_index(p_letters text) RETURNS integer
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE n integer := 0; i integer;
BEGIN
  FOR i IN 1..length(p_letters) LOOP n := n * 26 + (ascii(substr(p_letters, i, 1)) - 64); END LOOP;
  RETURN n;
END $$;

-- Structural locator validity against the artifact's structure index
-- (artifact_model.ts locatorFitsSummary twin). Content validity is checked by
-- the server at ingestion against its own extraction.
CREATE OR REPLACE FUNCTION public.impact_locator_fits(l jsonb, s jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE
  k text := l->>'kind';
  t text := s->>'type';
  m text[];
  sh jsonb;
BEGIN
  IF jsonb_typeof(l) <> 'object' OR jsonb_typeof(s) <> 'object' THEN RETURN false; END IF;
  IF k = 'PDF_PAGE' THEN
    RETURN t = 'PDF' AND (l - 'kind' - 'page') = '{}'::jsonb AND jsonb_typeof(l->'page') = 'number'
      AND (l->>'page')::numeric >= 1 AND (l->>'page')::numeric <= coalesce((s->>'pages')::numeric, 0);
  ELSIF k = 'DOCX_PARAGRAPH' THEN
    RETURN t = 'DOCX' AND (l - 'kind' - 'paragraph') = '{}'::jsonb AND jsonb_typeof(l->'paragraph') = 'number'
      AND (l->>'paragraph')::numeric >= 1 AND (l->>'paragraph')::numeric <= coalesce((s->>'paragraphs')::numeric, 0);
  ELSIF k = 'DOCX_TABLE_CELL' THEN
    RETURN t = 'DOCX' AND (l - 'kind' - 'table' - 'row' - 'cell') = '{}'::jsonb
      AND (l->>'table')::numeric >= 1 AND (l->>'row')::numeric >= 1 AND (l->>'cell')::numeric >= 1
      AND (l->>'row')::numeric <= jsonb_array_length(coalesce(s->'tables'->((l->>'table')::int - 1), '[]'::jsonb))
      AND (l->>'cell')::numeric <= coalesce((s->'tables'->((l->>'table')::int - 1)->>((l->>'row')::int - 1))::numeric, 0);
  ELSIF k = 'SHEET_CELL' THEN
    IF t <> 'XLSX' OR (l - 'kind' - 'sheet' - 'cell') <> '{}'::jsonb THEN RETURN false; END IF;
    m := regexp_match(l->>'cell', '^([A-Z]{1,3})([1-9][0-9]{0,6})$');
    IF m IS NULL THEN RETURN false; END IF;
    SELECT x INTO sh FROM jsonb_array_elements(coalesce(s->'sheets', '[]'::jsonb)) AS a(x) WHERE x->>'name' = l->>'sheet' LIMIT 1;
    RETURN sh IS NOT NULL AND m[2]::int <= (sh->>'rows')::int AND public.impact_column_index(m[1]) <= (sh->>'columns')::int;
  ELSIF k = 'CSV_CELL' THEN
    RETURN t = 'CSV' AND (l - 'kind' - 'row' - 'column') = '{}'::jsonb
      AND (l->>'row')::numeric >= 1 AND (l->>'column')::numeric >= 1
      AND (l->>'row')::numeric <= coalesce((s->>'rows')::numeric, 0) AND (l->>'column')::numeric <= coalesce((s->>'columns')::numeric, 0);
  ELSIF k = 'JSON_POINTER' THEN
    RETURN t = 'JSON' AND (l - 'kind' - 'pointer') = '{}'::jsonb AND jsonb_typeof(l->'pointer') = 'string'
      AND length(l->>'pointer') <= 500 AND (l->>'pointer' = '' OR left(l->>'pointer', 1) = '/');
  ELSIF k = 'TEXT_LINES' THEN
    RETURN t IN ('TEXT', 'MARKDOWN') AND (l - 'kind' - 'lineStart' - 'lineEnd') = '{}'::jsonb
      AND (l->>'lineStart')::numeric >= 1 AND (l->>'lineEnd')::numeric >= (l->>'lineStart')::numeric
      AND (l->>'lineEnd')::numeric - (l->>'lineStart')::numeric < 200
      AND (l->>'lineEnd')::numeric <= coalesce((s->>'lines')::numeric, 0);
  END IF;
  RETURN false;
EXCEPTION WHEN others THEN
  RETURN false; -- a malformed locator is never valid
END $$;

-- ── artifacts ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_artifacts (
  id                       uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id         uuid        NOT NULL,
  ref                      text        NOT NULL,
  source_ref               text        NOT NULL,
  artifact_type            text        NOT NULL,
  origin_type              text        NOT NULL,
  original_filename        text        NOT NULL,
  media_type               text        NOT NULL,
  size_bytes               integer     NOT NULL,
  file_hash                text        NOT NULL,
  normalized_content_hash  text        NULL,
  hash_algorithm           text        NOT NULL DEFAULT 'SHA-256',
  version                  integer     NOT NULL DEFAULT 1,
  supersedes_ref           text        NULL,
  cloud_provider           text        NULL,
  cloud_file_ref           text        NULL,
  source_modified_at       text        NULL,
  extraction_status        text        NOT NULL,
  extractor_version        text        NOT NULL,
  extraction_summary       jsonb       NOT NULL,
  ingested_at              text        NOT NULL,
  created_by               uuid        NOT NULL,
  created_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_artifacts_pkey PRIMARY KEY (id),
  CONSTRAINT impact_artifacts_ref_key UNIQUE (investigation_id, ref),
  -- Dedup is PER INVESTIGATION: the same file elsewhere is invisible here.
  CONSTRAINT impact_artifacts_hash_key UNIQUE (investigation_id, file_hash),
  -- A version chain never forks.
  CONSTRAINT impact_artifacts_supersedes_key UNIQUE (investigation_id, supersedes_ref),
  CONSTRAINT impact_artifacts_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_artifacts_source_fkey FOREIGN KEY (investigation_id, source_ref)
    REFERENCES public.impact_sources(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_artifacts_supersedes_fkey FOREIGN KEY (investigation_id, supersedes_ref)
    REFERENCES public.impact_artifacts(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_artifacts_ref_check CHECK (public.impact_is_ref(ref) AND source_ref = ref),
  CONSTRAINT impact_artifacts_type_check CHECK (artifact_type IN ('PDF','DOCX','XLSX','CSV','JSON','TEXT','MARKDOWN')),
  CONSTRAINT impact_artifacts_media_check CHECK (media_type = CASE artifact_type
    WHEN 'PDF' THEN 'application/pdf'
    WHEN 'DOCX' THEN 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    WHEN 'XLSX' THEN 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    WHEN 'CSV' THEN 'text/csv' WHEN 'JSON' THEN 'application/json' WHEN 'TEXT' THEN 'text/plain' WHEN 'MARKDOWN' THEN 'text/markdown' END),
  CONSTRAINT impact_artifacts_origin_check CHECK (origin_type IN ('USER_UPLOAD','CLOUD_IMPORT')
    AND ((origin_type = 'CLOUD_IMPORT') = (cloud_provider IS NOT NULL))
    AND ((cloud_provider IS NULL) = (cloud_file_ref IS NULL))
    AND (cloud_provider IS NULL OR cloud_provider IN ('GOOGLE_DRIVE','DROPBOX','ONEDRIVE','BOX','SHAREPOINT'))
    AND (cloud_file_ref IS NULL OR public.impact_is_ref(cloud_file_ref))
    AND (source_modified_at IS NULL OR public.impact_is_iso(source_modified_at))),
  CONSTRAINT impact_artifacts_filename_check CHECK (length(original_filename) BETWEEN 1 AND 200
    AND original_filename !~ '[/\\[:cntrl:]]'
    -- no bidi overrides / zero-width characters (display spoofing)
    AND original_filename !~ ('[' || chr(8203) || '-' || chr(8207) || chr(8234) || '-' || chr(8238)
                              || chr(8294) || '-' || chr(8297) || chr(65279) || ']')
    AND original_filename NOT IN ('.', '..')),
  CONSTRAINT impact_artifacts_size_check CHECK (size_bytes BETWEEN 1 AND 6291456),
  CONSTRAINT impact_artifacts_hash_check CHECK (file_hash ~ '^[0-9a-f]{64}$' AND hash_algorithm = 'SHA-256'
    AND (normalized_content_hash IS NULL OR normalized_content_hash ~ '^[0-9a-f]{64}$')),
  CONSTRAINT impact_artifacts_version_check CHECK (version >= 1 AND ((supersedes_ref IS NULL) = (version = 1))),
  CONSTRAINT impact_artifacts_extraction_check CHECK (
    extraction_status IN ('SUCCESS','PARTIAL','FAILED','UNSUPPORTED','OCR_REQUIRED')
    AND jsonb_typeof(extraction_summary) = 'object'
    AND extraction_summary->>'type' = artifact_type
    AND extraction_summary->>'status' = extraction_status
    AND extraction_summary->>'extractorVersion' = extractor_version
    -- structure only: no content-bearing keys in the summary
    AND NOT (extraction_summary ?| ARRAY['text','segments_text','content','excerpt','cells'])),
  CONSTRAINT impact_artifacts_ingested_check CHECK (public.impact_is_iso(ingested_at))
);
COMMENT ON TABLE public.impact_artifacts IS
  'Original evidence files of an investigation: server hash + structure index + provenance. Bytes are not stored. Append-only.';

CREATE OR REPLACE FUNCTION public.impact_artifacts_validate() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_src public.impact_sources%ROWTYPE; v_prior_version integer;
BEGIN
  SELECT * INTO v_src FROM public.impact_sources s WHERE s.investigation_id = NEW.investigation_id AND s.ref = NEW.source_ref;
  -- The artifact's source is a USER_UPLOAD document carrying the file hash —
  -- never PROVIDER provenance, never a snapshot, never authority.
  IF v_src.acquisition_method IS DISTINCT FROM 'USER_UPLOAD' OR v_src.source_type IS DISTINCT FROM 'USER_DOCUMENT'
     OR v_src.content_hash IS DISTINCT FROM NEW.file_hash OR v_src.retention IS DISTINCT FROM 'HASH_ONLY'
     OR NOT v_src.user_submitted OR v_src.snapshot IS NOT NULL THEN
    RAISE EXCEPTION 'IMPACT_ARTIFACT_SOURCE_INVALID: artifact source must be its own USER_UPLOAD document' USING ERRCODE = '23514';
  END IF;
  IF NEW.supersedes_ref IS NOT NULL THEN
    PERFORM 1 FROM public.impact_investigations WHERE id = NEW.investigation_id FOR UPDATE;
    SELECT a.version INTO v_prior_version FROM public.impact_artifacts a
    WHERE a.investigation_id = NEW.investigation_id AND a.ref = NEW.supersedes_ref;
    IF v_prior_version IS NULL OR NEW.version <> v_prior_version + 1 THEN
      RAISE EXCEPTION 'IMPACT_ARTIFACT_VERSION_INVALID' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- ── evidence candidates ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_evidence_candidates (
  id                     uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id       uuid        NOT NULL,
  ref                    text        NOT NULL,
  artifact_ref           text        NOT NULL,
  artifact_hash          text        NOT NULL,
  locator                jsonb       NOT NULL,
  excerpt                text        NOT NULL,
  excerpt_hash           text        NOT NULL,
  claim_ref              text        NULL,
  proposed_relationship  text        NULL,
  generation_method      text        NOT NULL,
  review_reasons         text[]      NOT NULL DEFAULT '{}',
  review_status          text        NOT NULL DEFAULT 'PENDING',
  review_relationship    text        NULL,
  review_claim_ref       text        NULL,
  review_about_org_ref   text        NULL,
  evidence_ref           text        NULL,
  reviewed_by            uuid        NULL,
  reviewed_at            text        NULL,
  created_by             uuid        NOT NULL,
  updated_by             uuid        NULL,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_evidence_candidates_pkey PRIMARY KEY (id),
  CONSTRAINT impact_evidence_candidates_ref_key UNIQUE (investigation_id, ref),
  CONSTRAINT impact_evidence_candidates_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_candidates_artifact_fkey FOREIGN KEY (investigation_id, artifact_ref)
    REFERENCES public.impact_artifacts(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_candidates_claim_fkey FOREIGN KEY (investigation_id, claim_ref)
    REFERENCES public.impact_claims(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_candidates_review_claim_fkey FOREIGN KEY (investigation_id, review_claim_ref)
    REFERENCES public.impact_claims(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_candidates_evidence_fkey FOREIGN KEY (investigation_id, evidence_ref)
    REFERENCES public.impact_evidence(investigation_id, ref) ON DELETE CASCADE,
  CONSTRAINT impact_evidence_candidates_ref_check CHECK (public.impact_is_ref(ref) AND length(ref) <= 120),
  CONSTRAINT impact_evidence_candidates_excerpt_check CHECK (length(excerpt) BETWEEN 1 AND 1000 AND excerpt_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT impact_evidence_candidates_method_check CHECK (generation_method IN ('ANALYST_LOCATOR','AUTO_VALUE_MATCH','LLM_SUGGESTED')),
  CONSTRAINT impact_evidence_candidates_rel_check CHECK (
    (proposed_relationship IS NULL OR proposed_relationship IN ('SUPPORTS','CONTRADICTS','CONTEXTUALIZES'))
    AND (review_relationship IS NULL OR review_relationship IN ('SUPPORTS','CONTRADICTS','CONTEXTUALIZES'))),
  CONSTRAINT impact_evidence_candidates_reasons_check CHECK (review_reasons <@ ARRAY['AUTOMATED_MATCH','SUBJECT_NOT_MENTIONED',
    'UNTRUSTED_INSTRUCTIONS','PII_REDACTED','EXCERPT_TRUNCATED','FORMULA_CELL','EXTRACTION_PARTIAL']::text[]),
  CONSTRAINT impact_evidence_candidates_status_check CHECK (review_status IN ('PENDING','ACCEPTED','REJECTED','NEEDS_CONTEXT')),
  -- Only ACCEPTED carries a promotion; the other states carry none.
  CONSTRAINT impact_evidence_candidates_promotion_check CHECK (
    CASE WHEN review_status = 'ACCEPTED'
      THEN review_relationship IS NOT NULL AND review_claim_ref IS NOT NULL AND review_about_org_ref IS NOT NULL
           AND evidence_ref IS NOT NULL AND evidence_ref = ref || '.ev'
           AND public.impact_is_ref(review_about_org_ref) AND (claim_ref IS NULL OR claim_ref = review_claim_ref)
      ELSE review_relationship IS NULL AND review_claim_ref IS NULL AND review_about_org_ref IS NULL AND evidence_ref IS NULL END),
  CONSTRAINT impact_evidence_candidates_reviewed_check CHECK (
    (review_status = 'PENDING') = (reviewed_by IS NULL) AND (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND (reviewed_at IS NULL OR public.impact_is_iso(reviewed_at)) AND (reviewed_by IS NULL OR reviewed_by = updated_by))
);
COMMENT ON TABLE public.impact_evidence_candidates IS
  'Extracted excerpts at verifiable locators of an artifact version. NOT evidence until a human review promotes them.';

CREATE OR REPLACE FUNCTION public.impact_candidates_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_art public.impact_artifacts%ROWTYPE; v_ev public.impact_evidence%ROWTYPE;
BEGIN
  SELECT * INTO v_art FROM public.impact_artifacts a WHERE a.investigation_id = NEW.investigation_id AND a.ref = NEW.artifact_ref;
  IF TG_OP = 'INSERT' THEN
    -- bound to the artifact version; excerpt hash recomputed; locator inside the structure
    IF NEW.artifact_hash IS DISTINCT FROM v_art.file_hash
       OR NEW.excerpt_hash IS DISTINCT FROM encode(sha256(convert_to(NEW.excerpt, 'UTF8')), 'hex') THEN
      RAISE EXCEPTION 'IMPACT_CANDIDATE_INVALID: not bound to its artifact / excerpt hash mismatch' USING ERRCODE = '23514';
    END IF;
    IF NOT public.impact_locator_fits(NEW.locator, v_art.extraction_summary) THEN
      RAISE EXCEPTION 'IMPACT_LOCATOR_INVALID: locator outside the artifact structure' USING ERRCODE = '23514';
    END IF;
    IF NEW.review_status <> 'PENDING' THEN
      RAISE EXCEPTION 'IMPACT_CANDIDATE_INVALID: candidates start PENDING' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  -- UPDATE: only the review, once, from PENDING / NEEDS_CONTEXT.
  IF OLD.review_status NOT IN ('PENDING', 'NEEDS_CONTEXT') OR NEW.review_status = 'PENDING' THEN
    RAISE EXCEPTION 'IMPACT_CANDIDATE_INVALID: review is final' USING ERRCODE = '42501';
  END IF;
  IF (to_jsonb(NEW) - ARRAY['review_status','review_relationship','review_claim_ref','review_about_org_ref','evidence_ref',
                            'reviewed_by','reviewed_at','updated_by','updated_at'])
     <> (to_jsonb(OLD) - ARRAY['review_status','review_relationship','review_claim_ref','review_about_org_ref','evidence_ref',
                               'reviewed_by','reviewed_at','updated_by','updated_at']) THEN
    RAISE EXCEPTION 'IMPACT_IMMUTABLE_FIELD: only the review can be recorded' USING ERRCODE = '42501';
  END IF;
  IF NEW.review_status = 'ACCEPTED' THEN
    SELECT * INTO v_ev FROM public.impact_evidence e WHERE e.investigation_id = NEW.investigation_id AND e.ref = NEW.evidence_ref;
    IF v_ev.ref IS NULL OR v_ev.claim_ref <> NEW.review_claim_ref OR v_ev.source_ref <> v_art.source_ref
       OR v_ev.excerpt IS DISTINCT FROM NEW.excerpt OR v_ev.relationship <> NEW.review_relationship
       OR v_ev.relationship_basis <> 'HUMAN_ASSESSED' OR v_ev.about_org_ref <> NEW.review_about_org_ref
       OR v_ev.locator->'artifact' IS DISTINCT FROM jsonb_build_object('ref', v_art.ref, 'hash', v_art.file_hash, 'locator', NEW.locator) THEN
      RAISE EXCEPTION 'IMPACT_CANDIDATE_INVALID: promoted evidence does not match the candidate' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- ── evidence validation (20260925010000 + artifact-bound evidence) ─────────

CREATE OR REPLACE FUNCTION public.impact_evidence_validate() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  v_retrieved timestamptz;
  v_src public.impact_sources%ROWTYPE;
  v_claim public.impact_claims%ROWTYPE;
  v_subject text;
  v_asof text;
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
  SELECT i.subject_org_ref INTO v_subject FROM public.impact_investigations i WHERE i.id = NEW.investigation_id;
  -- I2 entity-spoofing guard (Codex I2G1-03): evidence declared to be ABOUT the
  -- subject cannot come from a registry snapshot that does not identify it.
  IF v_src.snapshot IS NOT NULL AND NEW.about_org_ref = v_subject
     AND NOT public.impact_snapshot_identifies_subject(NEW.investigation_id, v_src.snapshot) THEN
    RAISE EXCEPTION 'IMPACT_ENTITY_MISMATCH: registry record of another organization' USING ERRCODE = '23514';
  END IF;
  -- I2: registry-record evidence is only the provider record supporting the
  -- registry statement generated from that same record — subject, text,
  -- period and observed period all derived from the stored snapshot.
  IF NEW.relationship_basis = 'REGISTRY_RECORD' THEN
    SELECT * INTO v_claim FROM public.impact_claims c WHERE c.investigation_id = NEW.investigation_id AND c.ref = NEW.claim_ref;
    v_asof := public.impact_registry_asof(v_src.snapshot);
    IF v_src.acquisition_method IS DISTINCT FROM 'PROVIDER' OR v_src.snapshot IS NULL OR v_src.status <> 'ACTIVE'
       OR NEW.relationship <> 'SUPPORTS' OR NEW.personal_data <> 'NONE'
       OR NEW.about_org_ref IS DISTINCT FROM v_subject
       OR v_claim.source_ref IS DISTINCT FROM NEW.source_ref OR v_claim.origin IS DISTINCT FROM 'REGISTRY_IMPORT'
       OR v_claim.kind IS DISTINCT FROM 'LEGAL_REGISTRATION'
       OR v_claim.claim_text IS DISTINCT FROM public.impact_registry_statement_text(v_src.publisher, v_src.snapshot)
       OR v_claim.period_from IS DISTINCT FROM v_asof OR v_claim.period_to IS DISTINCT FROM v_asof
       OR NEW.observed_to IS DISTINCT FROM v_asof
       OR NEW.observed_from IS DISTINCT FROM (CASE
            WHEN v_src.snapshot->>'status' = 'REGISTERED' AND v_src.snapshot->>'registeredOn' IS NOT NULL
                 AND left(v_src.snapshot->>'registeredOn', 10) <= v_asof THEN left(v_src.snapshot->>'registeredOn', 10)
            ELSE v_asof END)
       OR NOT public.impact_snapshot_identifies_subject(NEW.investigation_id, v_src.snapshot) THEN
      RAISE EXCEPTION 'IMPACT_REGISTRY_RECORD_INVALID: not the provider record of its own registry statement' USING ERRCODE = '23514';
    END IF;
  END IF;
  -- I3: evidence carrying an artifact locator is ONLY the promotion of a real
  -- candidate of that artifact version (same locator, same server excerpt,
  -- the artifact's own USER_UPLOAD source); a writer cannot mint an
  -- artifact-bound locator.
  -- The source of an artifact carries ONLY reviewed candidates of it: no
  -- free-form evidence may cite an artifact source (review cannot be skipped).
  IF (NEW.locator IS NULL OR NOT NEW.locator ? 'artifact')
     AND EXISTS (SELECT 1 FROM public.impact_artifacts a WHERE a.investigation_id = NEW.investigation_id AND a.source_ref = NEW.source_ref) THEN
    RAISE EXCEPTION 'IMPACT_ARTIFACT_EVIDENCE_INVALID: artifact sources carry only reviewed candidates' USING ERRCODE = '23514';
  END IF;
  IF NEW.locator ? 'artifact' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.impact_evidence_candidates c
      JOIN public.impact_artifacts a ON a.investigation_id = c.investigation_id AND a.ref = c.artifact_ref
      WHERE c.investigation_id = NEW.investigation_id
        AND NEW.ref = c.ref || '.ev'
        AND c.review_status IN ('PENDING', 'NEEDS_CONTEXT')
        AND a.source_ref = NEW.source_ref
        AND NEW.locator = jsonb_build_object('artifact', jsonb_build_object('ref', a.ref, 'hash', a.file_hash, 'locator', c.locator))
        AND NEW.excerpt IS NOT DISTINCT FROM c.excerpt
        AND NEW.excerpt_hash IS NOT DISTINCT FROM c.excerpt_hash
        AND NEW.relationship_basis = 'HUMAN_ASSESSED'
        AND (c.claim_ref IS NULL OR c.claim_ref = NEW.claim_ref)) THEN
      RAISE EXCEPTION 'IMPACT_ARTIFACT_EVIDENCE_INVALID: not the promotion of a candidate of this artifact' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- ── audit event types + producers ──────────────────────────────────────────

ALTER TABLE public.impact_audit_events DROP CONSTRAINT IF EXISTS impact_audit_events_type_check;
ALTER TABLE public.impact_audit_events ADD CONSTRAINT impact_audit_events_type_check CHECK (event_type IN (
  'INVESTIGATION_CREATED','INVESTIGATION_ARCHIVED','SOURCE_ADDED','CLAIM_CREATED','EVIDENCE_ADDED',
  'VERIFICATION_RUN','STATUS_CHANGED','CONFLICT_DETECTED','MANUAL_REVIEW','DISPUTE_OPENED',
  'DISPUTE_RESOLVED','SOURCE_STATUS_CHANGED','CORRECTION',
  'REGISTRY_SNAPSHOT_RECORDED','REGISTRY_CONFLICT_RECORDED',
  'ARTIFACT_INGESTED','ARTIFACT_VERSIONED','EXTRACTION_COMPLETED',
  'EVIDENCE_CANDIDATE_CREATED','EVIDENCE_CANDIDATE_REVIEWED','EVIDENCE_PROMOTED'));

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
  ELSIF TG_TABLE_NAME = 'impact_artifacts' THEN
    PERFORM public.impact_append_audit(NEW.investigation_id, 'ARTIFACT_INGESTED', NEW.created_by::text,
      ARRAY[NEW.ref, NEW.source_ref], ARRAY[NEW.artifact_type, NEW.origin_type, 'v' || NEW.version]);
    IF NEW.supersedes_ref IS NOT NULL THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'ARTIFACT_VERSIONED', NEW.created_by::text,
        ARRAY[NEW.ref, NEW.supersedes_ref], ARRAY['v' || NEW.version]);
    END IF;
    PERFORM public.impact_append_audit(NEW.investigation_id, 'EXTRACTION_COMPLETED', NEW.created_by::text,
      ARRAY[NEW.ref], ARRAY[NEW.extraction_status, NEW.extractor_version]);
  ELSIF TG_TABLE_NAME = 'impact_evidence_candidates' THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM public.impact_append_audit(NEW.investigation_id, 'EVIDENCE_CANDIDATE_CREATED', NEW.created_by::text,
        ARRAY[NEW.ref, NEW.artifact_ref], ARRAY[NEW.generation_method]);
    ELSE
      PERFORM public.impact_append_audit(NEW.investigation_id, 'EVIDENCE_CANDIDATE_REVIEWED', NEW.updated_by::text,
        ARRAY[NEW.ref], ARRAY[NEW.review_status]);
      IF NEW.review_status = 'ACCEPTED' THEN
        PERFORM public.impact_append_audit(NEW.investigation_id, 'EVIDENCE_PROMOTED', NEW.updated_by::text,
          ARRAY[NEW.ref, NEW.evidence_ref, NEW.review_claim_ref], ARRAY[NEW.review_relationship]);
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.impact_audit_writes() FROM PUBLIC, anon, authenticated, service_role;

-- ── triggers ───────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS impact_artifacts_validate ON public.impact_artifacts;
CREATE TRIGGER impact_artifacts_validate BEFORE INSERT ON public.impact_artifacts
  FOR EACH ROW EXECUTE FUNCTION public.impact_artifacts_validate();
DROP TRIGGER IF EXISTS impact_candidates_guard ON public.impact_evidence_candidates;
CREATE TRIGGER impact_candidates_guard BEFORE INSERT OR UPDATE ON public.impact_evidence_candidates
  FOR EACH ROW EXECUTE FUNCTION public.impact_candidates_guard();

DROP TRIGGER IF EXISTS impact_append_only ON public.impact_artifacts;
CREATE TRIGGER impact_append_only BEFORE UPDATE ON public.impact_artifacts
  FOR EACH ROW EXECUTE FUNCTION public.impact_guard_append_only();
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['impact_artifacts','impact_evidence_candidates'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS impact_no_direct_delete ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_no_direct_delete BEFORE DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_guard_no_direct_delete()', t);
    EXECUTE format('DROP TRIGGER IF EXISTS impact_audit_writes ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_audit_writes AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_audit_writes()', t);
    -- child writes need an ACTIVE investigation and the OWNER as actor
    EXECUTE format('DROP TRIGGER IF EXISTS impact_require_active ON public.%I', t);
    EXECUTE format('CREATE TRIGGER impact_require_active BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.impact_require_active()', t);
    -- RLS + privileges
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I NO FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated, service_role', t);
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO authenticated', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_own', t);
    EXECUTE format($p$CREATE POLICY %I ON public.%I FOR SELECT TO authenticated
      USING (EXISTS (SELECT 1 FROM public.impact_investigations i
                     WHERE i.id = %I.investigation_id AND i.owner_id = auth.uid()))$p$, t || '_select_own', t, t);
  END LOOP;
END $$;
-- service_role (impact-lab only): artifacts are insert-only; candidates insert + review update. No DELETE.
GRANT SELECT, INSERT ON TABLE public.impact_artifacts TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.impact_evidence_candidates TO service_role;
