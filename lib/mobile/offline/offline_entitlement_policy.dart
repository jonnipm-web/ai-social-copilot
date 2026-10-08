// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Offline entitlement TTL cache.
//
// Caches the last successful server entitlement result per (user, product).
// On network failure, the cached result is returned if within TTL.
// After TTL expiry, FAIL CLOSED: denied (paid products are not accessible).
//
// SECURITY (P1-R3-B fix — Codex adversarial review): cache key is ALWAYS
// scoped to (userId, productId). Unauthenticated state cannot inherit a prior
// user's cached grant. If the user changes between cacheResult() and
// getCachedResult(), the key mismatch naturally invalidates the entry.
//
// TTL policy (from mission brief Section 18):
//   - Default TTL: 24 hours for paid products
//   - BASE_FREE products: not cached (always accessible)
//
// Storage: shared_preferences (per-device, per-user session)
// Key namespace: iv_ent_cache_v2_<userId>_<productId>

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/product_entitlement_service.dart';

class OfflineEntitlementPolicy {
  static const Duration kDefaultTtl = Duration(hours: 24);

  // v2 prefix ensures clean migration from old single-product keys.
  static const String _keyPrefix = 'iv_ent_cache_v2_';

  final Duration ttl;

  OfflineEntitlementPolicy({this.ttl = kDefaultTtl});

  // Returns the key for the current authenticated user + product pair.
  // Returns null if no user is signed in (cache cannot be used).
  String? _cacheKey(String productId) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    return '$_keyPrefix${userId}_$productId';
  }

  // [anchoredUserId] — identity captured BEFORE the async RPC (P1-R6-B fix).
  // If provided, it is compared to currentUser at write time: if they differ
  // (user signed out or switched during the RPC), the write is discarded.
  // This prevents user A's grant being cached under user B's key on a
  // mid-flight session change.
  Future<void> cacheResult(
    String productId,
    ProductEntitlementResult result, {
    String? anchoredUserId,
  }) async {
    if (!result.allowed) return; // Only cache positive grants.
    final key = _cacheKey(productId);
    if (key == null) return; // Do not cache without a signed-in user.
    // P1-R6-B: verify identity did not change during the RPC.
    if (anchoredUserId != null) {
      final currentId = Supabase.instance.client.auth.currentUser?.id;
      if (currentId != anchoredUserId) return; // identity changed — discard
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'allowed': result.allowed,
        'product': result.product,
        'tier': result.tier,
        'source': result.source,
        'code': result.code,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at':
            DateTime.now().add(ttl).millisecondsSinceEpoch,
      });
      await prefs.setString(key, payload);
    } catch (_) {
      // Cache write failure is non-fatal.
    }
  }

  Future<ProductEntitlementResult?> getCachedResult(String productId) async {
    final key = _cacheKey(productId);
    if (key == null) return null; // Not signed in — no cache.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = data['expires_at'] as int?;
      if (expiresAt == null) return null;
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        // Cache expired: remove and return null (FAIL CLOSED upstream).
        await prefs.remove(key);
        return null;
      }
      return ProductEntitlementResult(
        allowed: data['allowed'] as bool,
        product: data['product'] as String,
        tier: data['tier'] as String?,
        source: '${data['source']}_offline_cache',
        code: data['code'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // Clears all cached entries for the CURRENT user only.
  // Call this on sign-out via MobileSessionManager.
  Future<void> clearAll() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    // If user already signed out, clear all v2 entries to be safe.
    final prefix = userId != null ? '$_keyPrefix${userId}_' : _keyPrefix;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
