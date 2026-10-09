// IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D6/D7
// Dart-side bridge that sends a raw billing receipt to the server
// for validation.
//
// SECURITY INVARIANTS:
//   - NEVER grant entitlement based on client-side validation
//   - This service ONLY transmits the opaque platform token to the server
//   - The server (validate-mobile-purchase EF) owns all entitlement decisions
//   - service_role key NEVER reaches this class
//   - Error = DENIED (fail-closed): on any RPC error the caller must treat
//     the purchase as unvalidated
//
// ACTIVATION GATE (IV-MOBILE-BILLING-01):
//   Returns BILLING_NOT_ACTIVATED until Paulo + AM authorize live billing,
//   real product IDs are configured, and the EF is deployed with
//   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON / APPLE_SHARED_SECRET env vars.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of server-side receipt validation.
class MobilePurchaseValidationResult {
  /// True only when the server confirmed and granted entitlement.
  final bool entitlementGranted;
  final String? entitledProduct;
  final String? entitledPlan;
  final String? error;

  const MobilePurchaseValidationResult({
    required this.entitlementGranted,
    this.entitledProduct,
    this.entitledPlan,
    this.error,
  });

  factory MobilePurchaseValidationResult.denied(String reason) =>
      MobilePurchaseValidationResult(entitlementGranted: false, error: reason);
}

class MobileBillingReceiptService {
  final SupabaseClient _client;

  static const _edgeFunction = 'validate-mobile-purchase';

  MobileBillingReceiptService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Sends the receipt payload to the server for validation.
  ///
  /// The caller must have obtained [platform] and [receiptPayload] from
  /// [BillingPurchaseResult.error == "PENDING_SERVER_VERIFICATION"] — i.e.,
  /// from a purchase or restore event on the platform stream.
  ///
  /// Never pass entitlementGranted=true to the UI before this method
  /// returns a result with entitlementGranted=true.
  Future<MobilePurchaseValidationResult> validateReceipt({
    required String platform,
    required String receiptPayload,
    required String productId,
    String? transactionId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        _edgeFunction,
        body: {
          // Opaque platform token — only the server decodes this
          'receipt': receiptPayload,
          'platform': platform,
          'product_id': productId,
          if (transactionId != null) 'transaction_id': transactionId,
        },
      );

      final data = response.data;
      if (data is! Map) {
        return MobilePurchaseValidationResult.denied(
          'VALIDATE_INVALID_RESPONSE: expected a JSON object',
        );
      }

      if (data.containsKey('error')) {
        return MobilePurchaseValidationResult.denied(
          'VALIDATE_SERVER_ERROR: ${data['error']}',
        );
      }

      final granted = data['entitlement_granted'] as bool? ?? false;
      if (!granted) {
        return MobilePurchaseValidationResult.denied(
          data['message'] as String? ?? 'VALIDATE_NOT_GRANTED',
        );
      }

      return MobilePurchaseValidationResult(
        entitlementGranted: true,
        entitledProduct: data['product'] as String?,
        entitledPlan: data['plan'] as String?,
      );
    } catch (e) {
      // Fail-closed: any network error, timeout, or exception = denied.
      return MobilePurchaseValidationResult.denied(
        'VALIDATE_RPC_ERROR: $e',
      );
    }
  }
}
