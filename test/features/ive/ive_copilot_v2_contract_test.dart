import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projectId = 'project-1';
  const evidenceId = '11111111-1111-4111-8111-111111111111';

  IveCopilotRequest request() => IveCopilotRequest.fromConversation(
        message: 'Qual ação devo priorizar?',
        projectId: projectId,
        route: '/executive-dashboard',
        screenName: 'Executive Dashboard',
        context: const CopilotContextData(
          userId: 'user-1',
          projectId: projectId,
          project: {'id': projectId, 'name': 'Projeto'},
          scores: {'ecosystem': 72},
          opportunities: [
            {'id': 'opp-1', 'title': 'Não enviar ao servidor'},
          ],
          actions: [
            {'id': 'action-1', 'title': 'Não enviar ao servidor'},
          ],
          documents: [
            {'id': 'kb-1', 'title': 'Não enviar ao servidor'},
          ],
        ),
        turns: const [],
        recentQuestions: const [],
        correlationId: 'corr-1',
      );

  Map<String, dynamic> evidence({
    String sourceType = 'opportunity',
    String sourceId = evidenceId,
    String evidenceProjectId = projectId,
    dynamic relevance = 0.8,
  }) =>
      {
        'source_type': sourceType,
        'source_id': sourceId,
        'title': 'Oportunidade validada',
        'excerpt': 'Score 87 e status pending.',
        'project_id': evidenceProjectId,
        'timestamp': '2026-07-18T10:00:00Z',
        'relevance': relevance,
      };

  Map<String, dynamic> v2({
    String responseProjectId = projectId,
    List<dynamic>? evidenceItems,
    List<dynamic>? limitations,
    Map<String, dynamic>? proposedAction,
  }) =>
      {
        'response_id': 'response-1',
        'correlation_id': 'corr-1',
        'response_text': 'Resposta V2 autorizada.',
        'answer': 'Resposta legada.',
        'intent': 'recommend',
        'project_id': responseProjectId,
        'evidence': evidenceItems ?? [evidence()],
        'limitations': limitations ?? <dynamic>[],
        'proposed_action': proposedAction,
        'model': 'model-v2',
        'prompt_version': '2.0.0',
        'server_timestamp': '2026-07-18T10:01:00Z',
        'confidence': 82,
      };

  test('1 request não envia userId nem listas autoritativas', () {
    final body = request().toMap();

    expect(body, isNot(contains('user_id')));
    expect(body['context'], isNot(contains('project')));
    expect(body['context'], isNot(contains('opportunities')));
    expect(body['context'], isNot(contains('actions')));
    expect(body['context'], isNot(contains('documents')));
  });

  test('2 request envia project_id do projeto ativo', () {
    expect(request().toMap()['project_id'], projectId);
  });

  test('3 request envia correlation id', () {
    expect(request().toMap()['client_correlation_id'], 'corr-1');
  });

  test('4 resposta V2 é processada prioritariamente', () {
    final response = IveCopilotResponse.parse(
      v2(),
      activeProjectId: projectId,
      requestCorrelationId: 'request-corr',
      allowedOpportunityIds: const {'opp-1'},
    );

    expect(response.isV2, isTrue);
    expect(response.responseText, 'Resposta V2 autorizada.');
    expect(response.responseId, 'response-1');
    expect(response.correlationId, 'corr-1');
  });

  test('5 resposta legada continua compatível', () {
    final response = IveCopilotResponse.parse(
      {
        'answer': 'Resposta antiga.',
        'sources': ['Projeto'],
        'confidence': 65,
        'entities': ['Oferta'],
        'timestamp': '2026-07-18T10:00:00Z',
        'action_suggestion': {
          'type': 'create_action',
          'label': 'Criar ação',
          'data': {'title': 'Validar oferta'},
        },
      },
      activeProjectId: projectId,
      requestCorrelationId: 'corr-legacy',
      allowedOpportunityIds: const {},
    );

    expect(response.isV2, isFalse);
    expect(response.responseText, 'Resposta antiga.');
    expect(response.legacySources, ['Projeto']);
    expect(response.legacySuggestion?.type, 'create_action');
  });

  test('6 project_id divergente é rejeitado', () {
    expect(
      () => IveCopilotResponse.parse(
        v2(responseProjectId: 'project-2'),
        activeProjectId: projectId,
        requestCorrelationId: 'corr-1',
        allowedOpportunityIds: const {},
      ),
      throwsA(isA<IveProjectMismatchException>()),
    );
  });

  test('7 evidence válida é aceita com dados exibíveis e sem depender do id',
      () {
    final response = IveCopilotResponse.parse(
      v2(),
      activeProjectId: projectId,
      requestCorrelationId: 'corr-1',
      allowedOpportunityIds: const {},
    );

    expect(response.evidence.single.title, 'Oportunidade validada');
    expect(response.evidence.single.sourceTypeLabel, 'Opportunity Lab');
    expect(response.evidence.single.excerpt, 'Score 87 e status pending.');
    expect(response.evidence.single.relevance, 0.8);
  });

  test('8 evidence inválida é descartada', () {
    final response = IveCopilotResponse.parse(
      v2(evidenceItems: [
        evidence(sourceType: 'unknown'),
        evidence(evidenceProjectId: 'project-2'),
        evidence(relevance: 2),
      ]),
      activeProjectId: projectId,
      requestCorrelationId: 'corr-1',
      allowedOpportunityIds: const {},
    );

    expect(response.evidence, isEmpty);
  });

  test('9 limitations são preservadas para apresentação', () {
    final response = IveCopilotResponse.parse(
      v2(limitations: [
        'Apenas metadados da Knowledge Base estavam disponíveis.',
        '',
      ]),
      activeProjectId: projectId,
      requestCorrelationId: 'corr-1',
      allowedOpportunityIds: const {},
    );

    expect(response.limitations, [
      'Apenas metadados da Knowledge Base estavam disponíveis.',
    ]);
  });

  test('10 proposed_action diferente de action.create não é executável', () {
    final response = IveCopilotResponse.parse(
      v2(proposedAction: {
        'tool_name': 'project.delete',
        'project_id': projectId,
        'title': 'Excluir',
        'priority': 'high',
        'impact': 'high',
        'effort': 'low',
        'evidence_ids': [evidenceId],
      }),
      activeProjectId: projectId,
      requestCorrelationId: 'corr-1',
      allowedOpportunityIds: const {},
    );

    expect(response.proposedAction, isNull);
  });

  test('proposed_action válida exige enums e evidências retornadas', () {
    final response = IveCopilotResponse.parse(
      v2(proposedAction: {
        'tool_name': 'action.create',
        'project_id': projectId,
        'title': 'Validar oferta',
        'description': 'Entrevistar clientes.',
        'priority': 'critical',
        'impact': 'high',
        'effort': 'medium',
        'evidence_ids': [evidenceId],
      }),
      activeProjectId: projectId,
      requestCorrelationId: 'corr-1',
      allowedOpportunityIds: const {},
    );

    expect(response.proposedAction, isNotNull);
    expect(response.proposedAction?.priorityScore, 100);
    expect(response.proposedAction?.impactScore, 90);
    expect(response.proposedAction?.effortScore, 60);
  });

  test('proposed_action com enum ou evidence id inválido é descartada', () {
    final response = IveCopilotResponse.parse(
      v2(proposedAction: {
        'tool_name': 'action.create',
        'project_id': projectId,
        'title': 'Validar oferta',
        'priority': 'urgent',
        'impact': 'high',
        'effort': 'medium',
        'evidence_ids': ['not-returned'],
      }),
      activeProjectId: projectId,
      requestCorrelationId: 'corr-1',
      allowedOpportunityIds: const {},
    );

    expect(response.proposedAction, isNull);
  });

  test('15 confidence V2 prevalece sobre campo legado', () {
    final payload = v2()
      ..['system_confidence'] = 91
      ..['confidence'] = 35;
    final response = IveCopilotResponse.parse(
      payload,
      activeProjectId: projectId,
      requestCorrelationId: 'corr-1',
      allowedOpportunityIds: const {},
    );

    expect(response.confidence, 91);
  });

  test('request limita histórico a 10 itens de 800 caracteres', () {
    final turns = List.generate(
      12,
      (index) => CopilotTurn(
        role: index.isEven ? 'user' : 'assistant',
        content: List.filled(900, 'x').join(),
        timestamp: DateTime.utc(2026, 7, 18),
      ),
    );
    final limited = IveCopilotRequest.fromConversation(
      message: 'Teste',
      projectId: projectId,
      route: '/projects',
      screenName: 'Projetos',
      context: const CopilotContextData(projectId: projectId),
      turns: turns,
      recentQuestions: const [],
    );

    expect(limited.history, hasLength(10));
    expect(limited.history.every((item) => item['content']!.length == 800),
        isTrue);
  });
}
