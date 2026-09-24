/**
 * Supabase implementation of ImpactLabStore — IV-IMPACT-I1-PERSISTENCE-RLS-01.
 *
 * Defense in depth (docs/impact/IMPACT_RLS_MODEL.md):
 *  - READS use a client carrying the CALLER's JWT (anon key + Authorization),
 *    so PostgreSQL RLS decides what is visible — a foreign investigation reads
 *    as "not found" even if the service layer had a bug.
 *  - WRITES use the service-role client (authenticated/anon have no write
 *    privilege on impact_* tables at all). They are only issued by the Lab
 *    service AFTER authentication, server-side entitlement and an RLS-bound
 *    ownership read, always with the server-verified investigation id and the
 *    caller's user id as created_by/updated_by. The database re-checks
 *    ownership links, subject binding, append-only history and temporal rules
 *    for this role too (migration 20260924010000).
 *  - No DELETE is ever issued.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import { fail, type ImpactErrorCode, ok, type ImpactResult } from '../_shared/impact/errors.ts';
import type {
  CandidateReview,
  StoredDossierSnapshot,
  ImpactLabStore,
  StoredArtifact,
  StoredCandidate,
  InvestigationData,
  InvestigationRecord,
  NewInvestigation,
  StoredAuditEvent,
  StoredDispute,
  StoredRegistryConflict,
  StoredSource,
  StoredVerification,
} from '../_shared/impact/lab_store.ts';
import type { CanonicalRegistryRecord } from '../_shared/impact/provider.ts';
import type { Claim, EvidenceItem, Source, SourceStatus } from '../_shared/impact/types.ts';
import type { VerificationResult } from '../_shared/impact/verification.ts';

type Row = Record<string, unknown>;
interface PgError {
  code?: string;
  message?: string;
}
interface QueryResult {
  data: unknown;
  error: PgError | null;
  count?: number | null;
}
/** Minimal structural view of the supabase-js client we use (lets tests inject a fake). */
export interface DbClient {
  // deno-lint-ignore no-explicit-any
  from(table: string): any;
  rpc(fn: string, args: Row): PromiseLike<QueryResult>;
}

const READ_LIMIT = 2_000;

// ── error mapping (never leaks SQL text to the client) ─────────────────────

export function mapDbError(e: PgError | null | undefined): ImpactErrorCode {
  const code = e?.code ?? '';
  const msg = e?.message ?? '';
  if (code === '23505') return 'ALREADY_EXISTS';
  if (/IMPACT_INVESTIGATION_NOT_ACTIVE/.test(msg)) return 'INVESTIGATION_NOT_ACTIVE';
  if (/IMPACT_PROJECT_NOT_OWNED/.test(msg)) return 'INVESTIGATION_NOT_FOUND';
  if (/IMPACT_DISPUTE_ALREADY_RESOLVED|IMPACT_NOOP/.test(msg)) return 'ALREADY_EXISTS';
  if (/IMPACT_ACTOR_NOT_OWNER/.test(msg)) return 'INVESTIGATION_NOT_FOUND';
  if (/IMPACT_RESULT_INCONSISTENT/.test(msg)) return 'INTERNAL_ERROR';
  if (/IMPACT_LOCATOR_INVALID/.test(msg)) return 'LOCATOR_INVALID';
  if (/IMPACT_(ARTIFACT|CANDIDATE|DOSSIER)_/.test(msg)) return 'INVALID_REQUEST';
  if (code === '23503' || code === '23514' || code === '22007' || code === '23502' || /IMPACT_(TEMPORAL|INVALID_TIMESTAMP|DISPUTE_EVIDENCE)/.test(msg)) {
    return 'INVALID_REQUEST';
  }
  return 'INTERNAL_ERROR';
}
const dbFail = <T>(e: PgError | null | undefined) => fail<T>(mapDbError(e), 'database rejected the operation');

// ── row mapping (exact round-trip: absent fields stay absent) ──────────────

function put<T extends Row>(o: T, k: string, v: unknown): T {
  if (v !== null && v !== undefined) (o as Row)[k] = v;
  return o;
}

