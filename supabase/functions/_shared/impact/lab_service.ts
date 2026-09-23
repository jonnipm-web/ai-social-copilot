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
 * No LLM, no network, no verdict field.
 */
import { requestImpactAction } from './boundaries.ts';
import { resolveEntity } from './entity_resolution.ts';
import { fail, ok, type ImpactResult } from './errors.ts';
import { LAB_LIMITS, type LabRequest } from './lab_contract.ts';
import type { ImpactLabStore, InvestigationData, InvestigationRecord, StoredDispute, StoredSource } from './lab_store.ts';
import { normalizeDomain } from './entity_resolution.ts';
import { parseIsoMs, sha256Hex, validateClaim, validateEvidence, validateSource } from './provenance.ts';
import { getRegisteredProvider, ingestProviderRecord, PROVIDER_REGISTRY_VERSION, trustedProviderRefs } from './provider_registry.ts';
import { buildImpactReport } from './report.ts';
import { deriveIndicators } from './risk_indicators.ts';
import { scanUntrustedContent } from './safety.ts';
import type { Claim, EvidenceItem, Jurisdiction, OrganizationIdentity, Source } from './types.ts';
import { IMPACT_POLICY_VERSION, type SubjectIdentityStatus, type VerificationResult, verifyClaim } from './verification.ts';

export interface LabActor {
  /** auth.users id, derived from the verified session — never from the body. */
  readonly userId: string;
}

export interface LabResponse {
  readonly action: LabRequest['action'];
  readonly data: Readonly<Record<string, unknown>>;
  /** Counts for observability (no content). */
  readonly metrics?: { readonly claims?: number; readonly evidence?: number; readonly conflicts?: number; readonly status?: string };
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
export function subjectIdentityFrom(inv: InvestigationRecord, sources: readonly StoredSource[]): SubjectIdentityStatus {
  const outcomes = sources
    .filter((s) =>
      s.snapshot && s.source.status === 'ACTIVE' && s.source.acquisition.method === 'PROVIDER' &&
      getRegisteredProvider(s.source.acquisition.providerId)?.descriptor.sourceType === s.source.type
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
  humanReviewBindingHash?: string,
): Promise<ImpactResult<StoredRun>> {
  const claim = data.claims.find((c) => c.id === claimRef);
  if (!claim) return fail('INVALID_REQUEST', 'unknown claim');
  const evidence = data.evidence.filter((e) => e.claimId === claim.id);
  // Untrusted-content boundary: excerpts carrying instructions flag their source (review), never obeyed.
  const flagged = [...new Set(evidence.filter((e) => e.excerpt && scanUntrustedContent(e.excerpt).flagged).map((e) => e.sourceId))];
  const openDispute = data.disputes.some((d) => d.claimRef === claim.id && d.resolution === null);
  const r = await verifyClaim(
    { claim, evidence, sources: data.sources.map((s) => s.source) },
    {
      evaluatedAt: now,
      subjectIdentity: subjectIdentityFrom(inv, data.sources),
      openDispute,
      flaggedSourceIds: flagged,
      trustedProviders: trustedProviderRefs(), // CF-06: server registry only
      ...(humanReviewBindingHash
        ? { humanReview: { reviewedAt: now, reviewerRef: await actorRefOf(actor.userId), reviewBindingHash: humanReviewBindingHash } }
        : {}),
    },
  );
  if (!r.ok) return r;
  const stored = await store.insertVerification(inv.id, r.value, idempotencyKey, actor.userId);
  if (!stored.ok) return stored;
  // Codex I1G2-03: an idempotency key replays only the SAME claim.
  if (stored.value.result.claimId !== claim.id) return fail('ALREADY_EXISTS', 'idempotency key already used for another claim');
  return ok({ result: stored.value.result, version: stored.value.version, replayed: stored.value.result.resultId !== r.value.resultId, evidenceCount: evidence.length });
}

async function reverify(store: ImpactLabStore, actor: LabActor, inv: InvestigationRecord, claimRef: string, now: string) {
  const fresh = await load(store, inv.id);
  if (!fresh.ok) return fresh;
  return await verifyAndStore(store, actor, inv, fresh.value, claimRef, now, null);
}

export async function handleLabRequest(
  store: ImpactLabStore,
  actor: LabActor,
  req: LabRequest,
  now: string,
): Promise<ImpactResult<LabResponse>> {
  const nowMs = parseIsoMs(now);
  if (nowMs === null) return fail('INTERNAL_ERROR', 'server clock unavailable');

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
        subjectIdentityStatus: subjectIdentityFrom(inv.value, data.value.sources),
        sources: data.value.sources.map((s) => ({ ...s.source, provenance: { acquisition: s.source.acquisition, hasSnapshot: !!s.snapshot } })),
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
        // CF-06: a client can never produce PROVIDER provenance.
        acquisition: i.userUpload ? { method: 'USER_UPLOAD' } : { method: 'ANALYST_ENTRY' },
        ...(i.userUpload ? { userSubmitted: true } : {}),
      };
      const v = validateSource(src, nowMs);
      if (!v.ok) return v;
      const r = await store.insertSource(inv.value.id, { source: src, snapshot: null }, actor.userId);
      if (!r.ok) return r;
      return ok({ action: req.action, data: { sourceRef: src.id, acquisition: src.acquisition.method } });
    }

