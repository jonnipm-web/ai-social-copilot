/**
 * Bounded Parameter Exploration / IVE Configuration Assistant —
 * INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 §16, §19.
 *
 * Rule-based and deterministic -- there is no LLM call anywhere in this
 * file, exactly like ive_strategy_analyst.ts. A proposal is generated
 * ONLY when a specific, named piece of evidence (a flagged
 * StrategyMarketFitEvidence dimension) justifies it, and the variant
 * count is fixed and small (§16: "NO giant grid search"). Returning an
 * empty list when there is no evidence-based reason is the correct,
 * honest behavior -- never pad it with an unjustified suggestion.
 */
import type { StrategySpecification } from './strategy_spec.ts';
import type { StrategyMarketFitEvidence } from './strategy_market_fit.ts';

/** Hard cap on how many variants ANY proposal function in this module
 * may return, regardless of how many multipliers are defined below --
 * enforced structurally, not just by having a short multiplier list. */
export const MAX_BOUNDED_VARIANTS = 5;

/** Fixed, documented multipliers -- not a search grid a caller can
 * widen. Testing a wider stop at these specific ratios is a bounded,
 * explainable exploration, not an optimizer. */
const STOP_WIDENING_MULTIPLIERS: readonly number[] = Object.freeze([1.1, 1.25, 1.5, 2.0]);

export interface BoundedVariantProposal {
  readonly label: string;
  readonly parametersChanged: Readonly<Record<string, { readonly from: number; readonly to: number }>>;
  readonly reason: string;
}

/**
 * Proposes testing a WIDER stop only when the caller's own
 * StrategyMarketFitEvidence already flags STOP_VS_MOVEMENT (the current
 * stop sits inside typical single-bar noise). Never proposes anything
 * when that evidence is absent or not flagged.
 */
export function proposeBoundedStopVariants(
  spec: StrategySpecification,
  fitEvidence: StrategyMarketFitEvidence,
): readonly BoundedVariantProposal[] {
  const stopFinding = fitEvidence.items.find((i) => i.dimension === 'STOP_VS_MOVEMENT');
  if (!stopFinding || !stopFinding.flagged) return Object.freeze([]);
  const current = spec.stop.distance;
  return Object.freeze(
    STOP_WIDENING_MULTIPLIERS.slice(0, MAX_BOUNDED_VARIANTS).map((mult) => {
      const to = Math.round(current * mult * 100) / 100;
      return Object.freeze({
        label: `stop=${to}`,
        parametersChanged: Object.freeze({ 'stop.distance': Object.freeze({ from: current, to }) }),
        reason: `Current stop (${current}) is only ${stopFinding.value.toFixed(2)}x the median observed bar range -- testing a wider stop (${mult}x current) to check whether that changes the outcome.`,
      });
    }),
  );
}
