// IV-WEB-ECOSYSTEM-UNIFICATION-01 — product entitlement providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/product_entitlement_service.dart';

final productEntitlementServiceProvider =
    Provider<ProductEntitlementService>((_) => ProductEntitlementService());

/// Resolves whether the current user has access to [product].
/// Fail open: returns true on any error (server not yet migrated, network, etc.)
/// The server-side resolve_product_entitlement() is the authority.
final productEntitlementProvider =
    FutureProvider.autoDispose.family<ProductEntitlementResult, String>((ref, product) async {
  return ref.watch(productEntitlementServiceProvider).resolve(product);
});
