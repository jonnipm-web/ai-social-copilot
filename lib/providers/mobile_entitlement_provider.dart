// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Platform-aware product entitlement provider.
//
// RUNTIME ROUTING:
//   kIsWeb == true  → ProductEntitlementService (existing Web path, unchanged)
//   kIsWeb == false → MobileEntitlementResolver (offline cache + identity anchor +
//                     FAIL CLOSED on network error)
//
// SECURITY INVARIANT (mission brief §4):
//   On mobile, the flavor gate in evaluateRouteAccess (isRouteBlockedByFlavor)
//   ensures that by the time this provider is consulted, requiredProduct always
//   matches the active flavor's own productId. Cross-product routes are blocked
//   UPSTREAM via the route gate; they never reach the entitlement check.
//
// app.dart uses runtimeProductEntitlementProvider(requiredProduct) in place of
// productEntitlementProvider(requiredProduct) inside _resolveEntitlementRedirect.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/product_entitlement_service.dart';
import '../mobile/entitlements/mobile_entitlement_resolver.dart';
import '../mobile/offline/offline_entitlement_policy.dart';
import 'product_entitlements_provider.dart';

// Offline policy singleton — shared between resolver and auth sign-out path.
// Exposed as a provider so tests can override it without touching SharedPreferences.
final offlineEntitlementPolicyProvider =
    Provider<OfflineEntitlementPolicy>((_) => OfflineEntitlementPolicy());

// Single resolver instance per ProviderScope. MobileEntitlementResolver holds
// no shared mutable state between calls (userId is anchored per call), so this
// singleton is safe to share across concurrent resolve() calls.
final mobileEntitlementResolverProvider = Provider<MobileEntitlementResolver>(
  (ref) => MobileEntitlementResolver(
    // Reuse the same policy instance so sign-out clearAll() and the resolver's
    // cache reads/writes operate on the same SharedPreferences namespace.
    offlinePolicy: ref.watch(offlineEntitlementPolicyProvider),
  ),
);

/// Platform-aware product entitlement resolution.
///
/// Web (kIsWeb == true):
///   Direct ProductEntitlementService RPC — exactly the existing Web path.
///   Behavior is identical to the old productEntitlementProvider.
///
/// Mobile (kIsWeb == false):
///   MobileEntitlementResolver with:
///     - userId captured before RPC (P1-R6-B identity anchor)
///     - userId re-verified after await (P1-R8-A cross-session discard)
///     - Offline TTL cache fallback on network failure (24h window)
///     - FAIL CLOSED: no cache + RPC failure → temporarilyUnavailable (denied)
final runtimeProductEntitlementProvider =
    FutureProvider.autoDispose.family<ProductEntitlementResult, String>(
        (ref, product) async {
  if (kIsWeb) {
    return ref.watch(productEntitlementServiceProvider).resolve(product);
  }
  return ref.read(mobileEntitlementResolverProvider).resolve(product);
});
