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

/** Macro-08 continuation §11 -- TARGET_VS_MOVEMENT flags a target that is
 * unrealistically FAR (> 5x the 90th-percentile observed move), the
 * opposite concern direction from stop (too close). Bounded exploration
 * here therefore tests NARROWER targets, at fixed, documented ratios --
 * same bounded/explainable posture as the stop multipliers, never a
 * search grid. */
const TARGET_NARROWING_MULTIPLIERS: readonly number[] = Object.freeze([0.9, 0.75, 0.6, 0.5]);

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

/**
 * Macro-08 continuation §11 -- generalizes the same evidence-motivated,
 * bounded pattern to TARGET (proposeBoundedStopVariants's original
 * comment doc applies identically here, only the market-fit dimension
 * and the direction of the fix differ). Proposes testing a NARROWER
 * target only when TARGET_VS_MOVEMENT is flagged (current target sits
 * far beyond typical observed moves) -- never when unflagged.
 */
export function proposeBoundedTargetVariants(
  spec: StrategySpecification,
  fitEvidence: StrategyMarketFitEvidence,
): readonly BoundedVariantProposal[] {
  const targetFinding = fitEvidence.items.find((i) => i.dimension === 'TARGET_VS_MOVEMENT');
  if (!targetFinding || !targetFinding.flagged) return Object.freeze([]);
  const current = spec.target.distance;
  return Object.freeze(
    TARGET_NARROWING_MULTIPLIERS.slice(0, MAX_BOUNDED_VARIANTS).map((mult) => {
      const to = Math.round(current * mult * 100) / 100;
      return Object.freeze({
        label: `target=${to}`,
        parametersChanged: Object.freeze({ 'target.distance': Object.freeze({ from: current, to }) }),
        reason: `Current target (${current}) is ${targetFinding.value.toFixed(2)}x the 90th-percentile observed bar move -- testing a narrower target (${mult}x current) to check whether that changes the outcome.`,
      });
    }),
  );
}

/** A parameter this module deliberately does NOT propose bounded
 * variants for, with the reason why -- reported explicitly rather than
 * silently omitted, so a caller never mistakes "no evidence dimension
 * exists yet" for "nothing to propose" (Macro-08 continuation §11: "if a
 * parameter cannot be generalized safely, report
 * UNSUPPORTED_BY_CURRENT_ENGINE rather than approximating it"). */
export interface UnsupportedParameter {
  readonly parameter: string;
  readonly reason: string;
}

/**
 * Combines every bounded-exploration dimension this module currently
 * supports (stop, target) and reports break-even as explicitly
 * unsupported -- ONLY when the strategy actually configures a
 * break-even rule, since an absent one has nothing to report a
 * limitation about. No market-fit evidence dimension measures
 * break-even distance against observed price movement yet (unlike
 * STOP_VS_MOVEMENT/TARGET_VS_MOVEMENT); inventing an unevidenced
 * perturbation would be exactly the fabricated-confidence failure mode
 * this whole module exists to avoid.
 */
export function proposeBoundedVariants(
  spec: StrategySpecification,
  fitEvidence: StrategyMarketFitEvidence,
): { proposals: readonly BoundedVariantProposal[]; unsupportedParameters: readonly UnsupportedParameter[] } {
  const proposals = Object.freeze([...proposeBoundedStopVariants(spec, fitEvidence), ...proposeBoundedTargetVariants(spec, fitEvidence)]);
  const unsupportedParameters: UnsupportedParameter[] = [];
  if (spec.breakEven) {
    unsupportedParameters.push({
      parameter: 'breakEven',
      reason: 'UNSUPPORTED_BY_CURRENT_ENGINE: no market-fit evidence dimension measures break-even distance against observed price movement yet -- proposing a variant here would be an unevidenced guess, not a bounded exploration.',
    });
  }
  return { proposals, unsupportedParameters: Object.freeze(unsupportedParameters) };
}
