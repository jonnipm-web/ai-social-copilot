// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — runtimeProductEntitlementProvider wiring tests.
//
// Proves that runtimeProductEntitlementProvider correctly delegates to
// MobileEntitlementResolver on mobile (kIsWeb == false in the test runner).
//
// IMPORTANT: these tests do NOT mock kIsWeb — it is always false in the Dart
// test runner, so they automatically exercise the mobile code path. The Web
// path (kIsWeb == true) is exercised only in a browser-target test; its
// behavior (identical to productEntitlementProvider) is verified by the
// web-regression suite in CI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/data/services/product_entitlement_service.dart';
import 'package:ai_social_copilot/mobile/entitlements/mobile_entitlement_resolver.dart';
import 'package:ai_social_copilot/mobile/offline/offline_entitlement_policy.dart';
import 'package:ai_social_copilot/providers/mobile_entitlement_provider.dart';
import 'package:ai_social_copilot/core/modules/route_policy.dart';
import 'package:ai_social_copilot/mobile/config/product_flavor.dart';

class MockMobileEntitlementResolver extends Mock
    implements MobileEntitlementResolver {}

class MockOfflineEntitlementPolicy extends Mock
    implements OfflineEntitlementPolicy {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ProductEntitlementResult(allowed: false, product: 'fallback'),
    );
  });

  // ---------------------------------------------------------------------------
  // Provider wiring: mobile path uses MobileEntitlementResolver
  // ---------------------------------------------------------------------------

  group('runtimeProductEntitlementProvider — mobile path (kIsWeb == false)', () {
    late MockMobileEntitlementResolver mockResolver;
    late ProviderContainer container;

    setUp(() {
      mockResolver = MockMobileEntitlementResolver();
      container = ProviderContainer(
        overrides: [
          mobileEntitlementResolverProvider.overrideWithValue(mockResolver),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('allowed: delegates to resolver and returns allowed result', () async {
      final granted = ProductEntitlementResult(
        allowed: true,
        product: 'impact',
        tier: 'impact',
        source: 'subscription',
      );
      when(() => mockResolver.resolve('impact')).thenAnswer((_) async => granted);

      final result =
          await container.read(runtimeProductEntitlementProvider('impact').future);
      expect(result.allowed, isTrue);
      expect(result.product, equals('impact'));
      verify(() => mockResolver.resolve('impact')).called(1);
    });

    test('denied: returns denied result without mutation', () async {
      final denied = ProductEntitlementResult.denied('quant', code: 'NOT_SUBSCRIBED');
      when(() => mockResolver.resolve('quant')).thenAnswer((_) async => denied);

      final result =
          await container.read(runtimeProductEntitlementProvider('quant').future);
      expect(result.allowed, isFalse);
      expect(result.code, equals('NOT_SUBSCRIBED'));
    });

    test('FAIL CLOSED: resolver returns temporarilyUnavailable on network error', () async {
      final unavailable = ProductEntitlementResult.temporarilyUnavailable('impact');
      when(() => mockResolver.resolve('impact')).thenAnswer((_) async => unavailable);

      final result =
          await container.read(runtimeProductEntitlementProvider('impact').future);
      expect(result.allowed, isFalse);
      expect(result.isTemporarilyUnavailable, isTrue);
    });

    test('FAIL CLOSED: resolver returns temporarilyUnavailable when no cache', () async {
      final unavailable = ProductEntitlementResult.temporarilyUnavailable('quant');
      when(() => mockResolver.resolve('quant')).thenAnswer((_) async => unavailable);

      final result =
          await container.read(runtimeProductEntitlementProvider('quant').future);
      expect(result.allowed, isFalse,
          reason: 'Quant must be denied when RPC fails and cache is empty');
    });
  });

  // ---------------------------------------------------------------------------
  // Flavor isolation: cross-product routes are blocked UPSTREAM by route gate
  // (route_policy.dart isRouteBlockedByFlavor). These tests verify the resolver
  // itself returns denied when the user lacks the required product entitlement.
  // ---------------------------------------------------------------------------

  group('runtimeProductEntitlementProvider — flavor isolation contract', () {
    late MockMobileEntitlementResolver mockResolver;
    late ProviderContainer container;

    setUp(() {
      mockResolver = MockMobileEntitlementResolver();
      container = ProviderContainer(
        overrides: [
          mobileEntitlementResolverProvider.overrideWithValue(mockResolver),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('Core APK: requesting Impact entitlement returns denied', () async {
      final denied = ProductEntitlementResult.denied('impact', code: 'NOT_SUBSCRIBED');
      when(() => mockResolver.resolve('impact')).thenAnswer((_) async => denied);

      final result =
          await container.read(runtimeProductEntitlementProvider('impact').future);
      expect(result.allowed, isFalse,
          reason: 'Core user must not gain Impact access');
    });

    test('Core APK: requesting Quant entitlement returns denied', () async {
      final denied = ProductEntitlementResult.denied('quant', code: 'NOT_SUBSCRIBED');
      when(() => mockResolver.resolve('quant')).thenAnswer((_) async => denied);

      final result =
          await container.read(runtimeProductEntitlementProvider('quant').future);
      expect(result.allowed, isFalse,
          reason: 'Core user must not gain Quant access');
    });

    test('Impact APK: Impact entitlement allowed for subscribed user', () async {
      final granted = ProductEntitlementResult(
        allowed: true,
        product: 'impact',
        tier: 'impact',
        source: 'subscription',
      );
      when(() => mockResolver.resolve('impact')).thenAnswer((_) async => granted);

      final result =
          await container.read(runtimeProductEntitlementProvider('impact').future);
      expect(result.allowed, isTrue);
    });

    test('Quant APK: Quant entitlement allowed for subscribed user', () async {
      final granted = ProductEntitlementResult(
        allowed: true,
        product: 'quant',
        tier: 'quant',
        source: 'subscription',
      );
      when(() => mockResolver.resolve('quant')).thenAnswer((_) async => granted);

      final result =
          await container.read(runtimeProductEntitlementProvider('quant').future);
      expect(result.allowed, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Flavor route gate integration (isRouteBlockedByFlavor + evaluateRouteAccess)
  // ---------------------------------------------------------------------------

  group('Flavor gate + entitlement: combined isolation contract', () {
    tearDown(() => FlavorRegistry.resetForTesting());

    test('Impact flavor blocks Quant route before entitlement check', () {
      FlavorRegistry.init(ProductFlavor.impact);
      // A concrete /quant path should be blocked by the flavor gate.
      final blocked = isRouteBlockedByFlavor('/quant', ProductFlavor.impact);
      expect(blocked, isTrue,
          reason: 'Impact APK must not navigate to Quant routes');
    });

    test('Impact flavor blocks Quant-lab route before entitlement check', () {
      FlavorRegistry.init(ProductFlavor.impact);
      final blocked = isRouteBlockedByFlavor('/quant-lab', ProductFlavor.impact);
      expect(blocked, isTrue,
          reason: 'Impact APK must not navigate to Quant Lab routes');
    });

    test('Quant flavor blocks Impact routes before entitlement check', () {
      FlavorRegistry.init(ProductFlavor.quant);
      final blocked = isRouteBlockedByFlavor('/impact', ProductFlavor.quant);
      expect(blocked, isTrue,
          reason: 'Quant APK must not navigate to Impact routes');
    });

    test('Quant flavor blocks parameterized /impact/:id route', () {
      FlavorRegistry.init(ProductFlavor.quant);
      final blocked =
          isRouteBlockedByFlavor('/impact/abc123', ProductFlavor.quant);
      expect(blocked, isTrue,
          reason: 'Parameterized Impact routes must be blocked for Quant APK');
    });

    test('Impact flavor allows own /impact route', () {
      FlavorRegistry.init(ProductFlavor.impact);
      final blocked = isRouteBlockedByFlavor('/impact', ProductFlavor.impact);
      expect(blocked, isFalse,
          reason: 'Impact APK must be able to navigate its own routes');
    });

    test('Core flavor allows all product routes (base product)', () {
      FlavorRegistry.init(ProductFlavor.core);
      expect(isRouteBlockedByFlavor('/impact', ProductFlavor.core), isFalse);
      expect(isRouteBlockedByFlavor('/quant', ProductFlavor.core), isFalse);
    });

    test('evaluateRouteAccess blocks cross-product route for Impact flavor', () {
      FlavorRegistry.init(ProductFlavor.impact);
      final decision = evaluateRouteAccess(
        path: '/quant',
        isAdmin: false,
        isPro: true,
        profileResolved: true,
        flavorOverride: ProductFlavor.impact,
      );
      expect(decision, equals(RouteDecision.redirectDenied),
          reason: 'Impact APK must redirectDenied for Quant route even with PRO');
    });

    test('evaluateRouteAccess allows own route for Impact flavor (admin bypasses)', () {
      FlavorRegistry.init(ProductFlavor.impact);
      final decision = evaluateRouteAccess(
        path: '/impact',
        isAdmin: true,
        isPro: false,
        profileResolved: true,
        flavorOverride: ProductFlavor.impact,
      );
      // /impact is INTERNAL lifecycle → redirectDenied unless admin
      expect(decision, equals(RouteDecision.allow),
          reason: 'Admin always passes the flavor gate');
    });
  });

  // ---------------------------------------------------------------------------
  // Base Free preservation
  // ---------------------------------------------------------------------------

  group('BASE_FREE preservation', () {
    late MockMobileEntitlementResolver mockResolver;
    late ProviderContainer container;

    setUp(() {
      mockResolver = MockMobileEntitlementResolver();
      container = ProviderContainer(
        overrides: [
          mobileEntitlementResolverProvider.overrideWithValue(mockResolver),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('Core BASE_FREE: resolver returns allowed without subscription', () async {
      final baseFree = ProductEntitlementResult(
        allowed: true,
        product: 'core',
        source: 'base_free',
      );
      when(() => mockResolver.resolve('core')).thenAnswer((_) async => baseFree);

      final result =
          await container.read(runtimeProductEntitlementProvider('core').future);
      expect(result.allowed, isTrue,
          reason: 'BASE_FREE core must always be allowed');
    });
  });

  // ---------------------------------------------------------------------------
  // Sign-out cache invalidation (P1-R13-B fix)
  // Verifies that offlineEntitlementPolicyProvider.clearAll() is accessible
  // via the provider graph, which is what AuthNotifier.signOut() calls on
  // mobile (kIsWeb == false) to prevent cached grants from surviving sign-out.
  // ---------------------------------------------------------------------------

  group('Sign-out cache invalidation — P1-R13-B', () {
    test('offlineEntitlementPolicyProvider is accessible and clearAll() callable', () async {
      final mockPolicy = MockOfflineEntitlementPolicy();
      when(() => mockPolicy.clearAll()).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          offlineEntitlementPolicyProvider.overrideWithValue(mockPolicy),
        ],
      );
      addTearDown(container.dispose);

      // Simulate what AuthNotifier.signOut() does on mobile:
      // read offlineEntitlementPolicyProvider and call clearAll().
      await container.read(offlineEntitlementPolicyProvider).clearAll();

      verify(() => mockPolicy.clearAll()).called(1);
    });

    test('runtimeProductEntitlementProvider uses shared policy when overridden', () async {
      // Verifies that mobileEntitlementResolverProvider and
      // offlineEntitlementPolicyProvider can both be overridden in the same
      // container, which is the pattern AuthNotifier.signOut() relies on.
      final mockPolicy = MockOfflineEntitlementPolicy();
      final mockResolver = MockMobileEntitlementResolver();
      when(() => mockPolicy.clearAll()).thenAnswer((_) async {});
      when(() => mockResolver.resolve(any())).thenAnswer((_) async =>
          ProductEntitlementResult(allowed: true, product: 'impact'));

      final container = ProviderContainer(
        overrides: [
          offlineEntitlementPolicyProvider.overrideWithValue(mockPolicy),
          mobileEntitlementResolverProvider.overrideWithValue(mockResolver),
        ],
      );
      addTearDown(container.dispose);

      // Simulate sign-out clearing the cache, then resolver still works.
      await container.read(offlineEntitlementPolicyProvider).clearAll();
      final result = await container
          .read(runtimeProductEntitlementProvider('impact').future);
      verify(() => mockPolicy.clearAll()).called(1);
      expect(result.allowed, isTrue);
    });
  });
}
