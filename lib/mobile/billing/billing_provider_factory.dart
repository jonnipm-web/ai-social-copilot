// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — BillingProvider factory.
//
// FOUNDATION PHASE — NOT YET WIRED INTO production purchase flows.
// Wiring the purchase/restore flows to use this factory is deferred to
// IV-MOBILE-BILLING-01 (requires BLOCKED_OWNER: Google Play + Apple IAP
// developer accounts and store listing). The stub providers below return
// BILLING_NOT_ACTIVATED; no purchase is possible in the Foundation build.
// This is the expected Foundation-phase state per mission brief Section 18.
//
// Selects the correct billing provider for the current platform:
//   - Web → StripeBillingProvider
//   - Android → GooglePlayBillingProvider (stub until IV-MOBILE-BILLING-01)
//   - iOS → AppleIapBillingProvider (stub until IV-MOBILE-BILLING-01)
//
// SECURITY: never returns a provider that sends secrets from the client.
// All receipt validation happens server-side.

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'apple_iap_billing_provider.dart';
import 'billing_provider.dart';
import 'google_play_billing_provider.dart';
import 'stripe_billing_provider.dart';

class BillingProviderFactory {
  BillingProviderFactory._();

  static BillingProvider create() {
    if (kIsWeb) {
      return StripeBillingProvider();
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return GooglePlayBillingProvider();
      case TargetPlatform.iOS:
        return AppleIapBillingProvider();
      default:
        // Desktop or other targets: fall back to Stripe Web flow.
        return StripeBillingProvider();
    }
  }
}
