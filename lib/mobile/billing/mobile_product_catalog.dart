// IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D6/D7
// Mobile product catalog — canonical registry of in-app product IDs.
//
// OWNER_INPUT_REQUIRED: populate with real product IDs before store submission.
// Convention: each product ID matches what's configured in Play Console /
// App Store Connect.
//
// FAIL-CLOSED: if no products are configured (catalog is empty or all
// OWNER_INPUT_REQUIRED), billing is unavailable and purchase attempts
// return an explicit error. This prevents silent misconfiguration.
//
// SECURITY: product IDs are NOT entitlement grants. They only identify
// which item to purchase. Entitlement is granted ONLY after the server
// validates the purchase token (via validate-mobile-purchase Edge Function).

class MobileProductId {
  final String id;
  final String platform; // 'google_play' | 'apple_iap' | 'both'
  final String description;

  const MobileProductId({
    required this.id,
    required this.platform,
    required this.description,
  });

  bool get isConfigured => !id.startsWith('OWNER_INPUT_REQUIRED');
}

class MobileProductCatalog {
  MobileProductCatalog._();

  // ─── OWNER_INPUT_REQUIRED ─────────────────────────────────────────────────
  // Replace each 'OWNER_INPUT_REQUIRED' with the real product ID configured
  // in Google Play Console / App Store Connect before submission.
  //
  // Google Play: product IDs must be lowercase, no spaces, no special chars.
  //   Recommended format: com.insightvalues.<product>.<plan>_<period>
  //   e.g. 'com.insightvalues.core.pro_monthly'
  //
  // Apple IAP: product IDs match the identifier in App Store Connect.
  //   Recommended format: com.insightvalues.<product>.<plan>_<period>
  //   e.g. 'com.insightvalues.impact.monthly'
  //
  // For testing the billing flow with real Play/AppStore sandbox accounts,
  // create the products in their respective consoles first, then update here.

  static const List<MobileProductId> _products = [
    // Core — Pro plan subscription
    MobileProductId(
      id: 'OWNER_INPUT_REQUIRED',
      platform: 'both',
      description: 'InsightValues Core — Pro Monthly',
    ),
    // Impact — monthly subscription
    MobileProductId(
      id: 'OWNER_INPUT_REQUIRED',
      platform: 'both',
      description: 'InsightValues Impact — Monthly',
    ),
    // Quant — monthly subscription
    MobileProductId(
      id: 'OWNER_INPUT_REQUIRED',
      platform: 'both',
      description: 'InsightValues Quant — Monthly',
    ),
    // Suite — all products bundled
    MobileProductId(
      id: 'OWNER_INPUT_REQUIRED',
      platform: 'both',
      description: 'InsightValues Suite — All Products Monthly',
    ),
  ];

  /// Returns true only when at least one product ID is configured (not placeholder).
  static bool get hasProducts => _products.any((p) => p.isConfigured);

  /// Returns true when the given product ID is in the catalog and configured.
  static bool isKnownProduct(String productId) =>
      _products.any((p) => p.isConfigured && p.id == productId);

  /// All configured (non-placeholder) product IDs for a given platform.
  static Set<String> productIdsFor(String platform) => {
    for (final p in _products)
      if (p.isConfigured && (p.platform == platform || p.platform == 'both'))
        p.id,
  };

  /// All configured product IDs (both platforms).
  static Set<String> get allConfiguredIds =>
      {for (final p in _products) if (p.isConfigured) p.id};

  /// Diagnostic: how many products are still OWNER_INPUT_REQUIRED.
  static int get placeholderCount =>
      _products.where((p) => !p.isConfigured).length;
}
