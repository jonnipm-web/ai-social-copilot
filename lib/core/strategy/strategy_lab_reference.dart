/// INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 — Strategy #001 (V10) display mirror.
///
/// A pure, display-only Dart mirror of
/// `supabase/functions/_shared/strategy/v10_reference.ts` (the canonical,
/// server-validated Strategy Specification for
/// PAULO_TREND_FIBONACCI_V10_BIDIRECTIONAL_STEPPED). This file contains NO
/// validation logic and NO backtest logic -- the server (strategy_spec.ts)
/// is the sole validation authority; this is only a typed shape for the
/// Strategy Lab screen to render, the same relationship
/// `strategy001_contracts.dart` has to the server's action-table types.
///
/// PROVENANCE (updates the prior MACRO-04 finding): this macro located a
/// REAL, working local worktree at
/// C:\Users\jpaul\Documents\Codex\2026-08-10\
/// referenced-chatgpt-conversation-this-is-an\insightvalues-quant
/// (branch codex/qt01c36-hierarchical-fibonacci-structural-fidelity @
/// 4b9eb19b) containing the actual V10 Python source, 2541 passing tests,
/// and an EXACT reproduction of the historical reference numbers below
/// against the real WIN1! dataset. The prior finding (remote GitHub repo =
/// README only) is still accurate for that specific remote branch, but no
/// longer means the source itself is unverified -- it was simply never
/// pushed there. See docs/commercial/STRATEGY001_SOURCE_FINDING.md for the
/// full, updated diligence trail.
library;

class StrategyLabRule {
  const StrategyLabRule(this.ruleId, this.summary);
  final String ruleId;
  final String summary;
}

/// Read-only reference data for the Strategy Lab screen. Every numeric
/// value here was read directly from v10.py and independently reproduced
/// against the real WIN1! dataset this macro -- see the final report's
/// V10_NO_COST_RESULT / V10_COST_RESULT for the exact reproduction run.
class V10ReferenceStrategy {
  const V10ReferenceStrategy._();

  static const name = 'Strategy #001 — Paulo Trend Fibonacci V10 (Bidirectional Stepped)';
  static const status = 'RESEARCH';
  static const instrumentSymbol = 'WIN1!';
  static const signalTimeframe = '5min';
  static const timezone = 'America/Sao_Paulo';

  static const entry = StrategyLabRule('ENTRY.PULLBACK_IN_TREND', 'Pullback in the prevailing trend direction');
  static const stopDistance = 100.0;
  static const targetDistance = 250.0;
  static const breakEvenTriggerDistance = 50.0;
  static const breakEvenInitialProtectedDistance = 10.0;
  static const breakEvenStepDistance = 10.0;
  static const sessionStart = '10:00';
  static const sessionEnd = '16:00';
  static const forcedExitTime = '16:00';
  static const allowedWeekdays = 'Monday–Thursday';
  static const allowedDirections = 'LONG + SHORT';
  static const allowReversals = false;
  static const positionSizeQuantity = 1;

  // Real reproduction, this macro, against the real WIN1! dataset.
  static const zeroCostTradeCount = 75;
  static const zeroCostNetPnl = -57.0;
  static const zeroCostResultHash = 'c19661f4dfc61193';
  static const withCostTradeCount = 75;
  static const withCostNetPnl = -270.75;
  static const withCostResultHash = 'e79067f77120956d';
  static const gapThroughStopTradeCount = 19;

  static const costBrokeragePerContract = 0.75;
  static const costExchangeFeePerContract = 0.10;
  static const costSlippageTicks = 1.0;
}
