/**
 * Golden datasets — IV-QUANT-FOUNDATION-01 (QUANT_CALCULATION_SPEC.md §10).
 *
 * Small, deterministic, synthetic series whose expected results were
 * derived BY HAND (derivations inline). Test-only; no network, no real
 * market data, no vendor. All instruments are fictitious (XTST venue code
 * is not a real MIC assignment used by any provider here).
 */
import type { FixtureDataset } from '../provider.ts';
import type { InstrumentIdentity } from '../instrument.ts';
import type { RawBarInput } from '../timeseries.ts';

const DAY = 86_400_000;
/** Monday 2026-01-05 00:00Z — session-date label for daily bars. */
export const G_START_T = Date.UTC(2026, 0, 5);

export function dailyBars(closes: readonly number[], startT = G_START_T): RawBarInput[] {
  // Weekdays only (Mon–Fri), so the calendar-naive gap detector stays quiet.
  const out: RawBarInput[] = [];
  let t = startT;
  for (const c of closes) {
    while (new Date(t).getUTCDay() === 0 || new Date(t).getUTCDay() === 6) t += DAY;
    out.push({ t, open: c, high: c + 1, low: c - 1 > 0 ? c - 1 : c / 2, close: c, volume: 1000 });
    t += DAY;
  }
  return out;
}

export const INSTR_A: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'TSTA', exchangeMic: 'XTST', currency: 'USD' };
export const INSTR_B: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'TSTB', exchangeMic: 'XTST', currency: 'USD' };
export const INSTR_C: InstrumentIdentity = { assetClass: 'ETF', symbol: 'TSTC', exchangeMic: 'XTST', currency: 'USD' };
export const INSTR_BRL: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'TSTR3', exchangeMic: 'BVMF', currency: 'BRL' };

/**
 * G1 — alternating ±10 %.
 *   closes 100, 110, 99, 108.9, 98.01
 *   simple returns  = +0.1, −0.1, +0.1, −0.1          (110/100−1, 99/110−1, …)
 *   log returns     = ln 1.1, ln 0.9, ln 1.1, ln 0.9
 *   cumulative      = 98.01/100 − 1 = −0.0199          (= (1.1·0.9)² − 1)
 *   mean return     = 0
 *   sample variance = 4·(0.1)² / (4−1) = 0.04/3 → σ = √(0.04/3) = 0.115470053837925152…
 *   annualized(252) = √(0.04/3 · 252) = √3.36 = 1.833030277982336…
 *   running peak    = 100, 110, 110, 110, 110
 *   drawdowns       = 0, 0, −0.1, −0.01, −0.109        (99/110−1, 108.9/110−1, 98.01/110−1)
 *   max drawdown    = −0.109, peak idx 1, trough idx 4, not recovered
 *   SMA(2)          = —, 105, 104.5, 103.95, 103.455
 *   SMA(3)          = —, —, 103, 317.9/3 = 105.9666…, 305.91/3 = 101.97
 */
export const G1_CLOSES = [100, 110, 99, 108.9, 98.01] as const;
export const G1 = {
  simpleReturns: [0.1, -0.1, 0.1, -0.1],
  logReturns: [Math.log(1.1), Math.log(0.9), Math.log(1.1), Math.log(0.9)],
  cumulative: -0.0199,
  meanReturn: 0,
  volPerPeriod: 0.11547005383792515,
  volAnnualized252: 1.833030277982336,
  drawdowns: [0, 0, -0.1, -0.01, -0.109],
  maxDrawdown: -0.109,
  sma2: [null, 105, 104.5, 103.95, 103.455],
  sma3: [null, null, 103, 317.9 / 3, 101.97],
};

/**
 * G2 — drawdown with recovery.
 *   closes 100, 80, 90, 120, 60, 130
 *   drawdowns 0, −0.2, −0.1, 0, −0.5, 0     (peak 100 until idx 3, then 120, then 130)
 *   max drawdown −0.5, peak idx 3 (120), trough idx 4 (60), recovery idx 5 (130 ≥ 120)
 *   cumulative 130/100 − 1 = 0.3
 */
export const G2_CLOSES = [100, 80, 90, 120, 60, 130] as const;
export const G2 = { maxDrawdown: -0.5, peakIndex: 3, troughIndex: 4, recoveryIndex: 5, cumulative: 0.3 };

/** G3 — constant series: returns all 0, σ = 0, MDD = 0, correlation/Sharpe undefined. */
export const G3_CLOSES = [50, 50, 50, 50] as const;

/**
 * G4 — MA crossover observations, fast SMA(2) vs slow SMA(3).
 *   closes      10, 9, 8, 9, 11, 13, 11, 9, 7
 *   SMA2 (i≥1)  9.5, 8.5, 8.5, 10, 12, 12, 10, 8
 *   SMA3 (i≥2)  9, 26/3, 28/3, 11, 35/3, 11, 9
 *   fast−slow   i2 −0.5, i3 −0.17, i4 +0.67 → CROSSED_ABOVE @4, i5 +1, i6 +0.33, i7 −1 → CROSSED_BELOW @7, i8 −1
 */
export const G4_CLOSES = [10, 9, 8, 9, 11, 13, 11, 9, 7] as const;
export const G4 = { crosses: [{ index: 4, direction: 'CROSSED_ABOVE' }, { index: 7, direction: 'CROSSED_BELOW' }] };

/**
 * Correlation goldens (Pearson on raw vectors):
 *   x = 1..5, y = 2x        → +1
 *   x = 1..5, y = 12 − 2x   → −1
 *   x = (1,2,3), y = (1,3,2): x̄ = ȳ = 2; Σdxdy = (−1)(−1)+0·1+1·0 = 1; Σdx² = Σdy² = 2 → r = 1/2
 */
export const CORR = {
  x: [1, 2, 3, 4, 5],
  yPos: [2, 4, 6, 8, 10],
  yNeg: [10, 8, 6, 4, 2],
  x3: [1, 2, 3],
  y3: [1, 3, 2],
  r3: 0.5,
};

/**
 * Portfolio golden: A 10 × 50 = 500, B 5 × 100 = 500, C 20 × 50 = 1000 → total 2000.
 *   weights 0.25, 0.25, 0.5; HHI = 0.0625 + 0.0625 + 0.25 = 0.375; effective holdings = 1/0.375 = 2.666…
 * Buy-and-hold: A 100 → 110 (+10 %), B 50 → 45 (−10 %), weights 0.5/0.5 → 0.
 */
export const PORTFOLIO = { total: 2000, weights: [0.25, 0.25, 0.5], hhi: 0.375, effective: 1 / 0.375 };

export function goldenFixtureDatasets(): FixtureDataset[] {
  return [
    { instrument: INSTR_A, frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', bars: dailyBars(G1_CLOSES) },
    { instrument: INSTR_B, frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', bars: dailyBars(G2_CLOSES) },
  ];
}

/** Relative tolerance for golden comparisons: each value involves < 20 float64
 * operations (≤ ~20 ulp ≈ 4.4e−15 relative); 1e−12 leaves ~200× margin and
 * still catches any formula error (those are ≥ 1e−6). */
export const TOL = 1e-12;

export function close(actual: number, expected: number, tol = TOL): boolean {
  return Math.abs(actual - expected) <= tol * Math.max(1, Math.abs(expected));
}
