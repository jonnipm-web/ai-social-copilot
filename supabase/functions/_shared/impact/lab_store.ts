/**
 * Impact Lab store contract — IV-IMPACT-I1-PERSISTENCE-RLS-01.
 *
 * `ImpactLabStore` is what the Lab service needs from persistence. The
 * production implementation lives in supabase/functions/impact-lab/
 * (user-scoped RLS reads + service-role writes against migration
 * 20260924010000). `InMemoryImpactLabStore` below mirrors the database
 * invariants (owner scoping, composite refs, append-only history, DB-assigned
 * versions, idempotency keys, subject binding, archive, hash-chained audit
 * written with every write) so the service can be tested deterministically.
 *
 * Audit hash format is IDENTICAL to public.impact_append_audit():
 *   sha256(seq|at|type|actor|investigation|refs(csv)|codes(csv)|prev)
 * (parity vector asserted in lab_service_test.ts and impact_lab_rls_test.sql).
 */
import { fail, ok, type ImpactResult } from './errors.ts';
import { registryConflicts, type RegistryConflictKind } from './organization_identity.ts';
import { type ArtifactLocator, type ArtifactOrigin, type ArtifactType, type CloudProvider, type ExtractionStatus, type ExtractionSummary, locatorKey } from './artifact_model.ts';
import type { CandidateMethod, CandidateRelationship, CandidateReviewReason } from './evidence_candidates.ts';
import type { CanonicalRegistryRecord } from './provider.ts';
import { sha256Hex } from './provenance.ts';
import type { Claim, EvidenceItem, OrganizationIdentity, OrganizationType, Source, SourceStatus } from './types.ts';
import type { VerificationResult } from './verification.ts';

export interface InvestigationRecord {
  readonly id: string;
  readonly ownerId: string;
  readonly projectId: string | null;
  readonly subjectOrgRef: string;
  readonly subjectOrgType: OrganizationType;
  readonly subjectIdentity: OrganizationIdentity;
  readonly status: 'ACTIVE' | 'ARCHIVED';
  readonly auditSeq: number;
  readonly auditHead: string;
  readonly createdAt: string;
}

export interface StoredSource {
  readonly source: Source;
  readonly snapshot: CanonicalRegistryRecord | null;
}

export interface StoredVerification {
  readonly version: number;
  readonly result: VerificationResult;
  readonly idempotencyKey: string | null;
}

export interface StoredDispute {
  readonly ref: string;
  readonly claimRef: string;
  readonly kind: 'ORGANIZATION_RESPONSE' | 'CORRECTION_REQUEST' | 'RETRACTION_REQUEST' | 'SOURCE_UPDATE';
  readonly openedAt: string;
  readonly submittedEvidenceRefs: readonly string[];
  readonly resolution: 'CORRECTED' | 'UPHELD' | 'WITHDRAWN' | 'SOURCE_RETRACTED' | null;
  readonly resolvedAt: string | null;
}

/** Two ACTIVE registry snapshots of one organization disagree (I2). Written
 * only by the database trigger (and its in-memory twin); never a finding. */
export interface StoredRegistryConflict {
  readonly kind: RegistryConflictKind;
  readonly canonicalOrgId: string;
  readonly sourceRef: string;
  readonly otherSourceRef: string;
}

/** I3: an evidence artifact (original bytes are NOT retained — hash + structure only). */
export interface StoredArtifact {
  readonly ref: string;
  readonly sourceRef: string;
  readonly type: ArtifactType;
  readonly origin: ArtifactOrigin;
  readonly originalFilename: string;
  readonly mediaType: string;
  readonly sizeBytes: number;
  /** SHA-256 of the bytes the SERVER received (integrity, not truth). */
  readonly fileHash: string;
  /** Hash of the normalized extracted text (dedup / similarity only). */
  readonly normalizedContentHash: string | null;
  readonly version: number;
  readonly supersedesRef: string | null;
  readonly cloudProvider: CloudProvider | null;
  readonly cloudFileRef: string | null;
  readonly sourceModifiedAt: string | null;
  readonly extractionStatus: ExtractionStatus;
  readonly extraction: ExtractionSummary;
  readonly ingestedAt: string;
}

