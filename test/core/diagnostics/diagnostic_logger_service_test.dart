// IVE-COMMERCIAL-STABILITY-08 — regression coverage for
// newDiagnosticCorrelationId(), the pure top-level helper in
// diagnostic_logger_service.dart. Importing the file does not require a
// live Supabase client (that's only needed to construct
// DiagnosticLoggerService itself, which this test never does).
//
// IVE-COMMERCIAL-STABILITY-09O-SHA — also covers buildDiagnosticEventPayload,
// the pure function extracted specifically so event-level build_sha (and
// the rest of the payload shape) is testable without a live Supabase
// client, matching this file's own existing convention above.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/core/diagnostics/diagnostic_models.dart';

void main() {
  group('buildDiagnosticEventPayload — IVE-COMMERCIAL-STABILITY-09O-SHA', () {
    Map<String, Object?> payload({Object? error, StackTrace? stackTrace}) =>
        buildDiagnosticEventPayload(
          sessionId: 'session-1',
          userId: 'user-1',
          category: DiagnosticCategory.runtime,
          eventName: 'uncaught_error',
          severity: DiagnosticSeverity.critical,
          route: '/dashboard',
          status: 'failure',
          error: error,
          stackTrace: stackTrace,
        );

    test('every event gets the runtime\'s current build_sha (kBuildSha) — never absent', () {
      final row = payload();
      // In a `flutter test` run, no --dart-define=BUILD_SHA is supplied,
      // so kBuildSha is the documented "unknown" fallback (see
      // build_info_test.dart) — the point here is that the KEY is always
      // present and populated from the runtime constant, not that its
      // value is any particular SHA.
      expect(row['build_sha'], 'unknown');
    });

    test('caller cannot substitute a build SHA — there is no parameter for one', () {
      // Structural, not behavioral: buildDiagnosticEventPayload's own
      // signature has no buildSha/build_sha argument at all (unlike the
      // pre-STABILITY-09O startSession(), which the 09O mission had to
      // actively CLOSE that surface on). This test documents the
      // invariant by construction — it would fail to COMPILE, not just
      // fail an assertion, if a future edit ever reintroduced one and a
      // caller here tried to use it.
      final row = payload();
      expect(row.containsKey('build_sha'), isTrue);
    });

    test('session build_sha and event build_sha are independent columns (no session dependency here)', () {
      // buildDiagnosticEventPayload never reads or references
      // diagnostic_sessions.build_sha in any way -- sessionId is passed
      // through verbatim as the foreign key, nothing more. This is the
      // whole point of the mission: an event's build identity must never
      // be DERIVED from the session's.
      final row = payload();
      expect(row['session_id'], 'session-1');
      expect(row['build_sha'], isNotNull);
    });

    test('build_sha survives serialization alongside the rest of the row unchanged', () {
      final row = payload(error: Exception('boom'), stackTrace: StackTrace.current);
      expect(row['build_sha'], 'unknown');
      expect(row['error_message'], contains('boom'));
      expect(row['route'], '/dashboard');
      expect(row['event_name'], 'uncaught_error');
    });

    test('privacy sanitizer (sanitizeBuildSha, reused from STABILITY-09O) does not redact the valid fallback', () {
      // "unknown" is explicitly allowlisted by sanitizeBuildSha (see its
      // own test suite in diagnostic_sanitizer_test.dart) -- this just
      // confirms that guarantee actually reaches the final row, not only
      // the sanitizer function in isolation.
      final row = payload();
      expect(row['build_sha'], isNot(contains('[redacted]')));
    });
  });


  group(
    'newDiagnosticCorrelationId — IVE-COMMERCIAL-STABILITY-08 '
    '(RangeError "max ... was 0" root cause: 1 << 32 dart2js web trap, '
    'dart-lang/sdk#37569)',
    () {
      test('never throws across many calls (regression for the proven RangeError)', () {
        for (var i = 0; i < 500; i++) {
          expect(() => newDiagnosticCorrelationId(), returnsNormally);
        }
      });

      test('matches the app-generated correlation-id shape (two base36 runs, one hyphen)', () {
        final id = newDiagnosticCorrelationId();
        expect(id, matches(RegExp(r'^[0-9a-z]+-[0-9a-z]+$')));
      });

      test('calls in quick succession are all unique', () {
        final ids = List.generate(200, (_) => newDiagnosticCorrelationId());
        expect(ids.toSet().length, ids.length);
      });
    },
  );
}
