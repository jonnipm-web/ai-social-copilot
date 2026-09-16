// IVE-COMMERCIAL-STABILITY-09O-R — regression coverage for
// DiagnosticSessionNotifier's recover()/reset() lifecycle (mission
// sections 05/07/10). Mocks DiagnosticLoggerService (same pattern as
// test/shared/widgets/ive_overlay_auth_gate_test.dart) so this exercises
// the NOTIFIER's own logic/state transitions without a live Supabase
// client — the server-side authorization boundary itself
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

  setUp(() {
    logger = MockDiagnosticLoggerService();
    final container = ProviderContainer(
      overrides: [diagnosticLoggerProvider.overrideWithValue(logger)],
    );
    addTearDown(container.dispose);
    notifier = container.read(diagnosticSessionProvider.notifier);
  });

  group('recover()', () {
    test('no server-active session -> state stays inactive, nothing adopted', () async {
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => null);

      await notifier.recover();

      expect(notifier.state.isActive, isFalse);
      verifyNever(() => logger.adoptActiveSession(any()));
    });

    test('a real server-active session -> adopted and reflected in state', () async {
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => {
            'id': 'session-123',
            'label': 'COMMERCIAL-E2E-001',
            'started_at': '2026-01-01T00:00:00.000Z',
          });

      await notifier.recover();

      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.sessionId, 'session-123');
      verify(() => logger.adoptActiveSession('session-123')).called(1);
    });

    test(
      'already tracking an active session locally -> no-op, never re-queries the server '
      '(mission section 05: "do not create a polling loop")',
      () async {
        when(() => logger.findMyActiveSession()).thenAnswer((_) async => {
              'id': 'session-already-active',
              'label': null,
              'started_at': '2026-01-01T00:00:00.000Z',
            });
        await notifier.recover(); // first call adopts it
        clearInteractions(logger);

        await notifier.recover(); // second call should short-circuit

        verifyNever(() => logger.findMyActiveSession());
      },
    );
  });

  group('reset() — mission section 10 (logout clears runtime session state)', () {
    test('clears in-memory state and detaches the logger, without a server call', () async {
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => {
            'id': 'session-to-clear',
            'label': null,
            'started_at': '2026-01-01T00:00:00.000Z',
          });
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

    test('after reset(), a subsequent recover() re-queries the server fresh (user-switch isolation)', () async {
      when(() => logger.findMyActiveSession()).thenAnswer((_) async => {
            'id': 'user-a-session',
            'label': null,
            'started_at': '2026-01-01T00:00:00.000Z',
          });
      await notifier.recover();
      when(() => logger.forgetActiveSession()).thenReturn(null);
      notifier.reset();

      when(() => logger.findMyActiveSession()).thenAnswer((_) async => {
            'id': 'user-b-session',
            'label': null,
            'started_at': '2026-01-01T00:00:00.000Z',
          });
      await notifier.recover();

      expect(notifier.state.sessionId, 'user-b-session');
    });
  });
}
