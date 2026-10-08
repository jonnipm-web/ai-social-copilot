// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Mobile session manager.
//
// Manages Supabase session state for native mobile builds.
// Responsibility:
//   - Detect and handle expired sessions proactively
//   - Coordinate entitlement cache invalidation on sign-out
//   - Provide a sign-out hook that clears all local cached state
//
// SECURITY: never persists raw JWT tokens in shared_preferences.
// Supabase Flutter handles token storage internally (secure storage).
// This class only stores non-sensitive session metadata.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline/offline_entitlement_policy.dart';

class MobileSessionManager {
  final SupabaseClient _client;
  final OfflineEntitlementPolicy _offlinePolicy;

  MobileSessionManager({
    SupabaseClient? client,
    OfflineEntitlementPolicy? offlinePolicy,
  })  : _client = client ?? Supabase.instance.client,
        _offlinePolicy = offlinePolicy ?? OfflineEntitlementPolicy();

  bool get isSignedIn => _client.auth.currentUser != null;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Signs out and clears all local cached state (entitlements, etc.).
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } finally {
      // Always clear local cache, even if sign-out fails.
      await _offlinePolicy.clearAll();
    }
  }

  /// Returns true if the current session is valid (not expired).
  bool get hasValidSession {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true; // No expiry set → treat as valid.
    return DateTime.now().millisecondsSinceEpoch < expiresAt * 1000;
  }

  /// Refreshes the session if it is about to expire (within 5 minutes).
  Future<bool> refreshIfNeeded() async {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    final expiresAtMs = expiresAt * 1000;
    final fiveMinutesFromNow =
        DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
    if (expiresAtMs > fiveMinutesFromNow) return true; // No refresh needed.
    try {
      final response = await _client.auth.refreshSession();
      return response.session != null;
    } catch (_) {
      return false;
    }
  }
}