export function sourceToRow(investigationId: string, s: StoredSource, actorId: string): Row {
  const src = s.source;
  return {
    investigation_id: investigationId,
    ref: src.id,
    source_type: src.type,
    publisher: src.publisher,
    publisher_org_ref: src.publisherOrganizationId ?? null,
    uri: src.uri ?? null,
    retrieved_at: src.retrievedAt,
    published_at: src.publishedAt ?? null,
    jurisdiction_country: src.jurisdiction?.country ?? null,
    jurisdiction_registry: src.jurisdiction?.registry ?? null,
    news_genre: src.newsGenre ?? null,
    status: src.status,
    retention: src.retention,
    content_hash: src.contentHash ?? null,
    acquisition_method: src.acquisition.method,
    acquisition_provider_id: src.acquisition.method === 'PROVIDER' ? src.acquisition.providerId : null,
    syndicated_from: src.syndicatedFrom ?? null,
    user_submitted: src.userSubmitted === true,
    snapshot: s.snapshot ?? null,
    // I2 lineage signals (server-derived); canonical_org_id is a generated column.
    derived_from: src.derivedFrom ?? null,
    content_fingerprint: src.contentFingerprint ?? null,
    similarity_sketch: src.similaritySketch ?? null,
    syndication_markers: [...(src.syndicationMarkers ?? [])],
    created_by: actorId,
  };
}

export function rowToSource(r: Row): StoredSource {
  const s: Row = { id: r.ref, type: r.source_type, publisher: r.publisher };
  put(s, 'publisherOrganizationId', r.publisher_org_ref);
  put(s, 'uri', r.uri);
  s.retrievedAt = r.retrieved_at;
  put(s, 'publishedAt', r.published_at);
  if (r.jurisdiction_country) {
    s.jurisdiction = put({ country: r.jurisdiction_country } as Row, 'registry', r.jurisdiction_registry);
  }
  put(s, 'newsGenre', r.news_genre);
  s.status = r.status;
  s.retention = r.retention;
  put(s, 'contentHash', r.content_hash);
  s.acquisition = r.acquisition_method === 'PROVIDER'
    ? { method: 'PROVIDER', providerId: r.acquisition_provider_id }
    : { method: r.acquisition_method };
  put(s, 'syndicatedFrom', r.syndicated_from);
  if (r.user_submitted === true) s.userSubmitted = true;
  put(s, 'derivedFrom', r.derived_from);
  put(s, 'contentFingerprint', r.content_fingerprint);
  put(s, 'similaritySketch', r.similarity_sketch);
  if (r.content_fingerprint !== null && r.content_fingerprint !== undefined) {
    // markers are only ever derived together with the fingerprint
    s.syndicationMarkers = Array.isArray(r.syndication_markers) ? r.syndication_markers : [];
  }
  return { source: s as unknown as Source, snapshot: (r.snapshot as CanonicalRegistryRecord | null) ?? null };
}

export function rowToRegistryConflict(r: Row): StoredRegistryConflict {
  return {
    kind: r.kind as StoredRegistryConflict['kind'],
    canonicalOrgId: r.canonical_org_id as string,
    sourceRef: r.source_ref as string,
    otherSourceRef: r.other_source_ref as string,
  };
}

// ── I3 artifacts / candidates ─────────────────────────────────────────────

export function artifactToRow(investigationId: string, a: StoredArtifact, actorId: string): Row {
  return {
    investigation_id: investigationId, ref: a.ref, source_ref: a.sourceRef, artifact_type: a.type, origin_type: a.origin,
    original_filename: a.originalFilename, media_type: a.mediaType, size_bytes: a.sizeBytes, file_hash: a.fileHash,
    normalized_content_hash: a.normalizedContentHash, hash_algorithm: 'SHA-256', version: a.version, supersedes_ref: a.supersedesRef,
    cloud_provider: a.cloudProvider, cloud_file_ref: a.cloudFileRef, source_modified_at: a.sourceModifiedAt,
    extraction_status: a.extractionStatus, extractor_version: a.extraction.extractorVersion, extraction_summary: a.extraction,
    ingested_at: a.ingestedAt, created_by: actorId,
  };
}

