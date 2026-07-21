import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ive_copilot_contract.dart';

/// Gateway do IVE Agent — Phase 1B.
///
/// Implementa [IveCopilotGateway] chamando o Edge Function [ive-agent-runner].
/// Retorna o mesmo contrato de resposta que [SupabaseIveCopilotGateway],
/// garantindo que [IveCopilotResponse.parse] funcione sem modificação.
///
/// API keys ficam exclusivamente nas env vars do servidor (Supabase Secrets).
/// O Flutter envia apenas o JWT do usuário — nenhuma key é exposta.
class IveAgentGateway implements IveCopilotGateway {
  final SupabaseClient client;

  const IveAgentGateway(this.client);

  /// Timeout maior que o legado (45s) para acomodar o agent loop (max 5 turnos).
  static const _timeout = Duration(seconds: 60);

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) async {
    try {
      final response = await client.functions
          .invoke(
            'ive-agent-runner',
            body: request.toMap(),
          )
          .timeout(
            _timeout,
            onTimeout: () => throw const IveCopilotHttpException(
              status: 504,
              code:   'TIMEOUT',
              message: 'A IVE demorou para responder. Tente novamente.',
            ),
          );

      final data = _map(response.data);

      if (response.status < 200 || response.status >= 300) {
        // 503 AGENT_DISABLED: feature flag desativada server-side → propaga para fallback
        throw _httpError(response.status, data);
      }

      return data;
    } on IveCopilotHttpException {
      rethrow;
    } on FunctionException catch (error) {
      throw _httpError(error.status, _map(error.details));
    }
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static IveCopilotHttpException _httpError(
    int status,
    Map<String, dynamic> data,
  ) {
    final rawError = data['error'];
    final error    = rawError is Map
        ? Map<String, dynamic>.from(rawError)
        : <String, dynamic>{};
    return IveCopilotHttpException(
      status:        status,
      code:          error['code'] as String? ?? 'HTTP_$status',
      message:       error['message'] as String? ?? _defaultMessage(status),
      correlationId: error['correlation_id'] as String?,
    );
  }

  static String _defaultMessage(int status) => switch (status) {
        401 => 'Sua sessão expirou. Entre novamente.',
        404 => 'O projeto ativo não foi encontrado ou não está autorizado.',
        503 => 'A IVE está temporariamente em modo legado. Tente novamente.',
        504 => 'A IVE demorou para responder. Tente novamente.',
        _   => 'Não foi possível consultar a IVE agora.',
      };
}
