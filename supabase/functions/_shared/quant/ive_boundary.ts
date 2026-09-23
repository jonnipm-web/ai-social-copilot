/**
 * IVE Quant / LLM boundary — IV-QUANT-FOUNDATION-01 (QUANT_ARCHITECTURE.md §7).
 *
 *   DETERMINISTIC ENGINE → QuantAnalysisResult → QuantExplanationRequest → (future) IVE narrator
 *
 * The LLM may summarize, explain, compare and narrate. It is NEVER the
 * authority for a price, return, volatility, drawdown, weight or risk
 * number: it writes a TEMPLATE whose figures are `{{FACT_ID}}` placeholders;
 * renderNarrative() substitutes the engine's pre-formatted values and
 * refuses any template that contains numeric content of its own.
 *
 * This is a CONTRACT, not an integration: IVE-INTELLIGENCE-CORE-01 is being
 * built in parallel and is not imported. A future Promotion/Integration
 * Gate implements QuantNarrator on top of IVE Core.
 */
import { fail, ok, type QuantResult } from './errors.ts';
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

/**
 * A narrative is a TEMPLATE: every figure appears only as a `{{FACT_ID}}`
 * placeholder that renderNarrative() replaces with the engine's display
 * string. The template itself may not contain any number (Codex Gate 1
 * CX1-04: lexical scanning of ASCII digits in free text was bypassable with
 * number words and non-ASCII digits).
 */
export interface QuantNarrative {
  readonly template: string;
}

/** Implemented later on top of IVE Intelligence Core. */
export interface QuantNarrator {
  explain(req: QuantExplanationRequest): Promise<QuantResult<QuantNarrative>>;
}

