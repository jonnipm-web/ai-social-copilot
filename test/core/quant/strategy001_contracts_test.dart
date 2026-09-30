// INSIGHTVALUES-COMMERCIAL-MACRO-01 Tranche 2 — coverage for the
// Strategy001 Dart contract mirror (lib/core/quant/strategy001_contracts.dart).
//
// This is pure data-contract scaffolding with no algorithm to test; the one
// piece of real logic is Strategy001Result.eventsByKind, which mirrors the
// Python model's `events_by_kind` property.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/quant/strategy001_contracts.dart';

StrategyEvent _event(EventKind kind, int barIndex) => StrategyEvent(
      kind: kind,
      timestamp: DateTime(2026, 1, 1),
      stateFrom: StrategyState.waitTrend,
      stateTo: StrategyState.waitPullback,
      reason: 'test',
      barIndex: barIndex,
      configHash: 'hash-config',
      eventHash: 'hash-event-$barIndex',
    );

void main() {
  group('Strategy001Result.eventsByKind', () {
    test('groups events by kind, preserving order within each group', () {
      final result = Strategy001Result(
        events: [
          _event(EventKind.trendDetected, 1),
          _event(EventKind.pullbackDetected, 2),
          _event(EventKind.trendDetected, 3),
        ],
      );

      final byKind = result.eventsByKind;

      expect(byKind[EventKind.trendDetected]?.map((e) => e.barIndex), [1, 3]);
      expect(byKind[EventKind.pullbackDetected]?.map((e) => e.barIndex), [2]);
      expect(byKind.containsKey(EventKind.triggered), isFalse);
    });

    test('an empty result has an empty map, not a missing/null one', () {
      expect(Strategy001Result().eventsByKind, isEmpty);
    });

    test('events/snapshots are unmodifiable (Codex Tranche 2 audit, P3)', () {
      final result = Strategy001Result(events: [_event(EventKind.trendDetected, 1)]);
      expect(() => result.events.add(_event(EventKind.triggered, 2)), throwsUnsupportedError);
    });
  });

  group('BarSnapshot', () {
    test('nullable fields (trendDirection/targetPrice/breakoutBarIndex) default to null', () {
      final snapshot = BarSnapshot(
        barIndex: 0,
        timestamp: DateTime(2026, 1, 1),
        state: StrategyState.unknown,
        events: const [],
        confirmationCount: 0,
      );
      expect(snapshot.trendDirection, isNull);
      expect(snapshot.targetPrice, isNull);
      expect(snapshot.breakoutBarIndex, isNull);
    });

    test('events is unmodifiable (Codex Tranche 2 audit, P3)', () {
      final snapshot = BarSnapshot(
        barIndex: 0,
        timestamp: DateTime(2026, 1, 1),
        state: StrategyState.unknown,
        events: [_event(EventKind.trendDetected, 1)],
        confirmationCount: 0,
      );
      expect(() => snapshot.events.add(_event(EventKind.triggered, 2)), throwsUnsupportedError);
    });
  });

  // INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §15-17 — Quant -> Action
  // Intent -> AEF. These prove the mapping stays in lockstep with the
  // server-side tool schema (aef/runtime/lab_tools.ts's
  // internal.mock_quant_signal_acknowledgment `event_kind` enum) -- every
  // EventKind value must produce a string that schema actually accepts.
  group('eventKindToAcknowledgmentValue (Quant -> Action Intent -> AEF)', () {
    test('every EventKind maps to the exact snake_case value the server tool schema accepts', () {
      const expected = {
        EventKind.trendDetected: 'trend_detected',
        EventKind.pullbackDetected: 'pullback_detected',
        EventKind.fibReady: 'fib_ready',
        EventKind.confirmation1: 'confirmation_1',
        EventKind.confirmation2: 'confirmation_2',
        EventKind.ready: 'ready',
        EventKind.triggered: 'triggered',
        EventKind.targetReached: 'target_reached',
        EventKind.expansionCandidate: 'expansion_candidate',
        EventKind.resetRequired: 'reset_required',
        EventKind.strategyInvalidated: 'strategy_invalidated',
      };
      // Exhaustive over the real enum -- a future EventKind value with no
      // entry above fails HERE (compile error on the switch), not silently
      // at the server.
      for (final kind in EventKind.values) {
        expect(eventKindToAcknowledgmentValue(kind), expected[kind], reason: kind.name);
      }
      expect(expected.length, EventKind.values.length, reason: 'every EventKind must be covered');
    });
  });

  group('strategyEventToAcknowledgmentParameters (Quant -> Action Intent -> AEF)', () {
    test('produces exactly the three keys internal.mock_quant_signal_acknowledgment requires, nothing else', () {
      final event = _event(EventKind.triggered, 7);
      final params = strategyEventToAcknowledgmentParameters(event, signalId: 'sig-1');
      expect(params.keys.toSet(), {'signal_id', 'event_kind', 'note'});
      expect(params['signal_id'], 'sig-1');
      expect(params['event_kind'], 'triggered');
      expect(params['note'], contains('bar 7'));
      expect(params['note'], contains('test')); // the event's own reason
    });

    test('never fabricates a trading signal -- the note is a structural description, not an instruction', () {
      final event = _event(EventKind.targetReached, 3);
      final params = strategyEventToAcknowledgmentParameters(event, signalId: 'sig-2');
      for (final word in ['buy', 'sell', 'long', 'short', 'order', 'trade']) {
        expect(params['note']!.toLowerCase(), isNot(contains(word)), reason: word);
      }
    });
  });
}
