// IV-WEB-ECOSYSTEM-UNIFICATION-01 — client-side product entitlement resolver.
//
// Wraps the server-authoritative resolve_product_entitlement() SQL function.
// FAIL OPEN: any error (network, table not found, unexpected shape) returns
// allowed=true so existing behaviour is preserved before migrations are applied
// to production. The server is the authority — this is a UX pre-check only.
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductEntitlementResult {
  final bool allowed;
  final String product;
  final String? tier;
  final String? source;
  final String? code;
  final String? reason;

  const ProductEntitlementResult({
    required this.allowed,
    required this.product,
    this.tier,
    this.source,
    this.code,
    this.reason,
  });

  factory ProductEntitlementResult.failOpen(String product) =>
      ProductEntitlementResult(allowed: true, product: product, reason: 'FAIL_OPEN');

  factory ProductEntitlementResult.denied(String product, {String? code, String? reason}) =>
      ProductEntitlementResult(allowed: false, product: product, code: code, reason: reason);
}

class ProductEntitlementService {
  final _client = Supabase.instance.client;

  static const _validProducts = {'core', 'impact', 'quant', 'suite'};

  Future<ProductEntitlementResult> resolve(String product) async {
    if (!_validProducts.contains(product)) {
      return ProductEntitlementResult.failOpen(product);
    }
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return ProductEntitlementResult.denied(product, code: 'AUTH_REQUIRED');
    }
    try {
      final result = await _client.rpc(
        'resolve_product_entitlement',
        params: {'p_user_id': uid, 'p_product': product},
      ).timeout(const Duration(seconds: 8));

      if (result == null || result is! Map) {
        return ProductEntitlementResult.failOpen(product);
      }
      final row = result as Map<String, dynamic>;
      return ProductEntitlementResult(
        allowed: row['allowed'] == true,
        product: row['product']?.toString() ?? product,
        tier: row['tier']?.toString(),
        source: row['source']?.toString(),
        code: row['code']?.toString(),
        reason: row['reason']?.toString(),
      );
    } catch (_) {
      // RPC not available (migrations not applied), network error, etc.
      // Fail open so existing behaviour is preserved pre-migration.
      return ProductEntitlementResult.failOpen(product);
    }
  }
}
