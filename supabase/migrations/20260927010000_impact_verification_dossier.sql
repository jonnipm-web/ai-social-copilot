-- IV-IMPACT-I4-VERIFICATION-DOSSIER-01 — Verification Dossier + I3F-03 closure.
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
--
--   * impact_ingest_artifact(): ONE transaction for source + artifact +
--     candidates (I3F-03). The previous two-write ingestion could leave an
--     orphan USER_UPLOAD source when the artifact write failed or lost a race;
--     now either every row exists or none does. SECURITY INVOKER: it runs with
--     the caller's (service_role) existing INSERT privileges and every row still
--     passes every table trigger — no privilege is added. Nothing is deleted:
--     history is preserved, legacy orphans stay adoptable by an identical
--     re-ingestion (never cited ones only, I3G2-02).
--   * impact_dossier_snapshots: the REGISTER of exported dossiers — metadata
--     only (content hash, as_of, completeness status, claim count, and the
--     audit-chain position it was issued at, bound to a REAL audit event). The
--     dossier content itself is never persisted (it is a deterministic
--     projection of the source-of-truth tables). Append-only, owner-only read,
--     idempotent on (investigation, content_hash); audited as DOSSIER_EXPORTED.
--
-- SERVICE_ROLE_TRUST_GATE = LAB_ONLY unchanged: service_role gets SELECT/INSERT
-- on the register and EXECUTE on the ingestion functions; no UPDATE/DELETE.
--
-- Rollback (Lab): DROP TABLE public.impact_dossier_snapshots; DROP FUNCTION
--   public.impact_ingest_artifact(uuid, jsonb, jsonb, jsonb), public.impact_insert_row(text, jsonb);
--   restore the 20260926010000 impact_audit_writes and audit type check.
--
-- Idempotent: safe to re-run.

-- ── I3F-03: atomic artifact ingestion ─────────────────────────────────────

-- Inserts one JSON row into one of the three ingestion tables. Columns come
-- from the table catalogue (never from the JSON keys as SQL text); an unknown
-- key is refused, so nothing can be smuggled into the statement.
CREATE OR REPLACE FUNCTION public.impact_insert_row(p_table text, p_row jsonb) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  v_rel regclass;
  v_cols text;
BEGIN
  IF p_table NOT IN ('impact_sources', 'impact_artifacts', 'impact_evidence_candidates') OR jsonb_typeof(p_row) <> 'object' THEN
    RAISE EXCEPTION 'IMPACT_ARTIFACT_INVALID: unsupported bundle row' USING ERRCODE = '22023';
  END IF;
  v_rel := ('public.' || p_table)::regclass;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_row) k(name)
             WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a
                               WHERE a.attrelid = v_rel AND a.attname = k.name AND a.attnum > 0 AND NOT a.attisdropped AND a.attgenerated = '')) THEN
    RAISE EXCEPTION 'IMPACT_ARTIFACT_INVALID: unknown column in bundle row' USING ERRCODE = '22023';
  END IF;
  SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY a.attnum) INTO v_cols
  FROM pg_catalog.pg_attribute a
  WHERE a.attrelid = v_rel AND a.attnum > 0 AND NOT a.attisdropped AND a.attgenerated = '' AND p_row ? a.attname;
  EXECUTE format('INSERT INTO %s (%s) SELECT %s FROM jsonb_populate_record(NULL::%s, $1)', v_rel, v_cols, v_cols, v_rel) USING p_row;
END $$;

