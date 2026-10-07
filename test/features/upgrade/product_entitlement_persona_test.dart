// IV-WEB-ECOSYSTEM-UNIFICATION-01 — persona E2E scenarios for product
// entitlement gate.
//
// Personas
//   Lucas A — free (BASE_FREE) user attempts Impact route
//   Lucas B — Core subscriber attempts Quant route
//   Lucas C — Impact subscriber accesses Impact route
//   Emily D  — Suite subscriber accesses Impact and Quant routes
//   Emily E  — Quant subscriber accesses Quant route
//   Emily F  — Admin user bypasses product gate entirely
//
// These tests verify the contract between ProductEntitlementResult,
// kRouteRequiredProduct, and the redirect logic in app.dart without
// requiring a live Supabase connection.
import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/modules/route_policy.dart';
import 'package:ai_social_copilot/data/services/product_entitlement_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates the product redirect decision made in app.dart
/// _resolveEntitlementRedirect for the product gate pass.
///
/// Returns the redirect path, or null if access is allowed.
String? _resolveProductRedirect({
  required String path,
  required bool isAdmin,
  required ProductEntitlementResult Function(String product) resolveProduct,
}) {
  if (isAdmin) return null;
  final requiredProduct = kRouteRequiredProduct[path];
  if (requiredProduct == null) return null;
  final pe = resolveProduct(requiredProduct);
  if (!pe.allowed) {
    final suffix = pe.isTemporarilyUnavailable ? '&state=unavailable' : '';
    return '${AppConstants.routeProductUpgrade}?product=$requiredProduct$suffix';
  }
  return null;
}

