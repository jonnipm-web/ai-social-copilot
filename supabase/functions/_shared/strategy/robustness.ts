/**
 * Robustness Engine (first layer) — INSIGHTVALUES-STRATEGY-INTELLIGENCE-
 * MACRO-07 §13-14.
 *
 * Deterministic, evidence-only functions over CanonicalBacktestResult.
 * This is explicitly a FIRST layer (§13: "Build a real first robustness-
 * analysis layer"), not a complete research platform -- two dimensions
 * the original brief lists (true trade-level long/short P&L
 * decomposition, single-trade concentration) are NOT implemented here
 * because CanonicalBacktestResult intentionally carries aggregates only,
 * never a raw trade list (backtest_result.ts's own contract) -- adding
 * those would require a contract change this pass does not make.
 * `directionalBalance` below is the honest, count-based proxy this
 * result shape actually supports; it is documented as a proxy, not
 * presented as a P&L decomposition it cannot be.
 *
 * Cost sensitivity is intentionally NOT reimplemented here --
 * ive_strategy_analyst.ts's `analyzeCostSensitivity` already is this
 * dimension (comparing a ZERO_COST_RESEARCH result against a
 * COST_ADJUSTED one for the same strategy/dataset); duplicating it
 * would create two sources of truth for the same question.
 */
import type { CanonicalBacktestResult } from './backtest_result.ts';
import { SMALL_SAMPLE_THRESHOLD } from './ive_strategy_analyst.ts';

export interface SampleSizeFinding {
  readonly tradeCount: number;
  readonly threshold: number;
  readonly sufficient: boolean;
}

export function sampleSizeSufficiency(result: CanonicalBacktestResult): SampleSizeFinding {
  return Object.freeze({ tradeCount: result.tradeCount, threshold: SMALL_SAMPLE_THRESHOLD, sufficient: result.tradeCount >= SMALL_SAMPLE_THRESHOLD });
}

export interface ExecutionAmbiguityFinding {
  readonly ambiguousCount: number;
  readonly tradeCount: number;
  readonly rate: number | null; // null when tradeCount is 0 -- never divide-by-zero into 0 or NaN silently
}

export function executionAmbiguityRate(result: CanonicalBacktestResult): ExecutionAmbiguityFinding {
  return Object.freeze({
    ambiguousCount: result.executionAmbiguityCount,
    tradeCount: result.tradeCount,
    rate: result.tradeCount > 0 ? result.executionAmbiguityCount / result.tradeCount : null,
  });
}

/** Count-based only (see module doc) -- NOT a P&L decomposition. A
 * strategy that allows both directions but has zero trades on one side
 * is flagged: the result says nothing evidenced about that side. */
export interface DirectionalBalanceFinding {
  readonly longCount: number;
  readonly shortCount: number;
  readonly longFraction: number | null;
  readonly untested: 'LONG' | 'SHORT' | null;
}

export function directionalBalance(result: CanonicalBacktestResult): DirectionalBalanceFinding {
  const total = result.longCount + result.shortCount;
  return Object.freeze({
    longCount: result.longCount,
    shortCount: result.shortCount,
    longFraction: total > 0 ? result.longCount / total : null,
    untested: result.longCount === 0 && result.shortCount > 0 ? 'LONG' : result.shortCount === 0 && result.longCount > 0 ? 'SHORT' : null,
  });
}

export type SegmentStabilityStatus = 'STABLE' | 'SIGN_FLIP' | 'NOT_COMPARABLE';

export interface SegmentStabilityFinding {
  readonly status: SegmentStabilityStatus;
  readonly incomparabilityReasons: readonly string[];
  readonly researchNetPnl: number | null;
  readonly holdoutNetPnl: number | null;
  readonly netPnlSignConsistent: boolean | null;
}

/**
 * Compares a "research" (in-sample) result against a "holdout"
 * (out-of-sample) result for what is asserted by the CALLER to be the
 * same strategy version run on two chronological segments of the same
 * underlying dataset. Deliberately does NOT require identical
 * datasetId/period the way comparison.ts's compareBacktestResults does
 * -- segments are SUPPOSED to have different periods/dataset ids; that
 * is the entire point. It does still require the same strategy
 * identity, cost methodology and instrument, since mixing those would
 * make "did it hold up out of sample" meaningless.
 */
export function analyzeSegmentStability(
  research: CanonicalBacktestResult,
  holdout: CanonicalBacktestResult,
): SegmentStabilityFinding {
  const reasons: string[] = [];
  if (research.strategyId !== holdout.strategyId || research.strategyVersion !== holdout.strategyVersion) {
    reasons.push('different strategy identity/version');
  }
  if (research.methodologyStatus !== holdout.methodologyStatus) reasons.push('different cost methodology');
  if (research.instrumentSymbol !== holdout.instrumentSymbol) reasons.push('different instrument');
  if (reasons.length > 0) {
    return Object.freeze({
      status: 'NOT_COMPARABLE', incomparabilityReasons: Object.freeze(reasons),
      researchNetPnl: null, holdoutNetPnl: null, netPnlSignConsistent: null,
    });
  }
  const signConsistent = Math.sign(research.netPnl) === Math.sign(holdout.netPnl);
  return Object.freeze({
    status: signConsistent ? 'STABLE' : 'SIGN_FLIP',
    incomparabilityReasons: Object.freeze([]),
    researchNetPnl: research.netPnl,
    holdoutNetPnl: holdout.netPnl,
    netPnlSignConsistent: signConsistent,
  });
}
