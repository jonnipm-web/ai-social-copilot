/**
 * Organization profile / Impact Report — IV-IMPACT-FOUNDATION-01.
 *
 * Structured, surface-independent (Android/Web render the same object).
 * Sections: identity · registration · projects · campaigns · claims ·
 * positive evidence · conflicts · gaps · indicators · verification summary ·
 * sources · commercial disclosures · last updated.
 *
 * There is no verdict field, no score and no rank — by type. Every claim is
 * rendered with its epistemic class and status label; every sentence the
 * report generates comes from fixed templates and is checked against the
 * verdict-language guard before it is returned.
 */
import type { CommercialRelationship } from './boundaries.ts';
import { deriveAffiliation, type FinancialDisclosure, spendingShares } from './financial_and_metrics.ts';
import { CLASS_LABEL, DISCLAIMERS, type Lang, POLARITY_LABEL, STATUS_LABEL, SUFFICIENCY_LABEL } from './i18n.ts';
import type { CanonicalRegistryRecord } from './provider.ts';
import type { Indicator } from './risk_indicators.ts';
import { findVerdictLanguage } from './safety.ts';
import type { Affiliation, Campaign, Claim, ClaimStatus, ImpactProject, Organization, Source } from './types.ts';
import type { VerificationResult } from './verification.ts';

export interface ReportInput {
  readonly organization: Organization;
  readonly registry?: readonly CanonicalRegistryRecord[];
  readonly projects?: readonly ImpactProject[];
  readonly campaigns?: readonly Campaign[];
  readonly claims: readonly Claim[];
  readonly results: readonly VerificationResult[];
  readonly indicators: readonly Indicator[];
  readonly sources: readonly Source[];
  readonly financials?: readonly FinancialDisclosure[];
  readonly commercialRelationships?: readonly CommercialRelationship[];
  readonly lang: Lang;
}

export interface ReportClaim {
  readonly claimId: string;
  readonly originalText: string;
  readonly originalLanguage?: string;
  readonly kind: Claim['kind'];
  readonly status: ClaimStatus;
  readonly statusLabel: string;
  readonly displayClass: VerificationResult['displayClass'];
  readonly displayClassLabel: string;
  readonly sufficiencyLabel: string;
  readonly summary: string;
  readonly supportingSourceIds: readonly string[];
  readonly contradictingSourceIds: readonly string[];
  readonly gaps: readonly string[];
  readonly reviewState: VerificationResult['reviewState'];
  readonly resultId: string;
  readonly evaluatedAt: string;
}

export interface ImpactReport {
  readonly organizationId: string;
  readonly identity: Organization['identity'];
  readonly organizationType: Organization['type'];
  readonly registration: readonly {
    readonly providerId: string;
    readonly country: string;
    readonly scheme: string;
    readonly registrationNumber: string;
    readonly status: CanonicalRegistryRecord['status'];
    readonly statusAsOf?: string;
    readonly retrievedAt: string;
  }[];
  readonly projects: readonly ImpactProject[];
  readonly campaigns: readonly { readonly campaignId: string; readonly name: string; readonly affiliation: Affiliation }[];
  readonly claims: readonly ReportClaim[];
  readonly positiveEvidence: readonly Indicator[];
  readonly concerns: readonly Indicator[];
  readonly informationGaps: readonly Indicator[];
  readonly conflicts: readonly VerificationResult['conflicts'][number][];
  readonly financials: readonly (FinancialDisclosure & { readonly shares: ReturnType<typeof spendingShares> })[];
  readonly statusCounts: Readonly<Record<ClaimStatus, number>>;
  readonly sources: readonly Pick<Source, 'id' | 'type' | 'publisher' | 'uri' | 'retrievedAt' | 'publishedAt' | 'status'>[];
  readonly commercialDisclosures: readonly CommercialRelationship[];
  readonly lastUpdated: string | null;
  readonly disclaimers: readonly string[];
  readonly labels: { readonly polarity: Readonly<Record<string, string>> };
}

const TEMPLATE: Readonly<Record<ClaimStatus, Readonly<Record<Lang, string>>>> = {
  UNVERIFIED: {
    pt: 'Nenhuma fonte independente utilizável foi encontrada para esta alegação.',
    en: 'No usable independent source was found for this claim.',
  },
  SUPPORTED: {
    pt: 'Fontes independentes sustentam esta alegação.',
    en: 'Independent sources support this claim.',
  },
  PARTIALLY_SUPPORTED: {
    pt: 'Fontes independentes sustentam apenas parte desta alegação.',
    en: 'Independent sources support only part of this claim.',
  },
  CONTRADICTED: {
    pt: 'Uma fonte independente registra informação diferente da alegação.',
    en: 'An independent source records information that differs from the claim.',
  },
  INCONCLUSIVE: {
    pt: 'As evidências disponíveis não permitem uma conclusão.',
    en: 'The available evidence does not allow a conclusion.',
  },
  OUTDATED: {
    pt: 'As evidências encontradas são antigas demais para indicar a situação atual.',
    en: 'The evidence found is too old to indicate the current situation.',
  },
  DISPUTED: {
    pt: 'Esta alegação está em contestação e aguarda revisão.',
    en: 'This claim is under dispute and awaits review.',
  },
};

