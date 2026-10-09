// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — Stripe billing provider (Web/desktop).
//
// Wraps the existing BillingService (create-checkout-session edge function).
// Used when running on Web or desktop Flutter targets. On Android/iOS, the
// platform-native billing providers are used instead.

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/services/billing_service.dart';
import 'billing_provider.dart';

class StripeBillingProvider implements BillingProvider {
  final BillingService _service;

  StripeBillingProvider({BillingService? service})
      : _service = service ?? BillingService();

  @override
  String get platform => 'stripe';

  @override
  bool get isAvailable => kIsWeb;

  @override
  Future<BillingPurchaseResult> purchase(String productId) async {
    // P2-R3-C (Codex adversarial review): a checkout session URL is NOT proof
    // of payment or entitlement activation. Actual entitlement is set
    // server-side by the Stripe webhook (stripe-webhook Edge Function).
    // This method opens the browser checkout flow; the result should be
    // treated as PENDING until the webhook-backed resolve_product_entitlement
    // RPC confirms the subscription is active.
    //
    // NOTE: productId is not passed to the server here because the current
    // create-checkout-session function resolves the price from STRIPE_PRICE_ID_*
    // server-side env vars. Per-product checkout routing is a future gate
    // (IV-MOBILE-BILLING-01).
    try {
      final url = await _service.createCheckoutSession();
      // success: false — checkout session created, PAYMENT NOT YET CONFIRMED.
      // The caller must open [transactionId] in a browser and then
      // re-resolve the entitlement via ProductEntitlementService after
      // the webhook has fired.
      return BillingPurchaseResult(
        success: false,
        productId: productId,
        transactionId: url, // = Stripe Checkout URL to open in browser
        error: 'CHECKOUT_SESSION_CREATED_PENDING_PAYMENT',
      );
    } catch (e) {
      return BillingPurchaseResult.failure('Stripe checkout failed: $e');
    }
  }

  @override
  Future<List<BillingReceipt>> restorePurchases() async {
    // Stripe reconciliation is server-driven via Stripe webhooks.
    // There is no client-side restore flow for Stripe.
    return const [];
  }

  @override
  Future<void> acknowledgePurchase(String transactionId) async {
    // Stripe entitlement is server-driven via webhooks.
    // There is no client-side acknowledgement step for Stripe.
  }

  @override
  Future<void> dispose() async {}
}
