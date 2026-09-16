// IVE-COMMERCIAL-STABILITY-09O-R — regression coverage for the canonical
// diagnostic-session recovery gate. Pure Dart logic, no Supabase/Riverpod
// needed: the actual side effect (ref.read(diagnosticSessionProvider
// .notifier).recover()) lives in lib/app.dart's _AppState, which — per the
// same established convention as profile_resume_policy_test.dart ("do not
// build large Supabase mocking infrastructure solely to test a one-line
// invalidation side effect") — is verified by inspection, not a widget
// test. The "already attempted for this user" statefulness that used to
// live in this function's parameters was moved into
// DiagnosticSessionNotifier itself (Codex Gate, P1 fix — see its own
// comment) and is covered by test/providers/diagnostic_session_provider_
// test.dart instead; this function is now a pure role/authorization gate
// only.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/app_lifecycle/diagnostic_recovery_policy.dart';

void main() {
  group('shouldAttemptDiagnosticRecovery', () {
    test('admin -> true (the actual recovery trigger)', () {
      expect(shouldAttemptDiagnosticRecovery(isAdmin: true), isTrue);
    });

    test('NOT admin -> false', () {
      expect(shouldAttemptDiagnosticRecovery(isAdmin: false), isFalse);
    });

    test(
      'role unresolved (caller passes isAdmin: false while loading/erroring) -> false, '
      'never optimistically true (mission section 06: fail closed until role is resolved)',
      () {
        // Mirrors how lib/app.dart calls this: `profile?.isAdmin ?? false`
        // — an AsyncValue still loading/erroring resolves profile to
        // null, which becomes isAdmin: false here.
        expect(shouldAttemptDiagnosticRecovery(isAdmin: false), isFalse);
      },
    );
  });
}
