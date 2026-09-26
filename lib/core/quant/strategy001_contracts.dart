/// INSIGHTVALUES-COMMERCIAL-MACRO-01 Tranche 2 — Financial Intelligence /
/// Strategy001 ("Paulo Trend Fibonacci") contract scaffolding.
///
/// SCOPE, READ BEFORE EXTENDING THIS FILE:
///
/// This file is a data-contract mirror of the REAL, validated, tested
/// Python state machine that already exists in the separate
/// `insightvalues-quant` repository
/// (`insightvalues_quant/strategy001/models.py`) — field names, types, and
/// the state/event vocabulary below were copied from that source, not
/// invented. It contains ZERO of that engine's actual logic: no Fibonacci
/// math, no trend detection, no confirmation counting, no state
/// transitions. It only describes the SHAPE of what that engine already
/// produces, so a future Strategy Engine integration layer in this app has
/// a real, faithful target to deserialize into, instead of an ad-hoc map.
///
/// Per Strategy001's own README (`insightvalues-quant`, same path as
/// above): "This module produces state transitions and events only. It
/// never generates BUY, SELL, LONG, SHORT, or any trading signal. It never
/// integrates with Backtest, Portfolio, Risk, or any broker." These Dart
/// contracts inherit that same boundary — nothing here is a trading signal
/// or an execution instruction.
///
/// Explicitly NOT done here (mission hard boundaries, still standing):
/// - No port of the Fibonacci/trend/confirmation algorithm itself.
/// - No market-data provider, invented or real.
/// - No broker adapter, no order execution, no real-money path.
/// - No wiring into any route, screen, provider, or Supabase function —
///   `ive-quant` in module_registry.dart remains `commercialEnabled: false`,
///   `route: null`. This file is reachable by nothing yet.
/// - No AEF integration — a future Strategy Engine that acts on these
///   events, if ever built, would need its own AEF governance pass; that
///   is a separate, future, Owner-gated decision, not implied by this file
///   existing.
///
/// See docs/commercial/FINANCIAL_INTELLIGENCE_POSITIONING.md for the full
/// reasoning behind this scope decision.
library;

/// Mirrors `insightvalues_quant.structure.models.TrendDirection`.
enum TrendDirection { uptrend, downtrend, range, transition, unknown }

/// Mirrors `insightvalues_quant.strategy001.models.StrategyState`.
enum StrategyState {
  unknown,
  waitTrend,
  waitPullback,
  waitFibonacci,
  waitConfirmation,
  ready,
  triggered,
  target,
  expansion,
  exit,
  reset,
}

/// Mirrors `insightvalues_quant.strategy001.models.EventKind`.
enum EventKind {
  trendDetected,
  pullbackDetected,
  fibReady,
  confirmation1,
  confirmation2,
  ready,
  triggered,
  targetReached,
  expansionCandidate,
  resetRequired,
  strategyInvalidated,
}

/// Mirrors `insightvalues_quant.strategy001.models.StrategyEvent`
/// (`@dataclass(frozen=True)`).
class StrategyEvent {
  const StrategyEvent({
    required this.kind,
    required this.timestamp,
    required this.stateFrom,
    required this.stateTo,
    required this.reason,
    required this.barIndex,
    required this.configHash,
    required this.eventHash,
  });

  final EventKind kind;
  final DateTime timestamp;
  final StrategyState stateFrom;
  final StrategyState stateTo;
  final String reason;
  final int barIndex;

  /// Hash of the strategy config that produced this event — lets a caller
  /// detect a mid-stream config change without re-deriving it.
  final String configHash;

  /// Hash of this specific event's content — lets a caller de-duplicate
  /// or verify integrity without re-deriving it.
  final String eventHash;
}

/// Mirrors `insightvalues_quant.strategy001.models.BarSnapshot`
/// (`@dataclass(frozen=True)`).
class BarSnapshot {
  const BarSnapshot({
    required this.barIndex,
    required this.timestamp,
    required this.state,
    required this.events,
    required this.confirmationCount,
    this.trendDirection,
    this.targetPrice,
    this.breakoutBarIndex,
  });

  final int barIndex;
  final DateTime timestamp;
  final StrategyState state;
  final List<StrategyEvent> events;
  final int confirmationCount;
  final TrendDirection? trendDirection;
  final double? targetPrice;
  final int? breakoutBarIndex;
}

/// Mirrors `insightvalues_quant.strategy001.models.Strategy001Result` — the
/// top-level shape a future integration would receive for one backtest/run.
class Strategy001Result {
  const Strategy001Result({
    this.snapshots = const [],
    this.events = const [],
    this.finalState = StrategyState.unknown,
    this.configHash = '',
  });

  final List<BarSnapshot> snapshots;
  final List<StrategyEvent> events;
  final StrategyState finalState;
  final String configHash;

  /// Mirrors the Python model's `events_by_kind` property.
  Map<EventKind, List<StrategyEvent>> get eventsByKind {
    final result = <EventKind, List<StrategyEvent>>{};
    for (final event in events) {
      (result[event.kind] ??= []).add(event);
    }
    return result;
  }
}
