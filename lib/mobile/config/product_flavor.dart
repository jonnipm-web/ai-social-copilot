// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Product flavor identity.
//
// Each product APK is built with a single flavor. FlavorRegistry.init()
// is called at the very start of the flavor-specific entry point
// (lib/main_core.dart, lib/main_impact.dart, lib/main_quant.dart).
// After that call, FlavorRegistry.current is immutable for the app lifetime.

enum ProductFlavor {
  core,
  impact,
  quant,
}

extension ProductFlavorInfo on ProductFlavor {
  String get productId {
    switch (this) {
      case ProductFlavor.core:
        return 'core';
      case ProductFlavor.impact:
        return 'impact';
      case ProductFlavor.quant:
        return 'quant';
    }
  }

  String get displayName {
    switch (this) {
      case ProductFlavor.core:
        return 'InsightValues Core';
      case ProductFlavor.impact:
        return 'InsightValues Impact';
      case ProductFlavor.quant:
        return 'InsightValues Quant';
    }
  }

  // The Android package id and iOS bundle id for this flavor.
  String get applicationId {
    switch (this) {
      case ProductFlavor.core:
        return 'com.insightvalues.core';
      case ProductFlavor.impact:
        return 'com.insightvalues.impact';
      case ProductFlavor.quant:
        return 'com.insightvalues.quant';
    }
  }

  // Deep link host for this flavor.
  String get deepLinkHost {
    return productId;
  }

  // Whether this flavor's primary product requires an active entitlement.
  bool get requiresEntitlement {
    switch (this) {
      case ProductFlavor.core:
        return false; // BASE_FREE tier — no entitlement gate
      case ProductFlavor.impact:
        return true;
      case ProductFlavor.quant:
        return true;
    }
  }
}

// Singleton registry — set once at app startup, read-only thereafter.
class FlavorRegistry {
  FlavorRegistry._();

  static ProductFlavor? _current;

  static ProductFlavor get current {
    assert(_current != null,
        'FlavorRegistry.init() must be called before FlavorRegistry.current');
    return _current!;
  }

  static void init(ProductFlavor flavor) {
    assert(_current == null,
        'FlavorRegistry.init() called twice — flavor is already ${_current?.name}');
    _current = flavor;
  }

  // Nullable accessor — returns null when init() has not been called.
  // Use this to check flavor state without triggering the assert.
  // In production code, use [current] after calling [init].
  // In tests/Web/desktop where no flavor is set, returns null (no-op gate).
  static ProductFlavor? get maybeCurrentFlavor => _current;

  // Test-only helper to reset the singleton between tests.
  // Must NOT be called in production code.
  static void resetForTesting() {
    _current = null;
  }
}
