/**
 * IVE Strategy Analyst — INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §23-29.
 *
 * Turns a real CanonicalBacktestResult into a list of EpistemicClaim
 * (estimate.ts) -- every claim traceable to an actual field on the
 * result, never a generic-model guess (§28: "Do NOT rely on generic
 * model knowledge when deterministic project data is available"). This
 * module does not call an LLM at all: everything below is a deterministic
 * function of the numbers already computed by buildCanonicalBacktestResult
 * (or, for the comparison-sensitive claims, compareBacktestResults).
 *
 * Wiring this into the live IVE chat's own context assembler
 * (supabase/functions/_shared/ive/context_assembler.ts) is intentionally
 * NOT done in this pass -- that pipeline is large and this macro's budget
 * did not include auditing it deeply enough to touch it safely. This
 * module is the real, tested ANALYSIS logic a future integration would
 * call; see the Macro-06 final report's IVE_STRATEGY_ANALYST_RESULT for
 * the honest scope line.
 */
import type { CanonicalBacktestResult } from './backtest_result.ts';
import type { StrategyComparison } from './comparison.ts';
import { buildEpistemicClaim, type EpistemicClaim, type EstimateProvenance } from './estimate.ts';

/** Below this trade count, a robustness/stability claim about the result
 * is explicitly flagged as under-evidenced rather than silently omitted
 * or, worse, asserted with false confidence. Not a statistical test --
 * a conservative, stated threshold (§21: multi-criteria evaluation, never
 * a fabricated confidence number). */
export const SMALL_SAMPLE_THRESHOLD = 30;

/** A cost-adjusted result whose net P&L differs from its zero-cost
 * counterpart by at least this fraction of the zero-cost gross P&L
 * magnitude is flagged as "materially" cost-sensitive. Documented,
 * arbitrary-but-stated threshold -- never presented as a computed
 * statistical significance. */
const COST_SENSITIVITY_FRACTION = 0.2;

function provenanceFor(result: CanonicalBacktestResult, extraLimitations: readonly string[] = []): EstimateProvenance {
  return {
    sourcePeriodStart: result.periodStart,
    sourcePeriodEnd: result.periodEnd,
    sampleSize: result.tradeCount,
    dataSource: `${result.datasetId} (hash ${result.datasetHash})`,
    assumptions: result.costAssumptions
      ? [`brokerage=${result.costAssumptions.brokeragePerContract}`, `exchangeFee=${result.costAssumptions.exchangeFeePerContract}`, `slippageTicks=${result.costAssumptions.slippageTicks}`]
      : ['zero-cost research methodology'],
    costModelDescription: result.costAssumptions ? result.costAssumptions.source : null,
    confidenceNote: result.tradeCount < SMALL_SAMPLE_THRESHOLD
      ? `sample size (${result.tradeCount}) is below the ${SMALL_SAMPLE_THRESHOLD}-trade caution threshold`
      : null,
    limitations: [...result.limitations, ...extraLimitations],
  };
}

/**
 * Builds the measured/inference/unknown claims for a single result. Never
 * throws: buildEpistemicClaim's own provenance requirement is always
 * satisfied here (every INFERENCE claim below is constructed with a real
 * provenance object), so every call succeeds.
 */
