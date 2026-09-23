/**
 * Source authority — IV-IMPACT-FOUNDATION-01.
 *
 * SOURCE ≠ TRUTH. There is no universal "credibility score". A source's
 * weight is decided per (source type × claim kind × who published it) by the
 * explicit, versioned table below (IMPACT_SOURCE_MODEL.md §3):
 *
 *   AUTHORITATIVE     may establish a FACT inside its legal scope
 *                     (a registry on registration, a court on a legal stage)
 *   INDEPENDENT       independent corroboration, not a legal determination
 *   SELF_REPORTED     published by the subject organization itself — proves
 *                     the organization MADE the assertion, not that it is true
 *   USER_SUBMITTED    uploaded by a platform user; never a fact by itself
 *   ATTRIBUTION_ONLY  proves "this account published this", nothing more
 *   CONTEXTUAL        relevant context (opinion, allegation, third-party
 *                     database); never support or contradiction by itself
 *   NONE              outside the source's scope — excluded
 *                     (e.g. a registry cannot prove wells were built)
 *
 * Only AUTHORITATIVE and INDEPENDENT items can move a claim away from
 * UNVERIFIED. Changing this table is a policy change: bump
 * SOURCE_AUTHORITY_POLICY_VERSION.
 */
import type { Claim, ClaimKind, Source } from './types.ts';

export const SOURCE_AUTHORITY_POLICY_VERSION = 'impact-source-authority/1';

export type AuthorityScope =
  | 'AUTHORITATIVE'
  | 'INDEPENDENT'
  | 'SELF_REPORTED'
  | 'USER_SUBMITTED'
  | 'ATTRIBUTION_ONLY'
  | 'CONTEXTUAL'
  | 'NONE';

export function isIndependentScope(s: AuthorityScope): boolean {
  return s === 'AUTHORITATIVE' || s === 'INDEPENDENT';
}

type KindTable = Partial<Record<ClaimKind, AuthorityScope>> & { readonly default: AuthorityScope };

/** Third-party (non-self, non-user) authority per source type and claim kind. */
const TABLE: Readonly<Record<Exclude<Source['type'], 'USER_DOCUMENT' | 'SOCIAL_MEDIA' | 'NEWS'>, KindTable>> = {
  OFFICIAL_REGISTRY: {
    LEGAL_REGISTRATION: 'AUTHORITATIVE',
    REGULATORY_STATUS: 'AUTHORITATIVE',
    OPERATING_HISTORY: 'INDEPENDENT', // registration date ≠ proof of activity, but independent
    GOVERNANCE: 'INDEPENDENT', //         registered trustees/directors
    // Filed accounts are submitted BY the organization: not independent.
    FINANCIAL: 'CONTEXTUAL',
    IMPACT_OUTPUT: 'NONE',
    IMPACT_OUTCOME: 'NONE',
    BENEFICIARY_COUNT: 'NONE',
    AFFILIATION: 'NONE',
    default: 'CONTEXTUAL',
  },
  REGULATOR: {
    LEGAL_REGISTRATION: 'AUTHORITATIVE',
    REGULATORY_STATUS: 'AUTHORITATIVE',
    GOVERNANCE: 'INDEPENDENT',
    IMPACT_OUTPUT: 'NONE',
    IMPACT_OUTCOME: 'NONE',
    BENEFICIARY_COUNT: 'NONE',
    default: 'CONTEXTUAL',
  },
  COURT_RECORD: {
    REGULATORY_STATUS: 'AUTHORITATIVE', // exact procedural stage only (see verification.ts)
    IMPACT_OUTPUT: 'NONE',
    IMPACT_OUTCOME: 'NONE',
    BENEFICIARY_COUNT: 'NONE',
    default: 'CONTEXTUAL',
  },
  GOVERNMENT_RECORD: {
    IMPACT_OUTPUT: 'INDEPENDENT',
    IMPACT_OUTCOME: 'INDEPENDENT',
    BENEFICIARY_COUNT: 'INDEPENDENT',
    OPERATING_HISTORY: 'INDEPENDENT',
    FINANCIAL: 'INDEPENDENT', // e.g. grant disbursement records
    LEGAL_REGISTRATION: 'INDEPENDENT',
    default: 'CONTEXTUAL',
  },
  AUDITED_REPORT: {
    FINANCIAL: 'INDEPENDENT', // auditors give assurance on accounts, not on impact
    default: 'CONTEXTUAL',
  },
  FINANCIAL_REPORT: { default: 'CONTEXTUAL' },
  ACADEMIC: {
    IMPACT_OUTPUT: 'INDEPENDENT',
    IMPACT_OUTCOME: 'INDEPENDENT',
    BENEFICIARY_COUNT: 'INDEPENDENT',
    default: 'CONTEXTUAL',
  },
  // Third-party databases frequently republish self-reported data.
  NGO_DATABASE: { default: 'CONTEXTUAL' },
  ORGANIZATION_WEBSITE: { default: 'CONTEXTUAL' }, // someone else's website
  OTHER: { default: 'CONTEXTUAL' },
};

const NEWS_REPORTING: KindTable = {
  IMPACT_OUTPUT: 'INDEPENDENT',
  IMPACT_OUTCOME: 'INDEPENDENT',
  BENEFICIARY_COUNT: 'INDEPENDENT',
  OPERATING_HISTORY: 'INDEPENDENT',
  AFFILIATION: 'INDEPENDENT',
  GOVERNANCE: 'INDEPENDENT',
  // Journalism cannot establish legal registration or legal status.
  LEGAL_REGISTRATION: 'CONTEXTUAL',
  REGULATORY_STATUS: 'CONTEXTUAL',
  default: 'CONTEXTUAL',
};

/**
 * The single authority decision. Order is part of the contract:
 *   1 user-submitted material → USER_SUBMITTED (whatever it claims to be)
 *   2 published by the claim's subject → SELF_REPORTED (whatever its type)
 *   3 social media → ATTRIBUTION_ONLY
 *   4 news → by genre (only REPORTING can corroborate)
 *   5 table lookup
 */
export function authorityFor(source: Source, claim: Claim): AuthorityScope {
  if (source.userSubmitted || source.type === 'USER_DOCUMENT') return 'USER_SUBMITTED';
  if (source.publisherOrganizationId !== undefined && source.publisherOrganizationId === claim.subjectOrganizationId) {
    return 'SELF_REPORTED';
  }
  if (source.type === 'SOCIAL_MEDIA') return 'ATTRIBUTION_ONLY';
  if (source.type === 'NEWS') {
    if (source.newsGenre !== 'REPORTING') return 'CONTEXTUAL';
    return NEWS_REPORTING[claim.kind] ?? NEWS_REPORTING.default;
  }
  const t = TABLE[source.type];
  return t[claim.kind] ?? t.default;
}

/** What a source can prove on its own, in words the UI can render
 * (IMPACT_REPUTATIONAL_SAFETY.md §2). */
export function provesOnlyThatStatementWasMade(scope: AuthorityScope): boolean {
  return scope === 'SELF_REPORTED' || scope === 'ATTRIBUTION_ONLY' || scope === 'USER_SUBMITTED';
}