export function rowToArtifact(r: Row): StoredArtifact {
  return {
    ref: r.ref as string, sourceRef: r.source_ref as string, type: r.artifact_type as StoredArtifact['type'],
    origin: r.origin_type as StoredArtifact['origin'], originalFilename: r.original_filename as string, mediaType: r.media_type as string,
    sizeBytes: Number(r.size_bytes), fileHash: r.file_hash as string, normalizedContentHash: (r.normalized_content_hash as string | null) ?? null,
    version: Number(r.version), supersedesRef: (r.supersedes_ref as string | null) ?? null,
    cloudProvider: (r.cloud_provider as StoredArtifact['cloudProvider']) ?? null, cloudFileRef: (r.cloud_file_ref as string | null) ?? null,
    sourceModifiedAt: (r.source_modified_at as string | null) ?? null, extractionStatus: r.extraction_status as StoredArtifact['extractionStatus'],
    extraction: r.extraction_summary as StoredArtifact['extraction'], ingestedAt: r.ingested_at as string,
  };
}

export function candidateToRow(investigationId: string, c: StoredCandidate, actorId: string): Row {
  return {
    investigation_id: investigationId, ref: c.ref, artifact_ref: c.artifactRef, artifact_hash: c.artifactHash, locator: c.locator,
    excerpt: c.excerpt, excerpt_hash: c.excerptHash, claim_ref: c.claimRef, proposed_relationship: c.proposedRelationship,
    generation_method: c.method, review_reasons: [...c.reviewReasons], created_by: actorId,
  };
}

export function rowToCandidate(r: Row): StoredCandidate {
  return {
    ref: r.ref as string, artifactRef: r.artifact_ref as string, artifactHash: r.artifact_hash as string,
    locator: r.locator as StoredCandidate['locator'], excerpt: r.excerpt as string, excerptHash: r.excerpt_hash as string,
    claimRef: (r.claim_ref as string | null) ?? null, proposedRelationship: (r.proposed_relationship as StoredCandidate['proposedRelationship']) ?? null,
    method: r.generation_method as StoredCandidate['method'], reviewReasons: (r.review_reasons as StoredCandidate['reviewReasons']) ?? [],
    reviewStatus: r.review_status as StoredCandidate['reviewStatus'],
    reviewRelationship: (r.review_relationship as StoredCandidate['reviewRelationship']) ?? null,
    reviewClaimRef: (r.review_claim_ref as string | null) ?? null, reviewAboutOrgRef: (r.review_about_org_ref as string | null) ?? null,
    evidenceRef: (r.evidence_ref as string | null) ?? null, reviewedAt: (r.reviewed_at as string | null) ?? null,
  };
}

export function claimToRow(investigationId: string, c: Claim, actorId: string): Row {
  return {
    investigation_id: investigationId,
    ref: c.id,
    kind: c.kind,
    claim_text: c.text,
    text_language: c.textLanguage ?? null,
    quantity_metric: c.quantity?.metric ?? null,
    quantity_value: c.quantity?.value ?? null,
    quantity_unit: c.quantity?.unit ?? null,
    impact_level: c.level ?? null,
    claimant_org_ref: c.claimantOrganizationId ?? null,
    claimant_label: c.claimantLabel ?? null,
    subject_org_ref: c.subjectOrganizationId,
    subject_project_ref: c.subjectProjectId ?? null,
    subject_campaign_ref: c.subjectCampaignId ?? null,
    period_from: c.period?.from ?? null,
    period_to: c.period?.to ?? null,
    source_ref: c.sourceId,
    extracted_at: c.extractedAt,
    origin: c.origin,
    created_by: actorId,
  };
}

export function rowToClaim(r: Row): Claim {
  const c: Row = { id: r.ref, investigationId: r.investigation_id, kind: r.kind, text: r.claim_text };
  put(c, 'textLanguage', r.text_language);
  if (r.quantity_metric != null) c.quantity = { metric: r.quantity_metric, value: Number(r.quantity_value), unit: r.quantity_unit };
  put(c, 'level', r.impact_level);
  put(c, 'claimantOrganizationId', r.claimant_org_ref);
  put(c, 'claimantLabel', r.claimant_label);
  c.subjectOrganizationId = r.subject_org_ref;
  put(c, 'subjectProjectId', r.subject_project_ref);
  put(c, 'subjectCampaignId', r.subject_campaign_ref);
  if (r.period_from != null || r.period_to != null) c.period = put(put({} as Row, 'from', r.period_from), 'to', r.period_to);
  c.sourceId = r.source_ref;
  c.extractedAt = r.extracted_at;
  c.origin = r.origin;
  return c as unknown as Claim;
}

