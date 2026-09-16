// IVE-COMMERCIAL-STABILITY-09O-R — regression coverage for
// DiagnosticSessionNotifier's recover()/reset() lifecycle (mission
// sections 05/07/10), including the Codex Gate P1 fixes: a stale in-flight
// recover() from a just-signed-out user must never overwrite a different
// (or the same) user's state, and reset() must fully re-arm recovery for
// whoever authenticates next. Mocks DiagnosticLoggerService (same pattern
// as test/shared/widgets/ive_overlay_auth_gate_test.dart) so this
// exercises the NOTIFIER's own logic/state transitions without a live
// Supabase client — the server-side authorization boundary itself
// (diagnostic_sessions_admin_manage_own's RLS) is enforced in Postgres,
// not testable from this pure-Dart suite, and is covered by the migration
// file's own documentation/Codex review instead.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';

class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

void main() {
  late MockDiagnosticLoggerService logger;
  late DiagnosticSessionNotifier notifier;

  Map<String, dynamic> sessionRow(String id) => {
        'id': id,
        'label': null,
        'started_at': '2026-01-01T00:00:00.000Z',
      };

  setUp(() {
    logger = MockDiagnosticLoggerService();
    when(() => logger.currentUserId).thenReturn('user-a');
    final container = ProviderContainer(
      overrides: [diagnosticLoggerProvider.overrideWithValue(logger)],
    );
    addTearDown(container.dispose);
    notifier = container.read(diagnosticSessionProvider.notifier);
  });

  group('recover()', () {
    test('no authenticated user -> false, never queries the server', () async {
      when(() => logger.currentUserId).thenReturn(null);

      await notifier.recover();

      expect(notifier.state.isActive, isFalse);
      verifyNever(() => logger.findMyActiveSession());
    });

    test('no server-active session -> state stays inactive, nothing adopted', () async {
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => null);

      await notifier.recover();

      expect(notifier.state.isActive, isFalse);
      verifyNever(() => logger.adoptActiveSession(any()));
    });

    test('a real server-active session -> adopted and reflected in state', () async {
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => sessionRow('session-123'));

      await notifier.recover();

      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.sessionId, 'session-123');
      verify(() => logger.adoptActiveSession('session-123')).called(1);
    });

    test(
      'already tracking an active session locally -> no-op, never re-queries the server '
      '(mission section 05: "do not create a polling loop")',
      () async {
        when(() => logger.findMyActiveSession()).thenAnswer((_) async => sessionRow('session-already-active'));
        await notifier.recover(); // first call adopts it
        clearInteractions(logger);

        await notifier.recover(); // second call should short-circuit

        verifyNever(() => logger.findMyActiveSession());
      },
    );

    test(
      'a second recover() call for the SAME user while the first is still in flight does not '
      'double-query (guard is set before the await, not after)',
      () async {
        var callCount = 0;
        when(() => logger.findMyActiveSession()).thenAnswer((_) async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return sessionRow('session-x');
        });

        final first = notifier.recover();
        final second = notifier.recover();
        await Future.wait([first, second]);

        expect(callCount, 1);
      },
    );

    test(
      'a failed query (exception) is caught, never rethrown, and does not corrupt state '
      '(Codex Gate P2: observability must not throw during bootstrap)',
      () async {
        when(() => logger.findMyActiveSession()).thenThrow(Exception('network down'));

        await expectLater(notifier.recover(), completes);

        expect(notifier.state.isActive, isFalse);
      },
    );

    test(
      'CODEX GATE P1 — a stale recover() for a user who signed out mid-flight must NOT '
      'overwrite state with their (no-longer-current) session',
      () async {
        when(() => logger.currentUserId).thenReturn('user-a');
        when(() => logger.findMyActiveSession()).thenAnswer((_) async {
          // Simulates user-a signing out WHILE this query is in flight —
          // by the time the response arrives, the logger's own current
          // user has already changed.
          when(() => logger.currentUserId).thenReturn('user-b');
          return sessionRow('user-a-session');
        });

        await notifier.recover();

        expect(notifier.state.isActive, isFalse);
        verifyNever(() => logger.adoptActiveSession(any()));
      },
    );
  });

  group('reset() — mission section 10 (logout clears runtime session state)', () {
    test('clears in-memory state and detaches the logger, without a server call', () async {
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => sessionRow('session-to-clear'));
      await notifier.recover();
      expect(notifier.state.isActive, isTrue);

      when(() => logger.forgetActiveSession()).thenReturn(null);
      notifier.reset();

      expect(notifier.state.isActive, isFalse);
      verify(() => logger.forgetActiveSession()).called(1);
      // reset() is a local-only detach — it must never call the
      // server-authoritative stopSession() (that would end the OTHER
      // user's/next-login's still-legitimately-active session).
      verifyNever(() => logger.stopSession());
    });

    test('after reset(), a subsequent recover() for a DIFFERENT user re-queries fresh (user-switch isolation)', () async {
      when(() => logger.currentUserId).thenReturn('user-a');
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => sessionRow('user-a-session'));
      await notifier.recover();
      when(() => logger.forgetActiveSession()).thenReturn(null);
      notifier.reset();

      when(() => logger.currentUserId).thenReturn('user-b');
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => sessionRow('user-b-session'));
      await notifier.recover();

      expect(notifier.state.sessionId, 'user-b-session');
    });

    test(
      'CODEX GATE P1 — after reset(), a subsequent recover() for the SAME user id also '
      're-queries fresh, not permanently suppressed by the earlier attempt',
      () async {
        when(() => logger.currentUserId).thenReturn('user-a');
        when(() => logger.findMyActiveSession()).thenAnswer((_) async => sessionRow('user-a-first-session'));
        await notifier.recover();
        expect(notifier.state.sessionId, 'user-a-first-session');

        when(() => logger.forgetActiveSession()).thenReturn(null);
        notifier.reset();

        // Same user id signs back in and a NEW session is now active
        // server-side.
        when(() => logger.findMyActiveSession()).thenAnswer((_) async => sessionRow('user-a-second-session'));
        await notifier.recover();

        expect(notifier.state.sessionId, 'user-a-second-session');
      },
    );
  });
}
