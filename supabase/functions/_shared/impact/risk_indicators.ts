/**
 * Indicators — IV-IMPACT-FOUNDATION-01.
 *
 * RiskIndicator ≠ fraud. An indicator is "something worth a closer look" or
 * "something that speaks in the organization's favour", always tied to the
 * evidence that produced it. There is deliberately NO aggregate score, no
 * ranking and no "fraud probability" (IMPACT_REPUTATIONAL_SAFETY.md §4): a
 * future scorecard must be explainable, calibrated, versioned, tested and
 * contestable, and is out of scope for the Foundation.
 *
 * Three polarities, so the model is not biased towards looking for problems:
 *   POSITIVE         verified registration, audited accounts, independent
 *                    impact evidence, consistent reporting…
 *   CONCERN          a specific, evidenced inconsistency or official action
 *   INFORMATION_GAP  something could not be verified — NOT a concern
 *
 * Rules that are NOT indicators on their own (tested):
 *   - absence of evidence (→ INFORMATION_GAP only)
 *   - a high overhead ratio (context matters; financial.ts never emits one)
 *   - a news allegation or an open investigation (→ exact legal stage, never guilt)
 */
import { sha256Hex } from './provenance.ts';
import type { LegalStage } from './types.ts';
import type { VerificationResult } from './verification.ts';
import type { EntityMatch } from './entity_resolution.ts';

export const INDICATOR_POLICY_VERSION = 'impact-indicators/1';

export type IndicatorPolarity = 'POSITIVE' | 'CONCERN' | 'INFORMATION_GAP';

export type IndicatorCode =
  // POSITIVE
  | 'VERIFIED_REGISTRATION'
  | 'AUDITED_ACCOUNTS'
  | 'INDEPENDENT_IMPACT_EVIDENCE'
  | 'MULTI_SOURCE_CORROBORATION'
  | 'FAVOURABLE_LEGAL_OUTCOME'
  // CONCERN
  | 'REGISTRATION_MISMATCH'
  | 'IDENTITY_INCONSISTENCY'
  | 'DOMAIN_MISMATCH'
  | 'CONFLICTING_CLAIMS'
  | 'CLAIM_CONTRADICTED_BY_INDEPENDENT_SOURCE'
  | 'REGULATORY_OR_COURT_RECORD'
  | 'UNVERIFIED_AFFILIATION'
  // INFORMATION_GAP
  | 'UNVERIFIED_CLAIMS'
  | 'ONLY_SELF_REPORTED_EVIDENCE'
  | 'OUTDATED_EVIDENCE'
  | 'UNRESOLVED_ALLEGATION'
  | 'INCONSISTENT_SELF_REPORTING';

const POLARITY: Readonly<Record<IndicatorCode, IndicatorPolarity>> = {
  VERIFIED_REGISTRATION: 'POSITIVE',
  AUDITED_ACCOUNTS: 'POSITIVE',
  INDEPENDENT_IMPACT_EVIDENCE: 'POSITIVE',
  MULTI_SOURCE_CORROBORATION: 'POSITIVE',
  FAVOURABLE_LEGAL_OUTCOME: 'POSITIVE',
  REGISTRATION_MISMATCH: 'CONCERN',
  IDENTITY_INCONSISTENCY: 'CONCERN',
  DOMAIN_MISMATCH: 'CONCERN',
  CONFLICTING_CLAIMS: 'CONCERN',
  CLAIM_CONTRADICTED_BY_INDEPENDENT_SOURCE: 'CONCERN',
  REGULATORY_OR_COURT_RECORD: 'CONCERN',
  UNVERIFIED_AFFILIATION: 'CONCERN',
  UNVERIFIED_CLAIMS: 'INFORMATION_GAP',
  ONLY_SELF_REPORTED_EVIDENCE: 'INFORMATION_GAP',
  OUTDATED_EVIDENCE: 'INFORMATION_GAP',
  UNRESOLVED_ALLEGATION: 'INFORMATION_GAP',
  INCONSISTENT_SELF_REPORTING: 'INFORMATION_GAP',
};

export function polarityOf(code: IndicatorCode): IndicatorPolarity {
  return POLARITY[code];
}

export interface Indicator {
  readonly code: IndicatorCode;
  readonly polarity: IndicatorPolarity;
  /** Claim/evidence ids this indicator rests on — never empty. */
  readonly basis: readonly string[];
  /** Exact procedural stage, when the indicator comes from a legal record. */
  readonly legalStage?: LegalStage;
  /** Contract literal: an indicator is never proof of wrongdoing. */
  readonly isProofOfWrongdoing: false;
  readonly requiresHumanReview: boolean;
}

const FINAL_ADVERSE: ReadonlySet<LegalStage> = new Set(['CONVICTED', 'SANCTIONED']);
const FAVOURABLE: ReadonlySet<LegalStage> = new Set(['ACQUITTED', 'DISMISSED', 'OVERTURNED', 'CLOSED_NO_ACTION']);

function ind(code: IndicatorCode, basis: string[], extra: Partial<Indicator> = {}): Indicator {
  const polarity = POLARITY[code];
  return Object.freeze({
    code,
    polarity,
    basis: Object.freeze([...new Set(basis)].sort()),
    isProofOfWrongdoing: false as const,
    requiresHumanReview: polarity === 'CONCERN',
    ...extra,
  });
}

export interface IndicatorInput {
  readonly results: readonly VerificationResult[];
  /** Entity resolution of the subject against registry candidates. */
  readonly identityMatches?: readonly { readonly candidateRef: string; readonly match: EntityMatch }[];
  /** Campaigns claiming affiliation without verification evidence. */
  readonly unverifiedAffiliationCampaignIds?: readonly string[];
}

