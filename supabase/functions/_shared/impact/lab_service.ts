/**
 * Impact Lab application service — IV-IMPACT-I1-PERSISTENCE-RLS-01.
 *
 *   authenticated user (server-derived) + parsed LabRequest + server clock
 *     → ownership (RLS-scoped read) → domain validation → engine → store
 *
 * Authority rules enforced here (the database enforces them again):
 *  - the investigation owner is always the authenticated caller;
 *  - a claim's subject is always the investigation subject;
 *  - client sources are ANALYST_ENTRY / USER_UPLOAD; PROVIDER sources only
 *    come from server-side ingestion (provider_registry.ts);
 *  - excerpt hashes, timestamps (extractedAt, addedAt, openedAt,
 *    evaluatedAt) and verification results are computed by the server;
 *  - the Verification Engine receives the SERVER provider registry, the
 *    identity status derived from provider snapshots, and flags computed from
 *    untrusted-content scanning — never values from the request;
 *  - class C actions are refused (AEF_HUMAN_GATE).
 * I2 (Registry Intelligence):
 *  - registry search resolves identity conservatively (EXACT / STRONG /
 *    AMBIGUOUS / NO_MATCH) and never attaches anything to a candidate;
 *  - re-ingesting identical registry data replays (no duplicate), changed
 *    data is a new snapshot version; registry disagreements are recorded by
 *    the database (never a finding);
 *  - registry-statement claims are generated only from a snapshot whose
 *    registration CONFIRMS the investigation subject;
 *  - lineage fingerprints are computed here from submitted text; the text
 *    itself is never persisted.
 * No LLM, no network, no verdict field.
 */
import { requestImpactAction } from './boundaries.ts';
import { resolveEntity } from './entity_resolution.ts';
import { ARTIFACT_LIMITS, ARTIFACT_POLICY_VERSION, locatorFitsSummary, locatorKey } from './artifact_model.ts';
import { detectArtifact } from './artifact_detect.ts';
import { extractArtifact } from './artifact_extract.ts';
import { analystCandidate, autoCandidates, type CandidateDraft } from './evidence_candidates.ts';
import { REGISTRY_CONFLICT_EXPLANATIONS, resolveOrganization, snapshotFresh } from './organization_identity.ts';
import { registryStatement } from './registry_claims.ts';
import { contentFingerprint, detectSyndicationMarkers, similaritySketch } from './source_lineage.ts';
import { fail, ok, type ImpactResult } from './errors.ts';
import { LAB_LIMITS, type LabRequest } from './lab_contract.ts';
import type { ImpactLabStore, InvestigationData, InvestigationRecord, StoredArtifact, StoredCandidate, StoredDispute, StoredSource } from './lab_store.ts';
import { normalizeDomain } from './entity_resolution.ts';
import { parseIsoMs, sha256Bytes, sha256Hex, validateClaim, validateEvidence, validateSource } from './provenance.ts';
import { ingestProviderRecord, PROVIDER_REGISTRY_VERSION, type ProviderRegistry, searchProvider, SERVER_PROVIDER_REGISTRY } from './provider_registry.ts';
import { buildImpactReport } from './report.ts';
import { buildDossierContent, DOSSIER_CANONICALIZATION, DOSSIER_LIMITS, DOSSIER_SCHEMA_VERSION, type DossierDocument, snapshotRefOf } from './dossier.ts';
import { renderDossierText } from './dossier_render.ts';
import { deriveIndicators } from './risk_indicators.ts';
import { scanUntrustedContent } from './safety.ts';
import type { Claim, EvidenceItem, Jurisdiction, OrganizationIdentity, Source } from './types.ts';
import { canonical, IMPACT_POLICY_VERSION, type SubjectIdentityStatus, type VerificationResult, verifyClaim } from './verification.ts';

export interface LabActor {
  /** auth.users id, derived from the verified session — never from the body. */
  readonly userId: string;
}

export interface LabResponse {
  readonly action: LabRequest['action'];
  readonly data: Readonly<Record<string, unknown>>;
  /** Counts for observability (no content). */
  readonly metrics?: {
    readonly claims?: number;
    readonly evidence?: number;
    readonly conflicts?: number;
    readonly status?: string;
    /** I2 registry lookups: provider id + identity outcome + candidate count (ids/codes only). */
    readonly registry?: { readonly providerId: string; readonly outcome: string; readonly candidates: number };
    readonly lineageLinks?: number;
    /** I3 artifact ingestion: type / extraction status / size / candidates (no content). */
    readonly artifact?: { readonly type: string; readonly status: string; readonly sizeBytes: number; readonly candidates: number };
    /** I4 dossier: completeness status + counts + staleness (no content). */
    readonly dossier?: { readonly status: string; readonly claims: number; readonly reverificationPending: number; readonly stale?: boolean; readonly exported?: boolean };
  };
}

/** Server composition handed to the service (never request-derived). */
export interface LabDeps {
  readonly providers?: ProviderRegistry;
}

const actorRefOf = async (userId: string) => `u_${(await sha256Hex(`impact-reviewer|${userId}`)).slice(0, 24)}`;

async function requireOwned(store: ImpactLabStore, actor: LabActor, id: string): Promise<ImpactResult<InvestigationRecord>> {
  const r = await store.getInvestigation(id);
  if (!r.ok) return r;
  // RLS returns nothing for foreign investigations; the owner check is a second layer.
  if (!r.value || r.value.ownerId !== actor.userId) return fail('INVESTIGATION_NOT_FOUND', 'investigation not found');
  return ok(r.value);
}

function requireActive(inv: InvestigationRecord): ImpactResult<true> {
  return inv.status === 'ACTIVE' ? ok(true) : fail('INVESTIGATION_NOT_ACTIVE', 'investigation is archived');
}

async function load(store: ImpactLabStore, id: string): Promise<ImpactResult<InvestigationData>> {
  return await store.loadInvestigationData(id);
}

/** Identity of the subject as established by PROVIDER registry snapshots only. */
export function subjectIdentityFrom(
  inv: InvestigationRecord,
  sources: readonly StoredSource[],
  providers: ProviderRegistry = SERVER_PROVIDER_REGISTRY,
): SubjectIdentityStatus {
  const outcomes = sources
    .filter((s) =>
      s.snapshot && s.source.status === 'ACTIVE' && s.source.acquisition.method === 'PROVIDER' &&
      providers.get(s.source.acquisition.providerId)?.descriptor.sourceType === s.source.type
    )
    .map((s) => resolveEntity(inv.subjectIdentity, s.snapshot!.identity).outcome);
  if (outcomes.includes('ENTITY_MATCH_UNCERTAIN')) return 'UNCERTAIN';
  if (outcomes.includes('CONFIRMED_MATCH')) return 'CONFIRMED';
  if (outcomes.includes('PROBABLE_MATCH')) return 'PROBABLE';
  return 'UNRESOLVED';
}

function latestByClaim(data: InvestigationData): Map<string, VerificationResult> {
  const out = new Map<string, { v: number; r: VerificationResult }>();
  for (const s of data.latestVerifications) {
    const cur = out.get(s.result.claimId);
    if (!cur || s.version > cur.v) out.set(s.result.claimId, { v: s.version, r: s.result });
  }
  return new Map([...out].map(([k, x]) => [k, x.r]));
}