CREATE OR REPLACE FUNCTION public.impact_ingest_artifact(p_investigation uuid, p_source jsonb, p_artifact jsonb, p_candidates jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE r jsonb;
BEGIN
  IF p_investigation IS NULL OR p_artifact IS NULL
     OR (p_artifact->>'investigation_id') IS DISTINCT FROM p_investigation::text
     OR (p_source IS NOT NULL AND (p_source->>'investigation_id') IS DISTINCT FROM p_investigation::text)
     OR jsonb_typeof(coalesce(p_candidates, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'IMPACT_ARTIFACT_INVALID: bundle does not belong to one investigation' USING ERRCODE = '23514';
  END IF;
  IF p_source IS NOT NULL THEN PERFORM public.impact_insert_row('impact_sources', p_source); END IF;
  PERFORM public.impact_insert_row('impact_artifacts', p_artifact);
  FOR r IN SELECT x FROM jsonb_array_elements(coalesce(p_candidates, '[]'::jsonb)) AS t(x) LOOP
    IF (r->>'investigation_id') IS DISTINCT FROM p_investigation::text THEN
      RAISE EXCEPTION 'IMPACT_ARTIFACT_INVALID: bundle does not belong to one investigation' USING ERRCODE = '23514';
    END IF;
    PERFORM public.impact_insert_row('impact_evidence_candidates', r);
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.impact_insert_row(text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.impact_ingest_artifact(uuid, jsonb, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.impact_insert_row(text, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.impact_ingest_artifact(uuid, jsonb, jsonb, jsonb) TO service_role;

-- ── dossier snapshot register ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_dossier_snapshots (
  id               uuid        NOT NULL DEFAULT gen_random_uuid(),
  investigation_id uuid        NOT NULL,
  ref              text        NOT NULL,
  schema_version   text        NOT NULL,
  content_hash     text        NOT NULL,
  as_of            text        NULL,
  dossier_status   text        NOT NULL,
  claim_count      integer     NOT NULL,
  audit_seq        integer     NOT NULL,
  audit_head       text        NOT NULL,
  exported_at      text        NOT NULL,
  created_by       uuid        NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_dossier_snapshots_pkey PRIMARY KEY (id),
  CONSTRAINT impact_dossier_snapshots_ref_key UNIQUE (investigation_id, ref),
  CONSTRAINT impact_dossier_snapshots_hash_key UNIQUE (investigation_id, content_hash),
  CONSTRAINT impact_dossier_snapshots_investigation_fkey FOREIGN KEY (investigation_id)
    REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  CONSTRAINT impact_dossier_snapshots_audit_fkey FOREIGN KEY (investigation_id, audit_seq)
    REFERENCES public.impact_audit_events(investigation_id, seq) ON DELETE CASCADE,
  CONSTRAINT impact_dossier_snapshots_hash_check CHECK (content_hash ~ '^[0-9a-f]{64}$' AND audit_head ~ '^[0-9a-f]{64}$'
    AND ref = 'dossier-' || left(content_hash, 24)),
  CONSTRAINT impact_dossier_snapshots_schema_check CHECK (schema_version = 'impact-dossier/1'),
  -- completeness of the DOSSIER, never a judgement of the organization
  CONSTRAINT impact_dossier_snapshots_status_check CHECK (dossier_status IN ('COMPLETE','PARTIAL','REVIEW_REQUIRED','INCOMPLETE')),
  CONSTRAINT impact_dossier_snapshots_counts_check CHECK (claim_count >= 0 AND audit_seq >= 1),
  CONSTRAINT impact_dossier_snapshots_time_check CHECK ((as_of IS NULL OR public.impact_is_iso(as_of)) AND public.impact_is_iso(exported_at))
);
COMMENT ON TABLE public.impact_dossier_snapshots IS
  'Register of exported verification dossiers: integrity metadata only (the dossier is a projection, never stored). Append-only.';

CREATE OR REPLACE FUNCTION public.impact_dossier_snapshots_validate() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_owner uuid; v_hash text;
BEGIN
  SELECT owner_id INTO v_owner FROM public.impact_investigations WHERE id = NEW.investigation_id FOR UPDATE;
  IF v_owner IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION 'IMPACT_ACTOR_NOT_OWNER' USING ERRCODE = '42501';
  END IF;
  -- The issued position must be a REAL event of this investigation's chain.
  SELECT e.hash INTO v_hash FROM public.impact_audit_events e WHERE e.investigation_id = NEW.investigation_id AND e.seq = NEW.audit_seq;
  IF v_hash IS DISTINCT FROM NEW.audit_head THEN
    RAISE EXCEPTION 'IMPACT_DOSSIER_INVALID: snapshot not bound to the audit chain' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;

ALTER TABLE public.impact_audit_events DROP CONSTRAINT IF EXISTS impact_audit_events_type_check;
ALTER TABLE public.impact_audit_events ADD CONSTRAINT impact_audit_events_type_check CHECK (event_type IN (
  'INVESTIGATION_CREATED','INVESTIGATION_ARCHIVED','SOURCE_ADDED','CLAIM_CREATED','EVIDENCE_ADDED',
  'VERIFICATION_RUN','STATUS_CHANGED','CONFLICT_DETECTED','MANUAL_REVIEW','DISPUTE_OPENED',
  'DISPUTE_RESOLVED','SOURCE_STATUS_CHANGED','CORRECTION',
  'REGISTRY_SNAPSHOT_RECORDED','REGISTRY_CONFLICT_RECORDED',
  'ARTIFACT_INGESTED','ARTIFACT_VERSIONED','EXTRACTION_COMPLETED',
  'EVIDENCE_CANDIDATE_CREATED','EVIDENCE_CANDIDATE_REVIEWED','EVIDENCE_PROMOTED',
  'DOSSIER_EXPORTED'));

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
  ELSIF TG_TABLE_NAME = 'impact_dossier_snapshots' THEN
    PERFORM public.impact_append_audit(NEW.investigation_id, 'DOSSIER_EXPORTED', NEW.created_by::text,
      ARRAY[NEW.ref], ARRAY[NEW.schema_version, NEW.dossier_status]);
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.impact_audit_writes() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS impact_dossier_snapshots_validate ON public.impact_dossier_snapshots;
CREATE TRIGGER impact_dossier_snapshots_validate BEFORE INSERT ON public.impact_dossier_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.impact_dossier_snapshots_validate();
DROP TRIGGER IF EXISTS impact_append_only ON public.impact_dossier_snapshots;
CREATE TRIGGER impact_append_only BEFORE UPDATE ON public.impact_dossier_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.impact_guard_append_only();
DROP TRIGGER IF EXISTS impact_no_direct_delete ON public.impact_dossier_snapshots;
CREATE TRIGGER impact_no_direct_delete BEFORE DELETE ON public.impact_dossier_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.impact_guard_no_direct_delete();
DROP TRIGGER IF EXISTS impact_audit_writes ON public.impact_dossier_snapshots;
CREATE TRIGGER impact_audit_writes AFTER INSERT ON public.impact_dossier_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.impact_audit_writes();

ALTER TABLE public.impact_dossier_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.impact_dossier_snapshots NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.impact_dossier_snapshots FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.impact_dossier_snapshots TO authenticated;
GRANT SELECT, INSERT ON TABLE public.impact_dossier_snapshots TO service_role;
DROP POLICY IF EXISTS impact_dossier_snapshots_select_own ON public.impact_dossier_snapshots;
CREATE POLICY impact_dossier_snapshots_select_own ON public.impact_dossier_snapshots FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.impact_investigations i
                 WHERE i.id = impact_dossier_snapshots.investigation_id AND i.owner_id = auth.uid()));
