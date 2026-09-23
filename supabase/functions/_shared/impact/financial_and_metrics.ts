/**
 * Financial transparency, impact metrics and campaign affiliation —
 * IV-IMPACT-FOUNDATION-01.
 *
 * Descriptive only. Nothing here emits an indicator or a judgement:
 *  - a high administrative/fundraising share is NOT a concern by itself
 *    (young organizations, advocacy work, emergency scale-up… context matters);
 *  - outputs are not outcomes, outcomes are not impact;
 *  - affiliation is VERIFIED only from a SUPPORTED AFFILIATION claim, never
 *    from a matching name, logo or look-alike domain.
 */
import type { VerificationResult } from './verification.ts';
import type { Affiliation, Campaign, ImpactLevel, Period } from './types.ts';

// ── Financial disclosure ────────────────────────────────────────────────────

export type FinancialLine =
  | 'REVENUE'
  | 'DONATIONS'
  | 'EXPENSES'
  | 'PROGRAM_SPENDING'
  | 'ADMINISTRATIVE_SPENDING'
  | 'FUNDRAISING_SPENDING'
  | 'ASSETS'
  | 'LIABILITIES';

export interface FinancialDisclosure {
  readonly organizationId: string;
  readonly period: Period;
  readonly currency: string; // ISO 4217
  readonly lines: Readonly<Partial<Record<FinancialLine, number>>>;
  readonly sourceId: string;
  readonly audited: boolean;
}

export interface SpendingShares {
  readonly program: number | null;
  readonly administrative: number | null;
  readonly fundraising: number | null;
  /** Always present so no consumer can present a ratio without it. */
  readonly interpretationNote: 'DESCRIPTIVE_ONLY_NOT_AN_INDICATOR';
}

/** Shares of total expenses; null when the inputs do not allow it. */
export function spendingShares(d: FinancialDisclosure): SpendingShares {
  const total = d.lines.EXPENSES;
  const share = (v: number | undefined) =>
    total !== undefined && total > 0 && v !== undefined && Number.isFinite(v) && v >= 0 ? v / total : null;
  return Object.freeze({
    program: share(d.lines.PROGRAM_SPENDING),
    administrative: share(d.lines.ADMINISTRATIVE_SPENDING),
    fundraising: share(d.lines.FUNDRAISING_SPENDING),
    interpretationNote: 'DESCRIPTIVE_ONLY_NOT_AN_INDICATOR' as const,
  });
}

// ── Impact metrics ──────────────────────────────────────────────────────────

export interface ImpactMetric {
  readonly id: string;
  readonly organizationId: string;
  readonly projectId?: string;
  readonly level: ImpactLevel;
  readonly metric: string;
  readonly value: number;
  readonly unit: string;
  readonly period?: Period;
  /** Aggregated figures only — beneficiary-level records are out of scope. */
  readonly aggregated: true;
  readonly sourceId: string;
}

const LEVEL_ORDER: readonly ImpactLevel[] = ['INPUT', 'ACTIVITY', 'OUTPUT', 'OUTCOME', 'IMPACT'];

/** Can evidence at `evidenceLevel` substantiate a claim at `claimLevel`?
 * Meals delivered (OUTPUT) cannot prove improved nutrition (OUTCOME). */
export function levelCanSubstantiate(evidenceLevel: ImpactLevel, claimLevel: ImpactLevel): boolean {
  return LEVEL_ORDER.indexOf(evidenceLevel) >= LEVEL_ORDER.indexOf(claimLevel);
}

// ── Campaign affiliation ────────────────────────────────────────────────────

/**
 * The only way a campaign's affiliation becomes VERIFIED: a verification
 * result for an AFFILIATION claim about that campaign that is SUPPORTED with
 * a CONFIRMED subject identity. A campaign that merely names an organization
 * is CLAIMED; anything else is UNKNOWN.
 */
export function deriveAffiliation(
  campaign: Pick<Campaign, 'id' | 'claimedOrganizationId'>,
  affiliationResult?: Pick<
    VerificationResult,
    'status' | 'subjectIdentity' | 'subjectOrganizationId' | 'claimKind' | 'subjectCampaignId'
  >,
): Affiliation {
  if (
    affiliationResult && affiliationResult.claimKind === 'AFFILIATION' &&
    affiliationResult.subjectCampaignId === campaign.id &&
    affiliationResult.status === 'SUPPORTED' && affiliationResult.subjectIdentity === 'CONFIRMED' &&
    campaign.claimedOrganizationId !== undefined && affiliationResult.subjectOrganizationId === campaign.claimedOrganizationId
  ) {
    return 'VERIFIED_AFFILIATION';
  }
  return campaign.claimedOrganizationId !== undefined ? 'CLAIMED_AFFILIATION' : 'UNKNOWN_AFFILIATION';
}