export type CandidateReviewStatus = 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'NEEDS_CONTEXT';

/** I3: an evidence candidate — never evidence until a human accepts it. */
export interface StoredCandidate {
  readonly ref: string;
  readonly artifactRef: string;
  readonly artifactHash: string;
  readonly locator: ArtifactLocator;
  readonly excerpt: string;
  readonly excerptHash: string;
  readonly claimRef: string | null;
  readonly proposedRelationship: CandidateRelationship | null;
  readonly method: CandidateMethod;
  readonly reviewReasons: readonly CandidateReviewReason[];
  readonly reviewStatus: CandidateReviewStatus;
  readonly reviewRelationship: CandidateRelationship | null;
  readonly reviewClaimRef: string | null;
  readonly reviewAboutOrgRef: string | null;
  readonly evidenceRef: string | null;
  readonly reviewedAt: string | null;
}

export interface CandidateReview {
  readonly status: Exclude<CandidateReviewStatus, 'PENDING'>;
  readonly relationship: CandidateRelationship | null;
  readonly claimRef: string | null;
  readonly aboutOrgRef: string | null;
  readonly evidenceRef: string | null;
  readonly reviewedAt: string;
}

export interface StoredAuditEvent {
  readonly seq: number;
  readonly atText: string;
  readonly eventType: string;
  readonly actorRef: string;
  readonly refs: readonly string[];
  readonly codes: readonly string[];
  readonly prevHash: string;
  readonly hash: string;
}

export interface InvestigationData {
  readonly sources: readonly StoredSource[];
  readonly claims: readonly Claim[];
  readonly evidence: readonly EvidenceItem[];
  /** Latest version per claim — complete, however long the history (I1G1-02). */
  readonly latestVerifications: readonly StoredVerification[];
  /** Recent history, newest first (bounded; for display only). */
  readonly verifications: readonly StoredVerification[];
  readonly disputes: readonly StoredDispute[];
  /** I2: registry disagreements between snapshots of the same organization. */
  readonly registryConflicts: readonly StoredRegistryConflict[];
  /** I3 */
  readonly artifacts: readonly StoredArtifact[];
  readonly candidates: readonly StoredCandidate[];
}

export interface NewInvestigation {
  readonly ownerId: string;
  readonly projectId: string | null;
  readonly subjectOrgRef: string;
  readonly subjectOrgType: OrganizationType;
  readonly subjectIdentity: OrganizationIdentity;
}

/**
 * Reads are scoped to the CALLER (RLS in production): an investigation the
 * caller does not own reads as null / empty. Writes are server-side and must
 * receive only server-verified investigation ids and the caller's user id.
 */
export interface ImpactLabStore {
  getInvestigation(id: string): Promise<ImpactResult<InvestigationRecord | null>>;
  listInvestigations(): Promise<ImpactResult<readonly InvestigationRecord[]>>;
  /** Counts every investigation of the owner (including project-hidden ones). */
  countOwnedInvestigations(ownerId: string): Promise<ImpactResult<number>>;
  projectOwnedByCaller(projectId: string): Promise<ImpactResult<boolean>>;
  loadInvestigationData(id: string): Promise<ImpactResult<InvestigationData>>;
  listAudit(id: string): Promise<ImpactResult<readonly StoredAuditEvent[]>>;
  auditChainOk(id: string): Promise<ImpactResult<boolean>>;