export function buildImpactReport(input: ReportInput): ImpactReport {
  const lang = input.lang;
  const byClaim = new Map(input.results.map((r) => [r.claimId, r]));
  const srcOf = (evIds: readonly { sourceId: string }[]) => [...new Set(evIds.map((a) => a.sourceId))].sort();

  const claims: ReportClaim[] = input.claims.map((c) => {
    const r = byClaim.get(c.id);
    const status: ClaimStatus = r?.status ?? 'UNVERIFIED';
    return Object.freeze({
      claimId: c.id,
      originalText: c.text,
      ...(c.textLanguage ? { originalLanguage: c.textLanguage } : {}),
      kind: c.kind,
      status,
      statusLabel: STATUS_LABEL[status][lang],
      displayClass: r?.displayClass ?? 'ABSENCE_OF_EVIDENCE',
      displayClassLabel: CLASS_LABEL[r?.displayClass ?? 'ABSENCE_OF_EVIDENCE'][lang],
      sufficiencyLabel: SUFFICIENCY_LABEL[r?.sufficiency ?? 'NO_EVIDENCE'][lang],
      summary: TEMPLATE[status][lang],
      supportingSourceIds: srcOf([...(r?.supporting ?? []), ...(r?.partiallySupporting ?? [])]),
      contradictingSourceIds: srcOf(r?.contradicting ?? []),
      gaps: r?.gaps ?? ['NO_EVIDENCE'],
      reviewState: r?.reviewState ?? 'AUTOMATED',
      resultId: r?.resultId ?? '',
      evaluatedAt: r?.evaluatedAt ?? '',
    });
  });

  const statusCounts = {
    UNVERIFIED: 0, SUPPORTED: 0, PARTIALLY_SUPPORTED: 0, CONTRADICTED: 0, INCONCLUSIVE: 0, OUTDATED: 0, DISPUTED: 0,
  } as Record<ClaimStatus, number>;
  for (const c of claims) statusCounts[c.status]++;

  const affiliationResultFor = (campaignId: string) =>
    input.results.find((r) => r.claimKind === 'AFFILIATION' && r.subjectCampaignId === campaignId);

  const lastUpdated = input.results.map((r) => r.evaluatedAt).sort().at(-1) ?? null;
  const disclaimers = [DISCLAIMERS.NO_VERDICT[lang], DISCLAIMERS.ABSENCE[lang], DISCLAIMERS.INDICATORS[lang], DISCLAIMERS.EXPERIMENTAL[lang]];

  const report: ImpactReport = {
    organizationId: input.organization.id,
    identity: input.organization.identity,
    organizationType: input.organization.type,
    registration: (input.registry ?? []).map((r) => ({
      providerId: r.providerId,
      country: r.jurisdiction.country,
      scheme: r.scheme,
      registrationNumber: r.registrationNumber,
      status: r.status,
      ...(r.statusAsOf ? { statusAsOf: r.statusAsOf } : {}),
      retrievedAt: r.retrievedAt,
    })),
    projects: input.projects ?? [],
    campaigns: (input.campaigns ?? []).map((c) => ({
      campaignId: c.id,
      name: c.name,
      affiliation: deriveAffiliation(c, affiliationResultFor(c.id)),
    })),
    claims,
    positiveEvidence: input.indicators.filter((i) => i.polarity === 'POSITIVE'),
    concerns: input.indicators.filter((i) => i.polarity === 'CONCERN'),
    informationGaps: input.indicators.filter((i) => i.polarity === 'INFORMATION_GAP'),
    conflicts: input.results.flatMap((r) => r.conflicts),
    financials: (input.financials ?? []).map((f) => ({ ...f, shares: spendingShares(f) })),
    statusCounts,
    sources: input.sources.map((s) => ({
      id: s.id, type: s.type, publisher: s.publisher, retrievedAt: s.retrievedAt, status: s.status,
      ...(s.uri ? { uri: s.uri } : {}),
      ...(s.publishedAt ? { publishedAt: s.publishedAt } : {}),
    })),
    commercialDisclosures: (input.commercialRelationships ?? []).filter((c) => c.organizationId === input.organization.id),
    lastUpdated,
    disclaimers,
    labels: {
      polarity: Object.fromEntries(Object.entries(POLARITY_LABEL).map(([k, v]) => [k, v[lang]])),
    },
  };

  // Self-check: generated text only (templates, labels, disclaimers).
  const generated = [...claims.flatMap((c) => [c.summary, c.statusLabel, c.displayClassLabel, c.sufficiencyLabel]), ...disclaimers];
  for (const t of generated) {
    if (findVerdictLanguage(t).length > 0) throw new Error('INTERNAL_ERROR: report template produced verdict language');
  }
  return Object.freeze(report);
}
