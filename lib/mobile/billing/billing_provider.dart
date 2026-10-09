// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Abstract billing provider interface.
//
// SECURITY INVARIANTS (verbatim from mission brief):
//   - Service role: NUNCA no Mobile
//   - Provider secrets: NUNCA no Mobile
//   - FAIL CLOSED for paid capability on RPC failure
//   - No LIVE billing in this macro
//
// Concrete implementations:
//   - StripeBillingProvider  → lib/mobile/billing/stripe_billing_provider.dart
//   - GooglePlayBillingProvider → lib/mobile/billing/google_play_billing_provider.dart
//   - AppleIapBillingProvider → lib/mobile/billing/apple_iap_billing_provider.dart

/// The result of a purchase or restoration attempt.
///
/// SECURITY CONTRACT (IV-MOBILE-BILLING-01):
///   success == false AND error == "PENDING_SERVER_VERIFICATION" means the
///   purchase was acknowledged by the platform, but NO entitlement has been
///   granted. The caller MUST send [receipt.payload] to the server
///   (validate-mobile-purchase EF) and only grant entitlement after the
///   server confirms. Never treat PENDING_SERVER_VERIFICATION as success.
class BillingPurchaseResult {
  final bool success;
  final String? productId;
  final String? transactionId;
  final String? error;
  /// Opaque platform receipt for server-side validation.
  /// Non-null only when error == "PENDING_SERVER_VERIFICATION".
  /// NEVER use this directly for entitlement — send it to the server.
  final BillingReceipt? receipt;

  const BillingPurchaseResult({
    required this.success,
    this.productId,
    this.transactionId,
    this.error,
    this.receipt,
  });

  factory BillingPurchaseResult.failure(String reason) =>
      BillingPurchaseResult(success: false, error: reason);
}

/// A raw receipt from the billing platform, passed server-side for validation.
/// Never trust these on-device — always validate via the server RPC.
class BillingReceipt {
  final String platform;    // 'google_play' | 'apple_iap' | 'stripe'
  final String payload;     // opaque platform token for server validation
  final String? productId;  // the purchased product ID (for validateReceipt)
  final String? transactionId; // platform transaction ID (for acknowledgePurchase)

  const BillingReceipt({
    required this.platform,
    required this.payload,
    this.productId,
    this.transactionId,
  });
}

/// Abstract billing provider.
/// All implementations MUST be fail-closed for paid entitlements:
/// if the provider cannot confirm a purchase, the entitlement is denied.
abstract class BillingProvider {
  /// Platform identifier, matched against BillingReceipt.platform.
  String get platform;

  /// Whether this provider is available on the current OS/environment.
  bool get isAvailable;

  /// Initiates a purchase flow for [productId].
  /// Returns a [BillingPurchaseResult] — never throws.
  Future<BillingPurchaseResult> purchase(String productId);

  /// Restores previous purchases (for iOS and some Android flows).
  /// Returns a list of receipts pending server-side validation.
  Future<List<BillingReceipt>> restorePurchases();

  /// Acknowledges a purchase after server-side validation confirms entitlement.
  ///
  /// SECURITY CONTRACT: call this ONLY after [MobileBillingReceiptService]
  /// returns [entitlementGranted: true]. Acknowledging before server validation
  /// voids the durability guarantee — the receipt may become unrecoverable.
  ///
  /// Concrete implementations call `InAppPurchase.completePurchase()` here.
  /// Default: no-op for platforms that auto-acknowledge (e.g. Stripe web).
  Future<void> acknowledgePurchase(String transactionId) async {}

  /// Releases any platform billing client resources.
  Future<void> dispose();
}