  createInvestigation(n: NewInvestigation): Promise<ImpactResult<InvestigationRecord>>;
  archiveInvestigation(id: string, actorId: string): Promise<ImpactResult<true>>;
  insertSource(investigationId: string, s: StoredSource, actorId: string): Promise<ImpactResult<true>>;
  updateSourceStatus(investigationId: string, ref: string, status: SourceStatus, actorId: string): Promise<ImpactResult<true>>;
  insertClaim(investigationId: string, c: Claim, actorId: string): Promise<ImpactResult<true>>;
  insertEvidence(investigationId: string, e: EvidenceItem, actorId: string): Promise<ImpactResult<true>>;
  /** Idempotent on (investigation, idempotencyKey): a retry returns the existing row. */
  insertVerification(investigationId: string, r: VerificationResult, idempotencyKey: string | null, actorId: string): Promise<ImpactResult<StoredVerification>>;
  insertDispute(investigationId: string, d: StoredDispute, actorId: string): Promise<ImpactResult<true>>;
  resolveDispute(investigationId: string, ref: string, resolution: NonNullable<StoredDispute['resolution']>, resolvedAt: string, actorId: string): Promise<ImpactResult<true>>;
  /** I3: the artifact row (its USER_UPLOAD source must already exist). */
  insertArtifact(investigationId: string, a: StoredArtifact, actorId: string): Promise<ImpactResult<true>>;
  /** I3: all candidates of one request in ONE write (all or nothing). */
  insertCandidates(investigationId: string, cs: readonly StoredCandidate[], actorId: string): Promise<ImpactResult<true>>;
  /** I3: records a review; succeeds only if the candidate was PENDING or NEEDS_CONTEXT. */
  reviewCandidate(investigationId: string, ref: string, r: CandidateReview, actorId: string): Promise<ImpactResult<true>>;
}

// ── audit hash (parity with SQL) ───────────────────────────────────────────

export const AUDIT_GENESIS = '0'.repeat(64);

export async function auditHash(e: Omit<StoredAuditEvent, 'hash'> & { readonly investigationId: string }): Promise<string> {
  return await sha256Hex([
    String(e.seq), e.atText, e.eventType, e.actorRef, e.investigationId, e.refs.join(','), e.codes.join(','), e.prevHash,
  ].join('|'));
}

/** TS twin of public.impact_audit_chain_ok(). */
export async function verifyPersistedAuditChain(
  investigationId: string,
  events: readonly StoredAuditEvent[],
  head: { readonly seq: number; readonly hash: string },
): Promise<boolean> {
  let prev = AUDIT_GENESIS;
  for (let i = 0; i < events.length; i++) {
    const e = events[i];
    if (e.seq !== i + 1 || e.prevHash !== prev) return false;
    if ((await auditHash({ ...e, investigationId })) !== e.hash) return false;
    prev = e.hash;
  }
  return prev === head.hash && events.length === head.seq;
}

// ── in-memory store (tests) ─────────────────────────────────────────────────

interface MemInvestigation {
  rec: InvestigationRecord;
  sources: Map<string, StoredSource>;
  claims: Map<string, Claim>;
  evidence: Map<string, EvidenceItem>;
  verifications: StoredVerification[];
  disputes: Map<string, StoredDispute>;
  registryConflicts: StoredRegistryConflict[];
  artifacts: Map<string, StoredArtifact>;
  candidates: Map<string, StoredCandidate>;
  audit: StoredAuditEvent[];
}

