/**
 * Deterministic calculation engine — IV-QUANT-FOUNDATION-01
 * (QUANT_CALCULATION_SPEC.md §2–§9 holds formula, assumptions and edge
 * cases for every function here).
 *
 * Pure functions over plain number arrays. No I/O, no clock, no randomness,
 * no LLM. Every function validates its own inputs and returns a
 * QuantResult — a failed calculation can never be read as a number.
 * No rounding happens here (display.ts owns display precision).
 */
import { fail, ok, type QuantResult } from './errors.ts';
import { allFinite, fsum, mean, variance } from './numeric.ts';

function requirePrices(prices: readonly number[], min: number): QuantResult<readonly number[]> {
  if (!Array.isArray(prices)) return fail('INVALID_PARAMETER', 'prices must be an array');
  if (!allFinite(prices)) return fail('INVALID_DATASET', 'prices must be finite numbers');
  if (prices.some((p) => p <= 0)) return fail('INVALID_DATASET', 'prices must be > 0');
  if (prices.length < min) return fail('INSUFFICIENT_DATA', 'not enough prices', { required: min, got: prices.length });
  return ok(prices);
}

function requireSeries(values: readonly number[], min: number, what: string): QuantResult<readonly number[]> {
  if (!Array.isArray(values)) return fail('INVALID_PARAMETER', `${what} must be an array`);
  if (!allFinite(values)) return fail('INVALID_DATASET', `${what} must be finite numbers`);
  if (values.length < min) return fail('INSUFFICIENT_DATA', `not enough ${what}`, { required: min, got: values.length });
  return ok(values);
}

/** Every successful result must be finite: finite inputs can still overflow
 * (e.g. MAX_VALUE / MIN_VALUE). Codex Gate 1 CX1-02. */
function finite<T extends number | readonly (number | null)[]>(v: T): QuantResult<T> {
  const bad = typeof v === 'number' ? !Number.isFinite(v) : v.some((x) => x !== null && !Number.isFinite(x));
  return bad ? fail('CALCULATION_ERROR', 'result is not a finite number', { reason: 'NON_FINITE_RESULT' }) : ok(v);
}

/**
 * True when the dispersion of `values` is below float64 resolution relative
 * to their magnitude, i.e. the series is constant up to rounding noise.
 * Returns of a constant-growth series (100, 110, 121, 133.1) differ only in
 * the last ulp; treating that noise as variance produced a Sharpe of ~1e16
 * and an arbitrary correlation (Claude finding CL-03). Threshold: RMS
 * deviation ≤ 64 ulp of the largest |value|.
 */
export function isNumericallyConstant(values: readonly number[], sumSqDev: number): boolean {
  const maxAbs = values.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
  return Math.sqrt(sumSqDev / values.length) <= 64 * Number.EPSILON * maxAbs;
}

function requireWindow(window: number, max: number): QuantResult<number> {
  if (!Number.isSafeInteger(window) || window < 1) return fail('INVALID_PARAMETER', 'window must be a positive integer');
  if (window > max) return fail('INSUFFICIENT_DATA', 'window longer than the series', { window, length: max });
  return ok(window);
}

/** r_t = P_t / P_{t-1} − 1, t = 1..n−1. Length n−1. */
export function simpleReturns(prices: readonly number[]): QuantResult<number[]> {
  const p = requirePrices(prices, 2);
  if (!p.ok) return p;
  const out: number[] = [];
  for (let i = 1; i < prices.length; i++) out.push(prices[i] / prices[i - 1] - 1);
  return finite(out);
}

/** ℓ_t = ln(P_t / P_{t-1}). Length n−1. */
export function logReturns(prices: readonly number[]): QuantResult<number[]> {
  const p = requirePrices(prices, 2);
  if (!p.ok) return p;
  const out: number[] = [];
  for (let i = 1; i < prices.length; i++) out.push(Math.log(prices[i] / prices[i - 1]));
  return finite(out);
}

/** P_{n−1} / P_0 − 1 (price return over the whole series). */
export function cumulativeReturn(prices: readonly number[]): QuantResult<number> {
  const p = requirePrices(prices, 2);
  if (!p.ok) return p;
  return finite(prices[prices.length - 1] / prices[0] - 1);
}

/** Π(1 + r_t) − 1 — compounding a return series. For returns derived from
 * a price series this equals cumulativeReturn (invariant, tested). */