export function evidenceToRow(investigationId: string, e: EvidenceItem, actorId: string): Row {
  return {
    investigation_id: investigationId,
    ref: e.id,
    claim_ref: e.claimId,
    source_ref: e.sourceId,
    about_org_ref: e.aboutOrganizationId,
    relationship: e.relationship,
    relationship_basis: e.relationshipBasis,
    reported_metric: e.reportedQuantity?.metric ?? null,
    reported_value: e.reportedQuantity?.value ?? null,
    reported_unit: e.reportedQuantity?.unit ?? null,
    impact_level: e.level ?? null,
    observed_from: e.observedPeriod?.from ?? null,
    observed_to: e.observedPeriod?.to ?? null,
    excerpt: e.excerpt ?? null,
    excerpt_hash: e.excerptHash ?? null,
    locator: e.locator ?? null,
    personal_data: e.personalData,
    legal_stage: e.legalStage ?? null,
    added_at: e.addedAt,
    created_by: actorId,
  };
}

export function rowToEvidence(r: Row): EvidenceItem {
  const e: Row = {
    id: r.ref, investigationId: r.investigation_id, claimId: r.claim_ref, sourceId: r.source_ref,
    aboutOrganizationId: r.about_org_ref, relationship: r.relationship, relationshipBasis: r.relationship_basis,
  };
  if (r.reported_metric != null) e.reportedQuantity = { metric: r.reported_metric, value: Number(r.reported_value), unit: r.reported_unit };
  put(e, 'level', r.impact_level);
  if (r.observed_from != null || r.observed_to != null) e.observedPeriod = put(put({} as Row, 'from', r.observed_from), 'to', r.observed_to);
  put(e, 'excerpt', r.excerpt);
  put(e, 'excerptHash', r.excerpt_hash);
  put(e, 'locator', r.locator);
  e.personalData = r.personal_data;
  put(e, 'legalStage', r.legal_stage);
  e.addedAt = r.added_at;
  return e as unknown as EvidenceItem;
}

function rowToInvestigation(r: Row): InvestigationRecord {
  return {
    id: r.id as string,
    ownerId: r.owner_id as string,
    projectId: (r.project_id as string | null) ?? null,
    subjectOrgRef: r.subject_org_ref as string,
    subjectOrgType: r.subject_org_type as InvestigationRecord['subjectOrgType'],
    subjectIdentity: (r.subject_identity ?? {}) as InvestigationRecord['subjectIdentity'],
    status: r.status as InvestigationRecord['status'],
    auditSeq: r.audit_seq as number,
    auditHead: r.audit_head as string,
    createdAt: r.created_at as string,
  };
}

function rowToVerification(r: Row): StoredVerification {
  return { version: r.version as number, result: r.result as VerificationResult, idempotencyKey: (r.idempotency_key as string | null) ?? null };
}

function rowToDispute(r: Row): StoredDispute {
  return {
    ref: r.ref as string, claimRef: r.claim_ref as string, kind: r.kind as StoredDispute['kind'], openedAt: r.opened_at as string,
    submittedEvidenceRefs: (r.submitted_evidence_refs as string[]) ?? [], resolution: (r.resolution as StoredDispute['resolution']) ?? null,
    resolvedAt: (r.resolved_at as string | null) ?? null,
  };
}

function rowToAudit(r: Row): StoredAuditEvent {
  return {
    seq: r.seq as number, atText: r.at_text as string, eventType: r.event_type as string, actorRef: r.actor_ref as string,
    refs: (r.refs as string[]) ?? [], codes: (r.codes as string[]) ?? [], prevHash: r.prev_hash as string, hash: r.hash as string,
  };
}

// ── store ───────────────────────────────────────────────────────────────────

export class SupabaseImpactLabStore implements ImpactLabStore {
  constructor(private readonly user: DbClient, private readonly service: DbClient) {}

