import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/diagnostics/diagnostic_models.dart';
import '../data/services/auth_service.dart';
import 'diagnostic_session_provider.dart';
import 'profile_provider.dart';

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
  void _invalidateProfile() => _ref.invalidate(currentProfileProvider);

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
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.signInWithGoogle);
    _logAuth('sign_in', success: !state.hasError, method: 'google');
    _invalidateProfile();
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.signOut);
    _logAuth('sign_out', success: !state.hasError);
    _invalidateProfile();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});
