import 'package:supabase_flutter/supabase_flutter.dart';

/// IVE-COMMERCIAL-BILLING-01 — cliente para a função create-checkout-session.
/// Nunca envia price_id/role/user_id no corpo: o servidor resolve tudo
/// a partir da sessão autenticada e de STRIPE_PRICE_ID_PRO.
class BillingService {
  final _client = Supabase.instance.client;

  static const _edgeFunction = 'create-checkout-session';

  Future<String> createCheckoutSession() async {
    final response = await _client.functions.invoke(_edgeFunction);

    final data = response.data;
    if (data is Map && data.containsKey('error')) {
      throw Exception(data['error']);
    }

    final url = data is Map ? data['url'] as String? : null;
    if (url == null || url.isEmpty) {
      throw Exception('Não foi possível iniciar o checkout. Tente novamente.');
    }
    return url;
  }
}
