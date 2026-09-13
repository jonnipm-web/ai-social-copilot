import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/services/auth_service.dart';
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

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _service.signIn(email: email, password: password),
    );
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
    _invalidateProfile();
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.signInWithGoogle);
    _invalidateProfile();
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.signOut);
    _invalidateProfile();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});
