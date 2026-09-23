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
import type { Claim, ClaimKind, Source, TrustedProviderRef } from './types.ts';

export const SOURCE_AUTHORITY_POLICY_VERSION = 'impact-source-authority/2';

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
 *   4 news → by genre (only REPORTING can corroborate); else table lookup
 *   5 provenance gate: AUTHORITATIVE/INDEPENDENT survive only if the source
 *     was obtained by a trusted provider declared for exactly this source
 *     type (and, when the source names one, this jurisdiction). Anything
 *     else — analyst-typed, unknown provider, type/jurisdiction mismatch —
 *     is capped at CONTEXTUAL.
 */
export function authorityFor(
  source: Source,
  claim: Claim,
  trustedProviders: ReadonlyMap<string, TrustedProviderRef>,
): AuthorityScope {
  if (source.userSubmitted || source.type === 'USER_DOCUMENT' || source.acquisition?.method === 'USER_UPLOAD') {
    return 'USER_SUBMITTED';
  }
  if (source.publisherOrganizationId !== undefined && source.publisherOrganizationId === claim.subjectOrganizationId) {
    return 'SELF_REPORTED';
  }
  if (source.type === 'SOCIAL_MEDIA') return 'ATTRIBUTION_ONLY';
  let base: AuthorityScope;
  if (source.type === 'NEWS') {
    base = source.newsGenre !== 'REPORTING' ? 'CONTEXTUAL' : lookup(NEWS_REPORTING, claim.kind);
  } else {
    const t = Object.prototype.hasOwnProperty.call(TABLE, source.type) ? TABLE[source.type as keyof typeof TABLE] : undefined;
    base = t ? lookup(t, claim.kind) : 'CONTEXTUAL';
  }
  if (!isIndependentScope(base)) return base;
  return hasTrustedProvenance(source, trustedProviders) ? base : 'CONTEXTUAL';
}

function lookup(t: KindTable, kind: ClaimKind): AuthorityScope {
  return Object.prototype.hasOwnProperty.call(t, kind) ? (t[kind] as AuthorityScope) : t.default;
}

export function hasTrustedProvenance(source: Source, trustedProviders: ReadonlyMap<string, TrustedProviderRef>): boolean {
  const a = source.acquisition;
  if (!a || a.method !== 'PROVIDER') return false;
  const p = trustedProviders.get(a.providerId);
  if (!p || p.sourceType !== source.type) return false;
  if (source.jurisdiction && !p.jurisdictions.includes(source.jurisdiction.country.toUpperCase())) return false;
  return true;
}

/** What a source can prove on its own, in words the UI can render
 * (IMPACT_REPUTATIONAL_SAFETY.md §2). */
export function provesOnlyThatStatementWasMade(scope: AuthorityScope): boolean {
  return scope === 'SELF_REPORTED' || scope === 'ATTRIBUTION_ONLY' || scope === 'USER_SUBMITTED';
}
