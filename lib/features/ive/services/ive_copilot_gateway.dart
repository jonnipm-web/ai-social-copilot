import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/ive_copilot_contract.dart';
import 'ive_agent_gateway.dart';

/// Feature flag lida da tabela [feature_flags] no Supabase.
/// Valor 'agent' → [IveAgentGateway]; qualquer outro → [SupabaseIveCopilotGateway].
///
/// Permite rollback sem novo APK: altere o valor no banco,
/// o provider recarrega na próxima criação de instância.
///
/// Fail-safe: se a tabela não existir ou houver erro, usa legado.
final _iveAgentModeProvider = FutureProvider<bool>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('feature_flags')
        .select('value')
        .eq('key', 'ive_agent_mode')
        .maybeSingle();
    return (res.data as Map<String, dynamic>?)?['value'] == 'agent';
  } catch (_) {
    return false;
  }
});

/// Seleciona o gateway correto baseado no feature flag.
/// [SupabaseIveCopilotGateway] é o legado (context-copilot).
/// [IveAgentGateway] é o novo agent runner (Phase 1B).
final iveCopilotGatewayProvider = Provider<IveCopilotGateway>((ref) {
  final useAgent = ref.watch(_iveAgentModeProvider).valueOrNull ?? false;
  if (useAgent) return IveAgentGateway(Supabase.instance.client);
  return SupabaseIveCopilotGateway(Supabase.instance.client);
});

class SupabaseIveCopilotGateway implements IveCopilotGateway {
  final SupabaseClient client;

  const SupabaseIveCopilotGateway(this.client);

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) async {
    try {
      final response = await client.functions
          .invoke(
            AppConstants.edgeFunctionContextCopilot,
            body: request.toMap(),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw const IveCopilotHttpException(
              status: 504,
              code: 'TIMEOUT',
              message: 'A IVE demorou para responder. Tente novamente.',
            ),
          );
      final data = _map(response.data);
      if (response.status < 200 || response.status >= 300) {
        throw _httpError(response.status, data);
      }
      return data;
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
    final error = rawError is Map
        ? Map<String, dynamic>.from(rawError)
        : <String, dynamic>{};
    return IveCopilotHttpException(
      status: status,
      code: error['code'] as String? ?? 'HTTP_$status',
      message: error['message'] as String? ?? _defaultMessage(status),
      correlationId: error['correlation_id'] as String?,
    );
  }

  static String _defaultMessage(int status) => switch (status) {
        401 => 'Sua sessão expirou. Entre novamente.',
        404 => 'O projeto ativo não foi encontrado ou não está autorizado.',
        504 => 'A IVE demorou para responder. Tente novamente.',
        _ => 'Não foi possível consultar a IVE agora.',
      };
}
