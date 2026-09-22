/**
 * QuantAnalysisResult — IV-QUANT-FOUNDATION-01 (QUANT_ARCHITECTURE.md §6).
 *
 * The single structured output of the deterministic engine. Everything a
 * reader (UI, IVE narrative, audit) needs to answer: WHICH data, FROM WHERE,
 * FROM WHEN, HOW normalized, WHICH formula, WHICH assumption, WHICH result,
 * and what is fact vs. caveat.
 *
 * Reproducibility: `analysisId` is derived from engine version + dataset
 * content hash + instrument + options, so the same data and options always
 * yield the same id and the same numbers. Only `generatedAt` (injected
 * clock) and freshness (age relative to that clock) vary.
 */
import { fail, ok, type QuantResult, type QuantWarning } from './errors.ts';
import { mean } from './numeric.ts';
import { type InstrumentIdentity, instrumentKey } from './instrument.ts';
import { cumulativeReturn, logReturns, sharpeRatio, type SharpeAssumptions, simpleMovingAverage, simpleReturns } from './metrics.ts';
import {
  assessFreshness,
  type DataProvenance,
  DEFAULT_FRESHNESS_POLICIES,
  type EvidenceStrength,
  evidenceStrength,
  type FreshnessAssessment,
  type FreshnessState,
  type Frequency,
} from './provenance.ts';
import { seriesRiskOverview, type SeriesRiskOverview } from './risk.ts';
import { movingAverageCrossovers, type Signal } from './signals.ts';
import { defaultPriceBasis, type PriceBasis, type PriceSeries, pricesOf } from './timeseries.ts';

export const QUANT_ENGINE_VERSION = 'quant-foundation-0.1.0';
export const ANALYSIS_SCHEMA_VERSION = 1;

export type FormulaId =
  | 'SIMPLE_RETURN_V1'
  | 'LOG_RETURN_V1'
  | 'CUMULATIVE_RETURN_V1'
  | 'VOLATILITY_SAMPLE_V1'
  | 'MAX_DRAWDOWN_V1'
  | 'SMA_V1'
  | 'PEARSON_V1'
  | 'SHARPE_V1'
  | 'HHI_V1'
  | 'BUY_AND_HOLD_RETURN_V1';

/** Human-readable formula catalog (explainability). Mirrors QUANT_CALCULATION_SPEC.md. */
export const FORMULAS: Readonly<Record<FormulaId, string>> = {
  SIMPLE_RETURN_V1: 'r_t = P_t / P_{t-1} - 1',
  LOG_RETURN_V1: 'l_t = ln(P_t / P_{t-1})',
  CUMULATIVE_RETURN_V1: 'R = P_last / P_first - 1',
  VOLATILITY_SAMPLE_V1: 'sigma = sqrt(sum((r - mean(r))^2) / (n - 1)); annualized = sigma * sqrt(periodsPerYear)',
  MAX_DRAWDOWN_V1: 'MDD = min_t (P_t / max_{s<=t} P_s - 1)  (<= 0)',
  SMA_V1: 'SMA_t = (1/k) * sum_{i=t-k+1..t} P_i',
  PEARSON_V1: 'rho = sum((x-mx)(y-my)) / sqrt(sum((x-mx)^2) * sum((y-my)^2))',
  SHARPE_V1: 'S = mean(r - rf) / stdev(r - rf) * sqrt(periodsPerYear)',
  HHI_V1: 'HHI = sum(w_i^2); effective holdings = 1 / HHI',
  BUY_AND_HOLD_RETURN_V1: 'R = sum_i w_i * (P_i(end) / P_i(start) - 1)',
};

export type MetricId =
  | 'CUMULATIVE_RETURN'
  | 'MEAN_SIMPLE_RETURN'
  | 'LAST_LOG_RETURN'
  | 'VOLATILITY_PER_PERIOD'
  | 'VOLATILITY_ANNUALIZED'
  | 'MAX_DRAWDOWN'
  | 'SMA_LAST'
  | 'SHARPE_RATIO';

