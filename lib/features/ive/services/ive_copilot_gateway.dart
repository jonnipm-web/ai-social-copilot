import 'package:flutter/foundation.dart' show debugPrint;
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
/// Implementação real: consulta `feature_flags` via DB.
/// 1. Verifica flag por usuário: `ive_agent_mode_tester_<uid>` (internal testers).
/// 2. Verifica flag global: `ive_agent_mode`.
/// Fail-safe: qualquer erro → false → legado.
///
/// uid é derivado da sessão local (client.auth.currentUser) — nunca enviado
/// ao servidor como parâmetro de identidade. O servidor valida sempre pelo JWT.
final iveCapabilityFetcherProvider = Provider<IveCapabilityFetcher>((ref) {
  return _defaultCapabilityFetcher;
});

Future<bool> _defaultCapabilityFetcher() async {
  try {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;

    if (uid != null) {
      final testerRow = await client
          .from('feature_flags')
          .select('enabled')
          .eq('feature_name', 'ive_agent_mode_tester_$uid')
          .maybeSingle();
      if (testerRow?['enabled'] == true) return true;
    }

    final globalRow = await client
        .from('feature_flags')
        .select('enabled')
        .eq('feature_name', 'ive_agent_mode')
        .maybeSingle();
    return globalRow?['enabled'] == true;
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

/// Seleciona o gateway correto no momento da invocação, depois que a
/// capability check terminou.
///
/// [SupabaseIveCopilotGateway] (legado): flag global OFF e uid não em INTERNAL_TESTER_IDS.
/// [IveAgentGateway]: flag global ON OU uid em INTERNAL_TESTER_IDS (servidor).
///
/// Fail-safe: qualquer erro na capability check resulta em `false` e usa o
/// legado. Um AGENT_DISABLED retornado pelo servidor também recua ao legado.
final iveCopilotGatewayProvider = Provider<IveCopilotGateway>((ref) {
  final client = Supabase.instance.client;
  return IveRoutingGateway(
    resolveAgentMode: () => ref.read(iveAgentModeProvider.future),
    agent: IveAgentGateway(client),
    legacy: SupabaseIveCopilotGateway(client),
  );
});

typedef IveAgentModeResolver = Future<bool> Function();

/// Gateway observável e testável. A marca `gateway_used` é metadado interno
/// de diagnóstico e não contém uid, token ou segredo.
class IveRoutingGateway implements IveCopilotGateway {
  final IveAgentModeResolver resolveAgentMode;
  final IveCopilotGateway agent;
  final IveCopilotGateway legacy;

  const IveRoutingGateway({
    required this.resolveAgentMode,
    required this.agent,
    required this.legacy,
  });

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) async {
    // Gap 1: resolveAgentMode() can throw if the Riverpod ref is disposed.
    // Default to false so we reach legacy rather than surfacing a raw error.
    bool agentEnabled = false;
    try {
      agentEnabled = await resolveAgentMode();
    } catch (_) {
      // capability check failed → legacy
    }

    if (agentEnabled) {
      try {
        return _withGateway(await agent.invoke(request), 'ive-agent-runner');
      } on IveCopilotHttpException catch (error) {
        // AGENT_DISABLED (503): server says feature is off → fall through to legacy.
        // All other IveCopilotHttpException (401, 404, TIMEOUT…) → rethrow so
        // the caller receives a meaningful, typed error instead of a silent fallback.
        if (error.code != 'AGENT_DISABLED') rethrow;
      } catch (e) {
        // Gap 2: unexpected (non-IveCopilotHttpException) exceptions — e.g.
        // SocketException, FormatException — were not caught by the typed handler
        // above and would escape invoke() without reaching the legacy branch.
        // Fall through to legacy and log so the issue is visible.
        debugPrint('[IveRoutingGateway] unexpected agent error, falling back to legacy: $e');
      }
    }
    return _withGateway(await legacy.invoke(request), 'context-copilot');
  }

  static Map<String, dynamic> _withGateway(
    Map<String, dynamic> response,
    String gateway,
  ) =>
      <String, dynamic>{...response, 'gateway_used': gateway};
}

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
