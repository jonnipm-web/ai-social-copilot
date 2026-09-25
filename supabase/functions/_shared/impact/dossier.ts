/**
 * Verification Dossier — IV-IMPACT-I4-VERIFICATION-DOSSIER-01.
 *
 * A dossier is a DETERMINISTIC PROJECTION of the persisted investigation
 * (claims, evidence, artifacts, verifications, conflicts, disputes, registry
 * snapshots). It is never a source of truth, never a verdict and never a
 * score: every status, class, authority and independence value is copied from
 * the server engine's stored results — nothing is re-decided here, and no
 * client input, reviewer text, document text or model output reaches it.
 *
 *   content   — language-neutral codes and refs; SAME persisted state ⇒ SAME
 *               content ⇒ SAME contentHash (sha256 over canonical JSON).
 *   envelope  — generatedAt, LIVE | SNAPSHOT, audit-chain position: outside
 *               the hash (they vary without the evidence changing).
 *
 * The hash proves the INTEGRITY of what was represented, never its TRUTH.
 * Human-readable text is rendered separately (dossier_render.ts), in PT/EN.
 */
import { ARTIFACT_POLICY_VERSION, locatorFitsSummary } from './artifact_model.ts';
import { type PresentationContext, present, presentUri, PRIVACY_POLICY_VERSION } from './privacy.ts';
import type { InvestigationData, InvestigationRecord, StoredArtifact, StoredDispute } from './lab_store.ts';
import { snapshotFresh } from './organization_identity.ts';
import { LINEAGE_POLICY_VERSION } from './source_lineage.ts';
import { sha256Hex } from './provenance.ts';
import type { ClaimStatus, EpistemicClass, EvidenceItem, Source } from './types.ts';
import {
  canonical,
  computeEvidenceSetHash,
  IMPACT_POLICY_VERSION,
  type SubjectIdentityStatus,
  type VerificationResult,
} from './verification.ts';

export const DOSSIER_SCHEMA_VERSION = 'impact-dossier/1';
export const DOSSIER_CANONICALIZATION = 'impact-canonical-json/1';

export const DOSSIER_LIMITS = Object.freeze({
  /** Canonical content above this size is refused (DOSSIER_TOO_LARGE), never truncated silently. */
  maxContentChars: 2_000_000,
});

/** Completeness / processing state of the DOSSIER — never a judgement of the organization. */
export type DossierStatus = 'COMPLETE' | 'PARTIAL' | 'REVIEW_REQUIRED' | 'INCOMPLETE';

export type LimitationCode =
  | 'IDENTITY_NOT_CONFIRMED'
  | 'IDENTITY_AMBIGUOUS'
  | 'NO_REGISTRY_RECORD'
  | 'REGISTRY_RECORD_NOT_FRESH'
  | 'REGISTRY_CONFLICT'
  | 'SOURCE_NOT_ACTIVE'
  | 'EXTRACTION_OCR_REQUIRED'
  | 'EXTRACTION_PARTIAL'
  | 'EXTRACTION_FAILED'
  | 'ARTIFACT_SUPERSEDED'
  | 'EVIDENCE_REVIEW_PENDING'
  | 'CLAIM_NOT_VERIFIED'
  | 'REVERIFICATION_PENDING'
  | 'INSUFFICIENT_EVIDENCE'
  | 'CONFLICTING_EVIDENCE'
  | 'DISPUTE_OPEN'
  | 'EVIDENCE_OUTDATED'
  | 'LINEAGE_UNCERTAIN'
  | 'HUMAN_REVIEW_REQUIRED'
  | 'LOCATOR_UNVERIFIABLE'
  | 'EXCERPT_WITHHELD'
  | 'PERSONAL_DATA_REDACTED';

export type LimitationScope = 'IDENTITY' | 'REGISTRY' | 'SOURCE' | 'ARTIFACT' | 'CLAIM' | 'EVIDENCE';

export interface Limitation {
  readonly code: LimitationCode;
  readonly scope: LimitationScope;
  readonly ref: string | null;
}

