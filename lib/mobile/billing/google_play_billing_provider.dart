// IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D6
// Google Play Billing adapter using in_app_purchase.
//
// SECURITY INVARIANTS:
//   - isAvailable = false when MobileProductCatalog has no configured products
//   - NEVER grant entitlement client-side from a purchase token
//   - purchase() returns PENDING_SERVER_VERIFICATION — caller must send the
//     BillingReceipt.payload to the server (validate-mobile-purchase EF) and
//     only update entitlement state after server confirmation
//   - BILLING_NOT_CONFIGURED when product IDs are OWNER_INPUT_REQUIRED
//
// ACTIVATION GATE (IV-MOBILE-BILLING-01):
//   Before this provider grants real entitlements:
//   1. Paulo + Agente Martins must authorize live billing activation
//   2. Real product IDs must be configured in MobileProductCatalog
//   3. validate-mobile-purchase Edge Function must be deployed
//   4. Play Console in-app products must be published and active
//   5. Server-side receipt validation must be end-to-end verified

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_provider.dart';
import 'mobile_product_catalog.dart';

class GooglePlayBillingProvider implements BillingProvider {
  // Lazy: InAppPurchase.instance is NOT accessed in the constructor.
  // It is only accessed when _iap is first used (after catalog checks).
  // This keeps unit tests free of platform channel errors.
  final InAppPurchase? _injectedIap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, Completer<BillingPurchaseResult>> _pending = {};
  // Collect restored receipts during a restorePurchases() call.
  // Null when no restore is in progress.
  List<BillingReceipt>? _restoreCollection;
  // Purchases waiting for explicit acknowledgement after server validation.
  // completePurchase() is NOT called until acknowledgePurchase() is invoked
  // by the caller (after server confirms entitlement).
  final Map<String, PurchaseDetails> _pendingAcks = {};

  GooglePlayBillingProvider({InAppPurchase? iap}) : _injectedIap = iap;

  InAppPurchase get _iap => _injectedIap ?? InAppPurchase.instance;

  @override
  String get platform => 'google_play';

  @override
  bool get isAvailable => MobileProductCatalog.hasProducts;

  void _ensureListening() {
    _subscription ??= _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        debugPrint('[GooglePlay] purchaseStream error: $error');
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
          // Populate receipt.payload with the platform token for server validation.
          // The caller must POST receipt.payload to validate-mobile-purchase and
          // only update local entitlement state after server confirmation.
          // key is defined before receipt so transactionId can be populated.
          final key = purchase.purchaseID ?? purchase.productID;
          final receipt = BillingReceipt(
            platform: platform,
            payload: purchase.verificationData.serverVerificationData,
            productId: purchase.productID,
            transactionId: key,
          );
          // Store for deferred acknowledgement. completePurchase() is NOT called
          // here — the caller must invoke acknowledgePurchase(transactionId) AFTER
          // server validation confirms entitlement. If the app crashes before
          // acknowledgement, the platform will re-deliver the event on next launch.
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
                '[GooglePlay] orphaned ${purchase.status.name} event for '
                '${purchase.productID} — no pending entry; call '
                'restorePurchases() to recover this transaction.',
              );
            }
          }

        case PurchaseStatus.error:
          final completer = _pending.remove(purchase.productID);
          if (completer != null && !completer.isCompleted) {
            completer.complete(BillingPurchaseResult.failure(
              purchase.error?.message ?? 'GOOGLE_PLAY_PURCHASE_ERROR',
            ));
          }
          // Error/cancel events are terminal — complete immediately to clean up
          // platform state. No entitlement is granted, so durability is not at risk.
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
          // Google Play pending transaction (e.g. cash payment in Brazil).
          // Result will arrive later via stream. Do not complete yet.
          debugPrint('[GooglePlay] pending transaction for ${purchase.productID}');
      }
    }
  }

  @override
  Future<BillingPurchaseResult> purchase(String productId) async {
    if (!MobileProductCatalog.hasProducts) {
      return BillingPurchaseResult.failure(
        'GOOGLE_PLAY_BILLING_NOT_CONFIGURED: configure product IDs in '
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
      return BillingPurchaseResult.failure('GOOGLE_PLAY_BILLING_UNAVAILABLE');
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
        'PRODUCT_NOT_FOUND_IN_STORE: ${response.error?.message ?? "not found in Play Console"}',
      );
    }

    // Guard: reject duplicate in-flight purchases for the same product.
    // Two simultaneous requests would share one completer, and the second
    // would silently overwrite the first, causing the first caller to never
    // receive a result.
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
    // Open a restore collection window. Events that arrive via purchaseStream
    // with status.restored and no matching pending entry are added to this list.
    _restoreCollection = [];
    try {
      await _iap.restorePurchases();
      // Platform events are delivered asynchronously. Wait a short window so
      // all restored events have time to arrive before returning.
      // 5 s is typical for Play Store restore; reduce in tests with DI if needed.
      await Future.delayed(const Duration(seconds: 5));
      return List.unmodifiable(_restoreCollection ?? const []);
    } catch (e) {
      debugPrint('[GooglePlay] restorePurchases error: $e');
      return const [];
    } finally {
      _restoreCollection = null;
    }
  }

  @override
  Future<void> acknowledgePurchase(String transactionId) async {
    final purchase = _pendingAcks.remove(transactionId);
    if (purchase == null) {
      debugPrint('[GooglePlay] acknowledgePurchase: no pending ack for $transactionId');
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
    // Unacknowledged purchases are intentionally NOT completed here.
    // They will re-appear on next app launch for recovery.
    _pendingAcks.clear();
  }
}