export function deriveIndicators(input: IndicatorInput): readonly Indicator[] {
  const out: Indicator[] = [];
  const unverified: string[] = [];
  const selfOnly: string[] = [];
  const outdated: string[] = [];

  for (const r of input.results) {
    const kind = r.claimKind;
    const auth = r.supporting.filter((a) => a.authority === 'AUTHORITATIVE');
    if (r.status === 'SUPPORTED' && kind === 'LEGAL_REGISTRATION' && auth.length > 0) {
      out.push(ind('VERIFIED_REGISTRATION', [r.claimId, ...auth.map((a) => a.evidenceId)]));
    }
    if (r.status === 'CONTRADICTED' && kind === 'LEGAL_REGISTRATION') {
      out.push(ind('REGISTRATION_MISMATCH', [r.claimId, ...r.contradicting.map((a) => a.evidenceId)]));
    }
    const audited = r.supporting.filter((a) => a.sourceType === 'AUDITED_REPORT');
    if (kind === 'FINANCIAL' && r.status === 'SUPPORTED' && audited.length > 0) {
      out.push(ind('AUDITED_ACCOUNTS', [r.claimId, ...audited.map((a) => a.evidenceId)]));
    }
    if (
      (kind === 'IMPACT_OUTPUT' || kind === 'IMPACT_OUTCOME' || kind === 'BENEFICIARY_COUNT') &&
      (r.status === 'SUPPORTED' || r.status === 'PARTIALLY_SUPPORTED')
    ) {
      out.push(ind('INDEPENDENT_IMPACT_EVIDENCE', [r.claimId, ...r.supporting.concat(r.partiallySupporting).map((a) => a.evidenceId)]));
    }
    if (r.sufficiency === 'MULTI_SOURCE_SUPPORT' && r.status === 'SUPPORTED') {
      out.push(ind('MULTI_SOURCE_CORROBORATION', [r.claimId, ...r.supporting.map((a) => a.evidenceId)]));
    }
    const indepConflicts = r.conflicts.filter((c) => c.basis === 'INDEPENDENT_SOURCES');
    const selfConflicts = r.conflicts.filter((c) => c.basis === 'SELF_REPORTED_ONLY');
    if (indepConflicts.length > 0) {
      out.push(ind('CONFLICTING_CLAIMS', [r.claimId, ...indepConflicts.flatMap((c) => c.positions.map((p) => p.evidenceId))]));
    }
    if (selfConflicts.length > 0) {
      out.push(ind('INCONSISTENT_SELF_REPORTING', [r.claimId, ...selfConflicts.flatMap((c) => c.positions.map((p) => p.evidenceId))]));
    }
    if (r.status === 'CONTRADICTED' && kind !== 'LEGAL_REGISTRATION') {
      out.push(ind('CLAIM_CONTRADICTED_BY_INDEPENDENT_SOURCE', [r.claimId, ...r.contradicting.map((a) => a.evidenceId)]));
    }
    for (const a of [...r.contradicting, ...r.contextual, ...r.supporting]) {
      if (!a.legalStage) continue;
      if (FINAL_ADVERSE.has(a.legalStage)) {
        out.push(ind('REGULATORY_OR_COURT_RECORD', [r.claimId, a.evidenceId], { legalStage: a.legalStage }));
      } else if (FAVOURABLE.has(a.legalStage)) {
        out.push(ind('FAVOURABLE_LEGAL_OUTCOME', [r.claimId, a.evidenceId], { legalStage: a.legalStage }));
      } else {
        out.push(ind('UNRESOLVED_ALLEGATION', [r.claimId, a.evidenceId], { legalStage: a.legalStage }));
      }
    }
    if (r.gaps.includes('ALLEGATION_UNRESOLVED') && !r.contextual.some((a) => a.legalStage)) {
      out.push(ind('UNRESOLVED_ALLEGATION', [r.claimId]));
    }
    if (r.status === 'UNVERIFIED') unverified.push(r.claimId);
    if (r.gaps.includes('ONLY_SELF_REPORTED')) selfOnly.push(r.claimId);
    if (r.status === 'OUTDATED') outdated.push(r.claimId);
  }
  if (unverified.length) out.push(ind('UNVERIFIED_CLAIMS', unverified));
  if (selfOnly.length) out.push(ind('ONLY_SELF_REPORTED_EVIDENCE', selfOnly));
  if (outdated.length) out.push(ind('OUTDATED_EVIDENCE', outdated));

  for (const m of input.identityMatches ?? []) {
    if (m.match.signals.includes('REGISTRATION_EQUAL') && m.match.signals.includes('DOMAIN_DIFFERENT')) {
      out.push(ind('DOMAIN_MISMATCH', [m.candidateRef]));
    }
    if (m.match.signals.includes('REGISTRATION_EQUAL') && m.match.signals.includes('REGISTRATION_DIFFERENT')) {
      out.push(ind('IDENTITY_INCONSISTENCY', [m.candidateRef]));
    }
  }
  for (const c of input.unverifiedAffiliationCampaignIds ?? []) out.push(ind('UNVERIFIED_AFFILIATION', [c]));

  return Object.freeze(
    out.sort((x, y) => (x.code < y.code ? -1 : x.code > y.code ? 1 : x.basis.join() < y.basis.join() ? -1 : 1)),
  );
}

/** Stable fingerprint of an indicator set (for versioned reports). */
export async function indicatorSetHash(indicators: readonly Indicator[]): Promise<string> {
  return await sha256Hex(JSON.stringify(indicators.map((i) => [i.code, i.basis, i.legalStage ?? null])));
}
