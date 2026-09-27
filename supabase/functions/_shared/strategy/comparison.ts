/**
 * Comparison Engine — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §30, §22.
 *
 * Quant remains the source of the numbers being compared; this module
 * only decides whether two CanonicalBacktestResults are apples-to-apples
 * and computes the deltas once that is established. Two results on
 * different datasets, periods or cost assumptions are NOT silently
 * compared -- §30: "Highlight when comparison is not apples-to-apples."
 */
import type { CanonicalBacktestResult } from './backtest_result.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

export interface ComparisonDeltas {
  readonly netPnlDelta: number;
  readonly tradeCountDelta: number;
  readonly expectancyDelta: number | null;
  readonly profitFactorDelta: number | null;
  readonly maxDrawdownDelta: number | null;
}

export interface StrategyComparison {
  readonly comparable: boolean;
  /** Populated only when NOT comparable -- the specific mismatched basis
   * (dataset, period, cost assumptions), never a silent guess. */
  readonly incomparabilityReasons: readonly string[];
  readonly a: CanonicalBacktestResult;
  readonly b: CanonicalBacktestResult;
  readonly deltas: ComparisonDeltas | null;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function costAssumptionsMatch(
  x: CanonicalBacktestResult['costAssumptions'],
  y: CanonicalBacktestResult['costAssumptions'],
): boolean {
  if (x === null && y === null) return true;
  if (x === null || y === null) return false;
  return (
    x.brokeragePerContract === y.brokeragePerContract &&
    x.exchangeFeePerContract === y.exchangeFeePerContract &&
    x.slippageTicks === y.slippageTicks
  );
}

/** Never throws/fails outright -- an incomparable pair is still a valid
 * answer (`comparable: false` with reasons), not an error. `fail` is
 * reserved for genuinely malformed input. */
export function compareBacktestResults(
  a: CanonicalBacktestResult,
  b: CanonicalBacktestResult,
): StrategyResult<StrategyComparison> {
  if (!a || !b) return fail('NOT_COMPARABLE', 'both results are required');

  const reasons: string[] = [];
  if (a.datasetId !== b.datasetId) reasons.push('different dataset');
  if (a.periodStart !== b.periodStart || a.periodEnd !== b.periodEnd) reasons.push('different period');
  if (a.methodologyStatus !== b.methodologyStatus) reasons.push('different cost methodology');
  if (!costAssumptionsMatch(a.costAssumptions, b.costAssumptions)) reasons.push('different cost assumptions');
  if (a.instrumentSymbol !== b.instrumentSymbol) reasons.push('different instrument');

  const comparable = reasons.length === 0;
  const deltas: ComparisonDeltas | null = comparable
    ? {
      netPnlDelta: round2(b.netPnl - a.netPnl),
      tradeCountDelta: b.tradeCount - a.tradeCount,
      expectancyDelta: a.expectancy !== null && b.expectancy !== null ? round2(b.expectancy - a.expectancy) : null,
      profitFactorDelta: a.profitFactor !== null && b.profitFactor !== null ? round2(b.profitFactor - a.profitFactor) : null,
      maxDrawdownDelta: a.maxDrawdown !== null && b.maxDrawdown !== null ? round2(b.maxDrawdown - a.maxDrawdown) : null,
    }
    : null;

  return ok(Object.freeze({ comparable, incomparabilityReasons: Object.freeze(reasons), a, b, deltas }));
}