  async getInvestigation(id: string): Promise<ImpactResult<InvestigationRecord | null>> {
    const { data, error } = await this.user.from('impact_investigations').select('*').eq('id', id).maybeSingle();
    if (error) return dbFail(error);
    return ok(data ? rowToInvestigation(data as Row) : null);
  }
  async listInvestigations(): Promise<ImpactResult<readonly InvestigationRecord[]>> {
    const { data, error } = await this.user.from('impact_investigations').select('*').order('created_at', { ascending: false }).limit(100);
    if (error) return dbFail(error);
    return ok((data as Row[]).map(rowToInvestigation));
  }
  async countOwnedInvestigations(ownerId: string): Promise<ImpactResult<number>> {
    // Service read by owner: project-hidden investigations still count toward the limit.
    const { count, error } = await this.service.from('impact_investigations').select('id', { count: 'exact', head: true }).eq('owner_id', ownerId);
    if (error) return dbFail(error);
    return ok(count ?? 0);
  }
  async projectOwnedByCaller(projectId: string): Promise<ImpactResult<boolean>> {
    const { data, error } = await this.user.from('projects').select('id').eq('id', projectId).maybeSingle();
    if (error) return dbFail(error);
    return ok(!!data);
  }
  async loadInvestigationData(id: string): Promise<ImpactResult<InvestigationData>> {
    const q = (t: string, order: string, ascending = true, limit = READ_LIMIT) =>
      this.user.from(t).select('*').eq('investigation_id', id).order(order, { ascending }).limit(limit);
    const [s, c, e, lv, v, d, rc, ar, ca] = await Promise.all([
      q('impact_sources', 'created_at'), q('impact_claims', 'created_at'), q('impact_evidence', 'created_at'),
      // I1G1-02: latest per claim from the security_invoker view — never truncated by history length.
      q('impact_latest_verifications', 'claim_ref'),
      q('impact_verifications', 'version', false, 500),
      q('impact_disputes', 'created_at'),
      q('impact_registry_conflicts', 'seq'),
      q('impact_artifacts', 'created_at'),
      q('impact_evidence_candidates', 'created_at', true, 5_000),
    ]);
    for (const r of [s, c, e, lv, v, d, rc, ar, ca]) if (r.error) return dbFail(r.error);
    return ok({
      sources: (s.data as Row[]).map(rowToSource),
      claims: (c.data as Row[]).map(rowToClaim),
      evidence: (e.data as Row[]).map(rowToEvidence),
      latestVerifications: (lv.data as Row[]).map(rowToVerification),
      verifications: (v.data as Row[]).map(rowToVerification),
      disputes: (d.data as Row[]).map(rowToDispute),
      registryConflicts: (rc.data as Row[]).map(rowToRegistryConflict),
      artifacts: (ar.data as Row[]).map(rowToArtifact),
      candidates: (ca.data as Row[]).map(rowToCandidate),
    });
  }
  async listAudit(id: string): Promise<ImpactResult<readonly StoredAuditEvent[]>> {
    const { data, error } = await this.user.from('impact_audit_events').select('*').eq('investigation_id', id).order('seq', { ascending: true }).limit(10_000);
    if (error) return dbFail(error);
    return ok((data as Row[]).map(rowToAudit));
  }
  async auditChainOk(id: string): Promise<ImpactResult<boolean>> {
    const { data, error } = await this.user.rpc('impact_audit_chain_ok', { p_investigation: id });
    if (error) return dbFail(error);
    return ok(data === true);
  }