/** What the dossier explicitly does NOT establish (always present, some conditional). */
export type NonFindingCode =
  | 'NOT_A_FINDING_OF_WRONGDOING'
  | 'NO_INTENT_OR_INNOCENCE'
  | 'NO_DONATION_ADVICE'
  | 'NOT_PROFESSIONAL_DUE_DILIGENCE'
  | 'ABSENCE_IS_NOT_EVIDENCE'
  | 'UNVERIFIED_IS_NOT_FALSE'
  | 'CONFLICT_IS_NOT_WRONGDOING'
  | 'REGISTRY_STATUS_IS_NOT_WRONGDOING'
  | 'DOCUMENTS_ARE_NOT_INDEPENDENT_SOURCES'
  | 'USER_UPLOADS_ARE_NOT_AUTHORITY'
  | 'QUOTED_TEXT_IS_NOT_A_PLATFORM_STATEMENT';

export type LocatorState = 'VALID' | 'NOT_ARTIFACT_BOUND' | 'ARTIFACT_SUPERSEDED' | 'ARTIFACT_MISSING' | 'HASH_MISMATCH' | 'OUT_OF_RANGE';

export type ReverificationReason = 'EVIDENCE_CHANGED' | 'DISPUTE_OPENED' | 'DISPUTE_RESOLVED';

/** Registry snapshot view as the Lab computes it (provider authority + freshness are server-derived). */
export interface RegistryFactInput {
  readonly sourceRef: string;
  readonly active: boolean;
  readonly providerId: string;
  readonly recordId: string;
  readonly canonicalOrgId: string;
  readonly legalName: string;
  readonly status: string;
  readonly statusAsOf: string | null;
  readonly sourceAsOf: string | null;
  readonly registeredOn: string | null;
  readonly dissolvedOn: string | null;
  readonly retrievedAt: string;
  readonly dataHash: string;
  readonly synthetic: boolean;
  /** Provider-declared freshness window (days) — freshness is evaluated at the dossier's asOf. */
  readonly freshnessDays: number;
  readonly authority: { readonly official: boolean; readonly authorityClass: string; readonly primaryPublisher: boolean; readonly termsStatus: string } | null;
}

export interface DossierInput {
  readonly investigation: InvestigationRecord;
  readonly identityStatus: SubjectIdentityStatus;
  readonly data: InvestigationData;
  /** Latest stored result per claim, WITH the dispute overlay already applied (lab_service.withDisputeOverlay). */
  readonly results: ReadonlyMap<string, VerificationResult & { readonly reverificationPending?: true }>;
  readonly latestVersions: ReadonlyMap<string, number>;
  readonly registryFacts: readonly RegistryFactInput[];
  readonly providerRegistryVersion: string;
}

const cmp = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0); // code-point order: locale-independent

/**
 * Every exported free-text value is presented by the SERVER through the
 * field-semantic privacy policy (privacy.ts, closes Codex I5F-03), whatever
 * personal-data class the caller declared (Codex I4G3-02): minor-risk text is
 * withheld; structured identifiers are redacted; free text with a
 * private-name / private-address signal is withheld (fail-closed).
 */

/** JSON contract: these fields carry QUOTED source text (data), never platform statements. */
export const QUOTED_DATA_FIELDS = Object.freeze([
  'subject.declaredIdentity', 'registryFacts[].legalName', 'claims[].text', 'evidence[].excerpt', 'sources[].publisher',
  'sources[].uri', 'sources[].syndicatedFrom', 'sources[].derivedFrom', 'verification.conflicts[].positions[].publisher',
]);
const byRef = <T extends { readonly ref: string }>(xs: readonly T[]) => [...xs].sort((a, b) => cmp(a.ref, b.ref));
const isoMs = (s: string | null | undefined) => {
  const t = s ? Date.parse(s) : NaN;
  return Number.isFinite(t) ? t : null;
};

const ALL_STATUSES: readonly ClaimStatus[] = ['SUPPORTED', 'PARTIALLY_SUPPORTED', 'CONTRADICTED', 'INCONCLUSIVE', 'OUTDATED', 'DISPUTED', 'UNVERIFIED'];
const ALL_CLASSES: readonly EpistemicClass[] = ['FACT', 'CLAIM', 'EVIDENCE', 'INFERENCE', 'ALLEGATION', 'CONFLICT', 'UNKNOWN', 'ABSENCE_OF_EVIDENCE'];
const INSUFFICIENT = new Set(['NO_EVIDENCE', 'SELF_REPORTED', 'SINGLE_SOURCE']);

function assessed(xs: VerificationResult['supporting']) {
  return [...xs].map((a) => ({
    evidenceRef: a.evidenceId, sourceRef: a.sourceId, sourceType: a.sourceType, authority: a.authority,
    declaredRelationship: a.declaredRelationship, effectiveRelationship: a.effectiveRelationship, basis: a.basis, asOf: a.asOf,
  })).sort((a, b) => cmp(a.evidenceRef, b.evidenceRef));
}

