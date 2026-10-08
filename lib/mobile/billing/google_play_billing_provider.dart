// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Google Play billing provider stub.
//
// BLOCKED_OWNER: full Google Play Billing integration requires:
//   1. Paulo + Agente Martins authorization to activate LIVE billing
//   2. in_app_purchase Flutter package integration (already in pubspec.yaml)
//   3. Play Console in-app product SKU configuration per application ID
//   4. Server-side receipt validation endpoint (separate mission gate)
//
// This stub is wired in via BillingProviderFactory when running on Android.
// It returns failure for all purchase attempts until the full integration
// is authorized and implemented.

import 'billing_provider.dart';

class GooglePlayBillingProvider implements BillingProvider {
  @override
  String get platform => 'google_play';

  @override
  bool get isAvailable {
    // TODO(IV-MOBILE-BILLING-01): check in_app_purchase availability
    // via InAppPurchase.instance.isAvailable() once authorized.
    return false;
  }

  @override
  Future<BillingPurchaseResult> purchase(String productId) async {
    // FAIL CLOSED: Google Play Billing not yet activated.
    // This is intentional — no LIVE billing in this macro.
    return BillingPurchaseResult.failure(
      'GOOGLE_PLAY_BILLING_NOT_ACTIVATED: purchase flow requires '
      'explicit authorization (IV-MOBILE-BILLING-01)',
    );
  }

  @override
  Future<List<BillingReceipt>> restorePurchases() async {
    return const [];
  }

  @override
  Future<void> dispose() async {}
}
