import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/diagnostics/diagnostic_models.dart';
import '../data/services/auth_service.dart';
import 'diagnostic_session_provider.dart';
import 'ive_memory_provider.dart';
import 'ive_session_isolation.dart';
import 'profile_provider.dart';
import 'quota_provider.dart';

final authServiceProvider = Provider<AuthService>((_) => AuthService());

// Stream do estado de autenticação
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Notifier para operações de login/cadastro
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  final AuthService _service;
  final Ref _ref;

  // IVE-COMMERCIAL-TARGETED-REMEDIATION-06R (Codex adversarial review, P1) —
  // currentProfileProvider (FutureProvider.autoDispose) had no invalidation
  // tied to identity changing at all. Harmless while it only drove display
  // (Account screen showing a stale role for a moment), but
  // lib/app.dart's new route entitlement guard now reads it to decide
  // real access -- a user logging out and a DIFFERENT user logging back in
  // within the same app session (same tab, no full reload) could
  // theoretically keep serving the first user's cached plan/role to the
  // second. Every method below that can change WHO auth.currentUser is
  // invalidates it, forcing the next read to hit the database for the
  // now-current session rather than any cached value from before.
  //
  // IVE-COMMERCIAL-OBSERVABILITY-07B (mission section 14 profile-cache
  // investigation) — currentQuotaProvider is exactly the same kind of
  // user-scoped FutureProvider.autoDispose as currentProfileProvider, sits
  // right next to it in the drawer/Account/Upgrade screens, but was never
  // included here. No path from it to a real authorization decision was
  // found (route entitlement reads currentProfileProvider, never quota;
  // every actual quota reservation is server-side per Remediation 06's own
  // audit), so this is a display-only staleness gap, not a security one —
  // still closed here for the same reason currentProfileProvider already
  // is: a second user signing in within the same tab, no reload, must
  // never see the first user's cached quota.
  void _invalidateProfile() {
    _ref.invalidate(currentProfileProvider);
    _ref.invalidate(currentQuotaProvider);
  }

  // IVE-INTELLIGENCE-CORE-01 (IVE-F01) — after a successful sign-in, bind the
  // IVE's device-local state to the user who is now signed in; if it
  // belonged to someone else it is wiped (transcripts, capability cache,
  // project context, device memory). Best effort: never blocks sign-in.
  Future<void> _bindIveToCurrentUser() async {
    if (state.hasError) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await bindIveSessionToUser(
        userId: userId,
        invalidate: _ref.invalidate,
        memory: _ref.read(iveMemoryProvider.notifier),
      );
    } catch (_) {}
  }

  // IVE-COMMERCIAL-OBSERVABILITY-07A — AUTH category (mission section 04:
  // "signed-in state, sign-in success/failure category, sign-out, profile
  // resolution, role/plan resolution. NEVER credentials/tokens."). Logs
  // only which METHOD was attempted and whether it succeeded — never the
  // email/password/token involved. A no-op when there's no active
  // diagnostic session, same as every other category.
  void _logAuth(String eventName, {required bool success, String? method}) {
    _ref.read(diagnosticLoggerProvider).logEvent(
      category: DiagnosticCategory.auth,
      eventName: eventName,
      severity: success ? DiagnosticSeverity.info : DiagnosticSeverity.warn,
      status: success ? 'success' : 'failure',
      metadata: {if (method != null) 'method': method},
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _service.signIn(email: email, password: password),
    );
    _logAuth('sign_in', success: !state.hasError, method: 'password');
    _invalidateProfile();
    await _bindIveToCurrentUser();
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _service.signUp(email: email, password: password),
    );
    _logAuth('sign_up', success: !state.hasError, method: 'password');
    _invalidateProfile();
    await _bindIveToCurrentUser();
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.signInWithGoogle);
    _logAuth('sign_in', success: !state.hasError, method: 'google');
    _invalidateProfile();
    await _bindIveToCurrentUser();
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.signOut);
    // Logged BEFORE the reset below, deliberately: the sign_out event
    // itself still belongs to the OUTGOING user's session.
    _logAuth('sign_out', success: !state.hasError);
    _invalidateProfile();
    // IVE-COMMERCIAL-STABILITY-09O-R (mission section 10) — clears this
    // tab's in-memory diagnostic session state so no subsequent event
    // (before a future recover()/start() runs for whoever signs in next)
    // can attach itself to the outgoing user's session. See
    // DiagnosticSessionNotifier.reset()'s own comment.
    //
    // Codex Gate (P2 ACCEPTED) — only when sign-out actually SUCCEEDED: a
    // failed _service.signOut() leaves the same user still authenticated,
    // so detaching their still-legitimately-active session here would
    // needlessly suppress capture for the rest of this runtime (recover()
    // marks a user "attempted" even on failure, and there is no reason to
    // force that here when nothing about the auth state actually changed).
    if (!state.hasError) {
      _ref.read(diagnosticSessionProvider.notifier).reset();
      // IVE-INTELLIGENCE-CORE-01 (IVE-F01) — the outgoing user's IVE
      // conversation, capability cache, project context and device-local
      // memory must not reach whoever signs in next on this device.
      await resetIveSessionState(
        invalidate: _ref.invalidate,
        memory: _ref.read(iveMemoryProvider.notifier),
      );
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});
