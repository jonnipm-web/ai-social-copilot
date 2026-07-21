import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRef extends Mock implements Ref {}

class MutableGateway implements IveCopilotGateway {
  Future<Map<String, dynamic>> Function(IveCopilotRequest request) handler;

  MutableGateway(this.handler);

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) =>
      handler(request);
}

void main() {
  const evidenceId = '11111111-1111-4111-8111-111111111111';
  const scope = CopilotScope(
    userId: 'user-1',
    projectId: 'project-1',
    screenName: 'Executive Dashboard',
  );
  const context = CopilotContextData(
    userId: 'user-1',
    projectId: 'project-1',
    route: '/executive-dashboard',
    project: {'id': 'project-1', 'name': 'Projeto principal'},
    opportunities: [
      {'id': 'opp-1'},
    ],
  );

  Map<String, dynamic> response({bool withProposal = false}) => {
        'response_id': 'response-1',
        'correlation_id': 'corr-1',
        'response_text': 'Resposta autorizada.',
        'intent': withProposal ? 'create' : 'query',
        'project_id': 'project-1',
        'evidence': [
          {
            'source_type': 'opportunity',
            'source_id': evidenceId,
            'title': 'Oportunidade validada',
            'project_id': 'project-1',
            'relevance': 0.9,
          },
        ],
        'limitations': ['Contexto parcial.'],
        'proposed_action': withProposal
            ? {
                'tool_name': 'action.create',
                'project_id': 'project-1',
                'title': 'Validar oferta',
                'description': 'Entrevistar clientes.',
                'priority': 'high',
                'impact': 'high',
                'effort': 'medium',
                'rationale': 'Reduz o risco.',
                'evidence_ids': [evidenceId],
                'opportunity_id': 'opp-1',
              }
            : null,
        'confidence': 85,
      };

  ContextCopilotNotifier notifier(
    MutableGateway gateway, {
    Future<void> Function()? clearProject,
    void Function()? clearMemory,
  }) =>
      ContextCopilotNotifier(
        MockRef(),
        scope,
        gateway: gateway,
        currentUserId: () => 'user-1',
        authChanges: const Stream<AuthState>.empty(),
        rememberQuestion: (_) {},
        recentQuestions: () => const [],
        clearSelectedProject: clearProject ?? () async {},
        clearSensitiveMemory: clearMemory ?? () {},
      );

  test('11 resposta 401 limpa estado sensível', () async {
    var memoryCleared = false;
    final gateway = MutableGateway((_) async => response());
    final controller = notifier(
      gateway,
      clearMemory: () => memoryCleared = true,
    );
    await controller.send(message: 'Primeira pergunta', context: context);
    expect(controller.state.turns, isNotEmpty);
    expect(controller.state.evidence, isNotEmpty);

    gateway.handler = (_) => Future.error(const IveCopilotHttpException(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Sessão expirada.',
        ));
    await controller.send(message: 'Nova pergunta', context: context);

    expect(controller.state.turns, isEmpty);
    expect(controller.state.evidence, isEmpty);
    expect(controller.state.pendingProposal, isNull);
    expect(controller.state.error, 'Sessão expirada.');
    expect(memoryCleared, isTrue);
    controller.dispose();
  });

  test('12 resposta 404 limpa projeto ativo inválido', () async {
    var projectCleared = false;
    final gateway = MutableGateway(
      (_) => Future.error(const IveCopilotHttpException(
        status: 404,
        code: 'NOT_FOUND',
        message: 'Projeto não autorizado.',
      )),
    );
    final controller = notifier(
      gateway,
      clearProject: () async => projectCleared = true,
    );

    await controller.send(message: 'Consultar projeto', context: context);

    expect(projectCleared, isTrue);
    expect(controller.state.pendingProposal, isNull);
    expect(controller.state.error, 'Projeto não autorizado.');
    controller.dispose();
  });

  test('13 timeout preserva mensagem e proposta para retry', () async {
    final gateway = MutableGateway((_) async => response(withProposal: true));
    final controller = notifier(gateway);
    await controller.send(message: 'Crie uma ação', context: context);
    final proposalId = controller.state.pendingProposal?.proposalId;

    gateway.handler = (_) => Future.error(const IveCopilotHttpException(
          status: 504,
          code: 'TIMEOUT',
          message: 'Tempo esgotado.',
        ));
    await controller.send(message: 'Tente novamente', context: context);

    expect(controller.state.pendingProposal?.proposalId, proposalId);
    expect(controller.state.turns.last.content, 'Tente novamente');
    expect(controller.state.error, 'Tempo esgotado.');
    controller.dispose();
  });

  test('16 troca de projeto invalida proposta pendente', () async {
    final controller = notifier(
      MutableGateway((_) async => response(withProposal: true)),
    );
    await controller.send(message: 'Crie uma ação', context: context);
    expect(controller.state.pendingProposal, isNotNull);

    controller.invalidateProposalForProjectChange();

    expect(controller.state.pendingProposal, isNull);
    expect(controller.state.error, contains('projeto ativo mudou'));
    controller.dispose();
  });
}
