/**
 * Multi-Criteria Strategy Score — INSIGHTVALUES-STRATEGY-INTELLIGENCE-
 * MACRO-07 §17-18.
 *
 * A transparent, component-based score -- never a single opaque
 * "profit score" (§17). Every component's value and rationale is
 * exposed; the overall number is a documented weighted sum of exactly
 * those components, nothing hidden. The output `language` is drawn from
 * a closed, pre-approved vocabulary (§18) -- this module can NEVER
 * produce "best", "guaranteed", or "optimal" language, because those
 * strings do not exist anywhere in this file.
 */
import type { CanonicalBacktestResult } from './backtest_result.ts';
import type { StrategyObjective } from './user_objective.ts';
import { directionalBalance, executionAmbiguityRate, sampleSizeSufficiency } from './robustness.ts';

export interface ScoreComponent {
  readonly name: 'PROFITABILITY' | 'SAMPLE_SIZE' | 'EXECUTION_AMBIGUITY' | 'DRAWDOWN_CONTROL' | 'DIRECTIONAL_COVERAGE';
  readonly value: number; // normalized 0-1
  readonly weight: number; // 0-1, sums to 1 across all components
  readonly rationale: string;
}

export type ScoreLanguage = 'MORE_ROBUST_UNDER_TESTED_ASSUMPTIONS' | 'REQUIRES_MORE_EVIDENCE';

export interface StrategyScore {
  readonly components: readonly ScoreComponent[];
  readonly overall: number; // 0-100
  readonly language: ScoreLanguage;
}

interface WeightSet {
  readonly profitability: number;
  readonly sampleSize: number;
  readonly ambiguity: number;
  readonly drawdownControl: number;
  readonly directionalCoverage: number;
}

const DEFAULT_WEIGHTS: WeightSet = { profitability: 0.25, sampleSize: 0.20, ambiguity: 0.15, drawdownControl: 0.25, directionalCoverage: 0.15 };

/** Only objectives with a documented, defensible reweighting are
 * listed -- CUSTOM_CONSTRAINTS and BALANCED fall through to
 * DEFAULT_WEIGHTS rather than inventing a bespoke recipe. */
const WEIGHTS_BY_OBJECTIVE: Partial<Record<StrategyObjective, WeightSet>> = Object.freeze({
  CAPITAL_PRESERVATION: { profitability: 0.10, sampleSize: 0.15, ambiguity: 0.15, drawdownControl: 0.50, directionalCoverage: 0.10 },
  LOW_DRAWDOWN: { profitability: 0.15, sampleSize: 0.15, ambiguity: 0.15, drawdownControl: 0.45, directionalCoverage: 0.10 },
  STABILITY: { profitability: 0.10, sampleSize: 0.30, ambiguity: 0.30, drawdownControl: 0.20, directionalCoverage: 0.10 },
  RETURN_WITHIN_RISK_LIMIT: { profitability: 0.30, sampleSize: 0.15, ambiguity: 0.10, drawdownControl: 0.35, directionalCoverage: 0.10 },
  LOW_FREQUENCY: { profitability: 0.20, sampleSize: 0.30, ambiguity: 0.20, drawdownControl: 0.20, directionalCoverage: 0.10 },
});

function clamp01(x: number): number {
  return Math.max(0, Math.min(1, x));
}

/** Profit factor capped at this value before normalizing to [0,1] --
 * chosen so an ordinary profitable result lands well short of 1.0
 * rather than saturating the component at a modest edge. Fixed and
 * documented, never tuned per strategy. */
const PROFIT_FACTOR_CAP = 3.0;