/**
 * Codex I1F-02: a dispute write and its re-verification are separate writes,
 * so reads never trust the latest stored version alone. An open dispute is
 * always shown as DISPUTED (exactly what the engine yields with openDispute),
 * and a DISPUTED version whose dispute was resolved shows the underlying
 * status as UNKNOWN-class — both flagged reverificationPending until a new
 * version is stored. Nothing here invents support or contradiction.
 */
export type ReadResult = VerificationResult & { readonly reverificationPending?: true };
export function withDisputeOverlay(r: VerificationResult, disputes: readonly StoredDispute[]): ReadResult {
  const open = disputes.some((d) => d.claimRef === r.claimId && d.resolution === null);
  if (open && r.status !== 'DISPUTED') {
    return {
      ...r, status: 'DISPUTED', displayClass: 'CONFLICT', reviewState: 'REVIEW_REQUIRED',
      reviewReasons: [...new Set([...r.reviewReasons, 'OPEN_DISPUTE' as const])].sort(), reverificationPending: true,
    };
  }
  if (!open && r.status === 'DISPUTED') {
    return { ...r, status: r.underlyingStatus, displayClass: 'UNKNOWN', reviewState: 'REVIEW_REQUIRED', reverificationPending: true };
  }
  return r;
}

/**
 * Retry replay (I1F2-02 / I1F3-01 / I1F3-03): the stored latest result is
 * replayed only if a FRESH engine run over the current state is canonically
 * IDENTICAL to it: every field, including resultId, evaluatedAt, reviewState,
 * gaps, rules and classifications. A retry at a later time, after any state
 * change, or over a human-reviewed result (the retry carries no review) returns
 * null, and the caller stores a new version.
 */
async function settledLatest(actor: LabActor, inv: InvestigationRecord, data: InvestigationData, claimRef: string, now: string, providers: ProviderRegistry) {
  const latest = data.latestVerifications.find((v) => v.result.claimId === claimRef);
  const claim = data.claims.find((c) => c.id === claimRef);
  if (!latest || !claim) return null;
  const read = withDisputeOverlay(latest.result, data.disputes);
  if (read.reverificationPending) return null;
  const fresh = await computeVerification(actor, inv, data, claim, data.evidence.filter((e) => e.claimId === claimRef), now, providers);
  if (!fresh.ok) return null;
  return canonical(fresh.value) === canonical(latest.result) ? summary(read, latest.version) : null;
}

function summary(r: ReadResult, version: number) {
  return {
    version,
    resultId: r.resultId,
    claimRef: r.claimId,
    status: r.status,
    underlyingStatus: r.underlyingStatus,
    sufficiency: r.sufficiency,
    displayClass: r.displayClass,
    reviewState: r.reviewState,
    reviewReasons: r.reviewReasons,
    gaps: r.gaps,
    conflicts: r.conflicts,
    rulesApplied: r.rulesApplied,
    evaluatedAt: r.evaluatedAt,
    policyVersion: r.policyVersion,
    evidenceSetHash: r.evidenceSetHash,
    reviewBindingHash: r.reviewBindingHash,
    isFindingOfWrongdoing: r.isFindingOfWrongdoing,
    ...(r.reverificationPending ? { reverificationPending: true } : {}),
  };
}

interface StoredRun {
  readonly result: VerificationResult;
  readonly version: number;
  readonly replayed: boolean;
  readonly evidenceCount: number;
}

/** Engine run with SERVER inputs only, persisted as a new version. */
async function verifyAndStore(
  store: ImpactLabStore,
  actor: LabActor,
  inv: InvestigationRecord,
  data: InvestigationData,
  claimRef: string,
  now: string,
  idempotencyKey: string | null,
  providers: ProviderRegistry,
  humanReviewBindingHash?: string,
): Promise<ImpactResult<StoredRun>> {
  const claim = data.claims.find((c) => c.id === claimRef);
  if (!claim) return fail('INVALID_REQUEST', 'unknown claim');
  const evidence = data.evidence.filter((e) => e.claimId === claim.id);
  const r = await computeVerification(actor, inv, data, claim, evidence, now, providers, humanReviewBindingHash);
  if (!r.ok) return r;
  const stored = await store.insertVerification(inv.id, r.value, idempotencyKey, actor.userId);
  if (!stored.ok) return stored;
  // Codex I1G2-03: an idempotency key replays only the SAME claim.
  if (stored.value.result.claimId !== claim.id) return fail('ALREADY_EXISTS', 'idempotency key already used for another claim');
  return ok({ result: stored.value.result, version: stored.value.version, replayed: stored.value.result.resultId !== r.value.resultId, evidenceCount: evidence.length });
}

/** Pure engine run with SERVER inputs only (nothing persisted). */
async function computeVerification(
  actor: LabActor,
  inv: InvestigationRecord,
  data: InvestigationData,
  claim: Claim,
  evidence: readonly EvidenceItem[],
  now: string,
  providers: ProviderRegistry,
  humanReviewBindingHash?: string,
): Promise<ImpactResult<VerificationResult>> {
  // Untrusted-content boundary: excerpts carrying instructions flag their source (review), never obeyed.
  const flagged = [...new Set(evidence.filter((e) => e.excerpt && scanUntrustedContent(e.excerpt).flagged).map((e) => e.sourceId))];
  const openDispute = data.disputes.some((d) => d.claimRef === claim.id && d.resolution === null);
  return await verifyClaim(
    { claim, evidence, sources: data.sources.map((s) => s.source) },
    {
      evaluatedAt: now,
      subjectIdentity: subjectIdentityFrom(inv, data.sources, providers),
      openDispute,
      flaggedSourceIds: flagged,
      // I2 entity-spoofing guard: a registry snapshot counts only for the organization it CONFIRMS.
      foreignRegistrySourceIds: data.sources
        .filter((s) => s.snapshot && resolveEntity(inv.subjectIdentity, s.snapshot.identity).outcome !== 'CONFIRMED_MATCH')
        .map((s) => s.source.id),
      trustedProviders: providers.trustedRefs(), // CF-06: server registry only
      ...(humanReviewBindingHash
        ? { humanReview: { reviewedAt: now, reviewerRef: await actorRefOf(actor.userId), reviewBindingHash: humanReviewBindingHash } }
        : {}),
    },
  );
}

async function reverify(store: ImpactLabStore, actor: LabActor, inv: InvestigationRecord, claimRef: string, now: string, providers: ProviderRegistry) {
  const fresh = await load(store, inv.id);
  if (!fresh.ok) return fresh;
  return await verifyAndStore(store, actor, inv, fresh.value, claimRef, now, null, providers);
}

/** I4: deterministic dossier content + its canonical hash, from SERVER state only. */
async function buildDossier(store: ImpactLabStore, inv: InvestigationRecord, providers: ProviderRegistry, nowMs: number) {
  const data = await load(store, inv.id);
  if (!data.ok) return data;
  const latest = latestByClaim(data.value);
  const results = new Map([...latest].map(([k, r]) => [k, withDisputeOverlay(r, data.value.disputes)]));
  const versions = new Map<string, number>();
  for (const v of data.value.latestVerifications) versions.set(v.result.claimId, Math.max(versions.get(v.result.claimId) ?? 0, v.version));
  const content = await buildDossierContent({
    investigation: inv,
    identityStatus: subjectIdentityFrom(inv, data.value.sources, providers),
    data: data.value,
    results,
    latestVersions: versions,
    registryFacts: data.value.sources.filter((s) => s.snapshot).map((s) => ({
      ...snapshotView(s.source.id, s.source.status === 'ACTIVE', s.snapshot!, providers, nowMs),
      freshnessDays: providers.get(s.snapshot!.providerId)?.descriptor.freshnessDays ?? 0,
    })),
    providerRegistryVersion: PROVIDER_REGISTRY_VERSION,
  });
  const canon = canonical(content);
  if (canon.length > DOSSIER_LIMITS.maxContentChars) return fail('DOSSIER_TOO_LARGE', 'the dossier exceeds the export bound');
  // Request-clock freshness (Codex I4G1-N01): envelope only, never hashed content.
  const freshNow = data.value.sources.filter((s) => s.snapshot).map((s) => ({
    sourceRef: s.source.id,
    fresh: snapshotFresh(s.snapshot!, providers.get(s.snapshot!.providerId)?.descriptor.freshnessDays ?? 0, nowMs),
  })).sort((a, b) => (a.sourceRef < b.sourceRef ? -1 : a.sourceRef > b.sourceRef ? 1 : 0));
  return ok({ content, contentHash: await sha256Hex(canon), freshNow });
}