    case 'ingest_provider_record': {
      if (data.value.sources.length >= LAB_LIMITS.maxSourcesPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many sources');
      const ing = await ingestProviderRecord(req.providerId, req.recordId, req.ref);
      if (!ing.ok) return ing;
      const v = validateSource(ing.value.source, nowMs);
      if (!v.ok) return v;
      const r = await store.insertSource(inv.value.id, { source: ing.value.source, snapshot: ing.value.record }, actor.userId);
      if (!r.ok) return r;
      return ok({
        action: req.action,
        data: {
          sourceRef: req.ref, providerId: ing.value.source.acquisition.method === 'PROVIDER' ? ing.value.source.acquisition.providerId : null,
          registration: { country: ing.value.record.jurisdiction.country, number: ing.value.record.registrationNumber, status: ing.value.record.status },
          subjectIdentityStatus: subjectIdentityFrom(inv.value, [...data.value.sources, { source: ing.value.source, snapshot: ing.value.record }]),
        },
      });
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

    case 'run_verification': {
      if (!data.value.claims.some((c) => c.id === req.claimRef)) return fail('INVALID_REQUEST', 'unknown claim');
      const v = await verifyAndStore(store, actor, inv.value, data.value, req.claimRef, now, req.idempotencyKey ?? null, req.humanReviewBindingHash);
      if (!v.ok) return v;
      return ok({
        action: req.action,
        data: { verification: summary(v.value.result, v.value.version), indicators: deriveIndicators({ results: [v.value.result] }), replayed: v.value.replayed },
        metrics: { evidence: v.value.evidenceCount, conflicts: v.value.result.conflicts.length, status: v.value.result.status },
      });
    }

    case 'open_dispute': {
      if (data.value.disputes.length >= LAB_LIMITS.maxDisputesPerInvestigation) return fail('LIMIT_EXCEEDED', 'too many disputes');
      if (!data.value.claims.some((c) => c.id === req.claimRef)) return fail('INVALID_REQUEST', 'unknown claim');
      for (const ref of req.submittedEvidenceRefs) {
        if (data.value.evidence.find((e) => e.id === ref)?.claimId !== req.claimRef) {
          return fail('INVALID_REQUEST', 'evidence must belong to the disputed claim');
        }
      }
      const existing = data.value.disputes.find((d) => d.ref === req.ref);
      if (existing) {
        // Retry of the same dispute (I1F-02): repair the re-verification instead of failing.
        if (existing.claimRef !== req.claimRef || existing.kind !== req.kind || existing.resolution !== null) {
          return fail('ALREADY_EXISTS', 'dispute ref already used');
        }
      } else {
        const r = await store.insertDispute(inv.value.id, {
          ref: req.ref, claimRef: req.claimRef, kind: req.kind, openedAt: now, submittedEvidenceRefs: req.submittedEvidenceRefs,
          resolution: null, resolvedAt: null,
        }, actor.userId);
        if (!r.ok) return r;
      }
      // Codex I1G2-02: the persisted latest state becomes DISPUTED immediately.
      const v = await reverify(store, actor, inv.value, req.claimRef, now);
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
      } // else: retry of the same resolution — repair the re-verification (I1F-02)
      const v = await reverify(store, actor, inv.value, d.claimRef, now);
      if (!v.ok) return v;
      return ok({ action: req.action, data: { disputeRef: req.disputeRef, resolution: req.resolution, verification: summary(v.value.result, v.value.version) } });
    }
  }
  return fail('INVALID_REQUEST', 'unknown action');
}
