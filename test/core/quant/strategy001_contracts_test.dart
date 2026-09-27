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
}
