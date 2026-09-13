// IVE-COMMERCIAL-TARGETED-REMEDIATION-06S — regression coverage for the
// paid-state refresh trigger. Pure Dart/Flutter-enum logic, no Supabase or
// Riverpod needed: the actual side effect (ref.invalidate) lives in
// lib/app.dart's _AppState, which per mission section 09 ("Do not build
// large Supabase mocking infrastructure solely to test a one-line
// invalidation side effect") is verified by inspection, not a widget test.

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/app_lifecycle/profile_resume_policy.dart';

void main() {
  group('shouldRefreshProfileOnResume', () {
    test('resumed + authenticated -> true (the actual refresh trigger)', () {
      expect(
        shouldRefreshProfileOnResume(state: AppLifecycleState.resumed, isAuthenticated: true),
        isTrue,
      );
    });

    test('resumed + NOT authenticated -> false (never assume entitlement while signed out)', () {
      expect(
        shouldRefreshProfileOnResume(state: AppLifecycleState.resumed, isAuthenticated: false),
        isFalse,
      );
    });

    test('every non-resumed lifecycle state -> false, even while authenticated', () {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        expect(
          shouldRefreshProfileOnResume(state: state, isAuthenticated: true),
          isFalse,
          reason: '$state must not trigger a refresh',
        );
      }
    });
  });
}
