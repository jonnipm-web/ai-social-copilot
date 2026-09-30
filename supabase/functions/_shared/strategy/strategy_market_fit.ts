/**
 * Strategy <-> Market Fit — INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07
 * §10.
 *
 * Deterministic cross-referencing of a StrategySpecification against
 * MarketStatistics (market_statistics.ts) computed from the SAME
 * dataset the strategy is meant to run against. This module produces
 * structured EVIDENCE ONLY -- ratios, fractions, factual comparisons.
 * It never phrases a recommendation ("lower your stop") and never
 * invents a property neither the spec nor the stats actually carry
 * (§18: IVE interprets this evidence; this module does not interpret
 * it for IVE).
 */
import type { StrategySpecification } from './strategy_spec.ts';
import type { MarketStatistics } from './market_statistics.ts';
import type { OhlcvBar } from './ohlcv.ts';

export type FitDimension =
  | 'STOP_VS_MOVEMENT'
  | 'TARGET_VS_MOVEMENT'
  | 'COST_VS_MOVEMENT'
  | 'SESSION_VS_DATA_COVERAGE'
  | 'SIGNAL_TIMEFRAME_MATCH';

export interface FitEvidenceItem {
  readonly dimension: FitDimension;
  /** The measured ratio/fraction this item is based on. Always a real
   * number computed from spec+stats, never estimated. */
  readonly value: number;
  /** A plain factual statement of what was measured -- no advice, no
   * "should"/"recommend" language belongs here (§18). */
  readonly observation: string;
  /** True when this measurement crosses a documented, fixed threshold
   * worth a human's attention -- the threshold itself is stated in
   * `observation`, never hidden. */
  readonly flagged: boolean;
}

export interface StrategyMarketFitEvidence {
  readonly items: readonly FitEvidenceItem[];
  /** Mirrors stats.sufficientForStatistics -- fit evidence computed
   * from too little data is still returned (it is still real
   * arithmetic), but callers/IVE must treat it as low-confidence. */
  readonly sufficientData: boolean;
}

/** Below this ratio, a stop sits inside typical single-bar noise --
 * i.e. an average bar's own range could touch it without any real
 * directional move. Fixed and documented, not tuned per strategy. */
const STOP_VS_MOVEMENT_CONCERN_RATIO = 1.0;
/** Above this ratio, a target sits far beyond the typical single-bar
 * move -- reaching it requires an outsized, infrequent move. */
const TARGET_VS_MOVEMENT_CONCERN_RATIO = 5.0;
/** Above this fraction, transaction costs alone would consume a
 * meaningful share of a typical bar's move. */
const COST_VS_MOVEMENT_CONCERN_FRACTION = 0.5;

function localHourAndMinute(timestampIso: string, timezone: string): { hour: number; minute: number } | null {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(new Date(timestampIso));
    const hour = Number(parts.find((p) => p.type === 'hour')?.value);
    const minute = Number(parts.find((p) => p.type === 'minute')?.value);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
    return { hour, minute };
  } catch {
    return null; // an invalid IANA zone name never throws into the caller
  }
}

function withinSessionWindow(hm: { hour: number; minute: number }, startTime: string, endTime: string): boolean {
  const minutes = hm.hour * 60 + hm.minute;
  const [sh, sm] = startTime.split(':').map(Number);
  const [eh, em] = endTime.split(':').map(Number);
  return minutes >= sh * 60 + sm && minutes <= eh * 60 + em;
}

/**
 * `bars` must be the SAME series `stats` was computed from -- this
 * function does not re-derive statistics, only the session-coverage
 * dimension needs the raw timestamps (MarketStatistics does not carry
 * a timezone-local breakdown, only UTC).
 */
export function analyzeStrategyMarketFit(
  spec: StrategySpecification,
  stats: MarketStatistics,
  bars: readonly OhlcvBar[],
): StrategyMarketFitEvidence {
  const items: FitEvidenceItem[] = [];

  const stopRatio = stats.rangePoints.median > 0 ? spec.stop.distance / stats.rangePoints.median : Infinity;
  items.push({
    dimension: 'STOP_VS_MOVEMENT',
    value: stopRatio,
    observation: `Stop distance (${spec.stop.distance}) is ${stopRatio.toFixed(2)}x the median observed bar range (${stats.rangePoints.median.toFixed(2)}).`,
    flagged: stopRatio < STOP_VS_MOVEMENT_CONCERN_RATIO,
  });

  const targetRatio = stats.absMovePoints.p90 > 0 ? spec.target.distance / stats.absMovePoints.p90 : Infinity;
  items.push({
    dimension: 'TARGET_VS_MOVEMENT',
    value: targetRatio,
    observation: `Target distance (${spec.target.distance}) is ${targetRatio.toFixed(2)}x the 90th-percentile observed bar move (${stats.absMovePoints.p90.toFixed(2)}).`,
    flagged: targetRatio > TARGET_VS_MOVEMENT_CONCERN_RATIO,
  });

  const costAssumptions = spec.marketProfile.defaultCostAssumptions;
  if (costAssumptions) {
    const roundTripCostPoints = 2 * (
      (costAssumptions.brokeragePerContract + costAssumptions.exchangeFeePerContract) / spec.marketProfile.contractMultiplier
      + costAssumptions.slippageTicks * spec.marketProfile.tickSize
    );
    const costFraction = stats.absMovePoints.mean > 0 ? roundTripCostPoints / stats.absMovePoints.mean : Infinity;
    items.push({
      dimension: 'COST_VS_MOVEMENT',
      value: costFraction,
      observation: `Estimated round-trip cost (${roundTripCostPoints.toFixed(2)} points, from the market profile's default cost assumptions) is ${(costFraction * 100).toFixed(1)}% of the mean observed bar move (${stats.absMovePoints.mean.toFixed(2)}).`,
      flagged: costFraction > COST_VS_MOVEMENT_CONCERN_FRACTION,
    });
  }

  let inSession = 0;
  let withTz = 0;
  for (const b of bars) {
    const hm = localHourAndMinute(b.timestamp, spec.marketProfile.timezone);
    if (!hm) continue;
    withTz++;
    if (withinSessionWindow(hm, spec.session.startTime, spec.session.endTime)) inSession++;
  }
  const coverage = withTz > 0 ? inSession / withTz : 0;
  items.push({
    dimension: 'SESSION_VS_DATA_COVERAGE',
    value: coverage,
    observation: `${(coverage * 100).toFixed(1)}% of dataset bars fall inside the configured session window (${spec.session.startTime}-${spec.session.endTime} ${spec.marketProfile.timezone}).`,
    flagged: coverage < 0.5,
  });

  const timeframeMatch = spec.signalTimeframe === stats.timeframe ? 1 : 0;
  items.push({
    dimension: 'SIGNAL_TIMEFRAME_MATCH',
    value: timeframeMatch,
    observation: `Strategy signal timeframe (${spec.signalTimeframe}) ${timeframeMatch ? 'matches' : 'does NOT match'} the dataset timeframe (${stats.timeframe}).`,
    flagged: timeframeMatch === 0,
  });

  return Object.freeze({ items: Object.freeze(items), sufficientData: stats.sufficientForStatistics });
}
