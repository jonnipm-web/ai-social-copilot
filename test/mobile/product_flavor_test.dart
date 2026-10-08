// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Product flavor isolation tests.
//
// Scenarios (from mission brief Section 23 — Personas):
//   Lucas (impact power user) → ProductFlavor.impact
//   Emily (quant analyst) → ProductFlavor.quant
// Both arrive in separate APKs — they never mix products.
//
// These tests verify:
//   1. FlavorRegistry initializes exactly once
//   2. Each flavor has the correct product ID, applicationId, deep link host
//   3. requiresEntitlement contract (core=false, impact/quant=true)
//   4. FlavorRegistry cannot be initialized twice in production

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/mobile/config/product_flavor.dart';

void main() {
  setUp(() {
    FlavorRegistry.resetForTesting();
  });

  tearDown(() {
    FlavorRegistry.resetForTesting();
  });

  group('ProductFlavor metadata', () {
    test('core has correct identifiers', () {
      expect(ProductFlavor.core.productId, equals('core'));
      expect(
          ProductFlavor.core.applicationId, equals('com.insightvalues.core'));
      expect(ProductFlavor.core.deepLinkHost, equals('core'));
      expect(ProductFlavor.core.displayName, equals('InsightValues Core'));
    });

    test('impact has correct identifiers', () {
      expect(ProductFlavor.impact.productId, equals('impact'));
      expect(ProductFlavor.impact.applicationId,
          equals('com.insightvalues.impact'));
      expect(ProductFlavor.impact.deepLinkHost, equals('impact'));
      expect(ProductFlavor.impact.displayName, equals('InsightValues Impact'));
    });

    test('quant has correct identifiers', () {
      expect(ProductFlavor.quant.productId, equals('quant'));
      expect(
          ProductFlavor.quant.applicationId, equals('com.insightvalues.quant'));
      expect(ProductFlavor.quant.deepLinkHost, equals('quant'));
      expect(ProductFlavor.quant.displayName, equals('InsightValues Quant'));
    });
  });

  group('Entitlement contract', () {
    // BASE_FREE — core does not gate the user
    test('core does NOT require entitlement (BASE_FREE)', () {
      expect(ProductFlavor.core.requiresEntitlement, isFalse);
    });

    // Lucas (impact power user) must be entitled
    test('impact requires entitlement — Lucas persona', () {
      expect(ProductFlavor.impact.requiresEntitlement, isTrue);
    });

    // Emily (quant analyst) must be entitled
    test('quant requires entitlement — Emily persona', () {
      expect(ProductFlavor.quant.requiresEntitlement, isTrue);
    });
  });

  group('FlavorRegistry', () {
    test('init sets current flavor correctly', () {
      FlavorRegistry.init(ProductFlavor.impact);
      expect(FlavorRegistry.current, equals(ProductFlavor.impact));
    });

    test('init can only be called once (assert guard)', () {
      FlavorRegistry.init(ProductFlavor.core);
      expect(
        () => FlavorRegistry.init(ProductFlavor.quant),
        throwsA(isA<AssertionError>()),
      );
    });

    test('current throws AssertionError before init', () {
      expect(
        () => FlavorRegistry.current,
        throwsA(isA<AssertionError>()),
      );
    });

    test('resetForTesting allows re-initialization', () {
      FlavorRegistry.init(ProductFlavor.core);
      FlavorRegistry.resetForTesting();
      FlavorRegistry.init(ProductFlavor.quant);
      expect(FlavorRegistry.current, equals(ProductFlavor.quant));
    });
  });

  group('Product isolation — per-APK identity', () {
    // Verifies that two products never share the same applicationId
    test('all three products have distinct applicationIds', () {
      final ids = {
        ProductFlavor.core.applicationId,
        ProductFlavor.impact.applicationId,
        ProductFlavor.quant.applicationId,
      };
      expect(ids.length, equals(3),
          reason:
              'Each product must have a unique applicationId — products share the same device, '
              'different package namespace prevents install collision');
    });

    test('all three products have distinct deep link hosts', () {
      final hosts = {
        ProductFlavor.core.deepLinkHost,
        ProductFlavor.impact.deepLinkHost,
        ProductFlavor.quant.deepLinkHost,
      };
      expect(hosts.length, equals(3));
    });
  });
}
