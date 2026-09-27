/**
 * Strategy Status Lifecycle — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §31.
 *
 * Promotion is never automatic past BACKTESTED/RESEARCH: §31 is explicit
 * that "promotion must depend on evidence/policy," and §55/§56 make
 * SIMULATION_ELIGIBLE/PAPER_ELIGIBLE/LIVE_ELIGIBLE an Owner Gate (paper
 * trading activation, real-money trading are hard boundaries this macro
 * may not cross). This module therefore hard-codes the evidence each
 * transition requires and refuses every transition this macro has no
 * authorization to grant, rather than leaving the ceiling implicit.
 */
import { fail, ok, type StrategyResult } from './errors.ts';

export type StrategyStatus =
  | 'DRAFT'
  | 'VALIDATED'
  | 'BACKTESTED'
  | 'RESEARCH'
  | 'SIMULATION_ELIGIBLE'
  | 'PAPER_ELIGIBLE'
  | 'LIVE_ELIGIBLE'
  | 'PAUSED'
  | 'RETIRED';

export const ALL_STRATEGY_STATUSES: readonly StrategyStatus[] = Object.freeze([
  'DRAFT', 'VALIDATED', 'BACKTESTED', 'RESEARCH', 'SIMULATION_ELIGIBLE',
  'PAPER_ELIGIBLE', 'LIVE_ELIGIBLE', 'PAUSED', 'RETIRED',
]);

export interface PromotionEvidence {
  readonly hasValidSpec: boolean;
  readonly hasBacktestResult: boolean;
  /** Explicit Owner/policy authorization for a gated promotion. This macro
   * never sets this true itself -- it exists so the type honestly models
   * that a future, authorized macro CAN extend the ceiling without a
   * redesign, not so this macro can flip it. */
  readonly ownerAuthorizedSimulationOrAbove: boolean;
}

const AUTOMATIC_TRANSITIONS: ReadonlyMap<StrategyStatus, readonly StrategyStatus[]> = new Map([
  ['DRAFT', ['VALIDATED']],
  ['VALIDATED', ['DRAFT', 'BACKTESTED']],
  ['BACKTESTED', ['VALIDATED', 'RESEARCH']],
  ['RESEARCH', ['BACKTESTED', 'PAUSED']],
  ['PAUSED', ['RESEARCH', 'RETIRED']],
  ['SIMULATION_ELIGIBLE', ['PAUSED', 'RETIRED']],
  ['PAPER_ELIGIBLE', ['PAUSED', 'RETIRED']],
  ['LIVE_ELIGIBLE', ['PAUSED', 'RETIRED']],
  ['RETIRED', []],
]);

/** Gated ceilings this macro documents but never authorizes crossing into
 * automatically -- reaching them requires ownerAuthorizedSimulationOrAbove,
 * which nothing in this macro's code ever sets true. */
const GATED_TRANSITIONS: ReadonlySet<StrategyStatus> = new Set(['SIMULATION_ELIGIBLE', 'PAPER_ELIGIBLE', 'LIVE_ELIGIBLE']);

export function canPromote(
  current: StrategyStatus,
  target: StrategyStatus,
  evidence: PromotionEvidence,
): StrategyResult<true> {
  if (current === target) return fail('PROMOTION_DENIED', 'no-op transition', { current, target });

  if (GATED_TRANSITIONS.has(target)) {
    if (!evidence.ownerAuthorizedSimulationOrAbove) {
      return fail('PROMOTION_DENIED', 'simulation/paper/live eligibility requires explicit Owner authorization', {
        current,
        target,
      });
    }
    if (current !== 'RESEARCH') {
      return fail('PROMOTION_DENIED', 'only a RESEARCH strategy may be considered for simulation/paper/live', {
        current,
        target,
      });
    }
  }

  const allowed = AUTOMATIC_TRANSITIONS.get(current) ?? [];
  if (!allowed.includes(target) && !GATED_TRANSITIONS.has(target)) {
    return fail('PROMOTION_DENIED', 'transition not permitted from current status', { current, target });
  }

  if (target === 'VALIDATED' && !evidence.hasValidSpec) {
    return fail('PROMOTION_DENIED', 'VALIDATED requires a spec that passed validateStrategySpecification', { current, target });
  }
  if (target === 'BACKTESTED' && !evidence.hasBacktestResult) {
    return fail('PROMOTION_DENIED', 'BACKTESTED requires at least one canonical backtest result', { current, target });
  }

  return ok(true);
}