void main() {
  // ── kRouteRequiredProduct coverage ────────────────────────────────────────

  group('PERSONA-MAP: kRouteRequiredProduct coverage', () {
    test('PERSONA-MAP-01: impact routes require "impact" product', () {
      for (final route in [
        AppConstants.routeImpact,
        AppConstants.routeImpactDiscover,
        AppConstants.routeImpactDossier,
        AppConstants.routeImpactMonitor,
      ]) {
        expect(kRouteRequiredProduct[route], 'impact',
            reason: '$route should require impact product');
      }
    });

    test('PERSONA-MAP-02: quant routes require "quant" product', () {
      for (final route in [
        AppConstants.routeQuant,
        AppConstants.routeQuantLab,
      ]) {
        expect(kRouteRequiredProduct[route], 'quant',
            reason: '$route should require quant product');
      }
    });

    test('PERSONA-MAP-03: routeProductUpgrade is always-allowed (not gated)',
        () {
      expect(kRouteRequiredProduct.containsKey(AppConstants.routeProductUpgrade),
          isFalse);
      expect(kAlwaysAllowedRoutes.contains(AppConstants.routeProductUpgrade),
          isTrue);
    });
  });

  // ── ProductEntitlementResult contract ─────────────────────────────────────

  group('PERSONA-CONTRACT: ProductEntitlementResult factories', () {
    test('PERSONA-CONTRACT-01: failOpen returns allowed=true', () {
      final r = ProductEntitlementResult.failOpen('impact');
      expect(r.allowed, isTrue);
      expect(r.product, 'impact');
      expect(r.reason, 'FAIL_OPEN');
      expect(r.isTemporarilyUnavailable, isFalse);
    });

    test('PERSONA-CONTRACT-02: denied returns allowed=false', () {
      final r = ProductEntitlementResult.denied('quant',
          code: 'PRODUCT_NOT_SUBSCRIBED', reason: 'no active subscription');
      expect(r.allowed, isFalse);
      expect(r.product, 'quant');
      expect(r.code, 'PRODUCT_NOT_SUBSCRIBED');
      expect(r.isTemporarilyUnavailable, isFalse);
    });

    test('PERSONA-CONTRACT-03: temporarilyUnavailable returns allowed=false com código correto', () {
      final r = ProductEntitlementResult.temporarilyUnavailable('impact');
      expect(r.allowed, isFalse);
      expect(r.product, 'impact');
      expect(r.code, 'TEMPORARILY_UNAVAILABLE');
      expect(r.isTemporarilyUnavailable, isTrue);
    });
  });

  // ── Persona scenarios ──────────────────────────────────────────────────────

  group('PERSONA-LUCAS-A: free user → Impact blocked', () {
    // Lucas A has no product subscription at all (BASE_FREE implicit).
    // resolve_product_entitlement for 'impact' returns denied.
    ProductEntitlementResult lucasAResolver(String product) =>
        ProductEntitlementResult.denied(product,
            code: 'PRODUCT_NOT_SUBSCRIBED', reason: 'BASE_FREE');

    test('PERSONA-A-01: /impact redirects to product-upgrade?product=impact',
        () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeImpact,
        isAdmin: false,
        resolveProduct: lucasAResolver,
      );
      expect(redirect,
          '${AppConstants.routeProductUpgrade}?product=impact');
    });

    test('PERSONA-A-02: /impact/discover also blocked', () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeImpactDiscover,
        isAdmin: false,
        resolveProduct: lucasAResolver,
      );
      expect(redirect, contains('product=impact'));
    });

    test('PERSONA-A-03: /impact/dossier also blocked', () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeImpactDossier,
        isAdmin: false,
        resolveProduct: lucasAResolver,
      );
      expect(redirect, contains('product=impact'));
    });
  });

  group('PERSONA-LUCAS-B: core subscriber → Quant blocked', () {
    // Lucas B has core product only. Quant returns denied.
    ProductEntitlementResult lucasBResolver(String product) {
      if (product == 'core') {
        return ProductEntitlementResult(
            allowed: true, product: 'core', tier: 'pro', source: 'stripe');
      }
      return ProductEntitlementResult.denied(product,
          code: 'PRODUCT_NOT_SUBSCRIBED');
    }

    test('PERSONA-B-01: /quant redirects to product-upgrade?product=quant',
        () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeQuant,
        isAdmin: false,
        resolveProduct: lucasBResolver,
      );
      expect(redirect, '${AppConstants.routeProductUpgrade}?product=quant');
    });

    test('PERSONA-B-02: /quant/lab also blocked', () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeQuantLab,
        isAdmin: false,
        resolveProduct: lucasBResolver,
      );
      expect(redirect, contains('product=quant'));
    });

    test('PERSONA-B-03: core-only routes not in kRouteRequiredProduct (no gate)', () {
      // Routes that aren't in the product map don't trigger the product gate.
      expect(kRouteRequiredProduct.containsKey(AppConstants.routeDashboard),
          isFalse);
    });
  });

  group('PERSONA-LUCAS-C: impact subscriber → Impact allowed', () {
    ProductEntitlementResult lucasCResolver(String product) {
      if (product == 'impact') {
        return ProductEntitlementResult(
            allowed: true, product: 'impact', tier: 'pro', source: 'stripe');
      }
      return ProductEntitlementResult.denied(product);
    }

    test('PERSONA-C-01: /impact allowed (no redirect)', () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeImpact,
        isAdmin: false,
        resolveProduct: lucasCResolver,
      );
      expect(redirect, isNull);
    });

    test('PERSONA-C-02: /impact/discover allowed', () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeImpactDiscover,
        isAdmin: false,
        resolveProduct: lucasCResolver,
      );
      expect(redirect, isNull);
    });

    test('PERSONA-C-03: /quant still blocked for impact-only subscriber', () {
      final redirect = _resolveProductRedirect(
        path: AppConstants.routeQuant,
        isAdmin: false,
        resolveProduct: lucasCResolver,
      );
      expect(redirect, contains('product=quant'));
    });
  });

  group('PERSONA-EMILY-D: suite subscriber → all products allowed', () {
    // Emily D has suite — resolver returns allowed for both impact and quant.
    ProductEntitlementResult emilyDResolver(String product) =>
        ProductEntitlementResult(
            allowed: true, product: product, tier: 'suite', source: 'stripe');

    for (final route in [
      AppConstants.routeImpact,
      AppConstants.routeImpactDiscover,
      AppConstants.routeImpactDossier,
      AppConstants.routeImpactMonitor,
      AppConstants.routeQuant,
      AppConstants.routeQuantLab,
    ]) {
      test('PERSONA-D-01: $route allowed for suite subscriber', () {
        final redirect = _resolveProductRedirect(
          path: route,
          isAdmin: false,
          resolveProduct: emilyDResolver,
        );
        expect(redirect, isNull, reason: '$route must not redirect suite users');
      });
    }
  });

  group('PERSONA-EMILY-E: quant subscriber → Quant allowed, Impact blocked', () {
    ProductEntitlementResult emilyEResolver(String product) {
      if (product == 'quant') {
        return ProductEntitlementResult(
            allowed: true, product: 'quant', tier: 'pro', source: 'stripe');
      }
      return ProductEntitlementResult.denied(product);
    }

    test('PERSONA-E-01: /quant allowed', () {
      expect(
        _resolveProductRedirect(
          path: AppConstants.routeQuant,
          isAdmin: false,
          resolveProduct: emilyEResolver,
        ),
        isNull,
      );
    });

    test('PERSONA-E-02: /quant/lab allowed', () {
      expect(
        _resolveProductRedirect(
          path: AppConstants.routeQuantLab,
          isAdmin: false,
          resolveProduct: emilyEResolver,
        ),
        isNull,
      );
    });

    test('PERSONA-E-03: /impact blocked for quant-only subscriber', () {
      expect(
        _resolveProductRedirect(
          path: AppConstants.routeImpact,
          isAdmin: false,
          resolveProduct: emilyEResolver,
        ),
        contains('product=impact'),
      );
    });
  });

  group('PERSONA-EMILY-F: admin bypasses product gate entirely', () {
    // Admin never hits the product resolver — isAdmin=true short-circuits.
    ProductEntitlementResult adminResolver(String product) =>
        ProductEntitlementResult.denied(product, code: 'SHOULD_NOT_BE_CALLED');

    for (final route in [
      AppConstants.routeImpact,
      AppConstants.routeImpactDossier,
      AppConstants.routeQuant,
      AppConstants.routeQuantLab,
    ]) {
      test('PERSONA-F-01: $route allowed for admin regardless of entitlement',
          () {
        final redirect = _resolveProductRedirect(
          path: route,
          isAdmin: true,
          resolveProduct: adminResolver,
        );
        expect(redirect, isNull,
            reason: 'admin must bypass product gate for $route');
      });
    }
  });

  // ── FAIL CLOSED: RPC error bloqueia acesso a produtos pagos ──────────────

  group('PERSONA-FAILCLOSED: RPC error → temporarily_unavailable → acesso negado', () {
    // Simula falha de RPC/rede — service retorna temporarilyUnavailable.
    ProductEntitlementResult failClosedResolver(String product) =>
        ProductEntitlementResult.temporarilyUnavailable(product);

    for (final route in [
      AppConstants.routeImpact,
      AppConstants.routeQuant,
    ]) {
      test('PERSONA-FC-01: $route bloqueado com state=unavailable quando RPC falha', () {
        final redirect = _resolveProductRedirect(
          path: route,
          isAdmin: false,
          resolveProduct: failClosedResolver,
        );
        expect(redirect, isNotNull,
            reason: 'FAIL CLOSED: RPC failure must block access to $route');
        expect(redirect, contains('state=unavailable'),
            reason: 'redirect must carry state=unavailable for temporarily_unavailable');
      });
    }
  });

  // ── BASE_FREE continua acessível ──────────────────────────────────────────

  group('PERSONA-BASEFREE: produto desconhecido/base_free → failOpen, nunca bloqueado', () {
    // BASE_FREE e produtos fora do conjunto pago retornam failOpen.
    ProductEntitlementResult baseFreeResolver(String product) =>
        ProductEntitlementResult.failOpen(product);

    for (final route in [
      AppConstants.routeDashboard,
    ]) {
      test('PERSONA-BF-01: $route não exige produto → sem redirecionamento', () {
        final redirect = _resolveProductRedirect(
          path: route,
          isAdmin: false,
          resolveProduct: baseFreeResolver,
        );
        expect(redirect, isNull,
            reason: 'BASE_FREE routes must never be blocked');
      });
    }
  });
}
