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
class BillingPurchaseResult {
  final bool success;
  final String? productId;
  final String? transactionId;
  final String? error;

  const BillingPurchaseResult({
    required this.success,
    this.productId,
    this.transactionId,
    this.error,
  });

  factory BillingPurchaseResult.failure(String reason) =>
      BillingPurchaseResult(success: false, error: reason);
}

/// A raw receipt from the billing platform, passed server-side for validation.
/// Never trust these on-device — always validate via the server RPC.
class BillingReceipt {
  final String platform; // 'google_play' | 'apple_iap' | 'stripe'
  final String payload;  // opaque platform token

  const BillingReceipt({required this.platform, required this.payload});
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

  /// Releases any platform billing client resources.
  Future<void> dispose();
}