/** Public view of an artifact: provenance + structure, never content. */
function artifactView(a: StoredArtifact) {
  return {
    ref: a.ref, sourceRef: a.sourceRef, type: a.type, origin: a.origin, originalFilename: a.originalFilename, mediaType: a.mediaType,
    sizeBytes: a.sizeBytes, fileHash: a.fileHash, hashAlgorithm: 'SHA-256', normalizedContentHash: a.normalizedContentHash,
    version: a.version, supersedesRef: a.supersedesRef, cloudProvider: a.cloudProvider, cloudFileRef: a.cloudFileRef,
    sourceModifiedAt: a.sourceModifiedAt, extractionStatus: a.extractionStatus, extraction: a.extraction, ingestedAt: a.ingestedAt,
    originalBytesRetained: false,
  };
}

function candidateView(c: StoredCandidate) {
  return {
    ref: c.ref, artifactRef: c.artifactRef, artifactHash: c.artifactHash, locator: c.locator, excerpt: c.excerpt, claimRef: c.claimRef,
    proposedRelationship: c.proposedRelationship, method: c.method, reviewReasons: c.reviewReasons, reviewStatus: c.reviewStatus,
    evidenceRef: c.evidenceRef, isEvidence: c.reviewStatus === 'ACCEPTED',
    // The excerpt is QUOTED from a user-provided document: never a statement of the platform (Codex I3G3-05).
    excerptAttribution: 'QUOTED_FROM_USER_UPLOAD' as const,
  };
}

/** Public view of a registry snapshot: identity + provenance, never raw payload. */
function snapshotView(ref: string, active: boolean, r: NonNullable<StoredSource['snapshot']>, providers: ProviderRegistry, nowMs: number) {
  const d = providers.get(r.providerId)?.descriptor;
  return {
    sourceRef: ref, active, providerId: r.providerId, recordId: r.recordId, canonicalOrgId: r.canonicalOrgId,
    canonicalIds: r.canonicalIds, legalName: r.name, formerNames: r.formerNames, tradingNames: r.tradingNames,
    status: r.status, statusAsOf: r.statusAsOf ?? null, sourceAsOf: r.sourceAsOf ?? null, registeredOn: r.registeredOn ?? null,
    dissolvedOn: r.dissolvedOn ?? null, retrievedAt: r.retrievedAt, adapterVersion: r.adapterVersion, dataHash: r.dataHash,
    synthetic: r.synthetic, fresh: d ? snapshotFresh(r, d.freshnessDays, nowMs) : false,
    authority: d ? { official: d.official, authorityClass: d.authorityClass, primaryPublisher: d.primaryPublisher, termsStatus: d.termsStatus } : null,
  };
}

