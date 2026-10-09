// IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D7
// Apple IAP billing adapter using in_app_purchase.
//
// SECURITY INVARIANTS (same as GooglePlayBillingProvider):
//   - isAvailable = false when MobileProductCatalog has no configured products
//   - NEVER grant entitlement client-side from a transaction
//   - purchase() returns PENDING_SERVER_VERIFICATION — caller must send the
//     BillingReceipt.payload to the server for validation
//   - BILLING_NOT_CONFIGURED when product IDs are OWNER_INPUT_REQUIRED
//
// ACTIVATION GATE (IV-MOBILE-BILLING-01):
//   Before this provider grants real entitlements:
//   1. Paulo + Agente Martins must authorize live billing activation
//   2. Real product IDs must be configured in MobileProductCatalog
//   3. validate-mobile-purchase Edge Function must be deployed with Apple
//      Shared Secret configured as env var
//   4. App Store Connect in-app purchases must be approved and active
//   5. Server-side receipt validation (App Store API v2) must be verified
//
// iOS BUILD NOTE (D8):
//   Full runtime validation requires macOS/Xcode build environment.
//   The Dart abstraction layer is complete and testable on all platforms.

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_provider.dart';
import 'mobile_product_catalog.dart';

class AppleIapBillingProvider implements BillingProvider {
  // Lazy: InAppPurchase.instance is NOT accessed in the constructor.
  // It is only accessed when _iap is first used (after catalog checks).
  // This keeps unit tests free of platform channel errors.
  final InAppPurchase? _injectedIap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, Completer<BillingPurchaseResult>> _pending = {};
  List<BillingReceipt>? _restoreCollection;
  final Map<String, PurchaseDetails> _pendingAcks = {};

  AppleIapBillingProvider({InAppPurchase? iap}) : _injectedIap = iap;

  InAppPurchase get _iap => _injectedIap ?? InAppPurchase.instance;

  @override
  String get platform => 'apple_iap';

  @override
  bool get isAvailable => MobileProductCatalog.hasProducts;

  void _ensureListening() {
    _subscription ??= _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        debugPrint('[AppleIAP] purchaseStream error: $error');
        for (final c in _pending.values) {
          if (!c.isCompleted) {
            c.complete(BillingPurchaseResult.failure('STREAM_ERROR: $error'));
          }
        }
        _pending.clear();
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // CRITICAL: do NOT grant entitlement here.
          // Populate receipt.payload with the base64-encoded App Store receipt.
          // POST to validate-mobile-purchase Edge Function for server validation.
          // key is defined before receipt so transactionId can be populated.
          final key = purchase.purchaseID ?? purchase.productID;
          final receipt = BillingReceipt(
            platform: platform,
            payload: purchase.verificationData.serverVerificationData,
            productId: purchase.productID,
            transactionId: key,
          );
          _pendingAcks[key] = purchase;

          final completer = _pending.remove(purchase.productID);
          if (completer != null && !completer.isCompleted) {
            completer.complete(BillingPurchaseResult(
              success: false,
              productId: purchase.productID,
              transactionId: key,
              error: 'PENDING_SERVER_VERIFICATION',
              receipt: receipt,
            ));
          } else {
            if (_restoreCollection != null) {
              _restoreCollection!.add(receipt);
            } else {
              debugPrint(
                '[AppleIAP] orphaned ${purchase.status.name} event for '
                '${purchase.productID} — no pending entry; call '
                'restorePurchases() to recover this transaction.',
              );
            }
          }
          // Do NOT call completePurchase() here — deferred to acknowledgePurchase()
          // after server validation. Un-finalized transactions re-appear on restart.

        case PurchaseStatus.error:
          final completer = _pending.remove(purchase.productID);
          if (completer != null && !completer.isCompleted) {
            completer.complete(BillingPurchaseResult.failure(
              purchase.error?.message ?? 'APPLE_IAP_PURCHASE_ERROR',
            ));
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

        case PurchaseStatus.canceled:
          final completer = _pending.remove(purchase.productID);
          if (completer != null && !completer.isCompleted) {
            completer.complete(BillingPurchaseResult.failure('PURCHASE_CANCELLED'));
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

        case PurchaseStatus.pending:
          // Apple pending transactions (e.g. Ask to Buy / parental approval).
          // Deliver a PurchaseStatus.purchased when approved.
          debugPrint('[AppleIAP] pending transaction for ${purchase.productID}');
      }
    }
  }

  @override
  Future<BillingPurchaseResult> purchase(String productId) async {
    if (!MobileProductCatalog.hasProducts) {
      return BillingPurchaseResult.failure(
        'APPLE_IAP_NOT_CONFIGURED: configure product IDs in '
        'MobileProductCatalog before activating billing (IV-MOBILE-BILLING-01)',
      );
    }
    if (!MobileProductCatalog.isKnownProduct(productId)) {
      return BillingPurchaseResult.failure(
        'PRODUCT_NOT_IN_CATALOG: $productId',
      );
    }

    final available = await _iap.isAvailable().catchError((_) => false);
    if (!available) {
      return BillingPurchaseResult.failure('APPLE_IAP_UNAVAILABLE');
    }

    ProductDetailsResponse response;
    try {
      response = await _iap.queryProductDetails({productId});
    } catch (e) {
      return BillingPurchaseResult.failure(
        'QUERY_PRODUCT_ERROR: $e',
      );
    }

    if (response.error != null || response.productDetails.isEmpty) {
      return BillingPurchaseResult.failure(
        'PRODUCT_NOT_FOUND_IN_STORE: ${response.error?.message ?? "not found in App Store Connect"}',
      );
    }

    // Guard: reject duplicate in-flight purchases for the same product.
    if (_pending.containsKey(productId)) {
      return BillingPurchaseResult.failure(
        'PURCHASE_ALREADY_IN_FLIGHT: $productId is already being purchased',
      );
    }

    _ensureListening();

    final completer = Completer<BillingPurchaseResult>();
    _pending[productId] = completer;

    final product = response.productDetails.first;
    final ok = await _iap
        .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product))
        .catchError((Object e) {
      _pending.remove(productId);
      if (!completer.isCompleted) {
        completer.complete(BillingPurchaseResult.failure('BUY_INIT_ERROR: $e'));
      }
      return false;
    });

    if (!ok && !completer.isCompleted) {
      _pending.remove(productId);
      return BillingPurchaseResult.failure('PURCHASE_INITIATION_FAILED');
    }

    return completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        _pending.remove(productId);
        return BillingPurchaseResult.failure('PURCHASE_TIMEOUT');
      },
    );
  }

  @override
  Future<List<BillingReceipt>> restorePurchases() async {
    if (!MobileProductCatalog.hasProducts) return const [];
    _ensureListening();
    _restoreCollection = [];
    try {
      await _iap.restorePurchases();
      // Apple delivers restored events asynchronously; wait for them.
      await Future.delayed(const Duration(seconds: 5));
      return List.unmodifiable(_restoreCollection ?? const []);
    } catch (e) {
      debugPrint('[AppleIAP] restorePurchases error: $e');
      return const [];
    } finally {
      _restoreCollection = null;
    }
  }

  @override
  Future<void> acknowledgePurchase(String transactionId) async {
    final purchase = _pendingAcks.remove(transactionId);
    if (purchase == null) {
      debugPrint('[AppleIAP] acknowledgePurchase: no pending ack for $transactionId');
      return;
    }
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete(BillingPurchaseResult.failure('PROVIDER_DISPOSED'));
      }
    }
    _pending.clear();
    _pendingAcks.clear();
  }
}
