/**
 * IVE Quant / LLM boundary — IV-QUANT-FOUNDATION-01 (QUANT_ARCHITECTURE.md §7).
 *
 *   DETERMINISTIC ENGINE → QuantAnalysisResult → QuantExplanationRequest → (future) IVE narrator
 *
 * The LLM may summarize, explain, compare and narrate. It is NEVER the
 * authority for a price, return, volatility, drawdown, weight or risk
 * number: every figure it may mention is handed to it here, pre-computed
 * and pre-formatted, and checkNarrativeGrounding() rejects a narrative that
 * introduces a number not present in the facts.
 *
 * This is a CONTRACT, not an integration: IVE-INTELLIGENCE-CORE-01 is being
 * built in parallel and is not imported. A future Promotion/Integration
 * Gate implements QuantNarrator on top of IVE Core.
 */
import type { QuantResult } from './errors.ts';
import type { QuantAnalysisResult } from './analysis.ts';
import { FORMULAS } from './analysis.ts';
import { formatNumber, formatPrice, formatRatioAsPercent } from './display.ts';

export const EXPLANATION_CONTRACT = 'quant.explanation.v1' as const;

export interface QuantFact {
  readonly id: string;
  readonly label: string;
  /** Pre-formatted display string. The narrator must quote this, not recompute. */
  readonly display: string;
  readonly rawValue: number | null;
  readonly source: 'DETERMINISTIC_ENGINE';
  readonly formula?: string;
}

export interface QuantExplanationRequest {
  readonly contract: typeof EXPLANATION_CONTRACT;
  readonly analysisId: string;
  readonly facts: readonly QuantFact[];
  readonly period: { readonly start: string; readonly end: string; readonly bars: number };
  readonly freshnessState: string;
  readonly evidenceStrength: string;
  readonly assumptionCodes: readonly string[];
  readonly warningCodes: readonly string[];
  readonly limitations: readonly string[];
  readonly rules: readonly string[];
}

export interface QuantNarrative {
  readonly text: string;
  readonly citedFactIds: readonly string[];
}

/** Implemented later on top of IVE Intelligence Core. */
export interface QuantNarrator {
  explain(req: QuantExplanationRequest): Promise<QuantResult<QuantNarrative>>;
}

export const NARRATIVE_RULES: readonly string[] = [
  'Use only the numbers in `facts`, quoted exactly as their `display` string.',
  'Never compute, estimate, extrapolate or round a financial figure yourself.',
  'State the analysis period and the data freshness; never describe historical data as current.',
  'Signals are descriptive observations, not recommendations. Do not recommend buying, selling or holding.',
  'Mention every warning code that affects interpretation (stale data, weak provenance, unadjusted prices).',
  'Separate facts (from `facts`) from interpretation, and label interpretation as such.',
];

export function buildExplanationRequest(result: QuantAnalysisResult): QuantExplanationRequest {
  const currency = result.instruments[0]?.currency ?? '';
  // Ids are unique: analyzeSeries rejects duplicate SMA windows, and SMA_LAST
  // is the only metric that can repeat (once per window).
  const facts: QuantFact[] = result.metrics.map((m) => {
    const suffix = m.parameters?.window !== undefined ? `_${m.parameters.window}` : '';
    const display = m.value === null ? 'n/a' : m.unit === 'PRICE' ? formatPrice(m.value, currency) : m.id === 'SHARPE_RATIO' ? formatNumber(m.value, 2) : formatRatioAsPercent(m.value);
    return {
      id: `${m.id}${suffix}`,
      label: m.id,
      display,
      rawValue: m.value,
      source: 'DETERMINISTIC_ENGINE',
      formula: FORMULAS[m.formulaId],
    };
  });
  const limitations = ['Risk coverage is FOUNDATION_PARTIAL: no VaR, CVaR, beta or factor exposure.'];
  if (result.dataSnapshot.evidenceStrength === 'WEAK') limitations.push('Evidence strength is WEAK (user-supplied, synthetic or incompletely sourced data).');
  return {
    contract: EXPLANATION_CONTRACT,
    analysisId: result.analysisId,
    facts,
    period: { start: result.period.start, end: result.period.end, bars: result.period.bars },
    freshnessState: result.dataSnapshot.freshness.state,
    evidenceStrength: result.dataSnapshot.evidenceStrength,
    assumptionCodes: result.assumptions.map((a) => a.code),
    warningCodes: result.warnings.map((w) => w.code),
    limitations,
    rules: NARRATIVE_RULES,
  };
}

const NUMBER_TOKEN_RE = /[-+]?\d+(?:[.,]\d+)*%?/g;

function normalizeToken(tok: string): string {
  return tok.replace(/^\+/, '').replace(/%$/, '');
}

/**
 * Anti-hallucination guard for narratives: every numeric token in the text
 * must appear in a fact's display string, the period/bar count, or a
 * metric parameter. Returns the ungrounded tokens (empty = grounded) and
 * rejects citations of unknown fact ids. Conservative by design: a
 * narrative that paraphrases a number ("about 12%") is rejected.
 */
export function checkNarrativeGrounding(
  narrative: QuantNarrative,
  req: QuantExplanationRequest,
): { grounded: boolean; ungroundedNumbers: string[]; unknownFactIds: string[] } {
  const allowed = new Set<string>();
  const add = (s: string) => {
    for (const m of s.matchAll(NUMBER_TOKEN_RE)) allowed.add(normalizeToken(m[0]));
  };
  for (const f of req.facts) {
    add(f.display);
    add(f.id);
  }
  add(req.period.start);
  add(req.period.end);
  add(String(req.period.bars));
  const ungroundedNumbers: string[] = [];
  for (const m of narrative.text.matchAll(NUMBER_TOKEN_RE)) {
    if (!allowed.has(normalizeToken(m[0]))) ungroundedNumbers.push(m[0]);
  }
  const ids = new Set(req.facts.map((f) => f.id));
  const unknownFactIds = narrative.citedFactIds.filter((id) => !ids.has(id));
  return { grounded: ungroundedNumbers.length === 0 && unknownFactIds.length === 0, ungroundedNumbers, unknownFactIds };
}