/** Shared "database" so several callers (users) can be simulated. */
export class InMemoryImpactDatabase {
  readonly investigations = new Map<string, MemInvestigation>();
  readonly projects = new Map<string, string>(); // projectId → ownerId
  private counter = 0;
  private clock = Date.UTC(2026, 8, 23, 12, 0, 0);
  nextId(): string {
    this.counter++;
    return `00000000-0000-4000-8000-${this.counter.toString(16).padStart(12, '0')}`;
  }
  nextAt(): string {
    this.clock += 1;
    return new Date(this.clock).toISOString().replace('Z', '000Z');
  }
  /** Test hook: simulate a database failure on the next write. */
  failNextWrite = false;
  /** Test hook: simulate a failure of the next verification insert only. */
  failNextVerification = false;
  /** Test hook: simulate a failure of the next evidence insert only (I2F-01). */
  failNextEvidence = false;
  /** Test hook: simulate a failure of the next artifact insert only (I3). */
  failNextArtifact = false;
  async appendAudit(m: MemInvestigation, type: string, actor: string, refs: string[], codes: string[]) {
    const seq = m.rec.auditSeq + 1;
    const base = { seq, atText: this.nextAt(), eventType: type, actorRef: actor, refs, codes, prevHash: m.rec.auditHead };
    const hash = await auditHash({ ...base, investigationId: m.rec.id });
    m.audit.push(Object.freeze({ ...base, refs: Object.freeze([...refs]), codes: Object.freeze([...codes]), hash }));
    m.rec = { ...m.rec, auditSeq: seq, auditHead: hash };
  }
}

export class InMemoryImpactLabStore implements ImpactLabStore {
  constructor(private readonly db: InMemoryImpactDatabase, private readonly callerId: string) {}

  private own(id: string): MemInvestigation | undefined {
    const m = this.db.investigations.get(id);
    if (!m || m.rec.ownerId !== this.callerId) return undefined;
    if (m.rec.projectId && this.db.projects.get(m.rec.projectId) !== this.callerId) return undefined;
    return m;
  }
  private writable(id: string): ImpactResult<MemInvestigation> {
    if (this.db.failNextWrite) {
      this.db.failNextWrite = false;
      return fail('INTERNAL_ERROR', 'simulated database failure');
    }
    const m = this.db.investigations.get(id);
    if (!m) return fail('INVESTIGATION_NOT_FOUND', 'no such investigation');
    if (m.rec.status !== 'ACTIVE') return fail('INVESTIGATION_NOT_ACTIVE', 'archived');
    return ok(m);
  }

  getInvestigation(id: string) {
    return Promise.resolve(ok(this.own(id)?.rec ?? null));
  }
  listInvestigations() {
    return Promise.resolve(ok([...this.db.investigations.keys()].map((k) => this.own(k)).filter((m) => !!m).map((m) => m!.rec)));
  }
  countOwnedInvestigations(ownerId: string) {
    return Promise.resolve(ok([...this.db.investigations.values()].filter((m) => m.rec.ownerId === ownerId).length));
  }
  projectOwnedByCaller(projectId: string) {
    return Promise.resolve(ok(this.db.projects.get(projectId) === this.callerId));
  }
  loadInvestigationData(id: string): Promise<ImpactResult<InvestigationData>> {
    const m = this.own(id);
    if (!m) return Promise.resolve(ok({ sources: [], claims: [], evidence: [], latestVerifications: [], verifications: [], disputes: [], registryConflicts: [], artifacts: [], candidates: [] }));
    const latest = new Map<string, StoredVerification>();
    for (const v of m.verifications) latest.set(v.result.claimId, v); // insertion order = version order
    return Promise.resolve(ok({
      sources: [...m.sources.values()],
      claims: [...m.claims.values()],
      evidence: [...m.evidence.values()],
      latestVerifications: [...latest.values()],
      verifications: [...m.verifications].reverse().slice(0, 500),
      disputes: [...m.disputes.values()],
      registryConflicts: [...m.registryConflicts],
      artifacts: [...m.artifacts.values()],
      candidates: [...m.candidates.values()],
    }));
  }
  listAudit(id: string) {
    return Promise.resolve(ok(this.own(id)?.audit.slice() ?? []));
  }
  async auditChainOk(id: string) {
    const m = this.own(id);
    if (!m) return ok(false);
    return ok(await verifyPersistedAuditChain(m.rec.id, m.audit, { seq: m.rec.auditSeq, hash: m.rec.auditHead }));
  }

