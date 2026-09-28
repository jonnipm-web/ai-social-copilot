/**
 * Experiment Provenance — INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07
 * §15, §28-29.
 *
 * A dedicated, closed vocabulary for "what kind of thing produced this
 * result" -- deliberately its OWN table/type, NOT an extension of
 * result_learning.ts's `business_memory.memory_type` (that vocabulary
 * is explicitly documented there as closed to
 * 'success'|'failure'|'decision'; forcing five new categories into it
 * would violate that module's own stated contract). Persistence
 * (strategy_experiments table) is wired in strategy_server.ts; this
 * module is the pure validation/contamination logic, testable without
 * a database.
 */
import { fail, ok, type StrategyResult } from './errors.ts';
import type { BacktestCostAssumptions } from './backtest_result.ts';

export type ExperimentCategory = 'BACKTEST' | 'ROBUSTNESS_EXPERIMENT' | 'SIMULATION' | 'USER_DECISION' | 'IVE_RECOMMENDATION';
export const EXPERIMENT_CATEGORIES: readonly ExperimentCategory[] = Object.freeze([
  'BACKTEST', 'ROBUSTNESS_EXPERIMENT', 'SIMULATION', 'USER_DECISION', 'IVE_RECOMMENDATION',
]);

export type ExperimentSegment = 'FULL' | 'RESEARCH' | 'HOLDOUT';
export const EXPERIMENT_SEGMENTS: readonly ExperimentSegment[] = Object.freeze(['FULL', 'RESEARCH', 'HOLDOUT']);

export type ExperimentSource = 'USER' | 'IVE_PROPOSAL' | 'AUTOMATED_RESEARCH_LOOP';
export const EXPERIMENT_SOURCES: readonly ExperimentSource[] = Object.freeze(['USER', 'IVE_PROPOSAL', 'AUTOMATED_RESEARCH_LOOP']);

const MAX_REASON_LENGTH = 500;

export interface StrategyExperimentInput {
  readonly strategyId: string;
  readonly strategyVersionId: string;
  readonly category: ExperimentCategory;
  readonly datasetId: string;
  readonly segment: ExperimentSegment;
  /** e.g. {"stop.distance": {"from": 100, "to": 110}} -- plain JSON,
   * validated shallowly (must be a plain object, not an array/class
   * instance) so it stores safely as jsonb without becoming a place to
   * smuggle arbitrary structure. null when nothing was changed (e.g. a
   * plain BACKTEST run of an unmodified version). */
  readonly parametersChanged: Readonly<Record<string, unknown>> | null;
  /** The stated hypothesis/reason this experiment was run -- required
   * and non-empty: an experiment without a reason is exactly the
   * "giant grid search with no defensible reason" §16 forbids. */
  readonly reason: string;
  readonly resultId: string | null;
  readonly costAssumptions: BacktestCostAssumptions | null;
  readonly source: ExperimentSource;
}

export interface ValidatedStrategyExperiment extends StrategyExperimentInput {
  /** Computed by the caller from persisted history (see
   * computeContamination below) -- this module does not fetch history
   * itself, so a validated experiment does not yet carry this; the
   * store sets it at insert time. */
}

export function validateStrategyExperimentInput(input: StrategyExperimentInput): StrategyResult<StrategyExperimentInput> {
  if (!input || typeof input !== 'object') return fail('INVALID_STRATEGY_SPEC', 'experiment input must be an object');
  if (!EXPERIMENT_CATEGORIES.includes(input.category)) return fail('INVALID_STRATEGY_SPEC', 'unknown experiment category', { field: 'category' });
  if (!EXPERIMENT_SEGMENTS.includes(input.segment)) return fail('INVALID_STRATEGY_SPEC', 'unknown experiment segment', { field: 'segment' });
  if (!EXPERIMENT_SOURCES.includes(input.source)) return fail('INVALID_STRATEGY_SPEC', 'unknown experiment source', { field: 'source' });
  if (typeof input.reason !== 'string' || input.reason.trim().length === 0 || input.reason.length > MAX_REASON_LENGTH) {
    return fail('INVALID_STRATEGY_SPEC', `reason must be a non-empty string of at most ${MAX_REASON_LENGTH} characters`, { field: 'reason' });
  }
  if (input.parametersChanged !== null) {
    if (typeof input.parametersChanged !== 'object' || Array.isArray(input.parametersChanged)) {
      return fail('INVALID_STRATEGY_SPEC', 'parametersChanged must be a plain object or null', { field: 'parametersChanged' });
    }
  }
  return ok(input);
}

/**
 * `holdoutFirstViewedAt`: the strategy's own persisted timestamp of the
 * first HOLDOUT-segment experiment ever recorded for it (null if none
 * yet) -- the store is the single source of truth for this value (§14:
 * "Track contamination state"). A candidate created AT OR AFTER that
 * moment is contaminated: the holdout had already been seen by the time
 * this configuration decision was made. The strategy's very FIRST
 * holdout experiment is never contaminated by itself (it is the
 * observation, not a reaction to one).
 */
export function computeContamination(holdoutFirstViewedAt: string | null, candidateCreatedAt: string, isHoldoutSegmentItself: boolean): boolean {
  if (holdoutFirstViewedAt === null) return false;
  if (isHoldoutSegmentItself && Date.parse(candidateCreatedAt) <= Date.parse(holdoutFirstViewedAt)) return false;
  return Date.parse(candidateCreatedAt) >= Date.parse(holdoutFirstViewedAt);
}