export function analyzeBacktestResult(result: CanonicalBacktestResult): readonly EpistemicClaim<unknown>[] {
  const claims: EpistemicClaim<unknown>[] = [];

  claims.push(unwrap(buildEpistemicClaim(
    'MEASURED', result.netPnl,
    `Net P&L over ${result.tradeCount} trades: ${result.netPnl.toFixed(2)} (${result.methodologyStatus}).`,
    null,
  )));

  claims.push(
    result.profitFactor !== null
      ? unwrap(buildEpistemicClaim('MEASURED', result.profitFactor, `Profit factor: ${result.profitFactor.toFixed(2)}.`, null))
      : unwrap(buildEpistemicClaim('UNKNOWN', null, 'Profit factor could not be computed (no losing trades, or zero gross loss).', null)),
  );

  if (result.tradeCount < SMALL_SAMPLE_THRESHOLD) {
    claims.push(unwrap(buildEpistemicClaim(
      'INFERENCE', result.tradeCount,
      `This result is based on only ${result.tradeCount} trades -- too few to judge robustness with confidence.`,
      provenanceFor(result),
    )));
  }

  if (result.executionAmbiguityCount > 0) {
    claims.push(unwrap(buildEpistemicClaim(
      'INFERENCE', result.executionAmbiguityCount,
      `${result.executionAmbiguityCount} of ${result.tradeCount} trades executed at an ambiguous price source (e.g. a gap) -- interpret exact P&L with that in mind.`,
      provenanceFor(result),
    )));
  }

  claims.push(unwrap(buildEpistemicClaim(
    'UNKNOWN', null,
    'Future profitability cannot be estimated from this historical result alone.',
    null,
  )));

  if (result.tradeCount < SMALL_SAMPLE_THRESHOLD) {
    claims.push(unwrap(buildEpistemicClaim(
      'RECOMMENDATION', null,
      'Consider testing over a longer period or additional datasets before drawing conclusions.',
      null,
    )));
  }

  return claims;
}

/**
 * Adds a cost-sensitivity claim when the SAME strategy/dataset/period was
 * run both zero-cost and cost-adjusted (i.e. `comparison.comparable` may
 * be false here on methodology alone -- that is expected and is exactly
 * the signal this function looks for, not an error).
 */
export function analyzeCostSensitivity(zeroCost: CanonicalBacktestResult, costAdjusted: CanonicalBacktestResult): EpistemicClaim<unknown> | null {
  if (zeroCost.methodologyStatus !== 'ZERO_COST_RESEARCH' || costAdjusted.methodologyStatus !== 'COST_ADJUSTED') return null;
  if (zeroCost.strategyId !== costAdjusted.strategyId || zeroCost.strategyVersion !== costAdjusted.strategyVersion) return null;
  if (zeroCost.datasetId !== costAdjusted.datasetId) return null;
  const grossMagnitude = Math.abs(zeroCost.grossPnl) || 1;
  const delta = Math.abs(zeroCost.netPnl - costAdjusted.netPnl);
  const material = delta / grossMagnitude >= COST_SENSITIVITY_FRACTION || Math.sign(zeroCost.netPnl) !== Math.sign(costAdjusted.netPnl);
  if (!material) return null;
  return unwrap(buildEpistemicClaim(
    'INFERENCE',
    { zeroCostNetPnl: zeroCost.netPnl, costAdjustedNetPnl: costAdjusted.netPnl },
    `Transaction costs materially changed the historical result (zero-cost ${zeroCost.netPnl.toFixed(2)} vs cost-adjusted ${costAdjusted.netPnl.toFixed(2)}).`,
    provenanceFor(costAdjusted, ['comparison basis: same strategy version and dataset, zero-cost vs cost-adjusted only']),
  ));
}

/** §30/§32: a comparison's own "not comparable" reasons become an
 * INFERENCE claim, never silently skipped or upgraded into a claim about
 * which version is "better". */
export function analyzeComparison(comparison: StrategyComparison): EpistemicClaim<unknown> {
  if (!comparison.comparable) {
    return unwrap(buildEpistemicClaim(
      'INFERENCE', comparison.incomparabilityReasons,
      `These two results are not directly comparable: ${comparison.incomparabilityReasons.join(', ')}.`,
      provenanceFor(comparison.a, ['comparison refused on incomparability grounds -- no delta computed']),
    ));
  }
  return unwrap(buildEpistemicClaim(
    'MEASURED', comparison.deltas,
    `Net P&L delta: ${comparison.deltas?.netPnlDelta?.toFixed(2) ?? 'n/a'}; trade count delta: ${comparison.deltas?.tradeCountDelta ?? 'n/a'}.`,
    null,
  ));
}

function unwrap<T>(result: { ok: true; value: T } | { ok: false; error: unknown }): T {
  if (!result.ok) throw new Error('ive_strategy_analyst: unreachable -- provenance always supplied where required');
  return result.value;
}
