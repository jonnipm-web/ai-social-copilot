// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — MobileEntitlementResolver tests.
//
// Tests the fail-closed contract and offline TTL fallback.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/data/services/product_entitlement_service.dart';
import 'package:ai_social_copilot/mobile/entitlements/mobile_entitlement_resolver.dart';
import 'package:ai_social_copilot/mobile/offline/offline_entitlement_policy.dart';

class MockProductEntitlementService extends Mock
    implements ProductEntitlementService {}

class MockOfflineEntitlementPolicy extends Mock
    implements OfflineEntitlementPolicy {}

void main() {
  setUpAll(() {
    // mocktail requires fallback values for custom types used with any().
    registerFallbackValue(
      const ProductEntitlementResult(allowed: false, product: 'fallback'),
    );
  });

  late MockProductEntitlementService mockService;
  late MockOfflineEntitlementPolicy mockPolicy;
  late MobileEntitlementResolver resolver;

  setUp(() {
    mockService = MockProductEntitlementService();
    mockPolicy = MockOfflineEntitlementPolicy();
    resolver = MobileEntitlementResolver(
      service: mockService,
      offlinePolicy: mockPolicy,
    );
  });

  group('MobileEntitlementResolver — live path', () {
    test('returns server result on successful RPC', () async {
      final granted = ProductEntitlementResult(
        allowed: true,
        product: 'impact',
        tier: 'impact',
        source: 'subscription',
      );
      when(() => mockService.resolve('impact'))
          .thenAnswer((_) async => granted);
      when(() => mockPolicy.cacheResult('impact', any()))
          .thenAnswer((_) async {});

      final result = await resolver.resolve('impact');
      expect(result.allowed, isTrue);
      expect(result.product, equals('impact'));
      verify(() => mockPolicy.cacheResult('impact', any())).called(1);
    });

    test('does NOT cache denied results', () async {
      final denied =
          ProductEntitlementResult.denied('impact', code: 'NOT_SUBSCRIBED');
      when(() => mockService.resolve('impact'))
          .thenAnswer((_) async => denied);

      final result = await resolver.resolve('impact');
      expect(result.allowed, isFalse);
      verifyNever(() => mockPolicy.cacheResult(any(), any()));
    });
  });

  group('MobileEntitlementResolver — identity anchoring (P1-R6-B / P1-R8-A)', () {
    // The resolver captures userId before the RPC and rechecks after.
    // In unit tests Supabase is not initialized, so anchoredUserId=null
    // and the re-check is skipped — the tests below verify the non-anchored
    // path still behaves correctly (allowed/denied pass through unchanged).
    test('allowed result passes through when no user anchoring (unit-test path)', () async {
      final granted = ProductEntitlementResult(
        allowed: true,
        product: 'impact',
        tier: 'impact',
        source: 'subscription',
      );
      when(() => mockService.resolve('impact'))
          .thenAnswer((_) async => granted);
      when(() => mockPolicy.cacheResult('impact', any()))
          .thenAnswer((_) async {});

      final result = await resolver.resolve('impact');
      expect(result.allowed, isTrue,
          reason: 'No anchoring in unit tests: result should pass through');
    });

    test('FAIL CLOSED when denied and no cache (identity check does not affect denied path)', () async {
      final denied =
          ProductEntitlementResult.denied('quant', code: 'NOT_SUBSCRIBED');
      when(() => mockService.resolve('quant'))
          .thenAnswer((_) async => denied);

      final result = await resolver.resolve('quant');
      expect(result.allowed, isFalse);
    });
  });

  group('MobileEntitlementResolver — FAIL CLOSED contract', () {
    test('FAIL CLOSED when server throws and no cache', () async {
      when(() => mockService.resolve('impact'))
          .thenThrow(Exception('Network error'));
      when(() => mockPolicy.getCachedResult('impact'))
          .thenAnswer((_) async => null);

      final result = await resolver.resolve('impact');
      expect(result.allowed, isFalse,
          reason:
              'Paid product must be denied when server fails and cache is empty');
      expect(result.code, equals('TEMPORARILY_UNAVAILABLE'));
    });

    test('uses offline cache when server throws', () async {
      final cached = ProductEntitlementResult(
        allowed: true,
        product: 'quant',
        tier: 'quant',
        source: 'subscription_offline_cache',
      );
      when(() => mockService.resolve('quant'))
          .thenThrow(Exception('Network error'));
      when(() => mockPolicy.getCachedResult('quant'))
          .thenAnswer((_) async => cached);

      final result = await resolver.resolve('quant');
      expect(result.allowed, isTrue);
      expect(result.source, contains('offline_cache'));
    });

    test('falls back to cache when server returns TEMPORARILY_UNAVAILABLE',
        () async {
      final unavailable =
          ProductEntitlementResult.temporarilyUnavailable('impact');
      final cached = ProductEntitlementResult(
        allowed: true,
        product: 'impact',
        tier: 'impact',
        source: 'subscription_offline_cache',
      );
      when(() => mockService.resolve('impact'))
          .thenAnswer((_) async => unavailable);
      when(() => mockPolicy.getCachedResult('impact'))
          .thenAnswer((_) async => cached);

      final result = await resolver.resolve('impact');
      expect(result.allowed, isTrue);
      expect(result.source, contains('offline_cache'));
    });

    test(
        'FAIL CLOSED when server returns TEMPORARILY_UNAVAILABLE and no cache',
        () async {
      final unavailable =
          ProductEntitlementResult.temporarilyUnavailable('quant');
      when(() => mockService.resolve('quant'))
          .thenAnswer((_) async => unavailable);
      when(() => mockPolicy.getCachedResult('quant'))
          .thenAnswer((_) async => null);

      final result = await resolver.resolve('quant');
      expect(result.allowed, isFalse);
      expect(result.isTemporarilyUnavailable, isTrue,
          reason:
              'Quant must remain denied without a valid offline cache entry');
    });
  });
}