export interface MetricEntry {
  readonly id: MetricId;
  /** Unrounded float64. null only if the metric was requested but undefined (see warnings). */
  readonly value: number | null;
  readonly unit: 'RATIO' | 'PRICE';
  readonly formulaId: FormulaId;
  readonly observations: number;
  readonly parameters?: Readonly<Record<string, number>>;
}

export interface Assumption {
  readonly code: 'PRICE_BASIS' | 'ANNUALIZATION' | 'NO_INTERPOLATION' | 'CALENDAR_NAIVE' | 'SQRT_TIME_SCALING' | 'RISK_FREE_RATE' | 'FRESHNESS_REFERENCE';
  readonly value: string | number | null;
}

export interface AnalysisSubject {
  readonly kind: 'INSTRUMENT_SERIES';
  readonly instrumentKey: string;
  /** Optional scope label. The ENGINE does not authorize it: a server caller
   * must verify project ownership (RLS / ownership check) before attaching it. */
  readonly projectId?: string;
}

export interface QuantAnalysisResult {
  readonly schemaVersion: typeof ANALYSIS_SCHEMA_VERSION;
  readonly analysisId: string;
  readonly engineVersion: string;
  readonly computedBy: 'DETERMINISTIC_ENGINE';
  readonly subject: AnalysisSubject;
  readonly instruments: readonly InstrumentIdentity[];
  readonly period: { readonly start: string; readonly end: string; readonly bars: number; readonly frequency: Frequency };
  readonly dataSnapshot: {
    readonly provenance: DataProvenance;
    readonly contentHash: string;
    readonly freshness: FreshnessAssessment;
    readonly evidenceStrength: EvidenceStrength;
  };
  readonly metrics: readonly MetricEntry[];
  readonly signals: readonly Signal[];
  readonly risk: SeriesRiskOverview | null;
  readonly assumptions: readonly Assumption[];
  readonly warnings: readonly QuantWarning[];
  readonly generatedAt: string;
}

