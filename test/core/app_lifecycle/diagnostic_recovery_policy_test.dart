// IVE-COMMERCIAL-STABILITY-09O-R — regression coverage for the canonical
// diagnostic-session recovery gate. Pure Dart logic, no Supabase/Riverpod
// needed: the actual side effect (ref.read(diagnosticSessionProvider
// .notifier).recover()) lives in lib/app.dart's _AppState, which — per the
// same established convention as profile_resume_policy_test.dart ("do not
// build large Supabase mocking infrastructure solely to test a one-line
// invalidation side effect") — is verified by inspection, not a widget
// test. recover() itself (DiagnosticSessionNotifier) already has its own
// safety properties documented and RLS-enforced server-side (see
// supabase/migrations/20260913200000_diagnostic_logger.sql); this file
// only covers the CLIENT-SIDE gate deciding whether to call it at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/app_lifecycle/diagnostic_recovery_policy.dart';

void main() {
  group('shouldAttemptDiagnosticRecovery', () {
    test('admin + resolved user id + never attempted -> true (the actual recovery trigger)', () {
      expect(
        shouldAttemptDiagnosticRecovery(
          isAdmin: true,
          userId: 'user-a',
          alreadyAttemptedForUserId: null,
        ),
        isTrue,
      );
    });

    test('NOT admin -> false, regardless of user id or prior attempt state', () {
      expect(
        shouldAttemptDiagnosticRecovery(
          isAdmin: false,
          userId: 'user-a',
          alreadyAttemptedForUserId: null,
        ),
        isFalse,
      );
    });

    test('no resolved user id -> false, even if isAdmin were somehow true (fail closed on unresolved auth)', () {
      expect(
        shouldAttemptDiagnosticRecovery(
          isAdmin: true,
          userId: null,
          alreadyAttemptedForUserId: null,
        ),
        isFalse,
      );
    });

    test('already attempted for the SAME user id -> false (no duplicate/repeat recovery calls)', () {
      expect(
        shouldAttemptDiagnosticRecovery(
          isAdmin: true,
          userId: 'user-a',
          alreadyAttemptedForUserId: 'user-a',
        ),
        isFalse,
      );
    });

    test(
      'already attempted for a DIFFERENT user id -> true (mission section 10: user-switch isolation — '
      'a sign-out/sign-in as a different admin in the same tab gets its own fresh attempt)',
      () {
        expect(
          shouldAttemptDiagnosticRecovery(
            isAdmin: true,
            userId: 'user-b',
            alreadyAttemptedForUserId: 'user-a',
          ),
          isTrue,
        );
      },
    );

    test('role unresolved (caller passes isAdmin: false while loading) -> false, never optimistically true', () {
      // Mirrors how lib/app.dart calls this: `profile?.isAdmin ?? false` —
      // an AsyncValue still loading/erroring resolves profile to null,
      // which becomes isAdmin: false here. This is the mission section 06
      // "fail closed until role is resolved" contract exercised directly.
      expect(
        shouldAttemptDiagnosticRecovery(
          isAdmin: false,
          userId: 'user-a',
          alreadyAttemptedForUserId: null,
        ),
        isFalse,
      );
    });
  });
}
