// IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D4
// Deep link contract tests: verifies per-flavor isolation at both the
// Android manifest level (scheme+host) and the Dart route-policy level
// (isRouteBlockedByFlavor / evaluateRouteAccess).
//
// Contract:
//   - Each APK only handles its own deep link scheme+host (manifest-level)
//   - Cross-product routes are denied inside the app (route-policy level)
//   - Core routes are accessible from any APK (BASE_FREE)

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/modules/route_policy.dart';
import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/mobile/config/product_flavor.dart';

// ---------------------------------------------------------------------------
// Manifest helpers
// ---------------------------------------------------------------------------

/// Reads the merged Android manifest for a given flavor overlay.
String _readFlavorManifest(String flavor) =>
    File('android/app/src/$flavor/AndroidManifest.xml').readAsStringSync();

/// Extracts all android:host values from intent-filter data elements.
List<String> _extractHosts(String manifestContent) {
  final re = RegExp(r'android:host="([^"]+)"');
  return re.allMatches(manifestContent).map((m) => m.group(1)!).toList();
}

/// Extracts all android:scheme values from intent-filter data elements.
List<String> _extractSchemes(String manifestContent) {
  final re = RegExp(r'android:scheme="([^"]+)"');
  return re.allMatches(manifestContent).map((m) => m.group(1)!).toList();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() => FlavorRegistry.resetForTesting());
  tearDown(() => FlavorRegistry.resetForTesting());

  // ─── D4-M: Android manifest isolation ────────────────────────────────────

  group('D4-M — Android manifest deep link isolation', () {
    test('core manifest handles only insightvalues://core/*', () {
      final manifest = _readFlavorManifest('core');
      final hosts = _extractHosts(manifest);
      final schemes = _extractSchemes(manifest);
      expect(hosts, equals(['core']),
          reason: 'Core APK manifest must handle only host=core');
      expect(schemes, everyElement(equals('insightvalues')));
    });

    test('impact manifest handles only insightvalues://impact/*', () {
      final manifest = _readFlavorManifest('impact');
      final hosts = _extractHosts(manifest);
      final schemes = _extractSchemes(manifest);
      expect(hosts, equals(['impact']),
          reason: 'Impact APK manifest must handle only host=impact');
      expect(schemes, everyElement(equals('insightvalues')));
    });

    test('quant manifest handles quant hosts only', () {
      final manifest = _readFlavorManifest('quant');
      final hosts = _extractHosts(manifest);
      final schemes = _extractSchemes(manifest);
      expect(hosts, everyElement(equals('quant')),
          reason: 'Quant APK manifest must handle only host=quant');
      expect(schemes, everyElement(equals('insightvalues')));
    });

    test('no APK manifest handles another product host', () {
      final coreHosts = _extractHosts(_readFlavorManifest('core'));
      final impactHosts = _extractHosts(_readFlavorManifest('impact'));
      final quantHosts = _extractHosts(_readFlavorManifest('quant'));
      // Cross-contamination check
      expect(coreHosts, isNot(contains('impact')));
      expect(coreHosts, isNot(contains('quant')));
      expect(impactHosts, isNot(contains('core')));
      expect(impactHosts, isNot(contains('quant')));
      expect(quantHosts, isNot(contains('core')));
      expect(quantHosts, isNot(contains('impact')));
    });
  });

  // ─── D4-R: Route-level cross-product deep link rejection ─────────────────

  group('D4-R — Route-level cross-product deep link rejection', () {
    // Impact deep link in Quant APK → DENY
    test('Quant APK: /impact route (Impact deep link) → isRouteBlockedByFlavor=true', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeImpact, ProductFlavor.quant),
        isTrue,
        reason: 'Quant APK must block /impact deep link route',
      );
    });

    test('Quant APK: /impact/discover → isRouteBlockedByFlavor=true', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeImpactDiscover, ProductFlavor.quant),
        isTrue,
      );
    });

    test('Quant APK: /impact/<id> concrete path → isRouteBlockedByFlavor=true', () {
      expect(
        isRouteBlockedByFlavor('/impact/inv-abc123', ProductFlavor.quant),
        isTrue,
        reason: 'Quant APK must block concrete /impact/<id> paths',
      );
    });

    // Quant deep link in Impact APK → DENY
    test('Impact APK: /quant route (Quant deep link) → isRouteBlockedByFlavor=true', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeQuant, ProductFlavor.impact),
        isTrue,
        reason: 'Impact APK must block /quant deep link route',
      );
    });

    test('Impact APK: /quant-lab → isRouteBlockedByFlavor=true', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeQuantLab, ProductFlavor.impact),
        isTrue,
      );
    });

    // Core deep link in Impact/Quant APK — Core routes are BASE_FREE
    test('Impact APK: core route /home → isRouteBlockedByFlavor=false (BASE_FREE)', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeHome, ProductFlavor.impact),
        isFalse,
        reason: 'Core routes must be reachable from Impact APK (BASE_FREE)',
      );
    });

    test('Quant APK: core route /dashboard → isRouteBlockedByFlavor=false (BASE_FREE)', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeDashboard, ProductFlavor.quant),
        isFalse,
      );
    });

    // Quant deep link in Core APK — Core sees all routes (BASE_FREE, full access)
    test('Core APK: /quant route → isRouteBlockedByFlavor=false (core is full access)', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeQuant, ProductFlavor.core),
        isFalse,
        reason: 'Core APK has full access (no flavor blocking)',
      );
    });

    // Own routes → PASS
    test('Impact APK: /impact → isRouteBlockedByFlavor=false (own product)', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeImpact, ProductFlavor.impact),
        isFalse,
      );
    });

    test('Quant APK: /quant → isRouteBlockedByFlavor=false (own product)', () {
      expect(
        isRouteBlockedByFlavor(AppConstants.routeQuant, ProductFlavor.quant),
        isFalse,
      );
    });
  });

  // ─── D4-E: evaluateRouteAccess integration (deep link + entitlement) ─────

  group('D4-E — evaluateRouteAccess: deep link blocked regardless of plan', () {
    test('Impact APK: Quant deep link → redirectDenied even for PRO user', () {
      final decision = evaluateRouteAccess(
        path: AppConstants.routeQuant,
        isAdmin: false,
        isPro: true,
        profileResolved: true,
        flavorOverride: ProductFlavor.impact,
      );
      expect(decision, equals(RouteDecision.redirectDenied),
          reason: 'Cross-product deep links must be denied regardless of plan');
    });

    test('Quant APK: Impact deep link → redirectDenied even for PRO user', () {
      final decision = evaluateRouteAccess(
        path: AppConstants.routeImpact,
        isAdmin: false,
        isPro: true,
        profileResolved: true,
        flavorOverride: ProductFlavor.quant,
      );
      expect(decision, equals(RouteDecision.redirectDenied));
    });

    test('Admin bypasses flavor gate (support access)', () {
      final decision = evaluateRouteAccess(
        path: AppConstants.routeImpact,
        isAdmin: true,
        isPro: false,
        profileResolved: true,
        flavorOverride: ProductFlavor.quant,
      );
      expect(decision, isNot(equals(RouteDecision.redirectDenied)),
          reason: 'Admin must bypass flavor gate for debugging/support');
    });
  });

  // ─── D4-V: Version catalog monotonicity ──────────────────────────────────

  group('D4-V — Android version catalog validation', () {
    late Map<String, String> catalog;

    setUpAll(() {
      final content = File('android/app/version_catalog.properties')
          .readAsStringSync();
      catalog = Map.fromEntries(
        content
            .split('\n')
            .where((l) => l.contains('=') && !l.startsWith('#'))
            .map((l) {
          final parts = l.split('=');
          return MapEntry(parts[0].trim(), parts[1].trim());
        }),
      );
    });

    for (final flavor in ['core', 'impact', 'quant']) {
      test('$flavor.versionCode is a positive integer', () {
        final raw = catalog['$flavor.versionCode'];
        expect(raw, isNotNull, reason: 'version_catalog.properties must have $flavor.versionCode');
        final code = int.tryParse(raw!);
        expect(code, isNotNull, reason: '$flavor.versionCode must be an integer');
        expect(code, greaterThan(0), reason: 'Play Store requires versionCode >= 1');
      });

      test('$flavor.versionName is a semver string', () {
        final raw = catalog['$flavor.versionName'];
        expect(raw, isNotNull);
        final semverRe = RegExp(r'^\d+\.\d+\.\d+$');
        expect(semverRe.hasMatch(raw!), isTrue,
            reason: '$flavor.versionName must be MAJOR.MINOR.PATCH format');
      });
    }

    test('all three products have independent version entries', () {
      expect(catalog.containsKey('core.versionCode'), isTrue);
      expect(catalog.containsKey('impact.versionCode'), isTrue);
      expect(catalog.containsKey('quant.versionCode'), isTrue);
    });
  });

  // ─── D4-A: Assetlinks template validation ────────────────────────────────

  group('D4-A — Assetlinks template structure', () {
    late List<dynamic> template;

    setUpAll(() {
      final content = File('android/.well-known/assetlinks.template.json')
          .readAsStringSync();
      template = jsonDecode(content) as List<dynamic>;
    });

    test('template has exactly 3 entries (one per product)', () {
      expect(template.length, equals(3));
    });

    test('template entries cover all three package IDs', () {
      final packages = template
          .map((e) => (e as Map<String, dynamic>)['target']['package_name'] as String)
          .toSet();
      expect(packages, containsAll([
        'com.insightvalues.core',
        'com.insightvalues.impact',
        'com.insightvalues.quant',
      ]));
    });

    test('template fingerprints are placeholder (not real SHA256)', () {
      for (final entry in template) {
        final fingerprints = (entry as Map<String, dynamic>)['target']['sha256_cert_fingerprints'] as List;
        expect(fingerprints, isNotEmpty);
        for (final fp in fingerprints) {
          expect(fp as String, startsWith('<'),
              reason: 'Fingerprints must remain placeholder until real keystore exists');
        }
      }
    });

    test('all entries use delegate_permission/common.handle_all_urls', () {
      for (final entry in template) {
        final relations = (entry as Map<String, dynamic>)['relation'] as List;
        expect(relations, contains('delegate_permission/common.handle_all_urls'));
      }
    });
  });
}
