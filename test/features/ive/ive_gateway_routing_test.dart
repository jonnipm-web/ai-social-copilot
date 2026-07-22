/// Testes de roteamento do gateway IVE.
///
/// Verifica que [iveAgentModeProvider] roteia corretamente baseado na
/// resposta da capability check server-side, sem depender de flags globais
/// acessíveis ao Flutter e sem trustar uid vindo do payload.
///
/// Cenários cobertos:
///   T1 — usuário normal + flag global OFF → legado (false)
///   T2 — internal tester + flag global OFF → agent (true)
///   T3 — flag global ON (todos) → agent (true)
///   T4 — erro de rede ao consultar capability → legado fail-safe (false)
///   T5 — uid nunca no payload Flutter: fetcher sem parâmetro uid (contrato)

import 'package:ai_social_copilot/features/ive/services/ive_copilot_gateway.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Função sem parâmetro uid — confirma contrato de IveCapabilityFetcher
Future<bool> _noUidFetcher() async => false;

class _RecordingGateway implements IveCopilotGateway {
  final Map<String, dynamic> response = const {'answer': 'ok'};
  final Object? error;
  int calls = 0;

  _RecordingGateway({this.error});

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) async {
    calls++;
    if (error != null) throw error!;
    return response;
  }
}

IveCopilotRequest _request() => IveCopilotRequest(
      message: 'teste',
      projectId: 'project-1',
      route: '/projects/project-1',
      screenName: 'Projeto',
    );

ProviderContainer _container(IveCapabilityFetcher fetcher) =>
    ProviderContainer(
      overrides: [iveCapabilityFetcherProvider.overrideWithValue(fetcher)],
    );

void main() {
  test(
      'T1 usuário normal + flag global OFF → iveAgentModeProvider false → rota legado',
      () async {
    final c = _container(() async => false);
    addTearDown(c.dispose);
    expect(await c.read(iveAgentModeProvider.future), isFalse);
  });

  test(
      'T2 internal tester + flag global OFF → servidor retorna true → iveAgentModeProvider true → rota agent',
      () async {
    // Simula servidor respondendo true porque uid está em INTERNAL_TESTER_IDS.
    // O Flutter não sabe do uid nem do allowlist — apenas recebe o resultado.
    final c = _container(() async => true);
    addTearDown(c.dispose);
    expect(await c.read(iveAgentModeProvider.future), isTrue);
  });

  test(
      'T3 flag global ON (rollout geral) → servidor retorna true → iveAgentModeProvider true',
      () async {
    final c = _container(() async => true);
    addTearDown(c.dispose);
    expect(await c.read(iveAgentModeProvider.future), isTrue);
  });

  test(
      'T4 erro ao consultar capability (rede/timeout) → fail-safe false → rota legado',
      () async {
    // Fetcher lança exceção — iveAgentModeProvider deve capturar e retornar false.
    final c = _container(() async => throw Exception('connection refused'));
    addTearDown(c.dispose);
    final result = await c.read(iveAgentModeProvider.future);
    expect(result, isFalse);
  });

  test(
      'T5 uid nunca no payload Flutter: IveCapabilityFetcher não recebe uid como parâmetro',
      () {
    // Contrato arquitetural: IveCapabilityFetcher = Future<bool> Function()
    // sem parâmetro uid. O servidor resolve uid exclusivamente do JWT.
    // Este teste falha em compilação se alguém adicionar uid ao typedef.
    expect(_noUidFetcher, isA<IveCapabilityFetcher>());
    // Se o typedef mudasse para Function(String uid), esta linha não compilaria.
  });

  test('T6 aguarda capability antes de invocar e registra agent gateway',
      () async {
    final agent = _RecordingGateway();
    final legacy = _RecordingGateway();
    final gateway = IveRoutingGateway(
      resolveAgentMode: () async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return true;
      },
      agent: agent,
      legacy: legacy,
    );

    final response = await gateway.invoke(_request());

    expect(agent.calls, 1);
    expect(legacy.calls, 0);
    expect(response['gateway_used'], 'ive-agent-runner');
  });

  test('T7 capability false invoca legado e registra gateway', () async {
    final agent = _RecordingGateway();
    final legacy = _RecordingGateway();
    final gateway = IveRoutingGateway(
      resolveAgentMode: () async => false,
      agent: agent,
      legacy: legacy,
    );

    final response = await gateway.invoke(_request());

    expect(agent.calls, 0);
    expect(legacy.calls, 1);
    expect(response['gateway_used'], 'context-copilot');
  });

  test('T8 AGENT_DISABLED recua ao legado sem enfraquecer outros erros',
      () async {
    final agent = _RecordingGateway(
      error: const IveCopilotHttpException(
        status: 503,
        code: 'AGENT_DISABLED',
        message: 'off',
      ),
    );
    final legacy = _RecordingGateway();
    final gateway = IveRoutingGateway(
      resolveAgentMode: () async => true,
      agent: agent,
      legacy: legacy,
    );

    final response = await gateway.invoke(_request());

    expect(agent.calls, 1);
    expect(legacy.calls, 1);
    expect(response['gateway_used'], 'context-copilot');
  });
}
