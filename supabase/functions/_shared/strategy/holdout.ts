/**
 * Holdout / Out-of-Sample Split — INSIGHTVALUES-STRATEGY-INTELLIGENCE-
 * MACRO-07 §14.
 *
 * A single, generic, deterministic CHRONOLOGICAL split -- never random,
 * never shuffled, so "holdout" genuinely means "later in time", the
 * only split that has any right to be called out-of-sample. This module
 * does not decide what counts as contamination (see
 * experiment_provenance.ts for that) -- it only produces the split.
 */
import type { OhlcvBar } from './ohlcv.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

export interface HoldoutSplit {
  readonly research: readonly OhlcvBar[];
  readonly holdout: readonly OhlcvBar[];
}

/**
 * Splits `bars` (already chronologically ordered -- ohlcv.ts's own
 * validateOhlcvBars enforces strictly increasing timestamps upstream)
 * into a leading "research" slice and a trailing "holdout" slice.
 * `holdoutFraction` is the fraction of bars reserved for holdout, taken
 * from the END of the series.
 */
export function splitBarsForHoldout(bars: readonly OhlcvBar[], holdoutFraction: number): StrategyResult<HoldoutSplit> {
  if (!Array.isArray(bars) || bars.length < 2) return fail('INVALID_STRATEGY_SPEC', 'at least 2 bars are required for a holdout split');
  if (typeof holdoutFraction !== 'number' || !Number.isFinite(holdoutFraction) || holdoutFraction <= 0 || holdoutFraction >= 1) {
    return fail('INVALID_STRATEGY_SPEC', 'holdoutFraction must be a finite number strictly between 0 and 1');
  }
  const splitIndex = Math.floor(bars.length * (1 - holdoutFraction));
  if (splitIndex <= 0 || splitIndex >= bars.length) {
    return fail('INVALID_STRATEGY_SPEC', 'holdoutFraction leaves one side empty for this many bars', { barCount: bars.length });
  }
  return ok(Object.freeze({
    research: Object.freeze(bars.slice(0, splitIndex)),
    holdout: Object.freeze(bars.slice(splitIndex)),
  }));
}
