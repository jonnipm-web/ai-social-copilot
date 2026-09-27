/**
 * Calculation engine tests — IV-QUANT-FOUNDATION-01.
 * Golden values are hand-derived in fixtures/golden.ts; property tests use
 * a seeded PRNG so every run is identical.
 *
 * Execução:
 *   deno test supabase/functions/_shared/quant/metrics_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  compoundReturns,
  cumulativeReturn,
  drawdownSeries,
  logReturns,
  maxDrawdown,
  pearsonCorrelation,
  rollingReturns,
  sharpeRatio,
  simpleMovingAverage,
  simpleReturns,
  volatility,
} from './metrics.ts';
import { fsum, variance } from './numeric.ts';
import { close, CORR, G1, G1_CLOSES, G2, G2_CLOSES, G3_CLOSES } from './fixtures/golden.ts';
import type { QuantResult } from './errors.ts';

function val<T>(r: QuantResult<T>): T {
  if (!r.ok) throw new Error(`expected ok, got ${r.error.code}: ${r.error.message}`);
  return r.value;
}
function code<T>(r: QuantResult<T>): string {
  assert(!r.ok, 'expected failure');
  return (r as { ok: false; error: { code: string } }).error.code;
}
function assertClose(actual: number | null, expected: number | null, tol?: number) {
  if (expected === null || actual === null) return assertEquals(actual, expected);
  assert(close(actual, expected, tol), `expected ${expected}, got ${actual}`);
}
function assertAllClose(actual: readonly (number | null)[], expected: readonly (number | null)[], tol?: number) {
  assertEquals(actual.length, expected.length);
  actual.forEach((a, i) => assertClose(a, expected[i], tol));
}

// ---------------------------------------------------------------- golden G1

Deno.test('MX-01 simple returns — golden G1', () => assertAllClose(val(simpleReturns(G1_CLOSES)), G1.simpleReturns));
Deno.test('MX-02 log returns — golden G1', () => assertAllClose(val(logReturns(G1_CLOSES)), G1.logReturns));
Deno.test('MX-03 cumulative return — golden G1', () => assertClose(val(cumulativeReturn(G1_CLOSES)), G1.cumulative));
Deno.test('MX-04 volatility per period + annualized(252) — golden G1', () => {
  const v = val(volatility(G1.simpleReturns, { periodsPerYear: 252 }));
  assertClose(v.perPeriod, G1.volPerPeriod);
  assertClose(v.annualized, G1.volAnnualized252);
  assertEquals(v.observations, 4);
});
Deno.test('MX-05 volatility not annualized when periodsPerYear = null', () => {
  assertEquals(val(volatility(G1.simpleReturns, { periodsPerYear: null })).annualized, null);
});
Deno.test('MX-06 drawdown series + max drawdown — golden G1 (never recovered)', () => {
  assertAllClose(val(drawdownSeries(G1_CLOSES)), G1.drawdowns);
  const m = val(maxDrawdown(G1_CLOSES));
  assertClose(m.maxDrawdown, G1.maxDrawdown);
  assertEquals([m.peakIndex, m.troughIndex, m.recoveryIndex], [1, 4, null]);
});
Deno.test('MX-07 max drawdown with recovery — golden G2', () => {
  const m = val(maxDrawdown(G2_CLOSES));
  assertClose(m.maxDrawdown, G2.maxDrawdown);
  assertEquals([m.peakIndex, m.troughIndex, m.recoveryIndex], [G2.peakIndex, G2.troughIndex, G2.recoveryIndex]);
  assertClose(val(cumulativeReturn(G2_CLOSES)), G2.cumulative);
});
Deno.test('MX-08 SMA(2) and SMA(3) — golden G1, leading entries are null (not filled)', () => {
  assertAllClose(val(simpleMovingAverage(G1_CLOSES, 2)), G1.sma2);
  assertAllClose(val(simpleMovingAverage(G1_CLOSES, 3)), G1.sma3);
});
Deno.test('MX-09 rolling 2-period return', () => {
  // 99/100−1, 108.9/110−1, 98.01/99−1
  assertAllClose(val(rollingReturns(G1_CLOSES, 2)), [null, null, -0.01, -0.01, -0.01]);
});
Deno.test('MX-10 Pearson correlation goldens: +1, −1, 0.5', () => {
  assertClose(val(pearsonCorrelation(CORR.x, CORR.yPos)), 1);
  assertClose(val(pearsonCorrelation(CORR.x, CORR.yNeg)), -1);
  assertClose(val(pearsonCorrelation(CORR.x3, CORR.y3)), CORR.r3);
});
Deno.test('MX-11 Sharpe only with explicit assumptions; golden', () => {
  // returns 0.02, 0.00, 0.04 with rf 0.01 → excess 0.01, −0.01, 0.03; mean 0.01; sd = √(0.0008/2) = 0.02 → 0.5·√4 = 1
  assertClose(val(sharpeRatio([0.02, 0.0, 0.04], { riskFreeRatePerPeriod: 0.01, periodsPerYear: 4 })), 1);
  // deno-lint-ignore no-explicit-any
  assertEquals(code(sharpeRatio([0.02, 0.0, 0.04], {} as any)), 'INVALID_PARAMETER');
  // deno-lint-ignore no-explicit-any
  assertEquals(code(sharpeRatio([0.02, 0.0, 0.04], { riskFreeRatePerPeriod: 0.01 } as any)), 'INVALID_PARAMETER');
});

// ---------------------------------------------------------------- edge cases

Deno.test('MX-20 empty series → INSUFFICIENT_DATA everywhere', () => {
  assertEquals(code(simpleReturns([])), 'INSUFFICIENT_DATA');
  assertEquals(code(cumulativeReturn([])), 'INSUFFICIENT_DATA');
  assertEquals(code(maxDrawdown([])), 'INSUFFICIENT_DATA');
  assertEquals(code(simpleMovingAverage([], 1)), 'INSUFFICIENT_DATA');
  assertEquals(code(volatility([], { periodsPerYear: null })), 'INSUFFICIENT_DATA');
  assertEquals(code(pearsonCorrelation([], [])), 'INSUFFICIENT_DATA');
});
Deno.test('MX-21 single value → no return, no volatility; drawdown of one price is 0', () => {
  assertEquals(code(simpleReturns([100])), 'INSUFFICIENT_DATA');
  assertEquals(code(volatility([0.01], { periodsPerYear: 252 })), 'INSUFFICIENT_DATA');
  assertEquals(val(maxDrawdown([100])).maxDrawdown, 0);
});
Deno.test('MX-22 zero and negative prices are rejected (not silently producing ±Infinity)', () => {
  assertEquals(code(simpleReturns([100, 0, 50])), 'INVALID_DATASET');
  assertEquals(code(logReturns([100, -5])), 'INVALID_DATASET');
  assertEquals(code(maxDrawdown([0, 1])), 'INVALID_DATASET');
});
Deno.test('MX-23 NaN / Infinity inputs are rejected', () => {
  assertEquals(code(simpleReturns([100, NaN])), 'INVALID_DATASET');
  assertEquals(code(simpleReturns([100, Infinity])), 'INVALID_DATASET');
  assertEquals(code(volatility([0.1, NaN], { periodsPerYear: null })), 'INVALID_DATASET');
  assertEquals(code(pearsonCorrelation([1, 2, NaN], [1, 2, 3])), 'INVALID_DATASET');
  assertEquals(code(simpleMovingAverage([1, Infinity], 1)), 'INVALID_DATASET');
});
Deno.test('MX-24 constant series: σ = 0, MDD = 0 (no peak), correlation and Sharpe undefined — never 0 or NaN', () => {
  const r = val(simpleReturns(G3_CLOSES));
  assertEquals(r, [0, 0, 0]);
  assertEquals(val(volatility(r, { periodsPerYear: 252 })).perPeriod, 0);
  const m = val(maxDrawdown(G3_CLOSES));
  assertEquals([m.maxDrawdown, m.peakIndex, m.troughIndex], [0, null, null]);
  const c = pearsonCorrelation(r, [0.1, 0.2, 0.3]);
  assertEquals(code(c), 'CALCULATION_ERROR');
  assert(!c.ok && c.error.details?.reason === 'ZERO_VARIANCE');
  assertEquals(code(sharpeRatio(r, { riskFreeRatePerPeriod: 0, periodsPerYear: 252 })), 'CALCULATION_ERROR');
});
Deno.test('MX-25 extreme values stay finite and correct', () => {
  assertClose(val(cumulativeReturn([1e-300, 1e-299])), 9);
  assertClose(val(cumulativeReturn([1e300, 2e300])), 1);
  assertClose(val(maxDrawdown([1e300, 1e-300])).maxDrawdown, -1, 1e-12);
  const v = val(volatility([1e-12, -1e-12, 1e-12, -1e-12], { periodsPerYear: null })).perPeriod;
  assert(Number.isFinite(v) && v > 0);
});
Deno.test('MX-26 invalid windows / parameters', () => {
  assertEquals(code(simpleMovingAverage([1, 2, 3], 0)), 'INVALID_PARAMETER');
  assertEquals(code(simpleMovingAverage([1, 2, 3], 1.5)), 'INVALID_PARAMETER');
  assertEquals(code(simpleMovingAverage([1, 2, 3], 4)), 'INSUFFICIENT_DATA');
  assertEquals(code(rollingReturns([1, 2, 3], 3)), 'INSUFFICIENT_DATA');
  assertEquals(code(volatility([0.1, 0.2], { periodsPerYear: 0 })), 'INVALID_PARAMETER');
  assertEquals(code(pearsonCorrelation([1, 2, 3], [1, 2, 3, 4])), 'INVALID_PARAMETER');
  assertEquals(code(pearsonCorrelation([1, 2], [2, 1])), 'INSUFFICIENT_DATA');
});
Deno.test('MX-27 compounding a −100 % return is refused', () => {
  assertEquals(code(compoundReturns([0.1, -1])), 'CALCULATION_ERROR');
});
Deno.test('MX-28 compensated summation beats naive summation on cancellation', () => {
  const xs = [1e16, 1, -1e16];
  assertEquals(fsum(xs), 1);
  // Naive left-to-right loses the 1 entirely.
  assertEquals(xs.reduce((a, b) => a + b, 0), 0);
  // Two-pass variance of a large-offset constant-ish series stays exact.
  assertEquals(variance([1e9 + 1, 1e9 + 1, 1e9 + 1], 1), 0);
});

// ---------------------------------------------------------------- invariants (seeded)

function mulberry32(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function randomWalk(rand: () => number, n: number): number[] {
  const out = [100];
  for (let i = 1; i < n; i++) out.push(out[i - 1] * (1 + (rand() - 0.5) * 0.1));
  return out;
}
/** Property tolerance: series up to 500 points; products/sums of ≤ 500 terms
 * accumulate ≤ ~500 ulp ≈ 1.1e−13 relative. 1e−10 documents that bound with margin. */