export function computeStrategyScore(result: CanonicalBacktestResult, objective: StrategyObjective | null): StrategyScore {
  const weights = (objective && WEIGHTS_BY_OBJECTIVE[objective]) ?? DEFAULT_WEIGHTS;

  const profitability: ScoreComponent = result.profitFactor !== null
    ? {
      name: 'PROFITABILITY', value: clamp01(result.profitFactor / PROFIT_FACTOR_CAP), weight: weights.profitability,
      rationale: `profit factor ${result.profitFactor.toFixed(2)}, normalized against a cap of ${PROFIT_FACTOR_CAP}`,
    }
    : { name: 'PROFITABILITY', value: 0, weight: weights.profitability, rationale: 'profit factor undefined (no losing trades or zero gross loss)' };

  const sampleFinding = sampleSizeSufficiency(result);
  const sampleSize: ScoreComponent = {
    name: 'SAMPLE_SIZE', value: clamp01(sampleFinding.tradeCount / sampleFinding.threshold), weight: weights.sampleSize,
    rationale: `${sampleFinding.tradeCount} trades against a ${sampleFinding.threshold}-trade sufficiency threshold`,
  };

  const ambiguityFinding = executionAmbiguityRate(result);
  const ambiguity: ScoreComponent = {
    name: 'EXECUTION_AMBIGUITY', value: ambiguityFinding.rate === null ? 1 : clamp01(1 - ambiguityFinding.rate), weight: weights.ambiguity,
    rationale: ambiguityFinding.rate === null
      ? 'no trades to measure execution ambiguity from'
      : `${ambiguityFinding.ambiguousCount} of ${ambiguityFinding.tradeCount} trades had an ambiguous execution price source`,
  };

  // Codex final audit (P2-01 fix): an unmeasured drawdown used to get a
  // neutral value of 0.5, which still CONTRIBUTED to the weighted sum
  // -- a strategy with no drawdown evidence at all could still reach
  // MORE_ROBUST_UNDER_TESTED_ASSUMPTIONS partly on the strength of a
  // component that measured nothing. Now it is excluded from the
  // weighted sum entirely (weight 0 in the OUTPUT, value 0, rationale
  // says so) and the other four components' weights are renormalized
  // to still sum to 1 among themselves -- the score reflects only what
  // was actually measured, never a placeholder standing in for missing
  // evidence.
  const drawdownAvailable = result.maxDrawdown !== null;
  const grossProfitMagnitude = Math.abs(result.grossProfit) || 1;
  const drawdownRawWeight = weights.drawdownControl;
  const renormalizer = drawdownAvailable ? 1 : 1 / (1 - drawdownRawWeight);

  const drawdownControl: ScoreComponent = drawdownAvailable
    ? {
      name: 'DRAWDOWN_CONTROL', value: clamp01(1 - Math.abs(result.maxDrawdown!) / grossProfitMagnitude), weight: drawdownRawWeight,
      rationale: `max drawdown ${result.maxDrawdown!.toFixed(2)} against gross profit ${result.grossProfit.toFixed(2)}`,
    }
    : {
      name: 'DRAWDOWN_CONTROL', value: 0, weight: 0,
      rationale: 'maxDrawdown was not measured for this result -- excluded from the score entirely (the other components\' weights are renormalized), never assigned a placeholder value',
    };

  const balance = directionalBalance(result);
  const directionalCoverage: ScoreComponent = {
    name: 'DIRECTIONAL_COVERAGE', value: balance.untested !== null ? 0.5 : 1, weight: weights.directionalCoverage * renormalizer,
    rationale: balance.untested !== null ? `no trades were ever taken on the ${balance.untested} side` : 'both allowed directions produced trades',
  };

  const components = Object.freeze([
    { ...profitability, weight: profitability.weight * renormalizer },
    { ...sampleSize, weight: sampleSize.weight * renormalizer },
    { ...ambiguity, weight: ambiguity.weight * renormalizer },
    drawdownControl,
    directionalCoverage,
  ]);
  const overall = Math.round(100 * components.reduce((s, c) => s + c.value * c.weight, 0));

  return Object.freeze({
    components,
    overall,
    language: overall >= 60 ? 'MORE_ROBUST_UNDER_TESTED_ASSUMPTIONS' : 'REQUIRES_MORE_EVIDENCE',
  });
}