  async createInvestigation(n: NewInvestigation) {
    if (n.projectId && this.db.projects.get(n.projectId) !== n.ownerId) return fail<InvestigationRecord>('INVESTIGATION_NOT_FOUND', 'project not owned');
    const rec: InvestigationRecord = {
      id: this.db.nextId(), ownerId: n.ownerId, projectId: n.projectId, subjectOrgRef: n.subjectOrgRef,
      subjectOrgType: n.subjectOrgType, subjectIdentity: n.subjectIdentity, status: 'ACTIVE', auditSeq: 0,
      auditHead: AUDIT_GENESIS, createdAt: this.db.nextAt(),
    };
    const m: MemInvestigation = {
      rec, sources: new Map(), claims: new Map(), evidence: new Map(), verifications: [], disputes: new Map(), registryConflicts: [],
      artifacts: new Map(), candidates: new Map(), audit: [],
    };
    this.db.investigations.set(rec.id, m);
    await this.db.appendAudit(m, 'INVESTIGATION_CREATED', n.ownerId, [n.subjectOrgRef], []);
    return ok(m.rec);
  }
  async archiveInvestigation(id: string, actorId: string) {
    const w = this.writable(id);
    if (!w.ok) return w;
    if (actorId !== w.value.rec.ownerId) return fail<true>('INVESTIGATION_NOT_FOUND', 'actor is not the owner');
    w.value.rec = { ...w.value.rec, status: 'ARCHIVED' };
    await this.db.appendAudit(w.value, 'INVESTIGATION_ARCHIVED', actorId, [], ['ARCHIVED']);
    return ok(true as const);
  }
  async insertSource(investigationId: string, s: StoredSource, actorId: string) {
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    if (w.value.sources.has(s.source.id)) return fail<true>('ALREADY_EXISTS', 'source ref exists');
    const snap = s.snapshot;
    // Mirrors impact_sources_snapshot_key: one row per (provider, record, data).
    if (snap && [...w.value.sources.values()].some((o) =>
      o.snapshot && o.snapshot.providerId === snap.providerId && o.snapshot.recordId === snap.recordId && o.snapshot.dataHash === snap.dataHash
    )) return fail<true>('ALREADY_EXISTS', 'registry snapshot already recorded');
    const before = [...w.value.sources.entries()];
    w.value.sources.set(s.source.id, Object.freeze({ ...s }));
    await this.db.appendAudit(w.value, 'SOURCE_ADDED', actorId, [s.source.id], [s.source.type, s.source.acquisition.method]);
    if (snap) {
      // Twin of the SQL trigger: snapshot event, then one conflict row + event per disagreement.
      const update = before.some(([, o]) => o.snapshot?.providerId === snap.providerId && o.snapshot?.recordId === snap.recordId);
      await this.db.appendAudit(w.value, 'REGISTRY_SNAPSHOT_RECORDED', actorId, [s.source.id], [snap.canonicalOrgId, snap.status, update ? 'UPDATE' : 'NEW']);
      const conflicts = registryConflicts(
        { sourceRef: s.source.id, active: true, record: snap },
        before.filter(([, o]) => o.snapshot).map(([ref, o]) => ({ sourceRef: ref, active: o.source.status === 'ACTIVE', record: o.snapshot! })),
      );
      for (const c of conflicts) {
        w.value.registryConflicts.push(Object.freeze({ ...c }));
        await this.db.appendAudit(w.value, 'REGISTRY_CONFLICT_RECORDED', actorId, [c.sourceRef, c.otherSourceRef], [c.kind, c.canonicalOrgId]);
      }
    }
    return ok(true as const);
  }
  async updateSourceStatus(investigationId: string, ref: string, status: SourceStatus, actorId: string) {
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    const s = w.value.sources.get(ref);
    if (!s) return fail<true>('INVALID_REQUEST', 'unknown source');
    if (s.source.status === status) return fail<true>('ALREADY_EXISTS', 'status unchanged');
    w.value.sources.set(ref, Object.freeze({ ...s, source: Object.freeze({ ...s.source, status }) }));
    if (s.source.status !== status) {
      await this.db.appendAudit(w.value, 'SOURCE_STATUS_CHANGED', actorId, [ref], [status, 'REVERIFICATION_REQUIRED']);
    }
    return ok(true as const);
  }
  async insertClaim(investigationId: string, c: Claim, actorId: string) {
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    if (c.subjectOrganizationId !== w.value.rec.subjectOrgRef) return fail<true>('CROSS_INVESTIGATION_DENIED', 'subject mismatch');
    if (!w.value.sources.has(c.sourceId)) return fail<true>('INVALID_REQUEST', 'unknown source');
    if (w.value.claims.has(c.id)) return fail<true>('ALREADY_EXISTS', 'claim ref exists');
    w.value.claims.set(c.id, Object.freeze({ ...c }));
    await this.db.appendAudit(w.value, 'CLAIM_CREATED', actorId, [c.id, c.sourceId], [c.kind, c.origin]);
    return ok(true as const);
  }
  async insertEvidence(investigationId: string, e: EvidenceItem, actorId: string) {
    if (this.db.failNextEvidence) {
      this.db.failNextEvidence = false;
      return fail<true>('INTERNAL_ERROR', 'simulated failure after the claim write');
    }
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    if (!w.value.claims.has(e.claimId) || !w.value.sources.has(e.sourceId)) return fail<true>('INVALID_REQUEST', 'unknown claim or source');
    if (w.value.evidence.has(e.id)) return fail<true>('ALREADY_EXISTS', 'evidence ref exists');
    // I3 twin of impact_evidence_validate: an artifact source carries only the
    // promotion of one of its own reviewable candidates (same locator/excerpt).
    const art = [...w.value.artifacts.values()].find((a) => a.sourceRef === e.sourceId);
    const bound = e.locator?.artifact;
    if (art || bound) {
      const cand = [...w.value.candidates.values()].find((c) => `${c.ref}.ev` === e.id);
      const cArt = cand ? w.value.artifacts.get(cand.artifactRef) : undefined;
      if (!cand || !cArt || !bound || cArt.sourceRef !== e.sourceId || !['PENDING', 'NEEDS_CONTEXT'].includes(cand.reviewStatus)
        || bound.ref !== cArt.ref || bound.hash !== cArt.fileHash || locatorKey(bound.locator) !== locatorKey(cand.locator)
        || Object.keys(e.locator ?? {}).length !== 1 || e.excerpt !== cand.excerpt || e.relationshipBasis !== 'HUMAN_ASSESSED'
        || (cand.claimRef !== null && cand.claimRef !== e.claimId)) {
        return fail<true>('INVALID_REQUEST', 'artifact evidence must be the promotion of one of its candidates');
      }
    }
    w.value.evidence.set(e.id, Object.freeze({ ...e }));
    await this.db.appendAudit(w.value, 'EVIDENCE_ADDED', actorId, [e.id, e.claimId, e.sourceId], [e.relationship, e.relationshipBasis]);
    return ok(true as const);
  }
  async insertVerification(investigationId: string, r: VerificationResult, idempotencyKey: string | null, actorId: string) {
    if (this.db.failNextVerification) {
      this.db.failNextVerification = false;
      return fail<StoredVerification>('INTERNAL_ERROR', 'simulated failure after the dispute write');
    }
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    const m = w.value;
    if (idempotencyKey) {
      const prior = m.verifications.find((v) => v.idempotencyKey === idempotencyKey);
      if (prior) return ok(prior);
    }
    if (m.verifications.some((v) => v.result.resultId === r.resultId)) {
      return ok(m.verifications.find((v) => v.result.resultId === r.resultId)!);
    }
    const history = m.verifications.filter((v) => v.result.claimId === r.claimId);
    const prev = history[history.length - 1];
    const stored: StoredVerification = Object.freeze({ version: history.length + 1, result: r, idempotencyKey });
    m.verifications.push(stored);
    await this.db.appendAudit(m, 'VERIFICATION_RUN', actorId, [r.claimId, r.resultId], [r.status, r.policyVersion]);
    if (prev && prev.result.status !== r.status) {
      await this.db.appendAudit(m, 'STATUS_CHANGED', actorId, [r.claimId, r.resultId], [prev.result.status, r.status]);
    }
    if (r.conflicts.length > 0) await this.db.appendAudit(m, 'CONFLICT_DETECTED', actorId, [r.claimId, r.resultId], []);
    if (r.reviewState === 'HUMAN_REVIEWED') await this.db.appendAudit(m, 'MANUAL_REVIEW', actorId, [r.claimId, r.resultId], ['HUMAN_REVIEWED']);
    return ok(stored);
  }
  async insertDispute(investigationId: string, d: StoredDispute, actorId: string) {
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    if (w.value.disputes.has(d.ref)) return fail<true>('ALREADY_EXISTS', 'dispute ref exists');
    if (!w.value.claims.has(d.claimRef)) return fail<true>('INVALID_REQUEST', 'unknown claim');
    for (const r of d.submittedEvidenceRefs) {
      if (w.value.evidence.get(r)?.claimId !== d.claimRef) return fail<true>('INVALID_REQUEST', 'evidence must belong to the disputed claim');
    }
    w.value.disputes.set(d.ref, Object.freeze({ ...d }));
    await this.db.appendAudit(w.value, 'DISPUTE_OPENED', actorId, [d.ref, d.claimRef, ...d.submittedEvidenceRefs], [d.kind]);
    return ok(true as const);
  }
  async resolveDispute(investigationId: string, ref: string, resolution: NonNullable<StoredDispute['resolution']>, resolvedAt: string, actorId: string) {
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    const d = w.value.disputes.get(ref);
    if (!d) return fail<true>('INVALID_REQUEST', 'unknown dispute');
    if (d.resolution) return fail<true>('ALREADY_EXISTS', 'dispute already resolved');
    w.value.disputes.set(ref, Object.freeze({ ...d, resolution, resolvedAt }));
    await this.db.appendAudit(w.value, 'DISPUTE_RESOLVED', actorId, [ref, d.claimRef], [resolution, 'REVERIFICATION_REQUIRED']);
    if (resolution === 'CORRECTED') await this.db.appendAudit(w.value, 'CORRECTION', actorId, [d.claimRef], ['CORRECTED']);
    return ok(true as const);
  }