function locatorState(e: EvidenceItem, artifacts: ReadonlyMap<string, StoredArtifact>, supersededBy: ReadonlyMap<string, string>): LocatorState {
  const bound = e.locator?.artifact;
  if (!bound) return 'NOT_ARTIFACT_BOUND';
  const a = artifacts.get(bound.ref);
  if (!a) return 'ARTIFACT_MISSING';
  if (a.fileHash !== bound.hash) return 'HASH_MISMATCH';
  if (!locatorFitsSummary(bound.locator, a.extraction)) return 'OUT_OF_RANGE';
  if (supersededBy.has(a.ref)) return 'ARTIFACT_SUPERSEDED';
  return 'VALID';
}

/** Build the language-neutral dossier content (deterministic). */
export async function buildDossierContent(input: DossierInput) {
  const { investigation: inv, data } = input;
  const limitations: Limitation[] = [];
  const lim = (code: LimitationCode, scope: LimitationScope, ref: string | null) => limitations.push({ code, scope, ref });

  // as_of: the latest MATERIAL timestamp in the persisted state (deterministic;
  // never the request clock — Codex I4G1-N01).
  const stamps = [
    ...data.claims.map((c) => c.extractedAt), ...data.evidence.map((e) => e.addedAt), ...data.sources.map((s) => s.source.retrievedAt),
    ...[...input.results.values()].map((r) => r.evaluatedAt), ...data.disputes.flatMap((d) => [d.openedAt, d.resolvedAt]),
    ...data.artifacts.map((a) => a.ingestedAt), ...data.candidates.map((c) => c.reviewedAt),
  ].map(isoMs).filter((t): t is number => t !== null);
  const asOfMs = stamps.length ? Math.max(...stamps) : null;
  const asOf = asOfMs === null ? null : new Date(asOfMs).toISOString();

  // ── presentation context: only REGISTRY-CONFIRMED organization names may
  // exempt text (Codex I6G1-02: the declared identity is client-supplied).
  const privacy: PresentationContext = {
    orgNames: input.registryFacts.map((r) => r.legalName).filter((n) => typeof n === 'string' && n.length > 0),
  };
  const sourceTypeOf = new Map(data.sources.map(({ source }) => [source.id, source.type]));
  // Lineage names are publisher-like; a withheld one leaves a visible limitation (Codex I6G1R5-02).
  const lineageName = (v: string | undefined, type: string, sourceId: string) => {
    const p = present('PUBLISHER', v, privacy, type);
    if (p.withheld) lim('EXCERPT_WITHHELD', 'SOURCE', sourceId);
    return p.text;
  };

  // ── declared identity: client-supplied ⇒ untrusted names (Codex I6G1R-04) ──
  const sid = inv.subjectIdentity;
  const declaredIdentity = JSON.parse(JSON.stringify(sid), (_k, v) => (typeof v === 'string' ? present('ORGANIZATION_NAME', v, privacy).text ?? '—' : v));
  const declaredName = (v: string | undefined) => {
    const p = present('DECLARED_ORG_NAME', v, privacy);
    if (p.withheld) lim('EXCERPT_WITHHELD', 'IDENTITY', null);
    return p.text ?? '—';
  };
  if (typeof sid.legalName === 'string') declaredIdentity.legalName = declaredName(sid.legalName);
  if (typeof sid.publicName === 'string') declaredIdentity.publicName = declaredName(sid.publicName);
  if (Array.isArray(sid.aliases)) declaredIdentity.aliases = sid.aliases.map(declaredName);
  if (Array.isArray(sid.tradingNames)) declaredIdentity.tradingNames = sid.tradingNames.map(declaredName);
  if (Array.isArray(sid.formerNames)) declaredIdentity.formerNames = sid.formerNames.map((f, i) => ({ ...declaredIdentity.formerNames[i], name: declaredName(f.name) }));
  const ownDomains = (sid.domains ?? []).filter((d): d is string => typeof d === 'string');

  // ── identity ─────────────────────────────────────────────────────────────
  if (input.identityStatus === 'UNCERTAIN') lim('IDENTITY_AMBIGUOUS', 'IDENTITY', null);
  else if (input.identityStatus !== 'CONFIRMED') lim('IDENTITY_NOT_CONFIRMED', 'IDENTITY', null);

  // ── registry facts (official source, attributed; never "not registered" from absence) ──
  const registryFacts = [...input.registryFacts].sort((a, b) => cmp(a.sourceRef, b.sourceRef)).map((r) => ({
    sourceRef: r.sourceRef, active: r.active, providerId: r.providerId, recordId: r.recordId, canonicalOrgId: r.canonicalOrgId,
    legalName: present('ORGANIZATION_NAME', r.legalName, privacy).text ?? '—', registryStatus: r.status, statusAsOf: r.statusAsOf, sourceAsOf: r.sourceAsOf, registeredOn: r.registeredOn,
    dissolvedOn: r.dissolvedOn, retrievedAt: r.retrievedAt, dataHash: r.dataHash, synthetic: r.synthetic,
    freshnessDays: r.freshnessDays,
    // Freshness AT THE DOSSIER'S asOf (deterministic); freshness "now" is in the envelope.
    freshAtAsOf: asOfMs !== null && r.freshnessDays > 0 && snapshotFresh({ retrievedAt: r.retrievedAt, sourceAsOf: r.sourceAsOf ?? undefined }, r.freshnessDays, asOfMs),
    authority: r.authority, factClass: 'OFFICIAL_REGISTRY_RECORD' as const,
  }));
  if (registryFacts.length === 0) lim('NO_REGISTRY_RECORD', 'REGISTRY', null);
  for (const r of registryFacts) if (r.active && !r.freshAtAsOf) lim('REGISTRY_RECORD_NOT_FRESH', 'REGISTRY', r.sourceRef);
  const registryConflicts = [...data.registryConflicts]
    .map((c) => ({ kind: c.kind, sourceRef: c.sourceRef, otherSourceRef: c.otherSourceRef, canonicalOrgId: c.canonicalOrgId }))
    .sort((a, b) => cmp(`${a.kind}|${a.sourceRef}|${a.otherSourceRef}`, `${b.kind}|${b.sourceRef}|${b.otherSourceRef}`));
  if (registryConflicts.length) lim('REGISTRY_CONFLICT', 'REGISTRY', null);

  // ── artifacts (provenance + structure; the original filename is NOT exported) ──
  const artifactsByRef = new Map(data.artifacts.map((a) => [a.ref, a]));
  const supersededBy = new Map(data.artifacts.filter((a) => a.supersedesRef).map((a) => [a.supersedesRef!, a.ref]));
  const pendingByArtifact = new Map<string, number>();
  for (const c of data.candidates) {
    if (c.reviewStatus === 'PENDING' || c.reviewStatus === 'NEEDS_CONTEXT') pendingByArtifact.set(c.artifactRef, (pendingByArtifact.get(c.artifactRef) ?? 0) + 1);
  }
  const artifacts = byRef(data.artifacts.map((a) => ({
    ref: a.ref, sourceRef: a.sourceRef, type: a.type, origin: a.origin, fileHash: a.fileHash, hashAlgorithm: 'SHA-256' as const,
    version: a.version, supersedesRef: a.supersedesRef, supersededBy: supersededBy.get(a.ref) ?? null,
    extractionStatus: a.extractionStatus, extractorVersion: a.extraction.extractorVersion, extractionNotes: [...a.extraction.notes].sort(cmp),
    cloudHost: a.cloudProvider, sourceModifiedAt: a.sourceModifiedAt, ingestedAt: a.ingestedAt,
    pendingCandidates: pendingByArtifact.get(a.ref) ?? 0, originalBytesRetained: false as const,
  })));
  for (const a of artifacts) {
    if (a.extractionStatus === 'OCR_REQUIRED') lim('EXTRACTION_OCR_REQUIRED', 'ARTIFACT', a.ref);
    else if (a.extractionStatus === 'PARTIAL') lim('EXTRACTION_PARTIAL', 'ARTIFACT', a.ref);
    else if (a.extractionStatus === 'FAILED' || a.extractionStatus === 'UNSUPPORTED') lim('EXTRACTION_FAILED', 'ARTIFACT', a.ref);
    if (a.supersededBy) lim('ARTIFACT_SUPERSEDED', 'ARTIFACT', a.ref);
    if (a.pendingCandidates > 0) lim('EVIDENCE_REVIEW_PENDING', 'ARTIFACT', a.ref);
  }

  // ── sources (publisher ≠ host ≠ uploader; authority/independence live on assessed evidence) ──
  const artifactOfSource = new Map(data.artifacts.map((a) => [a.sourceRef, a]));
  const sources = data.sources.map(({ source: s, snapshot }) => {
    const art = artifactOfSource.get(s.id);
    const pub = present('PUBLISHER', s.publisher, privacy, s.type);
    // URLs: origin only — paths / queries can carry personal handles or tokens.
    const uri = presentUri(s.uri, s.type, ownDomains);
    if (pub.withheld) lim('EXCERPT_WITHHELD', 'SOURCE', s.id);
    if (pub.redacted) lim('PERSONAL_DATA_REDACTED', 'SOURCE', s.id);
    return {
      ref: s.id, type: s.type, publisher: pub.text ?? '—', publisherOrgRef: s.publisherOrganizationId ?? null, uri: uri.text,
      retrievedAt: s.retrievedAt, publishedAt: s.publishedAt ?? null, status: s.status, retention: s.retention,
      contentHash: s.contentHash ?? null, acquisition: s.acquisition.method, providerId: s.acquisition.method === 'PROVIDER' ? s.acquisition.providerId : null,
      userSubmitted: s.userSubmitted === true, hasRegistrySnapshot: !!snapshot, newsGenre: s.newsGenre ?? null,
      syndicatedFrom: lineageName(s.syndicatedFrom, s.type, s.id),
      derivedFrom: lineageName(s.derivedFrom, s.type, s.id),
      syndicationMarkers: [...((s as Source & { syndicationMarkers?: readonly string[] }).syndicationMarkers ?? [])].sort(cmp),
      artifactRef: art?.ref ?? null,
      // A cloud drive HOSTED the uploaded copy; it is not the publisher and not an authority.
      host: art?.cloudProvider ? { provider: art.cloudProvider, role: 'HOST_NOT_PUBLISHER' as const } : null,
    };
  }).sort((a, b) => cmp(a.ref, b.ref));
  for (const s of sources) if (s.status !== 'ACTIVE') lim('SOURCE_NOT_ACTIVE', 'SOURCE', s.ref);

  // ── evidence (minimized: personal / minor-risk excerpts withheld) ─────────
  const evidence = data.evidence.map((e) => {
    const personal = e.personalData !== 'NONE' && e.personalData !== 'AGGREGATED';
    const sc = present('FREE_TEXT', e.excerpt, privacy);
    // Minor risk first, then the reviewer's classification, then the
    // fail-closed name / address signal.
    const withheld = e.excerpt
      ? (sc.withheld === 'MINOR_DATA_RISK' ? 'MINOR_DATA_RISK' as const : personal ? 'PERSONAL_DATA' as const : sc.withheld)
      : null;
    const src = data.sources.find((x) => x.source.id === e.sourceId)?.source;
    const state = locatorState(e, artifactsByRef, supersededBy);
    return {
      ref: e.id, claimRef: e.claimId, sourceRef: e.sourceId, aboutOrgRef: e.aboutOrganizationId, relationship: e.relationship,
      basis: e.relationshipBasis, observedPeriod: e.observedPeriod ?? null, level: e.level ?? null, reportedQuantity: e.reportedQuantity ?? null,
      legalStage: e.legalStage ?? null, personalData: e.personalData,
      excerpt: e.excerpt && !withheld ? sc.text : null, excerptHash: e.excerptHash ?? null, excerptWithheld: withheld,
      excerptRedacted: !withheld && sc.redacted,
      // Excerpts are QUOTES of their source (user uploads included): never a statement of the platform.
      excerptAttribution: e.excerpt ? (src?.userSubmitted ? 'QUOTED_FROM_USER_UPLOAD' as const : 'QUOTED_FROM_SOURCE' as const) : null,
      locator: e.locator ?? null, locatorState: state, addedAt: e.addedAt,
    };
  }).sort((a, b) => cmp(a.ref, b.ref));
  for (const e of evidence) {
    if (e.excerptWithheld) lim('EXCERPT_WITHHELD', 'EVIDENCE', e.ref);
    if (e.excerptRedacted) lim('PERSONAL_DATA_REDACTED', 'EVIDENCE', e.ref);
    if (e.locatorState !== 'VALID' && e.locatorState !== 'NOT_ARTIFACT_BOUND') lim('LOCATOR_UNVERIFIABLE', 'EVIDENCE', e.ref);
  }

  // ── disputes (no private content: kind, dates, resolution, count of submitted refs) ──
  const disputes = byRef(data.disputes.map((d: StoredDispute) => ({
    ref: d.ref, claimRef: d.claimRef, kind: d.kind, openedAt: d.openedAt, open: d.resolution === null,
    resolution: d.resolution, resolvedAt: d.resolvedAt, submittedEvidenceCount: d.submittedEvidenceRefs.length,
  })));

  // ── claims (status / class / authority / independence copied from the engine) ──
  const sourcesById = new Map(data.sources.map((s) => [s.source.id, s.source]));
  const claims = [];
  for (const c of [...data.claims].sort((a, b) => cmp(a.id, b.id))) {
    const r = input.results.get(c.id);
    const claimDisputes = disputes.filter((d) => d.claimRef === c.id);
    const reasons: ReverificationReason[] = [];
    if (r) {
      const current = await computeEvidenceSetHash(c, data.evidence.filter((e) => e.claimId === c.id), sourcesById);
      if (current !== r.evidenceSetHash) reasons.push('EVIDENCE_CHANGED');
      const evaluated = isoMs(r.evaluatedAt) ?? 0;
      if (claimDisputes.some((d) => d.open && (isoMs(d.openedAt) ?? 0) > evaluated)) reasons.push('DISPUTE_OPENED');
      if (claimDisputes.some((d) => !d.open && (isoMs(d.resolvedAt) ?? 0) > evaluated)) reasons.push('DISPUTE_RESOLVED');
      if (r.reverificationPending && reasons.length === 0) reasons.push(claimDisputes.some((d) => d.open) ? 'DISPUTE_OPENED' : 'DISPUTE_RESOLVED');
    }
    const verification = r
      ? {
        version: input.latestVersions.get(c.id) ?? 0, resultId: r.resultId, status: r.status, underlyingStatus: r.underlyingStatus,
        displayClass: r.displayClass, sufficiency: r.sufficiency, reviewState: r.reviewState, reviewReasons: [...r.reviewReasons].sort(cmp),
        gaps: [...r.gaps].sort(cmp), rulesApplied: [...r.rulesApplied], evaluatedAt: r.evaluatedAt, policyVersion: r.policyVersion,
        evidenceSetHash: r.evidenceSetHash, subjectIdentity: r.subjectIdentity,
        supporting: assessed(r.supporting), partiallySupporting: assessed(r.partiallySupporting), contradicting: assessed(r.contradicting),
        contextual: assessed(r.contextual),
        excluded: [...r.excluded].map((x) => ({ evidenceRef: x.evidenceId, reason: x.reason })).sort((a, b) => cmp(a.evidenceRef, b.evidenceRef)),
        conflicts: r.conflicts.map((k) => ({
          ...k,
          positions: k.positions.map((p) => {
            const pub = present('PUBLISHER', p.publisher, privacy, sourceTypeOf.get(p.sourceId));
            if (pub.withheld) lim('EXCERPT_WITHHELD', 'SOURCE', p.sourceId); // I6G1R5-02: every withholding is visible
            return { ...p, publisher: pub.text ?? '—' };
          }),
        })),
        independence: {
          policyVersion: r.lineage.policyVersion, independentVoices: r.lineage.voices, establishedVoices: r.lineage.establishedVoices,
          mergedByLineage: r.lineage.mergedByLineage, possibleLineage: r.lineage.possibleLineage, comparisonTruncated: r.lineage.comparisonTruncated,
          sources: [...r.lineage.sources].map((s) => ({ sourceRef: s.sourceId, state: s.state, established: s.established })).sort((a, b) => cmp(a.sourceRef, b.sourceRef)),
        },
      }
      : null;
    const scope = (code: LimitationCode) => lim(code, 'CLAIM', c.id);
    if (!verification) scope('CLAIM_NOT_VERIFIED');
    else {
      if (INSUFFICIENT.has(verification.sufficiency)) scope('INSUFFICIENT_EVIDENCE');
      if (verification.conflicts.length > 0 || verification.sufficiency === 'CONFLICTING_EVIDENCE') scope('CONFLICTING_EVIDENCE');
      if (verification.status === 'OUTDATED' || verification.gaps.includes('EVIDENCE_OUTDATED')) scope('EVIDENCE_OUTDATED');
      if (verification.independence.possibleLineage || verification.independence.comparisonTruncated) scope('LINEAGE_UNCERTAIN');
      if (verification.reviewState === 'REVIEW_REQUIRED') scope('HUMAN_REVIEW_REQUIRED');
    }
    if (reasons.length) scope('REVERIFICATION_PENDING');
    if (claimDisputes.some((d) => d.open)) scope('DISPUTE_OPEN');
    const ct = present('FREE_TEXT', c.text, privacy);
    if (ct.withheld) lim('EXCERPT_WITHHELD', 'CLAIM', c.id);
    if (ct.redacted) lim('PERSONAL_DATA_REDACTED', 'CLAIM', c.id);
    claims.push({
      ref: c.id, kind: c.kind, text: ct.text, textWithheld: ct.withheld, textRedacted: ct.redacted,
      textAttribution: 'QUOTED_FROM_SOURCE' as const,
      textLanguage: c.textLanguage ?? null, sourceRef: c.sourceId, origin: c.origin,
      period: c.period ?? null, quantity: c.quantity ?? null, level: c.level ?? null, extractedAt: c.extractedAt,
      subjectProjectRef: c.subjectProjectId ?? null, subjectCampaignRef: c.subjectCampaignId ?? null,
      verification, reverificationPending: reasons.length > 0, reverificationReasons: reasons,
      disputeRefs: claimDisputes.map((d) => d.ref),
      evidenceRefs: evidence.filter((e) => e.claimRef === c.id).map((e) => e.ref),
      // Contract literal: a claim status is never a finding about the organization.
      isFindingOfWrongdoing: false as const,
    });
  }

  // ── summary (counts of REAL engine categories) ───────────────────────────
  const byStatus = Object.fromEntries(ALL_STATUSES.map((s) => [s, 0])) as Record<ClaimStatus, number>;
  const byClass = Object.fromEntries(ALL_CLASSES.map((s) => [s, 0])) as Record<EpistemicClass, number>;
  for (const c of claims) {
    if (c.verification) { byStatus[c.verification.status]++; byClass[c.verification.displayClass]++; }
  }
  const notVerified = claims.filter((c) => !c.verification).length;
  const pending = claims.filter((c) => c.reverificationPending).length;
  const openDisputes = disputes.filter((d) => d.open).length;
  const conflictCount = claims.reduce((n, c) => n + (c.verification?.conflicts.length ?? 0), 0);
  const reviewRequired = claims.some((c) => c.verification?.reviewState === 'REVIEW_REQUIRED') || openDisputes > 0
    || artifacts.some((a) => a.pendingCandidates > 0);

  const sortedLimitations = limitations
    .filter((l, i, all) => all.findIndex((x) => x.code === l.code && x.scope === l.scope && x.ref === l.ref) === i)
    .sort((a, b) => cmp(`${a.code}|${a.scope}|${a.ref ?? ''}`, `${b.code}|${b.scope}|${b.ref ?? ''}`));

  const dossierStatus: DossierStatus = claims.length === 0 || notVerified > 0 || pending > 0
    ? 'INCOMPLETE'
    : reviewRequired ? 'REVIEW_REQUIRED' : sortedLimitations.length > 0 ? 'PARTIAL' : 'COMPLETE';

  const doesNotEstablish = new Set<NonFindingCode>([
    'NOT_A_FINDING_OF_WRONGDOING', 'NO_INTENT_OR_INNOCENCE', 'NO_DONATION_ADVICE', 'NOT_PROFESSIONAL_DUE_DILIGENCE', 'ABSENCE_IS_NOT_EVIDENCE',
  ]);
  if (claims.some((c) => !c.verification || ['UNVERIFIED', 'INCONCLUSIVE'].includes(c.verification.status) || INSUFFICIENT.has(c.verification.sufficiency))) {
    doesNotEstablish.add('UNVERIFIED_IS_NOT_FALSE');
  }
  if (conflictCount > 0 || registryConflicts.length > 0 || byStatus.CONTRADICTED > 0) doesNotEstablish.add('CONFLICT_IS_NOT_WRONGDOING');
  if (registryFacts.some((r) => r.registryStatus !== 'REGISTERED')) doesNotEstablish.add('REGISTRY_STATUS_IS_NOT_WRONGDOING');
  if (claims.some((c) => c.verification && c.verification.independence.independentVoices < new Set(c.evidenceRefs).size)) {
    doesNotEstablish.add('DOCUMENTS_ARE_NOT_INDEPENDENT_SOURCES');
  }
  if (artifacts.length > 0 || sources.some((s) => s.userSubmitted)) doesNotEstablish.add('USER_UPLOADS_ARE_NOT_AUTHORITY');
  if (evidence.some((e) => e.excerpt)) doesNotEstablish.add('QUOTED_TEXT_IS_NOT_A_PLATFORM_STATEMENT');


  return {
    schemaVersion: DOSSIER_SCHEMA_VERSION,
    kind: 'VERIFICATION_DOSSIER' as const,
    // Contract literals, checked by tests and by the renderer.
    isFindingOfWrongdoing: false as const,
    absenceOfEvidenceIsNotEvidenceOfWrongdoing: true as const,
    isPublication: false as const,
    quotedDataFields: QUOTED_DATA_FIELDS,
    policyVersions: {
      verification: IMPACT_POLICY_VERSION, lineage: LINEAGE_POLICY_VERSION, artifact: ARTIFACT_POLICY_VERSION,
      providerRegistry: input.providerRegistryVersion,
      privacy: PRIVACY_POLICY_VERSION,
    },
    investigation: { ref: inv.id, projectRef: inv.projectId, status: inv.status },
    asOf,
    subject: {
      ref: inv.subjectOrgRef, type: inv.subjectOrgType,
      declaredIdentity,
      identityStatus: input.identityStatus, identityConfirmed: input.identityStatus === 'CONFIRMED',
      identityBasis: 'PROVIDER_REGISTRY_SNAPSHOTS_ONLY' as const,
    },
    registryFacts,
    registryConflicts,
    claims,
    evidence,
    sources,
    artifacts,
    disputes,
    limitations: sortedLimitations,
    doesNotEstablish: [...doesNotEstablish].sort(cmp),
    summary: {
      claims: claims.length, byStatus, byDisplayClass: byClass, notVerified, reverificationPending: pending, openDisputes,
      conflicts: conflictCount, registryConflicts: registryConflicts.length, evidence: evidence.length, sources: sources.length,
      artifacts: artifacts.length, limitations: sortedLimitations.length,
    },
    dossierStatus,
  };
}