  async createInvestigation(n: NewInvestigation): Promise<ImpactResult<InvestigationRecord>> {
    const { data, error } = await this.service.from('impact_investigations').insert({
      owner_id: n.ownerId, project_id: n.projectId, subject_org_ref: n.subjectOrgRef,
      subject_org_type: n.subjectOrgType, subject_identity: n.subjectIdentity,
    }).select('*').single();
    if (error) return dbFail(error);
    return ok(rowToInvestigation(data as Row));
  }
  async archiveInvestigation(id: string, actorId: string): Promise<ImpactResult<true>> {
    const { data, error } = await this.service.from('impact_investigations').update({ status: 'ARCHIVED', updated_by: actorId, updated_at: new Date().toISOString() })
      .eq('id', id).eq('status', 'ACTIVE').select('id');
    if (error) return dbFail(error);
    // Codex I1F-03: success only if a row actually transitioned.
    return (data as Row[] | null)?.length === 1 ? ok(true) : fail('INVESTIGATION_NOT_ACTIVE', 'investigation is not active');
  }
  async insertSource(investigationId: string, s: StoredSource, actorId: string): Promise<ImpactResult<true>> {
    const { error } = await this.service.from('impact_sources').insert(sourceToRow(investigationId, s, actorId));
    return error ? dbFail(error) : ok(true);
  }
  async updateSourceStatus(investigationId: string, ref: string, status: SourceStatus, actorId: string): Promise<ImpactResult<true>> {
    const { data, error } = await this.service.from('impact_sources').update({ status, updated_by: actorId, updated_at: new Date().toISOString() })
      .eq('investigation_id', investigationId).eq('ref', ref).select('ref');
    if (error) return dbFail(error);
    return (data as Row[] | null)?.length === 1 ? ok(true) : fail('INVALID_REQUEST', 'source not updated');
  }
  async insertClaim(investigationId: string, c: Claim, actorId: string): Promise<ImpactResult<true>> {
    const { error } = await this.service.from('impact_claims').insert(claimToRow(investigationId, c, actorId));
    return error ? dbFail(error) : ok(true);
  }
  async insertEvidence(investigationId: string, e: EvidenceItem, actorId: string): Promise<ImpactResult<true>> {
    const { error } = await this.service.from('impact_evidence').insert(evidenceToRow(investigationId, e, actorId));
    return error ? dbFail(error) : ok(true);
  }
  private async findVerification(investigationId: string, col: 'idempotency_key' | 'result_id', v: string): Promise<ImpactResult<StoredVerification | null>> {
    const { data, error } = await this.service.from('impact_verifications').select('*').eq('investigation_id', investigationId).eq(col, v).maybeSingle();
    if (error) return dbFail(error);
    return ok(data ? rowToVerification(data as Row) : null);
  }
  async insertVerification(investigationId: string, r: VerificationResult, idempotencyKey: string | null, actorId: string): Promise<ImpactResult<StoredVerification>> {
    if (idempotencyKey) {
      const prior = await this.findVerification(investigationId, 'idempotency_key', idempotencyKey);
      if (!prior.ok || prior.value) return prior as ImpactResult<StoredVerification>;
    }
    const row = {
      investigation_id: investigationId, claim_ref: r.claimId, result_id: r.resultId, status: r.status,
      underlying_status: r.underlyingStatus, sufficiency: r.sufficiency, display_class: r.displayClass, review_state: r.reviewState,
      policy_version: r.policyVersion, evidence_set_hash: r.evidenceSetHash, review_binding_hash: r.reviewBindingHash,
      evaluated_at: r.evaluatedAt, rules_applied: r.rulesApplied, gaps: r.gaps, conflict_count: r.conflicts.length,
      result: r, idempotency_key: idempotencyKey, created_by: actorId,
    };
    const { data, error } = await this.service.from('impact_verifications').insert(row).select('*').single();
    if (!error) return ok(rowToVerification(data as Row));
    if (error.code === '23505') {
      // Retry race: return the row that won (same key or same resultId) — never a duplicate.
      const byKey = idempotencyKey ? await this.findVerification(investigationId, 'idempotency_key', idempotencyKey) : ok(null);
      if (byKey.ok && byKey.value) return ok(byKey.value);
      const byResult = await this.findVerification(investigationId, 'result_id', r.resultId);
      if (byResult.ok && byResult.value) return ok(byResult.value);
    }
    return dbFail(error);
  }
  async insertDispute(investigationId: string, d: StoredDispute, actorId: string): Promise<ImpactResult<true>> {
    const { error } = await this.service.from('impact_disputes').insert({
      investigation_id: investigationId, ref: d.ref, claim_ref: d.claimRef, kind: d.kind, opened_at: d.openedAt,
      submitted_evidence_refs: d.submittedEvidenceRefs, created_by: actorId,
    });
    return error ? dbFail(error) : ok(true);
  }
  async resolveDispute(investigationId: string, ref: string, resolution: NonNullable<StoredDispute['resolution']>, resolvedAt: string, actorId: string): Promise<ImpactResult<true>> {
    const { data, error } = await this.service.from('impact_disputes').update({ resolution, resolved_at: resolvedAt, updated_by: actorId })
      .eq('investigation_id', investigationId).eq('ref', ref).is('resolution', null).select('ref');
    if (error) return dbFail(error);
    return (data as Row[]).length === 1 ? ok(true) : fail('ALREADY_EXISTS', 'dispute already resolved');
  }
  async insertArtifact(investigationId: string, a: StoredArtifact, actorId: string): Promise<ImpactResult<true>> {
    const { error } = await this.service.from('impact_artifacts').insert(artifactToRow(investigationId, a, actorId));
    return error ? dbFail(error) : ok(true);
  }
  async insertCandidates(investigationId: string, cs: readonly StoredCandidate[], actorId: string): Promise<ImpactResult<true>> {
    // One INSERT statement: all candidates of a request, or none.
    const { error } = await this.service.from('impact_evidence_candidates').insert(cs.map((c) => candidateToRow(investigationId, c, actorId)));
    return error ? dbFail(error) : ok(true);
  }
  async reviewCandidate(investigationId: string, ref: string, r: CandidateReview, actorId: string): Promise<ImpactResult<true>> {
    const { data, error } = await this.service.from('impact_evidence_candidates').update({
      review_status: r.status, review_relationship: r.relationship, review_claim_ref: r.claimRef, review_about_org_ref: r.aboutOrgRef,
      evidence_ref: r.evidenceRef, reviewed_by: actorId, reviewed_at: r.reviewedAt, updated_by: actorId, updated_at: new Date().toISOString(),
    }).eq('investigation_id', investigationId).eq('ref', ref).in('review_status', ['PENDING', 'NEEDS_CONTEXT']).select('ref');
    if (error) return dbFail(error);
    // Codex I1F-03 pattern: success only if a row actually transitioned.
    return (data as Row[]).length === 1 ? ok(true) : fail('ALREADY_EXISTS', 'candidate already reviewed');
  }
  // ── I4 ──────────────────────────────────────────────────────────────────
  async insertArtifactBundle(
    investigationId: string,
    b: { readonly source: Source | null; readonly artifact: StoredArtifact; readonly candidates: readonly StoredCandidate[] },
    actorId: string,
  ): Promise<ImpactResult<true>> {
    // ONE database transaction (I3F-03): impact_ingest_artifact() inserts every row or none.
    const { error } = await this.service.rpc('impact_ingest_artifact', {
      p_investigation: investigationId,
      p_source: b.source ? sourceToRow(investigationId, { source: b.source, snapshot: null }, actorId) : null,
      p_artifact: artifactToRow(investigationId, b.artifact, actorId),
      p_candidates: b.candidates.map((c) => candidateToRow(investigationId, c, actorId)),
    });
    return error ? dbFail(error) : ok(true);
  }
  async insertDossierSnapshot(investigationId: string, d: StoredDossierSnapshot, actorId: string): Promise<ImpactResult<StoredDossierSnapshot>> {
    const { data, error } = await this.service.from('impact_dossier_snapshots').insert({
      investigation_id: investigationId, ref: d.ref, schema_version: d.schemaVersion, content_hash: d.contentHash, as_of: d.asOf,
      dossier_status: d.dossierStatus, claim_count: d.claimCount, audit_seq: d.auditSeq, audit_head: d.auditHead, exported_at: d.exportedAt,
      created_by: actorId,
    }).select('*');
    if (!error) return ok(rowToDossierSnapshot((data as Row[])[0]));
    if (error.code !== '23505') return dbFail(error);
    // Idempotent: the same content was already exported — return the ORIGINAL registration.
    const prior = await this.findDossierSnapshot(investigationId, d.contentHash);
    if (!prior.ok) return prior;
    return prior.value ? ok(prior.value) : dbFail(error);
  }
  async findDossierSnapshot(investigationId: string, contentHash: string): Promise<ImpactResult<StoredDossierSnapshot | null>> {
    const { data, error } = await this.service.from('impact_dossier_snapshots').select('*')
      .eq('investigation_id', investigationId).eq('content_hash', contentHash).limit(1);
    if (error) return dbFail(error);
    const rows = data as Row[];
    return ok(rows.length ? rowToDossierSnapshot(rows[0]) : null);
  }
}

export function rowToDossierSnapshot(r: Row): StoredDossierSnapshot {
  return {
    ref: r.ref as string, schemaVersion: r.schema_version as string, contentHash: r.content_hash as string,
    asOf: (r.as_of as string | null) ?? null, dossierStatus: r.dossier_status as string, claimCount: Number(r.claim_count),
    auditSeq: Number(r.audit_seq), auditHead: r.audit_head as string, exportedAt: r.exported_at as string,
  };
}

export function createSupabaseImpactLabStore(req: Request): SupabaseImpactLabStore {
  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const token = req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  if (!url || !anon || !serviceKey || !token) throw new Error('impact-lab: missing Supabase configuration');
  const opts = { auth: { autoRefreshToken: false, persistSession: false } };
  const user = createClient(url, anon, { ...opts, global: { headers: { Authorization: `Bearer ${token}` } } });
  const service = createClient(url, serviceKey, opts);
  return new SupabaseImpactLabStore(user as unknown as DbClient, service as unknown as DbClient);
}