  // ── I3 (twins of the impact_artifacts / impact_evidence_candidates triggers) ──
  async insertArtifact(investigationId: string, a: StoredArtifact, actorId: string) {
    if (this.db.failNextArtifact) {
      this.db.failNextArtifact = false;
      return fail<true>('INTERNAL_ERROR', 'simulated failure after the source write');
    }
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    const m = w.value;
    if (m.artifacts.has(a.ref)) return fail<true>('ALREADY_EXISTS', 'artifact ref exists');
    if ([...m.artifacts.values()].some((x) => x.fileHash === a.fileHash)) return fail<true>('ALREADY_EXISTS', 'artifact already recorded');
    const src = m.sources.get(a.sourceRef);
    if (!src || src.source.acquisition.method !== 'USER_UPLOAD' || src.source.type !== 'USER_DOCUMENT' || src.source.retention !== 'HASH_ONLY' || !src.source.userSubmitted || src.snapshot || src.source.contentHash !== a.fileHash || a.sourceRef !== a.ref) {
      return fail<true>('INVALID_REQUEST', 'artifact source mismatch');
    }
    if (a.supersedesRef) {
      const prior = m.artifacts.get(a.supersedesRef);
      if (!prior || a.version !== prior.version + 1 || [...m.artifacts.values()].some((x) => x.supersedesRef === a.supersedesRef)) {
        return fail<true>('ALREADY_EXISTS', 'invalid artifact version chain');
      }
    } else if (a.version !== 1) return fail<true>('INVALID_REQUEST', 'first version must be 1');
    m.artifacts.set(a.ref, Object.freeze({ ...a }));
    await this.db.appendAudit(m, 'ARTIFACT_INGESTED', actorId, [a.ref, a.sourceRef], [a.type, a.origin, `v${a.version}`]);
    if (a.supersedesRef) await this.db.appendAudit(m, 'ARTIFACT_VERSIONED', actorId, [a.ref, a.supersedesRef], [`v${a.version}`]);
    await this.db.appendAudit(m, 'EXTRACTION_COMPLETED', actorId, [a.ref], [a.extractionStatus, a.extraction.extractorVersion]);
    return ok(true as const);
  }
  async insertCandidates(investigationId: string, cs: readonly StoredCandidate[], actorId: string) {
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    const m = w.value;
    for (const c of cs) {
      const a = m.artifacts.get(c.artifactRef);
      if (!a || a.fileHash !== c.artifactHash) return fail<true>('INVALID_REQUEST', 'candidate artifact mismatch');
      if (m.candidates.has(c.ref) || cs.filter((x) => x.ref === c.ref).length > 1) return fail<true>('ALREADY_EXISTS', 'candidate ref exists');
      if (c.claimRef && !m.claims.has(c.claimRef)) return fail<true>('INVALID_REQUEST', 'unknown claim');
      if (c.reviewStatus !== 'PENDING' || c.evidenceRef) return fail<true>('INVALID_REQUEST', 'candidates start PENDING');
    }
    for (const c of cs) {
      m.candidates.set(c.ref, Object.freeze({ ...c }));
      await this.db.appendAudit(m, 'EVIDENCE_CANDIDATE_CREATED', actorId, [c.ref, c.artifactRef], [c.method]);
    }
    return ok(true as const);
  }
  async reviewCandidate(investigationId: string, ref: string, r: CandidateReview, actorId: string) {
    const w = this.writable(investigationId);
    if (!w.ok) return w;
    const m = w.value;
    const c = m.candidates.get(ref);
    if (!c) return fail<true>('INVALID_REQUEST', 'unknown candidate');
    if (c.reviewStatus !== 'PENDING' && c.reviewStatus !== 'NEEDS_CONTEXT') return fail<true>('ALREADY_EXISTS', 'candidate already reviewed');
    if (r.status === 'ACCEPTED') {
      const a = m.artifacts.get(c.artifactRef)!;
      const e = r.evidenceRef ? m.evidence.get(r.evidenceRef) : undefined;
      if (!e || e.sourceId !== a.sourceRef || e.claimId !== r.claimRef || e.excerpt !== c.excerpt || e.relationship !== r.relationship
          || e.relationshipBasis !== 'HUMAN_ASSESSED' || e.aboutOrganizationId !== r.aboutOrgRef || e.locator?.artifact?.hash !== c.artifactHash
          || (c.claimRef !== null && c.claimRef !== r.claimRef)) {
        return fail<true>('INVALID_REQUEST', 'promoted evidence does not match the candidate');
      }
    } else if (r.evidenceRef || r.relationship || r.claimRef || r.aboutOrgRef) {
      return fail<true>('INVALID_REQUEST', 'only an accepted candidate is promoted');
    }
    m.candidates.set(ref, Object.freeze({
      ...c, reviewStatus: r.status, reviewRelationship: r.relationship, reviewClaimRef: r.claimRef, reviewAboutOrgRef: r.aboutOrgRef,
      evidenceRef: r.evidenceRef, reviewedAt: r.reviewedAt,
    }));
    await this.db.appendAudit(m, 'EVIDENCE_CANDIDATE_REVIEWED', actorId, [ref], [r.status]);
    if (r.status === 'ACCEPTED') await this.db.appendAudit(m, 'EVIDENCE_PROMOTED', actorId, [ref, r.evidenceRef!, r.claimRef!], [r.relationship!]);
    return ok(true as const);
  }
}