export type DossierContent = Awaited<ReturnType<typeof buildDossierContent>>;

export async function dossierContentHash(content: unknown): Promise<string> {
  return await sha256Hex(canonical(content));
}

export interface DossierEnvelope {
  readonly kind: 'LIVE' | 'SNAPSHOT';
  readonly generatedAt: string;
  readonly auditSeq: number;
  readonly auditHead: string;
  readonly snapshotRef: string | null;
  /** LIVE reflects the state at generation; a SNAPSHOT never updates itself. */
  readonly notice: 'LIVE_VIEW_OF_CURRENT_STATE' | 'HISTORICAL_SNAPSHOT_AS_OF';
  /** Time-relative, request-clock facts (outside the hash): registry freshness at generation. */
  readonly registryFreshAtGeneration: readonly { readonly sourceRef: string; readonly fresh: boolean }[];
}

export interface DossierDocument {
  readonly schemaVersion: string;
  readonly content: DossierContent;
  readonly integrity: { readonly algorithm: 'SHA-256'; readonly canonicalization: string; readonly contentHash: string };
  readonly envelope: DossierEnvelope;
}

/**
 * Recompute the integrity of an exported dossier's CONTENT (any holder can run this, offline).
 * The envelope is NOT covered by this hash (Codex I4G3-01): whether a document was really
 * issued as a snapshot, when, and at which audit position, is answered only by the server
 * register (verify_dossier with the presented envelope).
 */
export async function verifyDossierIntegrity(doc: unknown): Promise<{ readonly intact: boolean; readonly contentHash: string | null; readonly envelopeCovered: false }> {
  if (!doc || typeof doc !== 'object') return { intact: false, contentHash: null, envelopeCovered: false };
  const d = doc as Partial<DossierDocument>;
  if (d.schemaVersion !== DOSSIER_SCHEMA_VERSION || !d.content || !d.integrity || d.integrity.canonicalization !== DOSSIER_CANONICALIZATION) {
    return { intact: false, contentHash: null, envelopeCovered: false };
  }
  const h = await dossierContentHash(d.content);
  return { intact: h === d.integrity.contentHash && (d.content as { schemaVersion?: string }).schemaVersion === DOSSIER_SCHEMA_VERSION, contentHash: h, envelopeCovered: false };
}

export function snapshotRefOf(contentHash: string): string {
  return `dossier-${contentHash.slice(0, 24)}`;
}