export interface SeriesAnalysisOptions {
  readonly priceBasis?: PriceBasis;
  /** Explicit: e.g. 252 for daily equity trading days, or null to skip annualization. */
  readonly periodsPerYear: number | null;
  readonly smaWindows?: readonly number[];
  readonly crossover?: { readonly fast: number; readonly slow: number };
  readonly sharpe?: SharpeAssumptions;
  /** If set, data whose freshness is not in this list is refused with STALE_DATA. */
  readonly acceptedFreshness?: readonly FreshnessState[];
  readonly projectId?: string;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const MAX_SMA_WINDOWS = 8;

async function sha256Hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d), (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Canonical serialization of the analyzed bars (fixed key order, already sorted). */
export function canonicalBarsJson(series: PriceSeries): string {
  return JSON.stringify(series.bars.map((b) => [b.t, b.open, b.high, b.low, b.close, b.volume ?? null, b.adjustedClose ?? null]));
}

export async function analyzeSeries(
  series: PriceSeries,
  options: SeriesAnalysisOptions,
  clock: () => number,
): Promise<QuantResult<QuantAnalysisResult>> {
  if (!options || !('periodsPerYear' in options)) {
    return fail('INVALID_PARAMETER', 'periodsPerYear must be stated explicitly (number or null)');
  }
  if (options.projectId !== undefined && !UUID_RE.test(options.projectId)) {
    return fail('INVALID_PARAMETER', 'projectId must be a UUID');
  }
  const smaWindows = options.smaWindows ?? [];
  if (smaWindows.length > MAX_SMA_WINDOWS) return fail('INVALID_PARAMETER', 'too many SMA windows', { max: MAX_SMA_WINDOWS });
  if (new Set(smaWindows).size !== smaWindows.length) return fail('INVALID_PARAMETER', 'duplicate SMA window');
  if (series.bars.length < 2) return fail('INSUFFICIENT_DATA', 'analysis needs at least two bars', { bars: series.bars.length });

  const nowMs = clock();
  const lastT = series.bars[series.bars.length - 1].t;
  const freshness = assessFreshness(lastT, nowMs, DEFAULT_FRESHNESS_POLICIES[series.frequency]);
  if (options.acceptedFreshness && !options.acceptedFreshness.includes(freshness.state)) {
    return fail('STALE_DATA', 'data freshness not accepted for this analysis', { state: freshness.state });
  }

  const basis = options.priceBasis ?? defaultPriceBasis(series);
  const pricesR = pricesOf(series, basis);
  if (!pricesR.ok) return pricesR;
  const prices = pricesR.value;

  const warnings: QuantWarning[] = [...series.normalizationWarnings];
  warnings.push({ code: 'CALENDAR_NAIVE', message: 'no exchange calendar applied; gaps are reported, not filled' });
  if (freshness.state === 'DELAYED') warnings.push({ code: 'DATA_DELAYED', message: 'newest bar is older than the fresh threshold' });
  if (freshness.state === 'STALE') warnings.push({ code: 'DATA_STALE', message: 'newest bar is stale; results describe the past period only' });
  if (freshness.state === 'UNKNOWN') warnings.push({ code: 'FRESHNESS_UNKNOWN', message: 'data age could not be established' });
  const strength = evidenceStrength(series.provenance);
  if (strength === 'WEAK') warnings.push({ code: 'PROVENANCE_WEAK', message: 'provenance does not support strong evidence' });
  if (series.provenance.adjustment === 'UNKNOWN' || (basis === 'close' && series.provenance.adjustment === 'UNADJUSTED')) {
    warnings.push({ code: 'ADJUSTMENT_UNKNOWN', message: 'prices may not reflect splits/dividends; returns across corporate actions can be wrong' });
  }

  const metrics: MetricEntry[] = [];
  const cum = cumulativeReturn(prices);
  if (!cum.ok) return cum;
  metrics.push({ id: 'CUMULATIVE_RETURN', value: cum.value, unit: 'RATIO', formulaId: 'CUMULATIVE_RETURN_V1', observations: prices.length });

  const rets = simpleReturns(prices);
  if (!rets.ok) return rets;
  const meanRet = mean(rets.value);
  metrics.push({ id: 'MEAN_SIMPLE_RETURN', value: meanRet, unit: 'RATIO', formulaId: 'SIMPLE_RETURN_V1', observations: rets.value.length });
  const logs = logReturns(prices);
  if (!logs.ok) return logs;
  metrics.push({ id: 'LAST_LOG_RETURN', value: logs.value[logs.value.length - 1], unit: 'RATIO', formulaId: 'LOG_RETURN_V1', observations: 1 });

  let risk: SeriesRiskOverview | null = null;
  if (rets.value.length >= 2) {
    const ro = seriesRiskOverview(prices, options.periodsPerYear);
    if (!ro.ok) return ro;
    risk = ro.value;
    metrics.push({ id: 'VOLATILITY_PER_PERIOD', value: risk.volatility.perPeriod, unit: 'RATIO', formulaId: 'VOLATILITY_SAMPLE_V1', observations: risk.volatility.observations });
    if (risk.volatility.annualized !== null) {
      metrics.push({
        id: 'VOLATILITY_ANNUALIZED', value: risk.volatility.annualized, unit: 'RATIO', formulaId: 'VOLATILITY_SAMPLE_V1',
        observations: risk.volatility.observations, parameters: { periodsPerYear: options.periodsPerYear as number },
      });
    }
    metrics.push({ id: 'MAX_DRAWDOWN', value: risk.drawdown.maxDrawdown, unit: 'RATIO', formulaId: 'MAX_DRAWDOWN_V1', observations: prices.length });
  } else {
    warnings.push({ code: 'INSUFFICIENT_DATA_FOR_METRIC', message: 'volatility/drawdown need at least three prices', details: { metric: 'VOLATILITY' } });
  }

  for (const w of smaWindows) {
    const sma = simpleMovingAverage(prices, w);
    if (!sma.ok) {
      if (sma.error.code === 'INSUFFICIENT_DATA') {
        warnings.push({ code: 'INSUFFICIENT_DATA_FOR_METRIC', message: 'SMA window longer than the series', details: { metric: 'SMA', window: w } });
        continue;
      }
      return sma;
    }
    metrics.push({ id: 'SMA_LAST', value: sma.value[sma.value.length - 1], unit: 'PRICE', formulaId: 'SMA_V1', observations: w, parameters: { window: w } });
  }

  if (options.sharpe) {
    const s = sharpeRatio(rets.value, options.sharpe);
    if (s.ok) {
      metrics.push({
        id: 'SHARPE_RATIO', value: s.value, unit: 'RATIO', formulaId: 'SHARPE_V1', observations: rets.value.length,
        parameters: { riskFreeRatePerPeriod: options.sharpe.riskFreeRatePerPeriod, periodsPerYear: options.sharpe.periodsPerYear },
      });
    } else if (s.error.code === 'CALCULATION_ERROR' || s.error.code === 'INSUFFICIENT_DATA') {
      warnings.push({ code: s.error.code === 'CALCULATION_ERROR' ? 'ZERO_VARIANCE' : 'INSUFFICIENT_DATA_FOR_METRIC', message: 'Sharpe ratio undefined', details: { metric: 'SHARPE' } });
    } else return s;
  }

  let signals: Signal[] = [];
  if (options.crossover) {
    const sig = movingAverageCrossovers(prices, series.bars.map((b) => b.t), options.crossover.fast, options.crossover.slow);
    if (sig.ok) signals = sig.value;
    else if (sig.error.code === 'INSUFFICIENT_DATA') {
      warnings.push({ code: 'INSUFFICIENT_DATA_FOR_METRIC', message: 'crossover windows longer than the series', details: { metric: 'MA_CROSSOVER' } });
    } else return sig;
  }

  const assumptions: Assumption[] = [
    { code: 'PRICE_BASIS', value: basis },
    { code: 'ANNUALIZATION', value: options.periodsPerYear },
    { code: 'NO_INTERPOLATION', value: null },
    { code: 'CALENDAR_NAIVE', value: null },
    { code: 'FRESHNESS_REFERENCE', value: 'newest bar timestamp' },
  ];
  if (options.periodsPerYear !== null) assumptions.push({ code: 'SQRT_TIME_SCALING', value: null });
  if (options.sharpe) assumptions.push({ code: 'RISK_FREE_RATE', value: options.sharpe.riskFreeRatePerPeriod });

  const key = instrumentKey(series.instrument);
  const contentHash = await sha256Hex(canonicalBarsJson(series));
  const idOptions = JSON.stringify({ basis, p: options.periodsPerYear, sma: smaWindows, x: options.crossover ?? null, s: options.sharpe ?? null, proj: options.projectId ?? null });
  const analysisId = `qa_${(await sha256Hex(`${QUANT_ENGINE_VERSION}|${key}|${contentHash}|${idOptions}`)).slice(0, 32)}`;

  return ok({
    schemaVersion: ANALYSIS_SCHEMA_VERSION,
    analysisId,
    engineVersion: QUANT_ENGINE_VERSION,
    computedBy: 'DETERMINISTIC_ENGINE',
    subject: { kind: 'INSTRUMENT_SERIES', instrumentKey: key, ...(options.projectId ? { projectId: options.projectId } : {}) },
    instruments: [series.instrument],
    period: {
      start: new Date(series.bars[0].t).toISOString(),
      end: new Date(lastT).toISOString(),
      bars: series.bars.length,
      frequency: series.frequency,
    },
    dataSnapshot: { provenance: series.provenance, contentHash, freshness, evidenceStrength: strength },
    metrics,
    signals,
    risk,
    assumptions,
    warnings,
    generatedAt: new Date(nowMs).toISOString(),
  });
}