export async function handleLabRequest(
  store: ImpactLabStore,
  actor: LabActor,
  req: LabRequest,
  now: string,
  deps: LabDeps = {},
): Promise<ImpactResult<LabResponse>> {
  const nowMs = parseIsoMs(now);
  if (nowMs === null) return fail('INTERNAL_ERROR', 'server clock unavailable');
  const providers = deps.providers ?? SERVER_PROVIDER_REGISTRY;

  switch (req.action) {
    case 'request_external_action': {
      const d = requestImpactAction(req.kind);
      if (d.decision === 'BLOCKED') {
        return fail('ACTION_BLOCKED', 'class C actions are not available', { requires: 'AEF_HUMAN_GATE', actionClass: 'C' });
      }
      return ok({ action: req.action, data: { decision: d.decision, actionClass: d.actionClass, note: 'use the dedicated Lab action' } });
    }

    case 'list_investigations': {
      const r = await store.listInvestigations();
      if (!r.ok) return r;
      return ok({
        action: req.action,
        data: { investigations: r.value.map((i) => ({ id: i.id, subjectOrgRef: i.subjectOrgRef, status: i.status, projectId: i.projectId, createdAt: i.createdAt })) },
      });
    }

    case 'create_investigation': {
      const count = await store.countOwnedInvestigations(actor.userId);
      if (!count.ok) return count;
      if (count.value >= LAB_LIMITS.maxInvestigationsPerOwner) return fail('LIMIT_EXCEEDED', 'too many investigations');
      if (req.projectId) {
        const owned = await store.projectOwnedByCaller(req.projectId);
        if (!owned.ok) return owned;
        if (!owned.value) return fail('INVESTIGATION_NOT_FOUND', 'project not found');
      }
      const s = req.subject;
      const domains: string[] = [];
      for (const d of s.identity.domains ?? []) {
        const n = normalizeDomain(d);
        if (!n) return fail('INVALID_REQUEST', 'invalid domain');
        domains.push(n);
      }
      const regs = (s.identity.registrations ?? []).map((r) => ({ jurisdiction: { country: r.country } as Jurisdiction, scheme: r.scheme, value: r.value }));
      const identity: OrganizationIdentity = {
        ...(s.identity.legalName ? { legalName: s.identity.legalName } : {}),
        ...(s.identity.publicName ? { publicName: s.identity.publicName } : {}),
        ...(s.identity.aliases?.length ? { aliases: s.identity.aliases } : {}),
        ...(regs.length ? { registrations: regs, jurisdictions: [...new Set(regs.map((r) => r.jurisdiction.country))].map((c) => ({ country: c })) } : {}),
        ...(domains.length ? { domains } : {}),
      };
      const r = await store.createInvestigation({
        ownerId: actor.userId, projectId: req.projectId ?? null, subjectOrgRef: s.ref, subjectOrgType: s.type, subjectIdentity: identity,
      });
      if (!r.ok) return r;
      return ok({ action: req.action, data: { investigationId: r.value.id, subjectOrgRef: r.value.subjectOrgRef, audit: { seq: r.value.auditSeq, head: r.value.auditHead } } });
    }
  }

  // Every remaining action is scoped to one owned investigation.
  const inv = await requireOwned(store, actor, req.investigationId);
  if (!inv.ok) return inv;

  if (req.action === 'search_registry') {
    // Read-only: nothing is persisted and nothing is attached to any candidate.
    const reg = providers.get(req.providerId);
    if (!reg) return fail('CAPABILITY_NOT_SUPPORTED', 'unknown provider');
    const q = req.query;
    if (q.country && !reg.descriptor.jurisdictions.includes(q.country)) {
      // A registry never answers for another jurisdiction.
      return ok({
        action: req.action,
        data: { providerId: reg.descriptor.id, outcome: 'NO_MATCH', candidates: [], reasons: ['OUTSIDE_PROVIDER_JURISDICTION'], requiresReview: true, identityStatus: 'UNRESOLVED', absenceIsNotEvidenceOfWrongdoing: true },
        metrics: { registry: { providerId: reg.descriptor.id, outcome: 'NO_MATCH', candidates: 0 } },
      });
    }
    // A registration is the identifier: the registry is asked for it ALONE, so a
    // mismatching name surfaces as a review signal instead of hiding the match.
    const providerQuery = q.registration ? { registration: q.registration, scheme: q.scheme, country: q.country } : q;
    const found = await searchProvider(reg.descriptor.id, providerQuery, providers);
    if (!found.ok) return found; // REGISTRY_UNAVAILABLE etc. — an operational state, never "not registered"
    const res = resolveOrganization(q, found.value, now, (id) => providers.get(id)?.descriptor.freshnessDays ?? 0);
    return ok({
      action: req.action,
      data: {
        providerId: reg.descriptor.id,
        synthetic: reg.descriptor.synthetic,
        ...res,
        // NO_MATCH / AMBIGUOUS are search results, not findings.
        absenceIsNotEvidenceOfWrongdoing: true,
      },
      metrics: { registry: { providerId: reg.descriptor.id, outcome: res.outcome, candidates: res.candidates.length } },
    });
  }

  if (req.action === 'get_investigation') {
    const data = await load(store, inv.value.id);
    if (!data.ok) return data;
    const audit = await store.listAudit(inv.value.id);
    if (!audit.ok) return audit;
    const chain = await store.auditChainOk(inv.value.id);
    if (!chain.ok) return chain;
    const latest = latestByClaim(data.value);
    const results = [...latest.values()].map((r) => withDisputeOverlay(r, data.value.disputes));
    const indicators = deriveIndicators({ results });
    const report = buildImpactReport({
      organization: { id: inv.value.subjectOrgRef, type: inv.value.subjectOrgType, identity: inv.value.subjectIdentity },
      registry: data.value.sources.filter((s) => s.snapshot).map((s) => s.snapshot!),
      claims: data.value.claims,
      results,
      indicators,
      sources: data.value.sources.map((s) => s.source),
      lang: req.lang,
    });
    return ok({
      action: req.action,
      data: {
        investigation: {
          id: inv.value.id, subjectOrgRef: inv.value.subjectOrgRef, subjectOrgType: inv.value.subjectOrgType,
          subjectIdentity: inv.value.subjectIdentity, status: inv.value.status, projectId: inv.value.projectId,
        },
        subjectIdentityStatus: subjectIdentityFrom(inv.value, data.value.sources, providers),
        sources: data.value.sources.map((s) => ({ ...s.source, provenance: { acquisition: s.source.acquisition, hasSnapshot: !!s.snapshot } })),
        registry: {
          snapshots: data.value.sources.filter((s) => s.snapshot)
            .map((s) => snapshotView(s.source.id, s.source.status === 'ACTIVE', s.snapshot!, providers, nowMs)),
          conflicts: data.value.registryConflicts,
          conflictExplanations: REGISTRY_CONFLICT_EXPLANATIONS,
          conflictIsNotWrongdoing: true,
        },
        artifacts: data.value.artifacts.map(artifactView),
        candidates: data.value.candidates.map(candidateView),
        claims: data.value.claims,
        evidence: data.value.evidence,
        verifications: [...data.value.verifications].sort((a, b) => a.result.claimId.localeCompare(b.result.claimId) || a.version - b.version)
          .map((v) => summary(v.result, v.version)),
        latest: results.map((r) => summary(r, data.value.latestVerifications.find((v) => v.result.claimId === r.claimId)?.version ?? 0)),
        disputes: data.value.disputes,
        indicators,
        report,
        audit: { seq: inv.value.auditSeq, head: inv.value.auditHead, chainOk: chain.value, events: audit.value.length },
        policyVersion: IMPACT_POLICY_VERSION,
        providerRegistryVersion: PROVIDER_REGISTRY_VERSION,
      },
      metrics: { claims: data.value.claims.length, evidence: data.value.evidence.length, conflicts: results.reduce((n, r) => n + r.conflicts.length, 0) },
    });
  }

  // ── I4 Verification Dossier (read-only projection; export registers metadata only) ──
  if (req.action === 'get_dossier' || req.action === 'export_dossier' || req.action === 'verify_dossier') {
    const built = await buildDossier(store, inv.value, providers, nowMs);
    if (!built.ok) return built;
    const { content, contentHash, freshNow } = built.value;
    const metrics = { status: content.dossierStatus, claims: content.summary.claims, reverificationPending: content.summary.reverificationPending };
    if (req.action === 'verify_dossier') {
      // Integrity of an exported dossier: was this hash ISSUED for this investigation, and is it still CURRENT?
      const snap = await store.findDossierSnapshot(inv.value.id, req.contentHash);
      if (!snap.ok) return snap;
      const state = !snap.value ? 'NOT_ISSUED' : snap.value.contentHash === contentHash ? 'CURRENT' : 'STALE';
      return ok({
        action: req.action,
        data: {
          state,
          snapshot: snap.value ? { ref: snap.value.ref, exportedAt: snap.value.exportedAt, asOf: snap.value.asOf, dossierStatus: snap.value.dossierStatus } : null,
          currentContentHash: contentHash,
          // Integrity is not truth: a CURRENT snapshot is unaltered, not "correct".
          integrityIsNotTruth: true,
        },
        metrics: { dossier: { ...metrics, stale: state === 'STALE' } },
      });
    }
    let envelope: DossierDocument['envelope'] = {
      kind: 'LIVE', generatedAt: now, auditSeq: inv.value.auditSeq, auditHead: inv.value.auditHead, snapshotRef: null,
      notice: 'LIVE_VIEW_OF_CURRENT_STATE', registryFreshAtGeneration: freshNow,
    };
    let snapshot: Record<string, unknown> | null = null;
    if (req.action === 'export_dossier') {
      const stored = await store.insertDossierSnapshot(inv.value.id, {
        ref: snapshotRefOf(contentHash), schemaVersion: DOSSIER_SCHEMA_VERSION, contentHash, asOf: content.asOf,
        dossierStatus: content.dossierStatus, claimCount: content.summary.claims, auditSeq: inv.value.auditSeq, auditHead: inv.value.auditHead,
        exportedAt: now,
      }, actor.userId);
      if (!stored.ok) return stored;
      envelope = {
        kind: 'SNAPSHOT', generatedAt: stored.value.exportedAt, auditSeq: stored.value.auditSeq, auditHead: stored.value.auditHead,
        snapshotRef: stored.value.ref, notice: 'HISTORICAL_SNAPSHOT_AS_OF', registryFreshAtGeneration: freshNow,
      };
      snapshot = { ref: stored.value.ref, contentHash, exportedAt: stored.value.exportedAt, replayed: stored.value.exportedAt !== now };
    }
    const doc: DossierDocument = {
      schemaVersion: DOSSIER_SCHEMA_VERSION, content,
      integrity: { algorithm: 'SHA-256', canonicalization: DOSSIER_CANONICALIZATION, contentHash },
      envelope,
    };
    return ok({
      action: req.action,
      data: { dossier: doc, text: renderDossierText(doc, req.lang), ...(snapshot ? { snapshot } : {}) },
      metrics: { dossier: { ...metrics, exported: req.action === 'export_dossier' } },
    });
  }

  const active = requireActive(inv.value);
  if (!active.ok) return active;
  const data = await load(store, inv.value.id);
  if (!data.ok) return data;
  const sourcesById = new Map(data.value.sources.map((s) => [s.source.id, s.source]));

  switch (req.action) {
    case 'archive_investigation': {
      const r = await store.archiveInvestigation(inv.value.id, actor.userId);
      if (!r.ok) return r;
      return ok({ action: req.action, data: { investigationId: inv.value.id, status: 'ARCHIVED' } });
    }

    case 'add_source': {
      if (data.value.sources.length >= LAB_LIMITS.maxSourcesPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many sources');
      const i = req.source;
      const src: Source = {
        id: i.ref,
        type: i.type,
        publisher: i.publisher,
        ...(i.publisherOrgRef ? { publisherOrganizationId: i.publisherOrgRef } : {}),
        ...(i.uri ? { uri: i.uri } : {}),
        retrievedAt: i.retrievedAt,
        ...(i.publishedAt ? { publishedAt: i.publishedAt } : {}),
        ...(i.jurisdictionCountry ? { jurisdiction: { country: i.jurisdictionCountry } } : {}),
        ...(i.newsGenre ? { newsGenre: i.newsGenre } : {}),
        status: 'ACTIVE',
        retention: i.retention,
        ...(i.contentHash ? { contentHash: i.contentHash } : {}),
        ...(i.syndicatedFrom ? { syndicatedFrom: i.syndicatedFrom } : {}),
        ...(i.derivedFrom ? { derivedFrom: i.derivedFrom } : {}),
        // I2: lineage signals are computed HERE from the submitted text; the text is not kept.
        ...(i.contentText
          ? {
            contentFingerprint: await contentFingerprint(i.contentText),
            similaritySketch: similaritySketch(i.contentText),
            syndicationMarkers: detectSyndicationMarkers(i.contentText),
          }
          : {}),
        // CF-06: a client can never produce PROVIDER provenance.
        acquisition: i.userUpload ? { method: 'USER_UPLOAD' } : { method: 'ANALYST_ENTRY' },
        ...(i.userUpload ? { userSubmitted: true } : {}),
      };
      const v = validateSource(src, nowMs);
      if (!v.ok) return v;
      const r = await store.insertSource(inv.value.id, { source: src, snapshot: null }, actor.userId);
      if (!r.ok) return r;
      return ok({
        action: req.action,
        data: {
          sourceRef: src.id, acquisition: src.acquisition.method,
          lineage: { fingerprinted: !!src.contentFingerprint, syndicationMarkers: src.syndicationMarkers ?? [] },
        },
      });
    }

    case 'ingest_provider_record': {
      const ing = await ingestProviderRecord(req.providerId, req.recordId, req.ref, providers);
      if (!ing.ok) return ing;
      const rec = ing.value.record;
      const sameSnapshot = (d: InvestigationData) =>
        d.sources.find((s) => s.snapshot && s.snapshot.providerId === rec.providerId && s.snapshot.recordId === rec.recordId && s.snapshot.dataHash === rec.dataHash);
      const respond = (d: InvestigationData, sourceRef: string, replayed: boolean) => ok<LabResponse>({
        action: req.action,
        data: {
          sourceRef,
          replayed,
          providerId: rec.providerId,
          canonicalOrgId: rec.canonicalOrgId,
          registration: { country: rec.jurisdiction.country, scheme: rec.scheme, number: rec.registrationNumber, status: rec.status },
          snapshot: snapshotView(sourceRef, true, d.sources.find((s) => s.source.id === sourceRef)?.snapshot ?? rec, providers, nowMs),
          registryConflicts: d.registryConflicts.filter((c) => c.sourceRef === sourceRef || c.otherSourceRef === sourceRef),
          subjectIdentityStatus: subjectIdentityFrom(inv.value, d.sources, providers),
        },
        metrics: { registry: { providerId: rec.providerId, outcome: replayed ? 'REPLAYED' : 'RECORDED', candidates: 1 } },
      });
      // I2 idempotency: identical registry data is one snapshot, whatever the ref.
      const existing = sameSnapshot(data.value);
      if (existing) return respond(data.value, existing.source.id, true);
      if (data.value.sources.length >= LAB_LIMITS.maxSourcesPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many sources');
      const v = validateSource(ing.value.source, nowMs);
      if (!v.ok) return v;
      const r = await store.insertSource(inv.value.id, { source: ing.value.source, snapshot: rec }, actor.userId);
      if (!r.ok) {
        // Concurrent ingestion of the same data: the unique snapshot key won — replay it.
        if (r.error.code === 'ALREADY_EXISTS') {
          const again = await load(store, inv.value.id);
          const winner = again.ok ? sameSnapshot(again.value) : undefined;
          if (again.ok && winner) return respond(again.value, winner.source.id, true);
        }
        return r;
      }
      const after = await load(store, inv.value.id);
      if (!after.ok) return after;
      return respond(after.value, req.ref, false);
    }

    case 'update_source_status': {
      const current = sourcesById.get(req.sourceRef);
      if (!current) return fail('INVALID_REQUEST', 'unknown source');
      // Codex I1G2-05: no silent no-op writes (the database refuses them too).
      if (current.status === req.status) return fail('ALREADY_EXISTS', 'source already has that status');
      const r = await store.updateSourceStatus(inv.value.id, req.sourceRef, req.status, actor.userId);
      if (!r.ok) return r;
      const affected = [...new Set(data.value.evidence.filter((e) => e.sourceId === req.sourceRef).map((e) => e.claimId))].sort();
      return ok({ action: req.action, data: { sourceRef: req.sourceRef, status: req.status, reverificationRequired: affected } });
    }

    case 'add_claim': {
      if (data.value.claims.length >= LAB_LIMITS.maxClaimsPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many claims');
      const i = req.claim;
      if (!sourcesById.has(i.sourceRef)) return fail('INVALID_REQUEST', 'unknown source');
      const c: Claim = {
        id: i.ref,
        investigationId: inv.value.id,
        kind: i.kind,
        text: i.text,
        ...(i.textLanguage ? { textLanguage: i.textLanguage } : {}),
        ...(i.quantity ? { quantity: i.quantity } : {}),
        ...(i.level ? { level: i.level } : {}),
        ...(i.claimantOrgRef ? { claimantOrganizationId: i.claimantOrgRef } : {}),
        ...(i.claimantLabel ? { claimantLabel: i.claimantLabel } : {}),
        subjectOrganizationId: inv.value.subjectOrgRef, // CF-01: forced by the server
        ...(i.subjectProjectRef ? { subjectProjectId: i.subjectProjectRef } : {}),
        ...(i.subjectCampaignRef ? { subjectCampaignId: i.subjectCampaignRef } : {}),
        ...(i.period ? { period: i.period } : {}),
        sourceId: i.sourceRef,
        extractedAt: now,
        origin: i.origin,
      };
      const v = validateClaim(c, inv.value.id);
      if (!v.ok) return v;
      const r = await store.insertClaim(inv.value.id, c, actor.userId);
      if (!r.ok) return r;
      return ok({ action: req.action, data: { claimRef: c.id, subjectOrgRef: c.subjectOrganizationId } });
    }

    case 'add_evidence': {
      if (data.value.evidence.length >= LAB_LIMITS.maxEvidencePerInvestigation) return fail('LIMIT_EXCEEDED', 'too much evidence');
      const i = req.evidence;
      const claim = data.value.claims.find((c) => c.id === i.claimRef);
      if (!claim) return fail('INVALID_REQUEST', 'unknown claim');
      if (!sourcesById.has(i.sourceRef)) return fail('INVALID_REQUEST', 'unknown source');
      // I2 entity-spoofing guard (Codex I2G1-03): a caller cannot declare that a
      // registry record of another organization is ABOUT the subject.
      const snap = data.value.sources.find((x) => x.source.id === i.sourceRef)?.snapshot;
      if (snap && i.aboutOrgRef === inv.value.subjectOrgRef && resolveEntity(inv.value.subjectIdentity, snap.identity).outcome !== 'CONFIRMED_MATCH') {
        return fail('ENTITY_MATCH_UNCERTAIN', 'registry record does not identify the investigation subject');
      }
      const e: EvidenceItem = {
        id: i.ref,
        investigationId: inv.value.id,
        claimId: i.claimRef,
        sourceId: i.sourceRef,
        aboutOrganizationId: i.aboutOrgRef,
        relationship: i.relationship,
        relationshipBasis: i.basis,
        ...(i.reportedQuantity ? { reportedQuantity: i.reportedQuantity } : {}),
        ...(i.level ? { level: i.level } : {}),
        ...(i.observedPeriod ? { observedPeriod: i.observedPeriod } : {}),
        ...(i.excerpt ? { excerpt: i.excerpt, excerptHash: await sha256Hex(i.excerpt) } : {}),
        ...(i.locator ? { locator: i.locator } : {}),
        personalData: i.personalData,
        ...(i.legalStage ? { legalStage: i.legalStage } : {}),
        addedAt: now,
      };
      const v = await validateEvidence(e, claim, sourcesById);
      if (!v.ok) return v;
      const r = await store.insertEvidence(inv.value.id, e, actor.userId);
      if (!r.ok) return r;
      const scan = e.excerpt ? scanUntrustedContent(e.excerpt) : null;
      return ok({ action: req.action, data: { evidenceRef: e.id, untrustedInstructionsDetected: scan?.flagged ?? false, markers: scan?.markers ?? [] } });
    }

    case 'import_registry_claim': {
      const s = data.value.sources.find((x) => x.source.id === req.sourceRef);
      if (!s || !s.snapshot || s.source.acquisition.method !== 'PROVIDER' || !providers.get(s.source.acquisition.providerId)) {
        return fail('INVALID_REQUEST', 'source is not a trusted registry snapshot');
      }
      if (s.source.status !== 'ACTIVE') return fail('SOURCE_UNAVAILABLE', 'registry snapshot is not active');
      // Entity spoofing guard: the record must CONFIRM the investigation subject
      // by registration — a name, a domain or a caller's say-so is not enough.
      const match = resolveEntity(inv.value.subjectIdentity, s.snapshot.identity);
      if (match.outcome !== 'CONFIRMED_MATCH') {
        return fail('ENTITY_MATCH_UNCERTAIN', 'registry record does not confirm the investigation subject', { outcome: match.outcome });
      }
      const st = registryStatement({
        record: s.snapshot, source: s.source, investigationId: inv.value.id, subjectRef: inv.value.subjectOrgRef, claimRef: req.ref, now,
      });
      const prior = data.value.claims.find((c) => c.id === req.ref);
      const vc = validateClaim(st.claim, inv.value.id);
      if (!vc.ok) return vc;
      const srcMap = new Map(sourcesById);
      const ve = await validateEvidence(st.evidence, st.claim, srcMap);
      if (!ve.ok) return ve;
      if (prior) {
        // Codex I2F-01: claim and evidence are two writes. An IDENTICAL retry
        // (same snapshot, same generated statement and period) replays when
        // both exist and REPAIRS the missing evidence otherwise; anything else
        // reusing the ref is a different request. Success is never reported
        // unless both rows exist.
        // I2F2-01: only a claim this action generated (server-only origin) can be replayed or repaired.
        const same = prior.sourceId === req.sourceRef && prior.text === st.claim.text && prior.origin === 'REGISTRY_IMPORT'
          && prior.kind === 'LEGAL_REGISTRATION' && prior.period?.from === st.claim.period?.from && prior.period?.to === st.claim.period?.to;
        if (!same) return fail('ALREADY_EXISTS', 'claim ref already used');
        const priorEv = data.value.evidence.find((e) => e.id === st.evidence.id);
        if (priorEv) {
          if (priorEv.relationshipBasis !== 'REGISTRY_RECORD' || priorEv.sourceId !== req.sourceRef || priorEv.claimId !== prior.id) {
            return fail('ALREADY_EXISTS', 'evidence ref already used');
          }
          return ok({ action: req.action, data: { claimRef: prior.id, evidenceRef: priorEv.id, text: prior.text, replayed: true } });
        }
        const repaired = await store.insertEvidence(inv.value.id, { ...st.evidence, claimId: prior.id }, actor.userId);
        if (!repaired.ok) return repaired;
        return ok({ action: req.action, data: { claimRef: prior.id, evidenceRef: st.evidence.id, text: prior.text, repaired: true } });
      }
      // I1F2-01 pattern: the limit applies to NEW claims only, so a retry can always repair.
      if (data.value.claims.length >= LAB_LIMITS.maxClaimsPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many claims');
      const c1 = await store.insertClaim(inv.value.id, st.claim, actor.userId);
      if (!c1.ok) return c1;
      const e1 = await store.insertEvidence(inv.value.id, st.evidence, actor.userId);
      if (!e1.ok) return e1; // the claim is persisted: an identical retry repairs the evidence
      return ok({ action: req.action, data: { claimRef: st.claim.id, evidenceRef: st.evidence.id, text: st.claim.text, period: st.claim.period } });
    }

    case 'ingest_artifact': {
      // I3: the SERVER decodes, validates, hashes and extracts; nothing the
      // client says about the file (type, hash, text, authority) is trusted.
      const a = req.artifact;
      let bytes: Uint8Array;
      try {
        const bin = atob(a.contentBase64);
        bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
      } catch {
        return fail('INVALID_REQUEST', 'contentBase64 is not valid base64');
      }
      if (bytes.length > ARTIFACT_LIMITS.maxBytes) return fail('FILE_TOO_LARGE', 'file exceeds the artifact size limit');
      const detected = await detectArtifact(bytes, a.filename, a.mediaType);
      if (!detected.ok) return detected; // nothing is persisted for a rejected file
      const fileHash = await sha256Bytes(bytes);
      const extraction = await extractArtifact(detected.value.type, bytes, detected.value.text);
      const identity = inv.value.subjectIdentity;
      const claimsById = new Map(data.value.claims.map((c) => [c.id, c]));

      // Same bytes in THIS investigation → REUSE (never a second artifact).
      // Dedup is per investigation only: another user's identical file is
      // invisible here (no cross-investigation side channel).
      const existing = data.value.artifacts.find((x) => x.fileHash === fileHash);
      const artifactRef = existing?.ref ?? a.ref;
      if (!existing && data.value.artifacts.some((x) => x.ref === a.ref)) {
        return fail('ALREADY_EXISTS', 'artifact ref holds another file; attach a new version with supersedes_ref');
      }

      // Validate every requested candidate BEFORE anything is written.
      const requested: { ref: string; draft: CandidateDraft }[] = [];
      for (const c of a.candidates) {
        if (c.claimRef && !claimsById.has(c.claimRef)) return fail('INVALID_REQUEST', 'unknown claim');
        const d = analystCandidate(extraction, c, identity);
        if (!d.ok) return d;
        if (d.value === 'MINOR_DATA_RISK') return fail('SENSITIVE_DATA_REJECTED', 'excerpt looks like personal data about a minor');
        requested.push({ ref: c.ref, draft: d.value });
      }

      let version = existing?.version ?? 1;
      let newSource: Source | null = null;
      let newArtifact: StoredArtifact | null = null;
      if (!existing) {
        if (data.value.artifacts.length >= ARTIFACT_LIMITS.maxArtifactsPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many artifacts');
        if (a.supersedesRef) {
          const prior = data.value.artifacts.find((x) => x.ref === a.supersedesRef);
          if (!prior) return fail('INVALID_REQUEST', 'unknown artifact to supersede');
          if (data.value.artifacts.some((x) => x.supersedesRef === prior.ref)) return fail('ALREADY_EXISTS', 'artifact already superseded');
          version = prior.version + 1;
        }
        const text = extraction.segments.map((x) => x.text).join('\n');
        const priorSource = data.value.sources.find((x) => x.source.id === artifactRef);
        if (priorSource) {
          // Legacy half-written ingestion (before the atomic write, I3F-03): the same bytes'
          // uncited source exists without its artifact — it is adopted, never duplicated.
          if (priorSource.source.acquisition.method !== 'USER_UPLOAD' || priorSource.source.contentHash !== fileHash) {
            return fail('ALREADY_EXISTS', 'source ref already used');
          }
        } else {
          if (data.value.sources.length >= LAB_LIMITS.maxSourcesPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many sources');
          const provider = a.cloud?.provider;
          const src: Source = {
            id: artifactRef,
            type: 'USER_DOCUMENT',
            publisher: provider ? `Cloud import (${provider}, client-declared)` : 'User upload',
            retrievedAt: now,
            status: 'ACTIVE',
            retention: 'HASH_ONLY', // I1 policy for USER_DOCUMENT kept: the ORIGINAL is not retained; reviewed excerpts live in candidates
            contentHash: fileHash, // server-computed; USER_UPLOAD never becomes provider provenance (CF-06)
            acquisition: { method: 'USER_UPLOAD' },
            userSubmitted: true,
            ...(text.trim()
              ? {
                contentFingerprint: await contentFingerprint(text.slice(0, 20_000)),
                similaritySketch: similaritySketch(text.slice(0, 20_000)),
                syndicationMarkers: detectSyndicationMarkers(text.slice(0, 20_000)),
              }
              : {}),
          };
          const v = validateSource(src, nowMs);
          if (!v.ok) return v;
          newSource = src;
        }
        newArtifact = {
          ref: artifactRef, sourceRef: artifactRef, type: detected.value.type, origin: a.origin, originalFilename: detected.value.filename,
          mediaType: detected.value.mediaType, sizeBytes: bytes.length, fileHash,
          normalizedContentHash: text.trim() ? await contentFingerprint(text) : null,
          version, supersedesRef: a.supersedesRef ?? null, cloudProvider: a.cloud?.provider ?? null, cloudFileRef: a.cloud?.fileRef ?? null,
          sourceModifiedAt: a.cloud?.modifiedAt ?? null, extractionStatus: extraction.summary.status, extraction: extraction.summary, ingestedAt: now,
        };
      }
      const artifact: StoredArtifact | undefined = existing ?? newArtifact ?? undefined;
      if (!artifact) return fail('INTERNAL_ERROR', 'artifact unavailable');

      // Candidates: analyst-requested (+ deterministic ones on first ingestion only).
      const auto = existing ? { drafts: [], skippedMinorRisk: 0 } : autoCandidates(extraction, data.value.claims, identity);
      const drafts = [
        ...requested,
        ...auto.drafts.map((d, i) => ({ ref: `${artifactRef}.auto${i + 1}`, draft: d })),
      ];
      const toInsert: StoredCandidate[] = [];
      const replayed: string[] = [];
      for (const { ref, draft } of drafts) {
        if (!locatorFitsSummary(draft.locator, artifact.extraction)) return fail('LOCATOR_INVALID', 'locator outside the artifact structure');
        const prior = data.value.candidates.find((x) => x.ref === ref);
        if (prior) {
          if (prior.artifactRef === artifactRef && locatorKey(prior.locator) === locatorKey(draft.locator) && prior.excerpt === draft.excerpt) {
            replayed.push(ref);
            continue;
          }
          return fail('ALREADY_EXISTS', 'candidate ref already used');
        }
        toInsert.push({
          ref, artifactRef, artifactHash: artifact.fileHash, locator: draft.locator, excerpt: draft.excerpt, excerptHash: await sha256Hex(draft.excerpt),
          claimRef: draft.claimRef ?? null, proposedRelationship: draft.proposedRelationship ?? null, method: draft.method,
          reviewReasons: draft.reviewReasons, reviewStatus: 'PENDING', reviewRelationship: null, reviewClaimRef: null, reviewAboutOrgRef: null,
          evidenceRef: null, reviewedAt: null,
        });
      }
      if (data.value.candidates.length + toInsert.length > ARTIFACT_LIMITS.maxCandidatesPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many candidates');
      if (newArtifact) {
        // ONE atomic write (I3F-03): source + artifact + candidates, or nothing —
        // a failed or racing ingestion can no longer leave an orphan source.
        const w = await store.insertArtifactBundle(inv.value.id, { source: newSource, artifact: newArtifact, candidates: toInsert }, actor.userId);
        if (!w.ok) return w;
      } else if (toInsert.length) {
        const r3 = await store.insertCandidates(inv.value.id, toInsert, actor.userId);
        if (!r3.ok) return r3;
      }
      return ok({
        action: req.action,
        data: {
          artifact: artifactView(artifact),
          duplicate: !!existing,
          candidates: toInsert.map(candidateView),
          replayedCandidates: replayed,
          skippedMinorDataRisk: auto.skippedMinorRisk,
          // Candidates are not evidence and not facts; a human review is required.
          candidatesAreNotEvidence: true,
          policyVersion: ARTIFACT_POLICY_VERSION,
        },
        metrics: { artifact: { type: artifact.type, status: artifact.extractionStatus, sizeBytes: artifact.sizeBytes, candidates: toInsert.length } },
      });
    }

    case 'review_candidate': {
      const rv = req.review;
      const cand = data.value.candidates.find((x) => x.ref === rv.candidateRef);
      if (!cand) return fail('INVALID_REQUEST', 'unknown candidate');
      const artifact = data.value.artifacts.find((x) => x.ref === cand.artifactRef)!;
      const evidenceRef = `${cand.ref}.ev`;
      if (rv.decision !== 'ACCEPTED') {
        if (rv.relationship || rv.claimRef || rv.aboutOrgRef || rv.personalData || rv.observedPeriod) {
          return fail('INVALID_REQUEST', 'only an ACCEPTED review carries a relationship');
        }
        if (cand.reviewStatus === rv.decision && rv.decision === 'REJECTED') return ok({ action: req.action, data: { candidate: candidateView(cand), replayed: true } });
        if (cand.reviewStatus === 'ACCEPTED' || cand.reviewStatus === 'REJECTED') return fail('ALREADY_EXISTS', 'candidate already reviewed');
        const r = await store.reviewCandidate(inv.value.id, cand.ref, {
          status: rv.decision, relationship: null, claimRef: null, aboutOrgRef: null, evidenceRef: null, reviewedAt: now,
        }, actor.userId);
        if (!r.ok) return r;
        return ok({ action: req.action, data: { candidateRef: cand.ref, reviewStatus: rv.decision, humanReviewIsNotVerification: true } });
      }
      // ACCEPTED → promotion to evidence (USER_UPLOAD: contextual, never authority).
      const claimRef = rv.claimRef ?? cand.claimRef ?? undefined;
      if (cand.claimRef && rv.claimRef && cand.claimRef !== rv.claimRef) return fail('INVALID_REQUEST', 'candidate belongs to another claim');
      if (!claimRef || !rv.relationship || !rv.aboutOrgRef || !rv.personalData) {
        return fail('EVIDENCE_REVIEW_REQUIRED', 'accepting needs claim_ref, relationship, about_org_ref and personal_data');
      }
      const claim = data.value.claims.find((c) => c.id === claimRef);
      if (!claim) return fail('INVALID_REQUEST', 'unknown claim');
      // Codex I3G3-06: the server's own isolation warning must be resolved explicitly.
      if (cand.reviewReasons.includes('SUBJECT_NOT_MENTIONED') && rv.aboutOrgRef === inv.value.subjectOrgRef && rv.subjectConfirmed !== true) {
        return fail('EVIDENCE_REVIEW_REQUIRED', 'the excerpt does not name the subject: confirm the attribution (subject_confirmed) or attribute it to another organization');
      }
      const e: EvidenceItem = {
        id: evidenceRef,
        investigationId: inv.value.id,
        claimId: claimRef,
        sourceId: artifact.sourceRef,
        aboutOrganizationId: rv.aboutOrgRef,
        relationship: rv.relationship,
        relationshipBasis: 'HUMAN_ASSESSED',
        ...(rv.observedPeriod ? { observedPeriod: rv.observedPeriod } : {}),
        excerpt: cand.excerpt,
        excerptHash: cand.excerptHash,
        locator: { artifact: { ref: artifact.ref, hash: artifact.fileHash, locator: cand.locator } },
        personalData: rv.personalData,
        addedAt: now,
      };
      if (cand.reviewStatus === 'ACCEPTED') {
        const same = cand.reviewClaimRef === claimRef && cand.reviewRelationship === rv.relationship && cand.reviewAboutOrgRef === rv.aboutOrgRef;
        return same ? ok({ action: req.action, data: { candidate: candidateView(cand), evidenceRef, replayed: true } }) : fail('ALREADY_EXISTS', 'candidate already reviewed');
      }
      if (cand.reviewStatus === 'REJECTED') return fail('ALREADY_EXISTS', 'candidate already reviewed');
      if (data.value.evidence.some((x) => x.id === evidenceRef)) return fail('ALREADY_EXISTS', 'evidence ref already used');
      if (data.value.evidence.length >= LAB_LIMITS.maxEvidencePerInvestigation) return fail('LIMIT_EXCEEDED', 'too much evidence');
      const ve = await validateEvidence(e, claim, sourcesById);
      if (!ve.ok) return ve;
      // ONE write: inserting the bound evidence IS the acceptance (the store /
      // database promote the candidate in the same statement — Codex I3G2-01).
      const r = await store.insertEvidence(inv.value.id, e, actor.userId);
      if (!r.ok) return r;
      return ok({
        action: req.action,
        data: {
          candidateRef: cand.ref, reviewStatus: 'ACCEPTED', evidenceRef, claimRef,
          // A human accepting a candidate is not a verification: run_verification decides, and
          // an uploaded document stays USER_SUBMITTED (never authority).
          humanReviewIsNotVerification: true,
        },
      });
    }

    case 'run_verification': {
      if (!data.value.claims.some((c) => c.id === req.claimRef)) return fail('INVALID_REQUEST', 'unknown claim');
      const v = await verifyAndStore(store, actor, inv.value, data.value, req.claimRef, now, req.idempotencyKey ?? null, providers, req.humanReviewBindingHash);
      if (!v.ok) return v;
      return ok({
        action: req.action,
        data: { verification: summary(v.value.result, v.value.version), indicators: deriveIndicators({ results: [v.value.result] }), replayed: v.value.replayed },
        metrics: {
          evidence: v.value.evidenceCount, conflicts: v.value.result.conflicts.length, status: v.value.result.status,
          lineageLinks: v.value.result.lineage.links.length,
        },
      });
    }

    case 'open_dispute': {
      const existing = data.value.disputes.find((d) => d.ref === req.ref);
      // I1F2-01: a retry is recognised BEFORE the limit, so it can always repair.
      if (!existing && data.value.disputes.length >= LAB_LIMITS.maxDisputesPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many disputes');
      if (!data.value.claims.some((c) => c.id === req.claimRef)) return fail('INVALID_REQUEST', 'unknown claim');
      for (const ref of req.submittedEvidenceRefs) {
        if (data.value.evidence.find((e) => e.id === ref)?.claimId !== req.claimRef) {
          return fail('INVALID_REQUEST', 'evidence must belong to the disputed claim');
        }
      }
      if (existing) {
        // Retry of the same dispute (I1F-02): repair the re-verification instead of failing.
        const a = [...existing.submittedEvidenceRefs].sort();
        const b = [...req.submittedEvidenceRefs].sort();
        const sameRefs = a.length === b.length && a.every((r, i) => r === b[i]);
        // I1F3-02: only an IDENTICAL request is a retry.
        if (existing.claimRef !== req.claimRef || existing.kind !== req.kind || existing.resolution !== null || !sameRefs) {
          return fail('ALREADY_EXISTS', 'dispute ref already used');
        }
        const settled = await settledLatest(actor, inv.value, data.value, req.claimRef, now, providers);
        if (settled) return ok({ action: req.action, data: { disputeRef: req.ref, claimRef: req.claimRef, verification: settled, replayed: true } });
      } else {
        const r = await store.insertDispute(inv.value.id, {
          ref: req.ref, claimRef: req.claimRef, kind: req.kind, openedAt: now, submittedEvidenceRefs: req.submittedEvidenceRefs,
          resolution: null, resolvedAt: null,
        }, actor.userId);
        if (!r.ok) return r;
      }
      // Codex I1G2-02: the persisted latest state becomes DISPUTED immediately.
      const v = await reverify(store, actor, inv.value, req.claimRef, now, providers);
      if (!v.ok) return v;
      return ok({ action: req.action, data: { disputeRef: req.ref, claimRef: req.claimRef, verification: summary(v.value.result, v.value.version) } });
    }

    case 'resolve_dispute': {
      const d = data.value.disputes.find((x) => x.ref === req.disputeRef);
      if (!d) return fail('INVALID_REQUEST', 'unknown dispute');
      if (d.resolution !== null && d.resolution !== req.resolution) return fail('ALREADY_EXISTS', 'dispute already resolved');
      if (d.resolution === null) {
        const r = await store.resolveDispute(inv.value.id, req.disputeRef, req.resolution, now, actor.userId);
        if (!r.ok) return r;
      } else {
        // Retry of the same resolution: repair only if the read state is still pending (I1F-02 / I1F2-02).
        const settled = await settledLatest(actor, inv.value, data.value, d.claimRef, now, providers);
        if (settled) return ok({ action: req.action, data: { disputeRef: req.disputeRef, resolution: req.resolution, verification: settled, replayed: true } });
      }
      const v = await reverify(store, actor, inv.value, d.claimRef, now, providers);
      if (!v.ok) return v;
      return ok({ action: req.action, data: { disputeRef: req.disputeRef, resolution: req.resolution, verification: summary(v.value.result, v.value.version) } });
    }
  }
  return fail('INVALID_REQUEST', 'unknown action');
}
