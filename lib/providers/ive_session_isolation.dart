import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_provider.dart';
import 'context_copilot_provider.dart';
import 'entitlement_provider.dart';
import 'ive_context_provider.dart';
import 'ive_memory_provider.dart';

/// IVE-INTELLIGENCE-CORE-01 (IVE-F01) — nothing the IVE knew about one
/// signed-in user may survive into another user's session on the same
/// device/tab: conversation transcripts (the `contextCopilotProvider`
/// family is not autoDispose), the server capability cache, the aggregated
/// project context and the device-local IVE memory.
///
/// Parameterised by `invalidate` so it runs identically from a Riverpod
/// `Ref` (AuthNotifier) and from a `ProviderContainer` (tests).
Future<void> resetIveSessionState({
  required void Function(ProviderOrFamily provider) invalidate,
  required IveMemoryNotifier memory,
}) async {
  invalidate(contextCopilotProvider);
  invalidate(serverModuleAccessProvider);
  invalidate(iveContextDataProvider);
  await memory.clearForSessionChange();
}

/// Called after a successful sign-in: if the device-local IVE memory
/// belonged to a different user, everything above is reset first.
Future<void> bindIveSessionToUser({
  required String userId,
  required void Function(ProviderOrFamily provider) invalidate,
  required IveMemoryNotifier memory,
}) async {
  final wiped = await memory.bindToUser(userId);
  if (wiped) {
    invalidate(contextCopilotProvider);
    invalidate(serverModuleAccessProvider);
    invalidate(iveContextDataProvider);
  }
}

/// Session guard for every sign-in path, including redirect-based OAuth on
/// the web where the session appears after `signInWithGoogle()` returns:
/// listens to the auth stream and binds (or resets) the IVE state to the
/// user actually signed in. Watched once from the app root.
final iveSessionGuardProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
    final authState = next.valueOrNull;
    if (authState == null) return;
    final memory = ref.read(iveMemoryProvider.notifier);
    if (authState.event == AuthChangeEvent.signedOut) {
      resetIveSessionState(invalidate: ref.invalidate, memory: memory);
      return;
    }
    final userId = authState.session?.user.id;
    if (userId != null) {
      bindIveSessionToUser(userId: userId, invalidate: ref.invalidate, memory: memory);
    }
  });
});
