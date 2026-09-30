/**
 * Multi-series analytics — IV-QUANT-REAL-DATA-READINESS-03 (docs/quant/QUANT_MULTI_SERIES.md).
 *
 * Deterministic analysis of several instruments at once, reusing the
 * Foundation engine (analyzeSeries, pearsonCorrelation, buyAndHoldReturn,
 * concentration). Explicit policies:
 *  - ALIGNMENT: intersection of bar timestamps across ALL series
 *    (INTERSECTION_OF_TIMESTAMPS). Nothing is filled or interpolated; bars
 *    outside the intersection are counted per series (missing-data report).
 *    The correlation matrix and relative returns use this single window, so
 *    every pair is measured over the same sessions.
 *  - CURRENCY: returns and correlation are dimensionless ratios measured in
 *    each instrument's OWN currency; mixed currencies raise
 *    MIXED_CURRENCY_RETURNS (no FX conversion exists). A portfolio across
 *    currencies is refused (CURRENCY_MISMATCH).
 *  - CALENDARS: different exchange calendars are allowed; the intersection
 *    keeps only sessions present on both, and CALENDARS_DIFFER is raised.
 *  - PORTFOLIO (manual weights, no broker): weights must cover exactly the
 *    analyzed series, each 0 < w ≤ 1 (no shorts, zero weights must be
 *    omitted), sum to 1 ± 1e-9, no duplicates, single currency.
 * No recommendation is produced: signals stay descriptive and are not part
 * of the multi-series output.
 */
import { analyzeSeries, QUANT_ENGINE_VERSION, type QuantAnalysisResult } from './analysis.ts';
import { fail, ok, type QuantResult, type QuantWarning } from './errors.ts';
import { instrumentKey, type InstrumentIdentity } from './instrument.ts';
import { pearsonCorrelation, simpleReturns } from './metrics.ts';
import { buyAndHoldReturn } from './portfolio.ts';
import { concentration, type Concentration, WEIGHT_SUM_TOLERANCE } from './risk.ts';
import { type PriceBasis, type PriceSeries, pricesOf } from './timeseries.ts';
import { fsum } from './numeric.ts';

/** Measured bound (QUANT_CURRENT_STATE §9): 10 × 5 000-bar series analyze in well under 1 s. */
export const MAX_SERIES_PER_ANALYSIS = 10;
/** 4 aligned prices → 3 aligned returns: the minimum for a meaningful correlation. */
export const MIN_ALIGNED_BARS = 4;

export interface MultiSeriesOptions {
  readonly periodsPerYear: number | null;
  readonly priceBasis?: PriceBasis;
  /** Manual portfolio weights keyed by canonical instrument key. */
  readonly weights?: ReadonlyArray<{ readonly instrumentKey: string; readonly weight: number }>;
  readonly projectId?: string;
}

export interface SeriesSummary {
  readonly instrumentKey: string;
  readonly instrument: InstrumentIdentity;
  readonly analysis: QuantAnalysisResult;
  /** Bars of this series outside the common intersection (never filled). */
  readonly droppedFromAlignment: number;
  /** Price return over the ALIGNED window, in the instrument's own currency. */
  readonly alignedCumulativeReturn: number;
}

export interface CorrelationCell {
  readonly a: string;
  readonly b: string;
  readonly correlation: number | null;
  readonly observations: number;
  readonly error?: string;
}

export interface PortfolioSection {
  readonly currency: string;
  readonly weights: ReadonlyArray<{ readonly instrumentKey: string; readonly weight: number }>;
  /** Σ wᵢ (Pᵢ(end)/Pᵢ(start) − 1) over the aligned window, initial weights, no rebalancing. */
  readonly buyAndHoldReturn: number;
  readonly concentration: Concentration;
}

export interface MultiSeriesResult {
  readonly schemaVersion: 1;
  readonly multiAnalysisId: string;
  readonly engineVersion: string;
  readonly computedBy: 'DETERMINISTIC_ENGINE';
  readonly series: readonly SeriesSummary[];
  readonly alignment: {
    readonly policy: 'INTERSECTION_OF_TIMESTAMPS';
    readonly start: string | null;
    readonly end: string | null;
    readonly commonBars: number;
    readonly seriesCount: number;
  };
  readonly correlation: readonly CorrelationCell[];
  readonly portfolio: PortfolioSection | null;
  readonly assumptions: ReadonlyArray<{ readonly code: string; readonly value: string | number | null }>;
  readonly warnings: readonly QuantWarning[];
  readonly generatedAt: string;
}

