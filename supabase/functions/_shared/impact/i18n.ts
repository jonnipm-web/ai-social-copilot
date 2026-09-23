/**
 * Impact UI strings (PT/EN) — IV-IMPACT-FOUNDATION-01.
 *
 * Keyed by code; logic never branches on these strings. Original evidence
 * and claim text are never translated in place: a translation is a derived
 * representation with its own language tag (see report.ts).
 */
import type { ClaimStatus, EpistemicClass, EvidenceSufficiency } from './types.ts';
import type { IndicatorPolarity } from './risk_indicators.ts';

export type Lang = 'pt' | 'en';

export const STATUS_LABEL: Readonly<Record<ClaimStatus, Readonly<Record<Lang, string>>>> = {
  UNVERIFIED: { pt: 'Não verificada', en: 'Unverified' },
  SUPPORTED: { pt: 'Sustentada por evidência independente', en: 'Supported by independent evidence' },
  PARTIALLY_SUPPORTED: { pt: 'Parcialmente sustentada', en: 'Partially supported' },
  CONTRADICTED: { pt: 'Contrariada por evidência independente', en: 'Contradicted by independent evidence' },
  INCONCLUSIVE: { pt: 'Inconclusiva', en: 'Inconclusive' },
  OUTDATED: { pt: 'Evidência desatualizada', en: 'Evidence outdated' },
  DISPUTED: { pt: 'Em contestação', en: 'Under dispute' },
};

export const CLASS_LABEL: Readonly<Record<EpistemicClass, Readonly<Record<Lang, string>>>> = {
  FACT: { pt: 'Fato verificado (fonte oficial, dentro do seu escopo)', en: 'Verified fact (official source, within its scope)' },
  CLAIM: { pt: 'Alegação da fonte', en: 'Source claim' },
  EVIDENCE: { pt: 'Evidência', en: 'Evidence' },
  INFERENCE: { pt: 'Inferência do sistema', en: 'System inference' },
  ALLEGATION: { pt: 'Acusação não comprovada', en: 'Unproven allegation' },
  CONFLICT: { pt: 'Fontes em conflito', en: 'Conflicting sources' },
  UNKNOWN: { pt: 'Desconhecido', en: 'Unknown' },
  ABSENCE_OF_EVIDENCE: { pt: 'Sem evidência encontrada', en: 'No evidence found' },
};

export const SUFFICIENCY_LABEL: Readonly<Record<EvidenceSufficiency, Readonly<Record<Lang, string>>>> = {
  NO_EVIDENCE: { pt: 'Nenhuma evidência utilizável', en: 'No usable evidence' },
  SELF_REPORTED: { pt: 'Apenas autodeclaração da própria organização', en: 'Self-reported by the organization only' },
  SINGLE_SOURCE: { pt: 'Sem corroboração independente', en: 'Not independently corroborated' },
  INDEPENDENT_SUPPORT: { pt: 'Uma fonte independente', en: 'One independent source' },
  MULTI_SOURCE_SUPPORT: { pt: 'Várias fontes independentes', en: 'Multiple independent sources' },
  CONFLICTING_EVIDENCE: { pt: 'Evidências conflitantes', en: 'Conflicting evidence' },
};

export const POLARITY_LABEL: Readonly<Record<IndicatorPolarity, Readonly<Record<Lang, string>>>> = {
  POSITIVE: { pt: 'Evidência positiva', en: 'Positive evidence' },
  CONCERN: { pt: 'Ponto que merece investigação adicional', en: 'Point that merits further investigation' },
  INFORMATION_GAP: { pt: 'Lacuna de informação', en: 'Information gap' },
};

export const DISCLAIMERS: Readonly<Record<string, Readonly<Record<Lang, string>>>> = {
  NO_VERDICT: {
    pt: 'Este relatório organiza evidências. Não é um veredito sobre a organização e não afirma fraude, crime ou confiabilidade.',
    en: 'This report organizes evidence. It is not a verdict on the organization and does not assert fraud, crime or trustworthiness.',
  },
  ABSENCE: {
    pt: 'Ausência de evidência não é evidência de irregularidade.',
    en: 'Absence of evidence is not evidence of wrongdoing.',
  },
  INDICATORS: {
    pt: 'Indicadores apontam onde olhar com mais atenção; nenhum indicador isolado é prova de irregularidade.',
    en: 'Indicators point to where to look more closely; no single indicator is proof of wrongdoing.',
  },
  EXPERIMENTAL: {
    pt: 'EXPERIMENTAL — uso interno do Impact Lab. Dados de teste fictícios.',
    en: 'EXPERIMENTAL — Impact Lab internal use. Fictitious test data.',
  },
};
