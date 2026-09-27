/**
 * Strategy #001 (V10) as the Reference Implementation —
 * INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §9, §27.
 *
 * Proves the generic StrategySpecification can represent
 * PAULO_TREND_FIBONACCI_V10_BIDIRECTIONAL_STEPPED with no V10-specific
 * schema branch anywhere in strategy_spec.ts. Every numeric value below
 * was read directly from the Python reference source (local worktree
 * codex/qt01c36-hierarchical-fibonacci-structural-fidelity @ 4b9eb19b,
 * insightvalues_quant/strategy_fidelity/v10.py) and independently
 * reproduced against the real WIN1! historical dataset this macro:
 *
 *   trades=75, net_pnl=-57.0 (zero cost), hash=c19661f4dfc61193
 *   trades=75, net_pnl=-270.75 (with cost), hash=e79067f77120956d
 *   19 of 75 trades executed at BAR_OPEN_GAP (execution_price_source)
 *
 * This module does NOT re-run that backtest (Strategy #001 keeps
 * executing in Python, §25) -- it only proves the CONFIGURATION side of
 * the round-trip: V10's parameters -> a valid, generic
 * StrategySpecification -> validateStrategySpecification() accepts it
 * with no special-casing.
 *
 * Status: RESEARCH. NOT paper/live eligible (§31).
 */
import { createStrategySpecification, type StrategySpecificationInput } from './strategy_spec.ts';

export const V10_REFERENCE_MARKET_PROFILE_INPUT = Object.freeze({
  instrument: Object.freeze({
    assetClass: 'FUTURE' as const,
    symbol: 'WIN1!',
    currency: 'BRL',
    exchangeTimezone: 'America/Sao_Paulo',
  }),
  tickSize: 5.0,
  tickValue: 1.0,
  contractMultiplier: 0.20,
  timezone: 'America/Sao_Paulo',
  sessionCalendarId: 'b3-win-2026',
  availableTimeframes: Object.freeze(['5min']),
  defaultCostAssumptions: Object.freeze({
    brokeragePerContract: 0.75,
    exchangeFeePerContract: 0.10,
    slippageTicks: 1.0,
    source: 'QT-01C.3 Run B — discount broker day-trade fees, manually declared public B3 spec',
  }),
});

/**
 * V10's exact configuration, mapped field-for-field from
 * strategy_fidelity/v10.py's kwargs into the generic rule vocabulary.
 * fixed_initial_stop_distance=100.0 -> stop.distance; fixed_target_
 * distance=250.0 -> target.distance; stepped_break_even_trigger/initial/
 * step=50/10/10 -> breakEven; entry_close_time=force_exit_time=16:00 and
 * the hardcoded `weekday() != 4` + `time(10,0) <= t < entry_close_time`
 * window (v4.py `entry_allowed`) -> session/forcedExit; allowed_directions
 * ={BULLISH,BEARISH}, allow_reversals=False -> allowedDirections/
 * allowReversals; quantity is the reproduction script's own quantity=1.
 */
export const V10_REFERENCE_SPEC_INPUT: StrategySpecificationInput = Object.freeze({
  name: 'Strategy #001 — Paulo Trend Fibonacci V10 (Bidirectional Stepped)',
  description:
    'Reference research strategy. NOT a proven profitable strategy, NOT live/paper-trading '
    + 'approved, NOT investment advice. Historical reference: 75 trades, net approx. -R$57 '
    + '(zero cost) / -R$270.75 (with QT-01C.3 Run B costs) on the real WIN1! 5-minute dataset.',
  marketProfile: V10_REFERENCE_MARKET_PROFILE_INPUT,
  signalTimeframe: '5min',
  executionTimeframe: null,
  allowedDirections: Object.freeze(['LONG', 'SHORT'] as const),
  allowReversals: false,
  entry: Object.freeze({ ruleId: 'ENTRY.PULLBACK_IN_TREND' }),
  stop: Object.freeze({ ruleId: 'STOP.FIXED_DISTANCE', distance: 100.0 }),
  target: Object.freeze({ ruleId: 'TARGET.FIXED_DISTANCE', distance: 250.0 }),
  breakEven: Object.freeze({
    ruleId: 'BREAK_EVEN.STEPPED',
    triggerDistance: 50.0,
    initialProtectedDistance: 10.0,
    stepDistance: 10.0,
  }),
  trailing: null,
  session: Object.freeze({
    ruleId: 'SESSION.WINDOW',
    startTime: '10:00',
    endTime: '16:00',
    allowedWeekdays: Object.freeze([1, 2, 3, 4]), // Monday-Thursday (v4.py: weekday() != 4, i.e. != Friday)
  }),
  forcedExit: Object.freeze({ ruleId: 'EXIT.FORCED_TIME', time: '16:00' }),
  positionSize: Object.freeze({ ruleId: 'POSITION_SIZE.FIXED_CONTRACTS', quantity: 1 }),
  riskLimits: null,
});

/** Builds and validates the V10 reference spec through the exact same
 * constructor any user-authored strategy goes through -- no bypass. */
export function buildV10ReferenceSpecification() {
  return createStrategySpecification(V10_REFERENCE_SPEC_INPUT);
}