async function sha256Hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d), (b) => b.toString(16).padStart(2, '0')).join('');
}

export async function analyzeMultiSeries(
  seriesList: readonly PriceSeries[],
  options: MultiSeriesOptions,
  clock: () => number,
): Promise<QuantResult<MultiSeriesResult>> {
  if (!Array.isArray(seriesList) || seriesList.length < 1) return fail('INSUFFICIENT_DATA', 'at least one series is required');
  if (seriesList.length > MAX_SERIES_PER_ANALYSIS) {
    return fail('DATASET_TOO_LARGE', 'too many series in one analysis', { max: MAX_SERIES_PER_ANALYSIS });
  }
  const keys = seriesList.map((s) => instrumentKey(s.instrument));
  if (new Set(keys).size !== keys.length) return fail('INVALID_PARAMETER', 'the same instrument appears twice');
  const freq = seriesList[0].frequency;
  if (seriesList.some((s) => s.frequency !== freq)) return fail('INVALID_PARAMETER', 'all series must share one frequency');
  const basis: PriceBasis = options.priceBasis ?? 'close';

  // Per-series deterministic analysis (freshness, calendar, provenance, metrics).
  const analyses: QuantAnalysisResult[] = [];
  for (const s of seriesList) {
    const r = await analyzeSeries(s, { periodsPerYear: options.periodsPerYear, priceBasis: basis, ...(options.projectId ? { projectId: options.projectId } : {}) }, clock);
    if (!r.ok) return fail(r.error.code, r.error.message, { ...(r.error.details ?? {}), series: keys[analyses.length] });
    analyses.push(r.value);
  }

  // Intersection of timestamps across every series (no fill).
  const counts = new Map<number, number>();
  for (const s of seriesList) for (const b of s.bars) counts.set(b.t, (counts.get(b.t) ?? 0) + 1);
  const common = [...counts].filter(([, n]) => n === seriesList.length).map(([t]) => t).sort((a, b) => a - b);
  const commonSet = new Set(common);
  if (seriesList.length > 1 && common.length < MIN_ALIGNED_BARS) {
    return fail('INSUFFICIENT_OVERLAP', 'series share too few common bars', { commonBars: common.length, required: MIN_ALIGNED_BARS });
  }

  const warnings: QuantWarning[] = [];
  const aligned: number[][] = [];
  const summaries: SeriesSummary[] = [];
  for (let i = 0; i < seriesList.length; i++) {
    const s = seriesList[i];
    const px = pricesOf(s, basis);
    if (!px.ok) return px;
    const idx: number[] = [];
    s.bars.forEach((b: { t: number }, k: number) => { if (commonSet.has(b.t)) idx.push(k); });
    const alignedPrices = idx.map((k) => px.value[k]);
    aligned.push(alignedPrices);
    const dropped = s.bars.length - idx.length;
    const rel = alignedPrices.length >= 2 ? alignedPrices[alignedPrices.length - 1] / alignedPrices[0] - 1 : 0;
    if (!Number.isFinite(rel)) return fail('CALCULATION_ERROR', 'aligned return is not finite', { reason: 'NON_FINITE_RESULT' });
    summaries.push({ instrumentKey: keys[i], instrument: s.instrument, analysis: analyses[i], droppedFromAlignment: dropped, alignedCumulativeReturn: rel });
  }
  const droppedTotal = summaries.reduce((n, s) => n + s.droppedFromAlignment, 0);
  if (seriesList.length > 1 && droppedTotal > 0) {
    warnings.push({ code: 'MISSING_FROM_ALIGNMENT', message: 'bars present in some series only were excluded from cross-series metrics (never filled)', details: { bars: droppedTotal } });
  }
  const currencies = new Set(seriesList.map((s) => s.instrument.currency));
  if (currencies.size > 1) {
    warnings.push({ code: 'MIXED_CURRENCY_RETURNS', message: 'returns are measured in each instrument’s own currency; no FX conversion is applied', details: { currencies: currencies.size } });
  }
  const calendars = new Set(analyses.map((a) => a.dataSnapshot.calendar.calendar ?? 'CALENDAR_UNKNOWN'));
  if (calendars.size > 1) {
    warnings.push({ code: 'CALENDARS_DIFFER', message: 'series follow different exchange calendars; only common sessions are compared' });
  }

  // Correlation of aligned simple returns (same window for every pair).
  const correlation: CorrelationCell[] = [];
  const returns = aligned.map((p) => simpleReturns(p));
  for (let i = 0; i < seriesList.length; i++) {
    for (let j = i + 1; j < seriesList.length; j++) {
      const ri = returns[i], rj = returns[j];
      if (!ri.ok || !rj.ok) {
        correlation.push({ a: keys[i], b: keys[j], correlation: null, observations: Math.max(0, common.length - 1), error: 'INSUFFICIENT_DATA' });
        continue;
      }
      const c = pearsonCorrelation(ri.value, rj.value);
      correlation.push(c.ok
        ? { a: keys[i], b: keys[j], correlation: c.value, observations: ri.value.length }
        : { a: keys[i], b: keys[j], correlation: null, observations: ri.value.length, error: (c.error.details?.reason as string | undefined) ?? c.error.code });
    }
  }

  // Optional manual portfolio (validation policies are explicit and total).
  let portfolio: PortfolioSection | null = null;
  if (options.weights !== undefined) {
    const w = options.weights;
    if (!Array.isArray(w) || w.length !== seriesList.length) {
      return fail('INVALID_PORTFOLIO', 'weights must cover exactly the analyzed instruments');
    }
    const seen = new Set<string>();
    for (const e of w) {
      if (!keys.includes(e.instrumentKey)) return fail('INVALID_PORTFOLIO', 'weight for an instrument not in the analysis', { key: e.instrumentKey });
      if (seen.has(e.instrumentKey)) return fail('INVALID_PORTFOLIO', 'duplicate weight', { key: e.instrumentKey });
      seen.add(e.instrumentKey);
      if (!Number.isFinite(e.weight) || e.weight <= 0 || e.weight > 1) {
        return fail('INVALID_PORTFOLIO', 'each weight must satisfy 0 < w ≤ 1 (no shorts; omit zero weights)', { key: e.instrumentKey });
      }
    }
    const sum = fsum(w.map((e) => e.weight));
    if (Math.abs(sum - 1) > WEIGHT_SUM_TOLERANCE) return fail('INVALID_PORTFOLIO', 'weights must sum to 1', { sum });
    if (currencies.size > 1) return fail('CURRENCY_MISMATCH', 'a portfolio cannot combine currencies without FX conversion');
    if (common.length < 2) return fail('INSUFFICIENT_OVERLAP', 'portfolio needs at least two common bars');
    const weights = w.map((e) => ({ key: e.instrumentKey, weight: e.weight }));
    const bh = buyAndHoldReturn(weights, seriesList, basis, seriesList[0].instrument.currency);
    if (!bh.ok) return bh;
    const conc = concentration(weights);
    if (!conc.ok) return conc;
    portfolio = { currency: seriesList[0].instrument.currency, weights: w.map((e) => ({ ...e })), buyAndHoldReturn: bh.value.value, concentration: conc.value };
  }

  const nowMs = clock();
  const idInput = JSON.stringify({
    v: QUANT_ENGINE_VERSION,
    series: summaries.map((s) => [s.instrumentKey, s.analysis.dataSnapshot.contentHash]),
    p: options.periodsPerYear, basis, w: options.weights ?? null, proj: options.projectId ?? null,
  });
  return ok({
    schemaVersion: 1,
    multiAnalysisId: `qm_${(await sha256Hex(idInput)).slice(0, 32)}`,
    engineVersion: QUANT_ENGINE_VERSION,
    computedBy: 'DETERMINISTIC_ENGINE',
    series: summaries,
    alignment: {
      policy: 'INTERSECTION_OF_TIMESTAMPS',
      start: common.length ? new Date(common[0]).toISOString() : null,
      end: common.length ? new Date(common[common.length - 1]).toISOString() : null,
      commonBars: common.length,
      seriesCount: seriesList.length,
    },
    correlation,
    portfolio,
    assumptions: [
      { code: 'ALIGNMENT', value: 'INTERSECTION_OF_TIMESTAMPS' },
      { code: 'PRICE_BASIS', value: basis },
      { code: 'RETURNS_IN_OWN_CURRENCY', value: null },
      { code: 'NO_INTERPOLATION', value: null },
      ...(portfolio ? [{ code: 'BUY_AND_HOLD_INITIAL_WEIGHTS', value: null }] : []),
    ],
    warnings,
    generatedAt: new Date(nowMs).toISOString(),
  });
}
