/**
 * Verification Engine — IV-IMPACT-FOUNDATION-01.
 *
 *   Claim + Evidence[] + Sources + context  →  VerificationResult
 *
 * Deterministic and rule-based (IMPACT_VERIFICATION_MODEL.md). No LLM, no
 * network, no clock. The engine never reads excerpt/document TEXT to decide
 * anything — only structured fields — so instructions hidden in a document
 * cannot change a status (prompt-injection boundary).
 *
 * What the engine will never do:
 *  - turn ABSENCE of evidence into a negative finding (→ UNVERIFIED);
 *  - count self-reported, user-submitted, attribution-only or contextual
 *    material as corroboration;
 *  - count an LLM-suggested relationship before it is confirmed;
 *  - count a non-final legal stage (investigation, charge, appeal) as a
 *    contradiction — it is recorded as an unresolved allegation;
 *  - choose a side in a conflict (→ INCONCLUSIVE + ConflictRecord);
 *  - produce SUPPORTED or CONTRADICTED about a subject whose identity is
 *    not confirmed (false-attribution guard → INCONCLUSIVE);
 *  - emit a score, a ranking or a verdict about an organization.
 */
import { fail, ok, type ImpactResult } from './errors.ts';
import { parseIsoMs, sha256Hex, validateClaim, validateEvidence, validateSource, LIMITS } from './provenance.ts';
import { authorityFor, isIndependentScope, SOURCE_AUTHORITY_POLICY_VERSION, type AuthorityScope } from './source_authority.ts';
import { evidenceAsOfMs, isStale, isStateClaim, periodsOverlap, TEMPORAL_POLICY_VERSION } from './temporal.ts';
import type {
  Claim,
  ClaimStatus,
  ConflictRecord,
  EpistemicClass,
  EvidenceItem,
  EvidenceRelationship,
  EvidenceSufficiency,
  ExclusionReason,
  GapCode,
  ImpactLevel,
  LegalStage,
  ReviewState,
  Source,
  TrustedProviderRef,
} from './types.ts';

export const VERIFICATION_ENGINE_VERSION = 'impact-verification/7';
export const IMPACT_POLICY_VERSION =
  `${VERIFICATION_ENGINE_VERSION}+${SOURCE_AUTHORITY_POLICY_VERSION}+${TEMPORAL_POLICY_VERSION}`;

/** Outcome of entity resolution for the claim's subject (entity_resolution.ts). */
export type SubjectIdentityStatus = 'CONFIRMED' | 'PROBABLE' | 'UNCERTAIN' | 'UNRESOLVED';

export interface HumanReviewRecord {
  readonly reviewedAt: string;
  /** Opaque reviewer reference (never a name/e-mail). */
  readonly reviewerRef: string;
  /** The review applies only to the exact state it looked at: evidence set,
   * flagged (untrusted) sources, subject identity, dispute and trusted
   * providers (Codex G1-04). Any change re-opens review. */
  readonly reviewBindingHash: string;
}

export interface VerificationContext {
  readonly evaluatedAt: string;
  readonly subjectIdentity: SubjectIdentityStatus;
  readonly openDispute?: boolean;
  /** Sources in which untrusted_content.ts found embedded instructions. */
  readonly flaggedSourceIds?: readonly string[];
  readonly humanReview?: HumanReviewRecord;
  /** Server-side provider registry. Required: without it nothing can be
   * independent (fail closed, Codex G1-01). */
  readonly trustedProviders: readonly TrustedProviderRef[];
}

export interface VerificationInput {
  readonly claim: Claim;
  readonly evidence: readonly EvidenceItem[];
  readonly sources: readonly Source[];
}

/** Supports fully, supports a smaller figure, contradicts, or is context. */
export type EffectiveRelationship = 'SUPPORTS' | 'PARTIALLY_SUPPORTS' | 'CONTRADICTS' | 'CONTEXTUALIZES';

export interface AssessedEvidence {
  readonly evidenceId: string;
  readonly sourceId: string;
  readonly sourceType: Source['type'];
  readonly publisher: string;
  /** Normalized RAW publisher (never the syndicatedFrom label — Codex FV3-01). */
  readonly publisherKey: string;
  readonly authority: AuthorityScope;
  readonly declaredRelationship: EvidenceRelationship;
  readonly effectiveRelationship: EffectiveRelationship;
  readonly basis: EvidenceItem['relationshipBasis'];
  readonly reportedValue?: number;
  readonly legalStage?: LegalStage;
  readonly asOf: string;
}

