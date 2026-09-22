/**
 * Risk foundation — IV-QUANT-FOUNDATION-01 (QUANT_RISK_MODEL.md).
 *
 * This is a FOUNDATION, not a complete risk system: volatility, drawdown,
 * concentration and correlation only. VaR, CVaR, beta and factor exposure
 * are declared as NOT_IMPLEMENTED in every overview so no consumer (UI or
 * IVE narrative) can present the overview as "risk complete".
 */
import { fail, ok, type QuantResult } from './errors.ts';
import { fsum } from './numeric.ts';
import { maxDrawdown, type MaxDrawdownValue, pearsonCorrelation, simpleReturns, volatility, type VolatilityValue } from './metrics.ts';
import { alignOnTimestamps, type PriceBasis, type PriceSeries, pricesOf } from './timeseries.ts';
import { instrumentKey } from './instrument.ts';

export const RISK_COVERAGE = 'FOUNDATION_PARTIAL' as const;
export const RISK_NOT_IMPLEMENTED = ['VAR', 'CVAR', 'BETA', 'FACTOR_EXPOSURE', 'LIQUIDITY', 'TAIL_DEPENDENCE'] as const;

export interface SeriesRiskOverview {
  readonly coverage: typeof RISK_COVERAGE;
  readonly notImplemented: readonly string[];
  readonly volatility: VolatilityValue;
  readonly drawdown: MaxDrawdownValue;
}

export function seriesRiskOverview(prices: readonly number[], periodsPerYear: number | null): QuantResult<SeriesRiskOverview> {
  const r = simpleReturns(prices);
  if (!r.ok) return r;
  const vol = volatility(r.value, { periodsPerYear });
  if (!vol.ok) return vol;
  const dd = maxDrawdown(prices);
  if (!dd.ok) return dd;
  return ok({ coverage: RISK_COVERAGE, notImplemented: RISK_NOT_IMPLEMENTED, volatility: vol.value, drawdown: dd.value });
}

export interface WeightEntry {
  readonly key: string;
  readonly weight: number;
}

/** Absolute tolerance for Σw = 1. Weights derived from market values carry
 * ~n·ε rounding; 1e-9 accepts that and still rejects any real mis-weighting
 * (a 0.0001% error is 1e-6). */
export const WEIGHT_SUM_TOLERANCE = 1e-9;

export function validateWeights(weights: readonly WeightEntry[]): QuantResult<readonly WeightEntry[]> {
  if (!Array.isArray(weights) || weights.length === 0) return fail('INVALID_PORTFOLIO', 'weights required');
  const seen = new Set<string>();
  for (const w of weights) {
    if (typeof w.key !== 'string' || w.key.length === 0) return fail('INVALID_PORTFOLIO', 'weight key required');
    if (seen.has(w.key)) return fail('INVALID_PORTFOLIO', 'duplicate weight key');
    seen.add(w.key);
    if (!Number.isFinite(w.weight) || w.weight < 0) {
      return fail('INVALID_PORTFOLIO', 'weights must be finite and >= 0 (short positions are not supported by the Foundation)');
    }
  }
  const sum = fsum(weights.map((w) => w.weight));
  if (Math.abs(sum - 1) > WEIGHT_SUM_TOLERANCE) return fail('INVALID_PORTFOLIO', 'weights must sum to 1', { sum });
  return ok(weights);
}

export interface Concentration {
  /** Herfindahl–Hirschman index Σw², in [1/n, 1]. */
  readonly hhi: number;
  /** 1 / HHI — the number of equally weighted holdings with the same concentration. */
  readonly effectiveHoldings: number;
  readonly maxWeight: number;
  readonly maxWeightKey: string;
  readonly holdings: number;
}

export function concentration(weights: readonly WeightEntry[]): QuantResult<Concentration> {
  const v = validateWeights(weights);
  if (!v.ok) return v;
  const hhi = fsum(weights.map((w) => w.weight * w.weight));
  let max = weights[0];
  for (const w of weights) if (w.weight > max.weight) max = w;
  return ok({ hhi, effectiveHoldings: 1 / hhi, maxWeight: max.weight, maxWeightKey: max.key, holdings: weights.length });
}

export interface CorrelationEntry {
  readonly a: string;
  readonly b: string;
  /** null when undefined for this pair (see `error`). */
  readonly correlation: number | null;
  readonly observations: number;
  readonly error?: string;
}

/** Pairwise Pearson correlation of simple returns on timestamp-aligned
 * bars (inner join per pair — no fill). Undefined pairs are reported with
 * their error code, never as 0. */
export function returnCorrelationMatrix(series: readonly PriceSeries[], basis: PriceBasis): QuantResult<CorrelationEntry[]> {
  if (series.length < 2) return fail('INSUFFICIENT_DATA', 'correlation needs at least two series');
  const out: CorrelationEntry[] = [];
  for (let i = 0; i < series.length; i++) {
    for (let j = i + 1; j < series.length; j++) {
      const a = series[i], b = series[j];
      const pa = pricesOf(a, basis), pb = pricesOf(b, basis);
      if (!pa.ok) return pa;
      if (!pb.ok) return pb;
      const al = alignOnTimestamps(a.bars, b.bars);
      const ka = instrumentKey(a.instrument), kb = instrumentKey(b.instrument);
      const ra = simpleReturns(al.ai.map((k) => pa.value[k]));
      const rb = simpleReturns(al.bi.map((k) => pb.value[k]));
      if (!ra.ok || !rb.ok) {
        out.push({ a: ka, b: kb, correlation: null, observations: Math.max(0, al.t.length - 1), error: 'INSUFFICIENT_DATA' });
        continue;
      }
      const c = pearsonCorrelation(ra.value, rb.value);
      out.push(c.ok
        ? { a: ka, b: kb, correlation: c.value, observations: ra.value.length }
        : { a: ka, b: kb, correlation: null, observations: ra.value.length, error: c.error.code });
    }
  }
  return ok(out);
}
