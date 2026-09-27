/// INSIGHTVALUES-COMMERCIAL-MACRO-01 Tranche 2 — Financial Intelligence /
/// Strategy001 ("Paulo Trend Fibonacci") contract scaffolding.
///
/// SCOPE, READ BEFORE EXTENDING THIS FILE:
///
/// This file is a data-contract mirror of a Python state machine this
/// mission's provenance claims describe as living in the separate
/// `insightvalues-quant` repository (`insightvalues_quant/strategy001/models.py`)
/// — field names, types, and the state/event vocabulary below were written
/// to match that description, not invented from nothing. It contains ZERO
/// of that engine's actual logic: no Fibonacci math, no trend detection, no
/// confirmation counting, no state transitions. It only describes a SHAPE,
/// so a future Strategy Engine integration layer in this app has a real,
/// faithful target to deserialize into, instead of an ad-hoc map.
///
/// PROVENANCE STATUS (updated INSIGHTVALUES-ROBOT-BUILDER-MACRO-05,
/// supersedes the MACRO-04 finding below): the real source was found and
/// directly inspected. A local worktree at
/// `C:\Users\jpaul\Documents\Codex\2026-08-10\referenced-chatgpt-
/// conversation-this-is-an\insightvalues-quant` (branch
/// `codex/qt01c36-hierarchical-fibonacci-structural-fidelity` @ `4b9eb19b`,
/// remote = the SAME `jonnipm-web/insightvalues-quant` repo MACRO-04 found
/// empty on `main` — the work existed on an unpushed branch) contains a
/// real `insightvalues_quant/strategy001/` package (`engine.py`,
/// `evaluator.py`, `state_machine.py`, `events.py`, `models.py`,
/// `config.py`, `audit.py`, `README.md`) and `insightvalues_quant/
/// fibonacci/` package, with real, passing tests (`test_strategy001_*.py` x
/// 7, `test_fibonacci_*.py` x 9, among 2541 total passing this worktree).
/// `strategy001/README.md`'s own text is a WORD-FOR-WORD match for the
/// Tranche 2 positioning doc's quote below, and its state/event vocabulary
/// (TREND_DETECTED, PULLBACK_DETECTED, FIB_READY, CONFIRMATION_1/2, READY,
/// TRIGGERED, TARGET_REACHED, EXPANSION_CANDIDATE, RESET_REQUIRED,
/// STRATEGY_INVALIDATED) is an exact match for this file's `EventKind`
/// below. The original Tranche 2 claim is CORROBORATED, not merely
/// no-longer-disproven. See docs/commercial/STRATEGY001_SOURCE_FINDING.md
/// for the full, updated diligence trail (including the still-accurate
/// original MACRO-04 finding for the specific `main` branch it checked).
///
/// Per the positioning doc's own quote of Strategy001's README: "This
/// module produces state transitions and events only. It never generates
/// BUY, SELL, LONG, SHORT, or any trading signal. It never integrates with
/// Backtest, Portfolio, Risk, or any broker." These Dart contracts inherit
/// that same boundary regardless of the provenance question above —
/// nothing here is a trading signal or an execution instruction, and the
/// Action Intent mapping added below (MACRO-04 §15-17) only ever proposes
/// a human ACKNOWLEDGMENT of a structural event through AEF, never a trade.
///
/// Explicitly NOT done here (mission hard boundaries, still standing):
/// - No port of the Fibonacci/trend/confirmation algorithm itself.
/// - No market-data provider, invented or real.
/// - No broker adapter, no order execution, no real-money path.
/// - No wiring into any route, screen, provider, or Supabase function —
///   `ive-quant` in module_registry.dart remains `commercialEnabled: false`,
///   `route: null`. This file is reachable by nothing yet.
///
/// See docs/commercial/FINANCIAL_INTELLIGENCE_POSITIONING.md and
/// docs/commercial/STRATEGY001_SOURCE_FINDING.md for the full reasoning.
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
/// (`@dataclass(frozen=True)`). `events` is defensively copied into an
/// unmodifiable list (Codex Tranche 2 audit, P3) to match the Python
/// model's own `tuple[StrategyEvent, ...]` immutability -- a caller cannot
/// mutate this snapshot's event list after construction.
class BarSnapshot {
  BarSnapshot({
    required this.barIndex,
    required this.timestamp,
    required this.state,
    required List<StrategyEvent> events,
    required this.confirmationCount,
    this.trendDirection,
    this.targetPrice,
    this.breakoutBarIndex,
  }) : events = List.unmodifiable(events);

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
/// `snapshots`/`events` are defensively copied into unmodifiable lists
/// (Codex Tranche 2 audit, P3), same reasoning as [BarSnapshot.events].
class Strategy001Result {
  Strategy001Result({
    List<BarSnapshot> snapshots = const [],
    List<StrategyEvent> events = const [],
    this.finalState = StrategyState.unknown,
    this.configHash = '',
  })  : snapshots = List.unmodifiable(snapshots),
        events = List.unmodifiable(events);

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

/// INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §15-17 — Quant -> Action
/// Intent -> AEF. Snake_case mirror of [EventKind]'s own values, matching
/// exactly what aef/runtime/lab_tools.ts's
/// `internal.mock_quant_signal_acknowledgment` tool accepts as its
/// `event_kind` field. A manual, individually-tested mapping (not a
/// generated `.name`) so a future [EventKind] addition fails a test here
/// instead of silently producing a value the server-side schema enum would
/// reject.
String eventKindToAcknowledgmentValue(EventKind kind) => switch (kind) {
      EventKind.trendDetected => 'trend_detected',
      EventKind.pullbackDetected => 'pullback_detected',
      EventKind.fibReady => 'fib_ready',
      EventKind.confirmation1 => 'confirmation_1',
      EventKind.confirmation2 => 'confirmation_2',
      EventKind.ready => 'ready',
      EventKind.triggered => 'triggered',
      EventKind.targetReached => 'target_reached',
      EventKind.expansionCandidate => 'expansion_candidate',
      EventKind.resetRequired => 'reset_required',
      EventKind.strategyInvalidated => 'strategy_invalidated',
    };

/// Turns a real [StrategyEvent] into the exact parameter shape
/// `internal.mock_quant_signal_acknowledgment` expects (the shape an
/// `AefActionCard`/`AefRuntimeApi.propose()` caller would pass through).
/// Pure data transformation — no algorithm logic, no market
/// interpretation, no decision of any kind. Display convenience only,
/// never trusted: the server re-validates every field regardless, exactly
/// like Action Engine's own `initialValues` (aef_action_card.dart).
Map<String, String> strategyEventToAcknowledgmentParameters(StrategyEvent event, {required String signalId}) => {
      'signal_id': signalId,
      'event_kind': eventKindToAcknowledgmentValue(event.kind),
      'note': '${event.reason} (bar ${event.barIndex}: ${event.stateFrom.name} -> ${event.stateTo.name})',
    };