export interface ExcludedEvidence {
  readonly evidenceId: string;
  readonly reason: ExclusionReason;
}

export type ReviewReason =
  | 'CONTRADICTION'
  | 'CONFLICT'
  | 'ALLEGATION'
  | 'LEGAL_RECORD'
  | 'IDENTITY_NOT_CONFIRMED'
  | 'UNTRUSTED_INSTRUCTIONS'
  | 'OPEN_DISPUTE'
  | 'USER_SUBMITTED_MATERIAL';

export interface VerificationResult {
  readonly resultId: string;
  readonly claimId: string;
  readonly investigationId: string;
  readonly claimKind: Claim['kind'];
  readonly subjectOrganizationId: string;
  readonly subjectProjectId?: string;
  readonly subjectCampaignId?: string;
  readonly status: ClaimStatus;
  /** When status is DISPUTED, what the evidence alone would say. */
  readonly underlyingStatus: ClaimStatus;
  readonly sufficiency: EvidenceSufficiency;
  readonly displayClass: EpistemicClass;
  readonly supporting: readonly AssessedEvidence[];
  readonly partiallySupporting: readonly AssessedEvidence[];
  readonly contradicting: readonly AssessedEvidence[];
  /** Counted-as-context: self-reported, user, attribution, allegations… */
  readonly contextual: readonly AssessedEvidence[];
  readonly excluded: readonly ExcludedEvidence[];
  readonly conflicts: readonly ConflictRecord[];
  readonly gaps: readonly GapCode[];
  readonly reviewState: ReviewState;
  readonly reviewReasons: readonly ReviewReason[];
  /** Ordered ids of the rules that fired — the machine-readable "why". */
  readonly rulesApplied: readonly string[];
  readonly subjectIdentity: SubjectIdentityStatus;
  readonly evaluatedAt: string;
  readonly policyVersion: string;
  readonly evidenceSetHash: string;
  readonly reviewBindingHash: string;
  /** Contract literals — checked by tests and by the report renderer. */
  readonly isFindingOfWrongdoing: false;
  readonly absenceOfEvidenceIsNotEvidenceOfWrongdoing: true;
}

const LEVEL_RANK: Readonly<Record<ImpactLevel, number>> = { INPUT: 0, ACTIVITY: 1, OUTPUT: 2, OUTCOME: 3, IMPACT: 4 };
const NON_FINAL_STAGES: ReadonlySet<LegalStage> = new Set(['INVESTIGATION_OPENED', 'CHARGED', 'UNDER_APPEAL']);