const PTOL = 1e-10;

Deno.test('MX-40 invariant: compound(simple returns) == cumulative return (200 seeded series)', () => {
  const rand = mulberry32(42);
  for (let k = 0; k < 200; k++) {
    const p = randomWalk(rand, 2 + Math.floor(rand() * 499));
    assertClose(val(compoundReturns(val(simpleReturns(p)))), val(cumulativeReturn(p)), PTOL);
    // Σ log returns == ln(P_last / P_0)
    assertClose(fsum(val(logReturns(p))), Math.log(p[p.length - 1] / p[0]), PTOL);
  }
});
Deno.test('MX-41 invariant: max drawdown ∈ [−1, 0], every drawdown ≤ 0, σ ≥ 0', () => {
  const rand = mulberry32(7);
  for (let k = 0; k < 200; k++) {
    const p = randomWalk(rand, 3 + Math.floor(rand() * 300));
    const m = val(maxDrawdown(p)).maxDrawdown;
    assert(m <= 0 && m >= -1, `mdd ${m}`);
    assert(val(drawdownSeries(p)).every((d) => d <= 0));
    assert(val(volatility(val(simpleReturns(p)), { periodsPerYear: 252 })).perPeriod >= 0);
    assertEquals(Math.min(...val(drawdownSeries(p))), m);
  }
});
Deno.test('MX-42 invariant: corr(x, x) = 1, corr(x, −x) = −1, symmetric, bounded', () => {
  const rand = mulberry32(99);
  for (let k = 0; k < 100; k++) {
    const x = val(simpleReturns(randomWalk(rand, 10 + Math.floor(rand() * 200))));
    const y = x.map(() => rand() - 0.5);
    assertClose(val(pearsonCorrelation(x, x)), 1, PTOL);
    assertClose(val(pearsonCorrelation(x, x.map((v) => -v))), -1, PTOL);
    const a = val(pearsonCorrelation(x, y)), b = val(pearsonCorrelation(y, x));
    assertClose(a, b, PTOL);
    assert(a >= -1 && a <= 1);
  }
});
Deno.test('MX-43 invariant: returns, σ, MDD and correlation are scale-invariant (price × c)', () => {
  const rand = mulberry32(2026);
  for (let k = 0; k < 100; k++) {
    const p = randomWalk(rand, 20 + Math.floor(rand() * 100));
    const c = 0.01 + rand() * 1000;
    const q = p.map((x) => x * c);
    assertClose(val(cumulativeReturn(q)), val(cumulativeReturn(p)), PTOL);
    assertClose(val(maxDrawdown(q)).maxDrawdown, val(maxDrawdown(p)).maxDrawdown, PTOL);
    const rp = val(simpleReturns(p)), rq = val(simpleReturns(q));
    assertClose(val(volatility(rq, { periodsPerYear: null })).perPeriod, val(volatility(rp, { periodsPerYear: null })).perPeriod, 1e-8);
    assertClose(val(pearsonCorrelation(rp, rq)), 1, 1e-8);
  }
});
Deno.test('MX-44 invariant: SMA(1) is the identity; SMA(n) last value is the mean', () => {
  const rand = mulberry32(5);
  const p = randomWalk(rand, 50);
  assertAllClose(val(simpleMovingAverage(p, 1)), p, PTOL);
  assertClose(val(simpleMovingAverage(p, 50))[49] as number, fsum(p) / 50, PTOL);
});