export function compoundReturns(returns: readonly number[]): QuantResult<number> {
  const r = requireSeries(returns, 1, 'returns');
  if (!r.ok) return r;
  if (returns.some((x) => x <= -1)) return fail('CALCULATION_ERROR', 'a return <= -100% cannot be compounded');
  // Sum of logs is more stable than a running product for long series.
  return finite(Math.expm1(fsum(returns.map((x) => Math.log1p(x)))));
}

/** Rolling k-period return: P_t / P_{t−k} − 1 for t = k..n−1; entries 0..k−1 are null (not computable, never filled). */
export function rollingReturns(prices: readonly number[], window: number): QuantResult<(number | null)[]> {
  const p = requirePrices(prices, 2);
  if (!p.ok) return p;
  const w = requireWindow(window, prices.length - 1);
  if (!w.ok) return w;
  return finite(prices.map((pt, t) => (t < window ? null : pt / prices[t - window] - 1)));
}

export interface VolatilityOptions {
  /** Periods per year used to annualize (e.g. 252 for trading days). null → not annualized. Must be explicit. */
  readonly periodsPerYear: number | null;
}

export interface VolatilityValue {
  /** Sample standard deviation (ddof = 1) of the per-period returns. */
  readonly perPeriod: number;
  /** perPeriod × √periodsPerYear, or null when not annualized. */
  readonly annualized: number | null;
  readonly observations: number;
}

/** σ = sqrt( Σ(r − r̄)² / (n − 1) ); annualized σ·√k (i.i.d. square-root-of-time assumption). */
export function volatility(returns: readonly number[], opts: VolatilityOptions): QuantResult<VolatilityValue> {
  const r = requireSeries(returns, 2, 'returns');
  if (!r.ok) return r;
  if (opts.periodsPerYear !== null && (!Number.isFinite(opts.periodsPerYear) || opts.periodsPerYear <= 0)) {
    return fail('INVALID_PARAMETER', 'periodsPerYear must be > 0 or null');
  }
  const perPeriod = Math.sqrt(variance(returns, 1));
  const annualized = opts.periodsPerYear === null ? null : perPeriod * Math.sqrt(opts.periodsPerYear);
  if (!Number.isFinite(perPeriod) || (annualized !== null && !Number.isFinite(annualized))) {
    return fail('CALCULATION_ERROR', 'volatility is not a finite number', { reason: 'NON_FINITE_RESULT' });
  }
  return ok({ perPeriod, annualized, observations: returns.length });
}

/** DD_t = P_t / max_{s<=t} P_s − 1. Always <= 0 (convention: drawdowns are non-positive). */
export function drawdownSeries(prices: readonly number[]): QuantResult<number[]> {
  const p = requirePrices(prices, 1);
  if (!p.ok) return p;
  let peak = prices[0];
  return ok(prices.map((x) => {
    if (x > peak) peak = x;
    return x / peak - 1;
  }));
}

export interface MaxDrawdownValue {
  /** min_t DD_t, in [−1, 0]. 0 means the series never fell below a prior peak. */
  readonly maxDrawdown: number;
  /** Index of the running peak that preceded the trough (null when maxDrawdown = 0). */
  readonly peakIndex: number | null;
  readonly troughIndex: number | null;
  /** First index after the trough whose price >= the peak price; null if not (yet) recovered. */
  readonly recoveryIndex: number | null;
}

export function maxDrawdown(prices: readonly number[]): QuantResult<MaxDrawdownValue> {
  const p = requirePrices(prices, 1);
  if (!p.ok) return p;
  let peakIdx = 0;
  let worst = 0;
  let worstPeak: number | null = null;
  let worstTrough: number | null = null;
  for (let i = 0; i < prices.length; i++) {
    if (prices[i] > prices[peakIdx]) peakIdx = i;
    const dd = prices[i] / prices[peakIdx] - 1;
    if (dd < worst) {
      worst = dd;
      worstPeak = peakIdx;
      worstTrough = i;
    }
  }
  let recoveryIndex: number | null = null;
  if (worstTrough !== null && worstPeak !== null) {
    for (let i = worstTrough + 1; i < prices.length; i++) {
      if (prices[i] >= prices[worstPeak]) {
        recoveryIndex = i;
        break;
      }
    }
  }
  return ok({ maxDrawdown: worst, peakIndex: worstPeak, troughIndex: worstTrough, recoveryIndex });
}

