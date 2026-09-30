/**
 * Second Reference Strategy — INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §11.
 *
 * A deliberately simple, non-proprietary strategy built through the SAME
 * generic StrategySpecification constructor V10 goes through, running on
 * the GENERIC_RULE_ENGINE against the synthetic fixture dataset --
 * architectural proof that the platform is not hardcoded to Strategy
 * #001/V10. NOT a claim of profitability, NOT optimized for P&L (§11).
 */
import { createStrategySpecification, type StrategySpecificationInput } from './strategy_spec.ts';
import { SYNTHETIC_5MIN_DATASET } from './dataset_registry.ts';

export const GENERIC_REFERENCE_SPEC_INPUT: StrategySpecificationInput = Object.freeze({
  name: 'Generic Session-Open Bracket (architecture proof, not a recommendation)',
  description:
    'Enters LONG at the first bar of the session window every session, with a fixed stop/target bracket. '
    + 'Exists to prove the generic Strategy Specification -> GENERIC_RULE_ENGINE path end-to-end. '
    + 'No signal condition, no edge claimed, NOT investment advice.',
  marketProfile: Object.freeze({
    instrument: Object.freeze({
      assetClass: 'INDEX' as const,
      symbol: SYNTHETIC_5MIN_DATASET.instrumentSymbol,
      currency: 'USD',
      exchangeTimezone: 'UTC',
    }),
    tickSize: 1,
    tickValue: 1,
    contractMultiplier: 1,
    timezone: 'UTC',
    sessionCalendarId: 'synthetic-fixture',
    availableTimeframes: Object.freeze(['5min']),
  }),
  signalTimeframe: '5min',
  executionTimeframe: null,
  allowedDirections: Object.freeze(['LONG'] as const),
  allowReversals: false,
  entry: Object.freeze({ ruleId: 'ENTRY.SESSION_OPEN' }),
  stop: Object.freeze({ ruleId: 'STOP.FIXED_DISTANCE', distance: 5 }),
  target: Object.freeze({ ruleId: 'TARGET.FIXED_DISTANCE', distance: 10 }),
  breakEven: null,
  trailing: null,
  session: Object.freeze({
    ruleId: 'SESSION.WINDOW',
    startTime: '13:00',
    endTime: '14:00',
    allowedWeekdays: Object.freeze([1, 2, 3, 4, 5]),
  }),
  forcedExit: Object.freeze({ ruleId: 'EXIT.FORCED_TIME', time: '14:00' }),
  positionSize: Object.freeze({ ruleId: 'POSITION_SIZE.FIXED_CONTRACTS', quantity: 1 }),
  riskLimits: null,
});

export function buildGenericReferenceSpecification() {
  return createStrategySpecification(GENERIC_REFERENCE_SPEC_INPUT);
}
