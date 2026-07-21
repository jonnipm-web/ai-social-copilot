import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/ive_copilot_contract.dart';
import 'ive_agent_gateway.dart';

// ── Capability fetcher ─────────────────────────────────────────────────────────

/// Assinatura do fetcher de capability — sem uid no payload (uid vem do JWT server-side).
typedef IveCapabilityFetcher = Future<bool> Function();

/// Provider sobrescritível em testes.
///
/// Implementação real: chama [AppConstants.edgeFunctionAgentRunner] com
/// `capability_check: true`. O servidor valida o JWT, consulta INTERNAL_TESTER_IDS
/// (env var server-side) e a flag global — retorna `{ ive_agent_enabled: bool }`.
///
/// O uid NUNCA é enviado pelo Flutter: é derivado exclusivamente do JWT pelo servidor.
/// Nenhum dado do payload Flutter é usado como autoridade de identidade.
final iveCapabilityFetcherProvider = Provider<IveCapabilityFetcher>((ref) {
  return _defaultCapabilityFetcher;
});

Future<bool> _defaultCapabilityFetcher() async {
  try {
    final response = await Supabase.instance.client.functions.invoke(
      AppConstants.edgeFunctionAgentRunner,
      body: const {'capability_check': true},
    );
    final data = response.data;
    if (data is Map) return data['ive_agent_enabled'] == true;
    return false;
  } catch (_) {
    return false; // fail-safe → context-copilot legado
  }
}

// ── Agent mode provider ────────────────────────────────────────────────────────

/// Resolve se o agent mode está habilitado para a sessão atual.
///
/// Delega ao [iveCapabilityFetcherProvider] (sobrescritível em testes).
/// Fail-safe duplo: erro no fetcher → catch interno → false → legado.
///
/// Público (sem `_`) para permitir override em testes de integração.
final iveAgentModeProvider = FutureProvider<bool>((ref) async {
  try {
    final fetch = ref.read(iveCapabilityFetcherProvider);
    return await fetch();
  } catch (_) {
    return false; // defesa secundária: erro inesperado no fetcher → legado
  }
});

// ── Gateway selector ───────────────────────────────────────────────────────────

/// Seleciona o gateway correto baseado no resultado da capability check.
///
/// [SupabaseIveCopilotGateway] (legado): flag global OFF e uid não em INTERNAL_TESTER_IDS.
/// [IveAgentGateway]: flag global ON OU uid em INTERNAL_TESTER_IDS (servidor).
///
/// Fail-safe: qualquer erro em [iveAgentModeProvider] → `valueOrNull ?? false` → legado.
final iveCopilotGatewayProvider = Provider<IveCopilotGateway>((ref) {
  final useAgent = ref.watch(iveAgentModeProvider).valueOrNull ?? false;
  if (useAgent) return IveAgentGateway(Supabase.instance.client);
  return SupabaseIveCopilotGateway(Supabase.instance.client);
});

// ── Legacy gateway (context-copilot) ──────────────────────────────────────────

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
