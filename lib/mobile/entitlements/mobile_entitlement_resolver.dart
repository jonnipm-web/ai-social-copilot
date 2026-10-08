// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Mobile entitlement resolver facade.
//
// FOUNDATION PHASE — NOT YET WIRED INTO app.dart.
// Integration (replacing productEntitlementProvider calls on mobile with this
// resolver + offline cache) is deferred to IV-MOBILE-ECOSYSTEM-INTEGRATION-01.
// This file delivers the Foundation abstraction; wiring is out-of-scope here.
// See ARCHITECTURAL_DECISION_REQUIRED note in the mission report.
//
// Thin wrapper over ProductEntitlementService with mobile-specific policy:
//   1. FAIL CLOSED on any RPC/network error for paid products.
//   2. Offline TTL cache via OfflineEntitlementPolicy (P1-R3-B: user-scoped).
//   3. Identity-anchored cache writes (P1-R6-B: no cross-user cache leakage).
//
// SECURITY INVARIANTS:
//   - Service role: NUNCA invocado no Mobile
//   - Provider secrets: NUNCA no Mobile
//   - All resolution happens server-side via resolve_product_entitlement()

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/product_entitlement_service.dart';
import '../offline/offline_entitlement_policy.dart';

class MobileEntitlementResolver {
  final ProductEntitlementService _service;
  final OfflineEntitlementPolicy _offlinePolicy;

  MobileEntitlementResolver({
    ProductEntitlementService? service,
    OfflineEntitlementPolicy? offlinePolicy,
  })  : _service = service ?? ProductEntitlementService(),
        _offlinePolicy = offlinePolicy ?? OfflineEntitlementPolicy();

  /// Resolves entitlement for [productId], with offline TTL fallback.
  ///
  /// Resolution order:
  ///   1. Live server check via ProductEntitlementService
  ///   2. On network failure: use cached result if within TTL
  ///   3. On network failure + no/expired cache: FAIL CLOSED (denied)
  Future<ProductEntitlementResult> resolve(String productId) async {
    // P1-R6-B: capture identity BEFORE the async RPC. If the user signs out
    // or switches accounts while the RPC is in flight, the cached grant will
    // not be written under the new user's key. Wrapped in try/catch so unit
    // tests without a live Supabase instance degrade gracefully (no anchoring).
    String? anchoredUserId;
    try {
      anchoredUserId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      // Supabase not initialized (unit tests / pre-init path) — no anchoring.
    }
    try {
      final result = await _service.resolve(productId);

      // P1-R8-A: re-verify identity AFTER the async RPC. If the user signed
      // out or switched accounts during the await, discard the result and FAIL
      // CLOSED — even an allowed=true result must not be returned to a new
      // session. Cache write is discarded by cacheResult's anchoredUserId check.
      try {
        final currentUserId =
            Supabase.instance.client.auth.currentUser?.id;
        if (anchoredUserId != null && currentUserId != anchoredUserId) {
          return ProductEntitlementResult.temporarilyUnavailable(productId);
        }
      } catch (_) {
        // Supabase not initialized — no re-check.
      }

      if (result.allowed) {
        // Cache positive grants only (denied results have nothing to fall back to).
        await _offlinePolicy.cacheResult(productId, result,
            anchoredUserId: anchoredUserId);
        return result;
      } else if (result.isTemporarilyUnavailable) {
        // Server returned TEMPORARILY_UNAVAILABLE: try offline cache.
        return await _fallbackToCache(productId, result);
      }
      return result;
    } catch (_) {
      // Network or unexpected failure: try offline cache.
      final cached = await _offlinePolicy.getCachedResult(productId);
      if (cached != null) return cached;
      // FAIL CLOSED: no cache, deny paid product.
      return ProductEntitlementResult.temporarilyUnavailable(productId);
    }
  }

  Future<ProductEntitlementResult> _fallbackToCache(
    String productId,
    ProductEntitlementResult serverResult,
  ) async {
    final cached = await _offlinePolicy.getCachedResult(productId);
    if (cached != null) return cached;
    // FAIL CLOSED: cache empty or expired.
    return serverResult;
  }
}