export const NARRATIVE_RULES: readonly string[] = [
  'Write a template: every figure must be a {{FACT_ID}} placeholder from `facts`; never write a number, digit, number word or % sign yourself.',
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
  const day = (iso: string) => iso.slice(0, 10);
  facts.push(
    { id: 'PERIOD_START', label: 'PERIOD_START', display: day(result.period.start), rawValue: null, source: 'DETERMINISTIC_ENGINE' },
    { id: 'PERIOD_END', label: 'PERIOD_END', display: day(result.period.end), rawValue: null, source: 'DETERMINISTIC_ENGINE' },
    { id: 'PERIOD_BARS', label: 'PERIOD_BARS', display: String(result.period.bars), rawValue: result.period.bars, source: 'DETERMINISTIC_ENGINE' },
  );
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

const PLACEHOLDER_RE = /\{\{([A-Z0-9_]{1,64})\}\}/g;
/** Any Unicode decimal digit, other numeric char (½ ² ①) or letter-number (Ⅳ). */
const NUMERIC_CHAR_RE = /[\p{Nd}\p{No}\p{Nl}]+/gu;
const PERCENT_RE = /[%\u2030\u2031\u066A\uFE6A\uFF05]/gu;
/**
 * Unambiguous number words (EN + PT). Deliberately excluded because they are
 * also articles/pronouns: "one", "um", "uma" — documented residual risk.
 */
const NUMBER_WORDS = [
  'zero', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen',
  'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty', 'thirty', 'forty', 'fifty', 'sixty',
  'seventy', 'eighty', 'ninety', 'hundreds?', 'thousands?', 'millions?', 'billions?', 'trillions?', 'percent', 'percentage',
  'dozens?', 'half', 'double[sd]?', 'triple[sd]?', 'twice', 'thrice',
  'dois', 'duas', 'tr[eê]s', 'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove', 'dez', 'onze', 'doze', 'treze',
  'quatorze', 'catorze', 'quinze', 'dezesseis', 'dezessete', 'dezoito', 'dezenove', 'vinte', 'trinta', 'quarenta',
  'cinquenta', 'sessenta', 'setenta', 'oitenta', 'noventa', 'cem', 'cento', 'duzent[oa]s', 'trezent[oa]s',
  'quatrocent[oa]s', 'quinhent[oa]s', 'seiscent[oa]s', 'setecent[oa]s', 'oitocent[oa]s', 'novecent[oa]s', 'mil',
  'milh[aã]o', 'milh[oõ]es', 'bilh[aã]o', 'bilh[oõ]es', 'trilh[aã]o', 'trilh[oõ]es', 'porcento', 'metade', 'dobro',
  'dobrou', 'triplo', 'triplicou', 'dezenas?', 'd[uú]zias?',
];
const NUMBER_WORD_RE = new RegExp(`(?<![\\p{L}])(?:${NUMBER_WORDS.join('|')})(?![\\p{L}])`, 'giu');

export interface GroundingReport {
  readonly grounded: boolean;
  /** Numeric content written outside placeholders (digits, numeric chars, %, number words). */
  readonly ungroundedNumbers: string[];
  /** Placeholders that name no fact. */
  readonly unknownFactIds: string[];
  readonly citedFactIds: string[];
}

/**
 * Fail-closed grounding check. A template is grounded iff, after removing
 * `{{FACT_ID}}` placeholders, it contains no numeric content at all, and
 * every placeholder names a fact of this request. What it cannot catch: a
 * narrator citing a REAL fact under a wrong description (e.g. calling
 * volatility a return) and the excluded words "one/um/uma" — residual risks
 * recorded in QUANT_SECURITY_MODEL.md.
 */
export function checkNarrativeGrounding(narrative: QuantNarrative, req: QuantExplanationRequest): GroundingReport {
  const raw = typeof narrative?.template === 'string' ? narrative.template : '';
  // NFKC folds fullwidth digits to ASCII (caught below) but also folds
  // letter-numbers such as U+2163 to plain letters, so numeric characters are
  // scanned in BOTH the raw and the normalized text.
  const template = raw.normalize('NFKC');
  const ids = new Set(req.facts.map((f) => f.id));
  const cited: string[] = [];
  const unknownFactIds: string[] = [];
  for (const m of template.matchAll(PLACEHOLDER_RE)) {
    (ids.has(m[1]) ? cited : unknownFactIds).push(m[1]);
  }
  const rest = template.replace(PLACEHOLDER_RE, ' ');
  // Anything that still looks like a placeholder is malformed (wrong case, bad chars): fail closed.
  for (const m of rest.matchAll(/\{\{[^{}]{0,64}\}\}|\{\{|\}\}/g)) unknownFactIds.push(m[0]);
  const restRaw = raw.replace(PLACEHOLDER_RE, ' ');
  const ungroundedNumbers = [
    ...new Set([...restRaw.matchAll(NUMERIC_CHAR_RE), ...rest.matchAll(NUMERIC_CHAR_RE)].map((m) => m[0])),
    ...[...rest.matchAll(PERCENT_RE)].map((m) => m[0]),
    ...[...rest.matchAll(NUMBER_WORD_RE)].map((m) => m[0]),
  ];
  return {
    grounded: template.trim().length > 0 && ungroundedNumbers.length === 0 && unknownFactIds.length === 0,
    ungroundedNumbers,
    unknownFactIds,
    citedFactIds: [...new Set(cited)],
  };
}

/** Renders a grounded template by substituting engine display strings; refuses ungrounded ones. */
export function renderNarrative(narrative: QuantNarrative, req: QuantExplanationRequest): QuantResult<string> {
  const report = checkNarrativeGrounding(narrative, req);
  if (!report.grounded) {
    return fail('CALCULATION_ERROR', 'narrative is not grounded in engine facts', {
      reason: 'UNGROUNDED_NARRATIVE',
      ungrounded: report.ungroundedNumbers.length,
      unknownFacts: report.unknownFactIds.length,
    });
  }
  const byId = new Map(req.facts.map((f) => [f.id, f.display]));
  return ok(narrative.template.normalize('NFKC').replace(PLACEHOLDER_RE, (_, id: string) => byId.get(id) as string));
}