/** Simple moving average: SMA_t = (1/k) Σ_{i=t−k+1..t} x_i for t >= k−1; earlier entries are null. */
export function simpleMovingAverage(values: readonly number[], window: number): QuantResult<(number | null)[]> {
  const v = requireSeries(values, 1, 'values');
  if (!v.ok) return v;
  const w = requireWindow(window, values.length);
  if (!w.ok) return w;
  // O(n) with bounded drift (Codex Gate 1 CX1-07: the per-window fsum was
  // O(n·k), i.e. ~2.5e9 operations per 50 000-bar series with a 50 000
  // window). The window sum is recomputed exactly with fsum once every k
  // steps (n/k recomputes × k terms = O(n)); between recomputes it is
  // updated by add/subtract, so rounding drift spans at most k−1 updates.
  const out: (number | null)[] = new Array(values.length).fill(null);
  let sum = 0;
  for (let t = window - 1; t < values.length; t++) {
    if ((t - (window - 1)) % window === 0) sum = fsum(values.slice(t - window + 1, t + 1));
    else sum += values[t] - values[t - window];
    out[t] = sum / window;
  }
  return finite(out);
}

/** Minimum paired observations for a correlation to be reported. With n = 2
 * Pearson's r is always ±1 and carries no information. */
export const MIN_CORRELATION_OBSERVATIONS = 3;

/** Pearson r = Σ(x−x̄)(y−ȳ) / sqrt(Σ(x−x̄)² Σ(y−ȳ)²). Undefined (CALCULATION_ERROR, ZERO_VARIANCE) for a constant input. */
export function pearsonCorrelation(x: readonly number[], y: readonly number[]): QuantResult<number> {
  const a = requireSeries(x, MIN_CORRELATION_OBSERVATIONS, 'x');
  if (!a.ok) return a;
  const b = requireSeries(y, MIN_CORRELATION_OBSERVATIONS, 'y');
  if (!b.ok) return b;
  if (x.length !== y.length) return fail('INVALID_PARAMETER', 'x and y must have equal length', { x: x.length, y: y.length });
  const mx = mean(x), my = mean(y);
  const dx = x.map((v) => v - mx), dy = y.map((v) => v - my);
  const sxx = fsum(dx.map((d) => d * d));
  const syy = fsum(dy.map((d) => d * d));
  if (!Number.isFinite(sxx) || !Number.isFinite(syy)) {
    return fail('CALCULATION_ERROR', 'correlation inputs overflow', { reason: 'NON_FINITE_RESULT' });
  }
  if (sxx === 0 || syy === 0 || isNumericallyConstant(x, sxx) || isNumericallyConstant(y, syy)) {
    return fail('CALCULATION_ERROR', 'correlation undefined for a (numerically) constant series', { reason: 'ZERO_VARIANCE' });
  }
  const sxy = fsum(dx.map((d, i) => d * dy[i]));
  // sqrt(sxx)·sqrt(syy) instead of sqrt(sxx·syy): the product can overflow
  // even when each factor is finite.
  const r = sxy / (Math.sqrt(sxx) * Math.sqrt(syy));
  if (!Number.isFinite(r)) return fail('CALCULATION_ERROR', 'correlation is not a finite number', { reason: 'NON_FINITE_RESULT' });
  // Guard only against floating overshoot past the mathematical bound.
  return ok(Math.max(-1, Math.min(1, r)));
}

export interface SharpeAssumptions {
  /** Risk-free rate PER PERIOD of the return series (e.g. annual 5% on daily data ≈ 0.05/252). Required. */
  readonly riskFreeRatePerPeriod: number;
  /** Periods per year for annualization. Required. */
  readonly periodsPerYear: number;
}

/** Sharpe = mean(r − rf) / stdev(r − rf) · √k. Only computed with explicit assumptions. */
export function sharpeRatio(returns: readonly number[], a: SharpeAssumptions): QuantResult<number> {
  if (!a || !Number.isFinite(a.riskFreeRatePerPeriod) || !Number.isFinite(a.periodsPerYear) || a.periodsPerYear <= 0) {
    return fail('INVALID_PARAMETER', 'Sharpe requires explicit riskFreeRatePerPeriod and periodsPerYear');
  }
  const r = requireSeries(returns, 2, 'returns');
  if (!r.ok) return r;
  const excess = returns.map((x) => x - a.riskFreeRatePerPeriod);
  const v = variance(excess, 1);
  if (!Number.isFinite(v)) return fail('CALCULATION_ERROR', 'Sharpe inputs overflow', { reason: 'NON_FINITE_RESULT' });
  if (v === 0 || isNumericallyConstant(excess, v * (excess.length - 1))) {
    return fail('CALCULATION_ERROR', 'Sharpe undefined for (numerically) zero-variance returns', { reason: 'ZERO_VARIANCE' });
  }
  return finite((mean(excess) / Math.sqrt(v)) * Math.sqrt(a.periodsPerYear));
}