function normPublisher(p: string): string {
  return p.normalize('NFKC').trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Number of independent VOICES among counted items (Codex CF-04, FV3-02/03).
 * Publishers linked by `syndicatedFrom` (in either direction, transitively)
 * form one voice: union-find over normalized names, so the result does not
 * depend on input order, copies of copies collapse, and cycles merge into one
 * voice. An unverified `syndicatedFrom` label can therefore only MERGE voices
 * (lower corroboration) — never split them, never create a status, and never
 * change how a disagreement is classified (that uses the raw publisher).
 */
function countIndependentVoices(counted: readonly AssessedEvidence[], sources: ReadonlyMap<string, Source>): number {
  const parent = new Map<string, string>();
  const find = (x: string): string => {
    let r = x;
    while (parent.has(r) && parent.get(r) !== r) r = parent.get(r)!;
    parent.set(x, r);
    return r;
  };
  const union = (a: string, b: string) => {
    const [ra, rb] = [find(a), find(b)];
    if (ra !== rb) (ra < rb ? parent.set(rb, ra) : parent.set(ra, rb));
  };
  const node = (k: string) => {
    if (!parent.has(k)) parent.set(k, k);
    return k;
  };
  // Edges from EVERY validated source in the set — not only counted ones — so
  // a chain through an intermediate source that carries no counted evidence
  // still collapses into one voice (Codex FV4-01).
  for (const s of sources.values()) {
    if (s.syndicatedFrom) union(node(normPublisher(s.publisher)), node(normPublisher(s.syndicatedFrom)));
  }
  for (const a of counted) node(a.publisherKey);
  return new Set(counted.map((a) => find(a.publisherKey))).size;
}

function canonical(v: unknown): string {
  if (v === undefined) return 'null';
  if (v === null || typeof v !== 'object') return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(canonical).join(',')}]`;
  const o = v as Record<string, unknown>;
  return `{${Object.keys(o).filter((k) => o[k] !== undefined).sort().map((k) => `${JSON.stringify(k)}:${canonical(o[k])}`).join(',')}}`;
}

function deepFreeze<T>(o: T): T {
  if (o && typeof o === 'object' && !Object.isFrozen(o)) {
    Object.freeze(o);
    for (const v of Object.values(o as Record<string, unknown>)) deepFreeze(v);
  }
  return o;
}

/** Hash of every input the conclusion depends on (claim, evidence, the
 * provenance-relevant source fields). Same inputs → same hash. */
export async function computeEvidenceSetHash(
  claim: Claim,
  evidence: readonly EvidenceItem[],
  sources: ReadonlyMap<string, Source>,
): Promise<string> {
  // Explicit field lists (not spreads): metadata the engine must ignore —
  // e.g. sponsorship/advertiser flags (commercial firewall) — cannot even
  // change the hash, let alone the conclusion.
  const items = [...evidence].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0)).map((e) => {
    const s = sources.get(e.sourceId);
    return {
      e: {
        id: e.id, investigationId: e.investigationId, claimId: e.claimId, sourceId: e.sourceId,
        aboutOrganizationId: e.aboutOrganizationId, relationship: e.relationship, relationshipBasis: e.relationshipBasis,
        reportedQuantity: e.reportedQuantity, level: e.level, observedPeriod: e.observedPeriod,
        excerptHash: e.excerptHash, locator: e.locator, personalData: e.personalData, legalStage: e.legalStage,
        addedAt: e.addedAt,
      },
      s: s
        ? {
          id: s.id, type: s.type, publisher: s.publisher, publisherOrganizationId: s.publisherOrganizationId,
          retrievedAt: s.retrievedAt, publishedAt: s.publishedAt, newsGenre: s.newsGenre, status: s.status,
          contentHash: s.contentHash, userSubmitted: s.userSubmitted, jurisdiction: s.jurisdiction, uri: s.uri,
          retention: s.retention, acquisition: s.acquisition, syndicatedFrom: s.syndicatedFrom,
        }
        : null,
    };
  });
  const c = {
    id: claim.id, investigationId: claim.investigationId, kind: claim.kind, quantity: claim.quantity, level: claim.level,
    claimantOrganizationId: claim.claimantOrganizationId, subjectOrganizationId: claim.subjectOrganizationId,
    subjectProjectId: claim.subjectProjectId, subjectCampaignId: claim.subjectCampaignId, period: claim.period,
    sourceId: claim.sourceId, origin: claim.origin,
  };
  return await sha256Hex(canonical({ claim: c, claimTextHash: await sha256Hex(claim.text), items }));
}

function effectiveRelationship(
  claim: Claim,
  e: EvidenceItem,
): { rel: EffectiveRelationship } | { excluded: ExclusionReason } {
  if (e.relationshipBasis === 'STRUCTURED_MATCH') {
    const c = claim.quantity!;
    const r = e.reportedQuantity!;
    if (c.metric !== r.metric || c.unit !== r.unit) return { excluded: 'UNITS_NOT_COMPARABLE' };
    if (r.value >= c.value) return { rel: 'SUPPORTS' };
    if (r.value === 0) return { rel: 'CONTRADICTS' };
    return { rel: 'PARTIALLY_SUPPORTS' };
  }
  return { rel: e.relationship === 'SUPPORTS' ? 'SUPPORTS' : e.relationship === 'CONTRADICTS' ? 'CONTRADICTS' : 'CONTEXTUALIZES' };
}

export async function verifyClaim(
  input: VerificationInput,
  ctx: VerificationContext,
): Promise<ImpactResult<VerificationResult>> {
  const evaluatedAtMs = parseIsoMs(ctx.evaluatedAt);
  if (evaluatedAtMs === null) return fail('INTERNAL_ERROR', 'evaluatedAt must be an ISO timestamp');
  const { claim } = input;
  const vc = validateClaim(claim, claim.investigationId);
  if (!vc.ok) return vc;
  if (input.evidence.length > LIMITS.maxEvidencePerClaim) {
    return fail('INVALID_EVIDENCE', 'too many evidence items for one claim', { claimId: claim.id });
  }

  const sources = new Map<string, Source>();
  for (const s of input.sources) {
    if (sources.has(s.id)) return fail('INVALID_SOURCE', 'duplicate source id', { sourceId: s.id });
    const vs = validateSource(s, evaluatedAtMs);
    if (!vs.ok) return vs;
    sources.set(s.id, s);
  }
  if (!sources.has(claim.sourceId)) {
    return fail('INVALID_CLAIM', 'the source where the claim was made is missing (no provenance)', { claimId: claim.id });
  }
  const seenEvidence = new Set<string>();
  for (const e of input.evidence) {
    if (seenEvidence.has(e.id)) return fail('INVALID_EVIDENCE', 'duplicate evidence id', { evidenceId: e.id });
    seenEvidence.add(e.id);
    const ve = await validateEvidence(e, claim, sources);
    if (!ve.ok) return ve;
  }

  const rules: string[] = [];
  const gaps = new Set<GapCode>();
  const review = new Set<ReviewReason>();
  const excluded: ExcludedEvidence[] = [];
  const counted: AssessedEvidence[] = [];
  const contextual: AssessedEvidence[] = [];
  let staleCount = 0;
  const seenContentHashes = new Map<string, string>(); // contentHash → sourceId
  const flagged = new Set(ctx.flaggedSourceIds ?? []);
  if (!Array.isArray(ctx.trustedProviders)) return fail('INTERNAL_ERROR', 'trustedProviders required');
  const providers = new Map(ctx.trustedProviders.map((p) => [p.id, p]));

  const ordered = [...input.evidence].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  for (const e of ordered) {
    const src = sources.get(e.sourceId)!;
    const exclude = (reason: ExclusionReason, gap?: GapCode) => {
      excluded.push({ evidenceId: e.id, reason });
      if (gap) gaps.add(gap);
    };
    if (flagged.has(src.id)) {
      gaps.add('UNTRUSTED_INSTRUCTIONS_DETECTED');
      review.add('UNTRUSTED_INSTRUCTIONS');
    }
    if (src.status === 'RETRACTED') { exclude('SOURCE_RETRACTED', 'SOURCE_RETRACTED'); rules.push('R01_SOURCE_RETRACTED'); continue; }
    if (src.status === 'UPDATED') { exclude('SOURCE_CHANGED', 'SOURCE_CHANGED'); rules.push('R02_SOURCE_CHANGED'); continue; }
    if (e.aboutOrganizationId !== claim.subjectOrganizationId) {
      exclude('ENTITY_MISMATCH', 'IDENTITY_UNCONFIRMED');
      rules.push('R03_ENTITY_MISMATCH');
      continue;
    }
    if (e.relationshipBasis === 'LLM_SUGGESTED') {
      exclude('UNCONFIRMED_LLM_LINK', 'UNCONFIRMED_LLM_LINKS');
      rules.push('R04_LLM_LINK_NOT_COUNTED');
      continue;
    }
    const authority = authorityFor(src, claim, providers);
    if (authority === 'NONE') { exclude('OUT_OF_AUTHORITY_SCOPE', 'OUT_OF_AUTHORITY_SCOPE'); rules.push('R05_OUT_OF_SCOPE'); continue; }

    const er = effectiveRelationship(claim, e);
    if ('excluded' in er) { exclude(er.excluded, 'UNITS_NOT_COMPARABLE'); rules.push('R06_UNITS'); continue; }
    let rel = er.rel;

    if (e.legalStage !== undefined) review.add('LEGAL_RECORD');
    if (rel === 'CONTRADICTS' && e.legalStage !== undefined && NON_FINAL_STAGES.has(e.legalStage)) {
      rel = 'CONTEXTUALIZES';
      gaps.add('ALLEGATION_UNRESOLVED');
      review.add('ALLEGATION');
      rules.push('R07_NON_FINAL_LEGAL_STAGE_NOT_CONTRADICTION');
    }
    if (src.type === 'NEWS' && src.newsGenre === 'ALLEGATION') {
      gaps.add('ALLEGATION_UNRESOLVED');
      review.add('ALLEGATION');
      rules.push('R08_NEWS_ALLEGATION_IS_CONTEXT');
    }
    if (
      (rel === 'SUPPORTS' || rel === 'PARTIALLY_SUPPORTS') && claim.level && e.level &&
      LEVEL_RANK[e.level] < LEVEL_RANK[claim.level]
    ) {
      exclude('LEVEL_MISMATCH', 'LEVEL_MISMATCH');
      rules.push('R09_OUTPUT_IS_NOT_OUTCOME');
      continue;
    }
    if (!isStateClaim(claim.kind) && !periodsOverlap(claim.period, e.observedPeriod)) {
      exclude('PERIOD_MISMATCH', 'PERIOD_NOT_COVERED');
      rules.push('R10_PERIOD_MISMATCH');
      continue;
    }
    const asOfMs = evidenceAsOfMs(e.observedPeriod, src.publishedAt, src.retrievedAt);
    if (isStale(claim.kind, asOfMs, evaluatedAtMs)) {
      exclude('STALE', 'EVIDENCE_OUTDATED');
      staleCount++;
      rules.push('R11_STALE_STATE_EVIDENCE');
      continue;
    }
    if (src.contentHash) {
      const prior = seenContentHashes.get(src.contentHash);
      if (prior !== undefined && prior !== src.id) {
        exclude('DUPLICATE_CONTENT');
        rules.push('R12_DUPLICATE_CONTENT');
        continue;
      }
      seenContentHashes.set(src.contentHash, src.id);
    }

    const assessed: AssessedEvidence = {
      evidenceId: e.id,
      sourceId: src.id,
      sourceType: src.type,
      publisher: src.publisher,
      publisherKey: normPublisher(src.publisher),
      authority,
      declaredRelationship: e.relationship,
      effectiveRelationship: rel,
      basis: e.relationshipBasis,
      ...(e.reportedQuantity ? { reportedValue: e.reportedQuantity.value } : {}),
      ...(e.legalStage ? { legalStage: e.legalStage } : {}),
      asOf: new Date(asOfMs).toISOString(),
    };
    if (isIndependentScope(authority) && rel !== 'CONTEXTUALIZES') {
      counted.push(assessed);
    } else {
      contextual.push(assessed);
      if (authority === 'USER_SUBMITTED') review.add('USER_SUBMITTED_MATERIAL');
    }
  }

  // ── Conclusion ────────────────────────────────────────────────────────────
  const supporting = counted.filter((a) => a.effectiveRelationship === 'SUPPORTS');
  const partial = counted.filter((a) => a.effectiveRelationship === 'PARTIALLY_SUPPORTS');
  const contradicting = counted.filter((a) => a.effectiveRelationship === 'CONTRADICTS');
  const conflicts: ConflictRecord[] = [];
  const position = (a: AssessedEvidence) => ({
    evidenceId: a.evidenceId,
    sourceId: a.sourceId,
    publisher: a.publisher,
    relationship: (a.effectiveRelationship === 'CONTEXTUALIZES' ? 'CONTEXTUALIZES'
      : a.effectiveRelationship === 'CONTRADICTS' ? 'CONTRADICTS' : 'SUPPORTS') as EvidenceRelationship,
    ...(a.reportedValue !== undefined ? { reportedValue: a.reportedValue } : {}),
  });

  const authoritative = counted.filter((a) => a.authority === 'AUTHORITATIVE');
  const relKinds = (xs: AssessedEvidence[]) => new Set(xs.map((a) => a.effectiveRelationship));
  const allKinds = relKinds(counted);
  const recordConflict = () => {
    const withValues = counted.some((a) => a.reportedValue !== undefined);
    conflicts.push({
      claimId: claim.id,
      kind: withValues && !allKinds.has('CONTRADICTS') ? 'QUANTITY_DISAGREEMENT' : 'SUPPORT_VS_CONTRADICTION',
      positions: counted.map(position),
      basis: new Set(counted.map((a) => a.publisherKey)).size > 1 ? 'INDEPENDENT_SOURCES' : 'SAME_PUBLISHER',
      resolution: 'UNRESOLVED',
    });
  };

  // Self-reported figures that disagree with the organization's own claim
  // are an inconsistency worth showing — never a contradiction by themselves.
  const selfDisagreeing = contextual.filter((a) =>
    a.authority === 'SELF_REPORTED' && (a.effectiveRelationship === 'CONTRADICTS' || a.effectiveRelationship === 'PARTIALLY_SUPPORTS')
  );

  let status: ClaimStatus;
  if (counted.length === 0) {
    if (staleCount > 0) {
      status = 'OUTDATED';
      rules.push('S01_ONLY_STALE_EVIDENCE');
    } else {
      status = 'UNVERIFIED';
      rules.push(contextual.length === 0 ? 'S02_ABSENCE_OF_EVIDENCE_IS_UNVERIFIED' : 'S03_NO_INDEPENDENT_CORROBORATION');
    }
  } else if (authoritative.length > 0) {
    const ak = relKinds(authoritative);
    if (ak.size > 1) {
      status = 'INCONCLUSIVE';
      rules.push('S04_AUTHORITATIVE_SOURCES_DISAGREE');
    } else {
      const k = [...ak][0];
      status = k === 'SUPPORTS' ? 'SUPPORTED' : k === 'PARTIALLY_SUPPORTS' ? 'PARTIALLY_SUPPORTED' : 'CONTRADICTED';
      rules.push('S05_AUTHORITATIVE_WITHIN_SCOPE');
    }
    if (allKinds.size > 1) {
      recordConflict();
      rules.push('S06_LOWER_TIER_DISAGREEMENT_RECORDED');
    }
  } else if (allKinds.size > 1) {
    status = 'INCONCLUSIVE';
    recordConflict();
    rules.push('S07_INDEPENDENT_SOURCES_DISAGREE');
  } else {
    const k = [...allKinds][0];
    status = k === 'SUPPORTS' ? 'SUPPORTED' : k === 'PARTIALLY_SUPPORTS' ? 'PARTIALLY_SUPPORTED' : 'CONTRADICTED';
    rules.push('S08_INDEPENDENT_AGREEMENT');
  }
  if (selfDisagreeing.length > 0) {
    conflicts.push({
      claimId: claim.id,
      kind: selfDisagreeing.some((a) => a.reportedValue !== undefined) ? 'QUANTITY_DISAGREEMENT' : 'SUPPORT_VS_CONTRADICTION',
      positions: selfDisagreeing.map(position),
      basis: 'SELF_REPORTED_ONLY',
      resolution: 'UNRESOLVED',
    });
    rules.push('S09_SELF_REPORTED_INCONSISTENCY_RECORDED');
  }

  // False-attribution guard: never corroborate or contradict a subject whose
  // identity is not confirmed.
  if (ctx.subjectIdentity !== 'CONFIRMED') {
    gaps.add('IDENTITY_UNCONFIRMED');
    review.add('IDENTITY_NOT_CONFIRMED');
    if (status === 'SUPPORTED' || status === 'PARTIALLY_SUPPORTED' || status === 'CONTRADICTED') {
      status = 'INCONCLUSIVE';
      rules.push('S10_IDENTITY_NOT_CONFIRMED_CAPS_STATUS');
    }
  }

  const underlyingStatus = status;
  if (ctx.openDispute) {
    status = 'DISPUTED';
    review.add('OPEN_DISPUTE');
    rules.push('S11_OPEN_DISPUTE');
  }

  // Sufficiency describes the evidence base, not the organization.
  const independentVoices = countIndependentVoices(counted, sources);
  let sufficiency: EvidenceSufficiency;
  if (counted.length === 0 && contextual.length === 0) sufficiency = 'NO_EVIDENCE';
  else if (conflicts.some((c) => c.positions.some((p) => counted.some((a) => a.evidenceId === p.evidenceId)))) {
    sufficiency = 'CONFLICTING_EVIDENCE';
  } else if (independentVoices >= 2) sufficiency = 'MULTI_SOURCE_SUPPORT';
  else if (independentVoices === 1) sufficiency = 'INDEPENDENT_SUPPORT';
  else if (contextual.every((a) => a.authority === 'SELF_REPORTED')) sufficiency = 'SELF_REPORTED';
  else sufficiency = 'SINGLE_SOURCE';

  if (input.evidence.length === 0) gaps.add('NO_EVIDENCE');
  if (counted.length === 0) gaps.add('NO_INDEPENDENT_SOURCE');
  if (counted.length === 0 && contextual.length > 0 && contextual.every((a) => a.authority === 'SELF_REPORTED')) {
    gaps.add('ONLY_SELF_REPORTED');
  }
  if (status === 'CONTRADICTED' || underlyingStatus === 'CONTRADICTED') review.add('CONTRADICTION');
  if (conflicts.length > 0) review.add('CONFLICT');

  const evidenceSetHash = await computeEvidenceSetHash(claim, input.evidence, sources);
  const relevantFlags = [...flagged].filter((id) => sources.has(id)).sort();
  const providerKey = [...ctx.trustedProviders]
    .map((p) => `${p.id}:${p.sourceType}:${[...p.jurisdictions].sort().join('+')}`).sort();
  const reviewBindingHash = await sha256Hex(canonical({
    evidenceSetHash, flagged: relevantFlags, identity: ctx.subjectIdentity, dispute: !!ctx.openDispute, providers: providerKey,
  }));
  let reviewState: ReviewState = review.size > 0 ? 'REVIEW_REQUIRED' : 'AUTOMATED';
  if (ctx.humanReview) {
    if (ctx.humanReview.reviewBindingHash === reviewBindingHash && parseIsoMs(ctx.humanReview.reviewedAt) !== null) {
      reviewState = 'HUMAN_REVIEWED';
      rules.push('H01_HUMAN_REVIEW_BOUND_TO_EVIDENCE_SET');
    } else {
      reviewState = 'REVIEW_REQUIRED';
      rules.push('H02_HUMAN_REVIEW_STALE_FOR_NEW_EVIDENCE');
    }
  }

  let displayClass: EpistemicClass;
  if (status === 'DISPUTED' || (status === 'INCONCLUSIVE' && conflicts.length > 0)) displayClass = 'CONFLICT';
  else if (status === 'SUPPORTED' && supporting.some((a) => a.authority === 'AUTHORITATIVE')) displayClass = 'FACT';
  else if (status === 'UNVERIFIED' && sufficiency === 'NO_EVIDENCE') displayClass = 'ABSENCE_OF_EVIDENCE';
  else if (status === 'INCONCLUSIVE' || status === 'OUTDATED') displayClass = 'UNKNOWN';
  else displayClass = 'CLAIM';

  const ctxKey = canonical({
    identity: ctx.subjectIdentity, dispute: !!ctx.openDispute, flagged: relevantFlags, providers: providerKey,
    review: ctx.humanReview ?? null,
  });
  const resultId = `vr_${
    (await sha256Hex(`${IMPACT_POLICY_VERSION}|${claim.id}|${ctx.evaluatedAt}|${evidenceSetHash}|${ctxKey}`)).slice(0, 32)
  }`;

  return ok(deepFreeze({
    resultId,
    claimId: claim.id,
    investigationId: claim.investigationId,
    claimKind: claim.kind,
    subjectOrganizationId: claim.subjectOrganizationId,
    ...(claim.subjectProjectId ? { subjectProjectId: claim.subjectProjectId } : {}),
    ...(claim.subjectCampaignId ? { subjectCampaignId: claim.subjectCampaignId } : {}),
    status,
    underlyingStatus,
    sufficiency,
    displayClass,
    supporting,
    partiallySupporting: partial,
    contradicting,
    contextual,
    excluded,
    conflicts,
    gaps: [...gaps].sort(),
    reviewState,
    reviewReasons: [...review].sort(),
    rulesApplied: rules,
    subjectIdentity: ctx.subjectIdentity,
    evaluatedAt: ctx.evaluatedAt,
    policyVersion: IMPACT_POLICY_VERSION,
    evidenceSetHash,
    reviewBindingHash,
    isFindingOfWrongdoing: false as const,
    absenceOfEvidenceIsNotEvidenceOfWrongdoing: true as const,
  }));
}
