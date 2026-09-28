/**
 * Market Statistics — INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 §8-9.
 *
 * Deterministic, dependency-free statistics computed directly from an
 * already-validated OHLCV bar series (ohlcv.ts). This module never
 * invents a market property it cannot measure from the bars it was
 * given (§9: "Do not invent unavailable market properties") -- every
 * field here is a real aggregate of real bar data, nothing is estimated
 * or looked up from external knowledge.
 *
 * `hourOfDayUtcRangePoints` is bucketed in UTC, not the instrument's
 * local session timezone -- this module has no timezone-conversion
 * logic of its own and does not borrow MarketProfile's just to label a
 * bucket "session-local"; a caller that needs local-time buckets must
 * convert before calling, or interpret the UTC buckets knowing the
 * offset itself.
 */
import type { OhlcvBar } from './ohlcv.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

/** Below this many bars, distributional statistics (percentiles,
 * hour-of-day buckets) are too noisy to be useful -- mirrors the
 * SMALL_SAMPLE_THRESHOLD convention already used by
 * ive_strategy_analyst.ts, so "is this enough data" reads the same way
 * across the whole Strategy Intelligence surface. */
export const MIN_BARS_FOR_STATISTICS = 30;
/** Hour-of-day buckets need multiple distinct calendar days behind them
 * to mean anything -- one day's bars would just reproduce that one
 * day's shape, not a real "time-of-day behavior". */
export const MIN_DISTINCT_DAYS_FOR_HOUR_OF_DAY = 5;

export interface Distribution {
  readonly mean: number;
  readonly median: number;
  readonly p90: number;
  readonly max: number;
}

export interface HourOfDayBucket {
  readonly hourUtc: number; // 0-23
  readonly meanRangePoints: number;
  readonly sampleCount: number;
}

export interface MarketStatistics {
  readonly barCount: number;
  readonly timeframe: string;
  readonly rangePoints: Distribution;
  readonly absMovePoints: Distribution;
  readonly upBarFraction: number;
  readonly downBarFraction: number;
  readonly averageVolume: number;
  /** Fraction of consecutive-bar time gaps exceeding 1.5x the modal gap
   * -- a real, measured proxy for session breaks/missing bars, never a
   * guess at liquidity. */
  readonly gapFrequency: number;
  readonly sufficientForStatistics: boolean;
  /** null when there are not enough distinct UTC calendar days behind
   * the series for a time-of-day breakdown to be meaningful -- never a
   * fabricated breakdown padded from too little data. */
  readonly hourOfDayUtcRangePoints: readonly HourOfDayBucket[] | null;
}

function mean(xs: readonly number[]): number {
  return xs.reduce((s, x) => s + x, 0) / xs.length;
}

function percentile(sorted: readonly number[], p: number): number {
  if (sorted.length === 1) return sorted[0];
  const idx = (sorted.length - 1) * p;
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  if (lo === hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
}

function distributionOf(xs: readonly number[]): Distribution {
  const sorted = [...xs].sort((a, b) => a - b);
  return {
    mean: mean(xs),
    median: percentile(sorted, 0.5),
    p90: percentile(sorted, 0.9),
    max: sorted[sorted.length - 1],
  };
}

function modalGapMs(deltasMs: readonly number[]): number {
  const counts = new Map<number, number>();
  for (const d of deltasMs) counts.set(d, (counts.get(d) ?? 0) + 1);
  let best = deltasMs[0];
  let bestCount = 0;
  for (const [d, c] of counts) {
    if (c > bestCount) {
      best = d;
      bestCount = c;
    }
  }
  return best;
}

/**
 * Computes MarketStatistics from bars this module trusts are already
 * shape-valid (run validateOhlcvBars first -- this function does not
 * repeat that check, to avoid two sources of truth for bar validity).
 */
export function computeMarketStatistics(bars: readonly OhlcvBar[], timeframe: string): StrategyResult<MarketStatistics> {
  if (!Array.isArray(bars) || bars.length === 0) return fail('INVALID_STRATEGY_SPEC', 'bars must be a non-empty array');
  if (typeof timeframe !== 'string' || timeframe.length === 0) return fail('INVALID_STRATEGY_SPEC', 'timeframe is required');

  const rangePointsRaw = bars.map((b) => b.high - b.low);
  const absMoveRaw = bars.map((b) => Math.abs(b.close - b.open));
  const upBars = bars.filter((b) => b.close > b.open).length;
  const downBars = bars.filter((b) => b.close < b.open).length;
  const averageVolume = mean(bars.map((b) => b.volume));

  const timestampsMs = bars.map((b) => Date.parse(b.timestamp));
  const deltasMs: number[] = [];
  for (let i = 1; i < timestampsMs.length; i++) deltasMs.push(timestampsMs[i] - timestampsMs[i - 1]);
  let gapFrequency = 0;
  if (deltasMs.length > 0) {
    const modal = modalGapMs(deltasMs);
    const gaps = deltasMs.filter((d) => d > modal * 1.5).length;
    gapFrequency = gaps / deltasMs.length;
  }

  const sufficientForStatistics = bars.length >= MIN_BARS_FOR_STATISTICS;

  const distinctDaysUtc = new Set(bars.map((b) => b.timestamp.slice(0, 10)));
  let hourOfDayUtcRangePoints: readonly HourOfDayBucket[] | null = null;
  if (distinctDaysUtc.size >= MIN_DISTINCT_DAYS_FOR_HOUR_OF_DAY) {
    const byHour = new Map<number, number[]>();
    for (let i = 0; i < bars.length; i++) {
      const hour = new Date(timestampsMs[i]).getUTCHours();
      const arr = byHour.get(hour) ?? [];
      arr.push(rangePointsRaw[i]);
      byHour.set(hour, arr);
    }
    hourOfDayUtcRangePoints = Object.freeze(
      [...byHour.entries()]
        .sort((a, b) => a[0] - b[0])
        .map(([hourUtc, ranges]) => Object.freeze({ hourUtc, meanRangePoints: mean(ranges), sampleCount: ranges.length })),
    );
  }

  return ok(Object.freeze({
    barCount: bars.length,
    timeframe,
    rangePoints: Object.freeze(distributionOf(rangePointsRaw)),
    absMovePoints: Object.freeze(distributionOf(absMoveRaw)),
    upBarFraction: upBars / bars.length,
    downBarFraction: downBars / bars.length,
    averageVolume,
    gapFrequency,
    sufficientForStatistics,
    hourOfDayUtcRangePoints,
  }));
}
