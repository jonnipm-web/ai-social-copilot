// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Apple IAP billing provider stub.
//
// BLOCKED_OWNER: full Apple IAP integration requires:
//   1. Paulo + Agente Martins authorization to activate LIVE billing
//   2. macOS/Xcode environment for iOS build (Windows env: config only)
//   3. App Store Connect in-app purchase configuration per bundle ID
//   4. Server-side receipt validation endpoint (separate mission gate)
//   5. Apple Shared Secret configured in server environment
//
// This stub is wired in via BillingProviderFactory when running on iOS.
// It returns failure for all purchase attempts until the full integration
// is authorized and implemented.

import 'billing_provider.dart';

class AppleIapBillingProvider implements BillingProvider {
  @override
  String get platform => 'apple_iap';

  @override
  bool get isAvailable {
    // TODO(IV-MOBILE-BILLING-01): check in_app_purchase availability
    // via InAppPurchase.instance.isAvailable() once authorized.
    return false;
  }

  @override
  Future<BillingPurchaseResult> purchase(String productId) async {
    // FAIL CLOSED: Apple IAP not yet activated.
    // This is intentional — no LIVE billing in this macro.
    return BillingPurchaseResult.failure(
      'APPLE_IAP_NOT_ACTIVATED: purchase flow requires '
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
