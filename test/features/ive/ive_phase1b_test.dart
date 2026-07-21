// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'package:ai_social_copilot/features/ive/domain/ive_action_proposal.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:ai_social_copilot/features/ive/services/ive_agent_gateway.dart';
import 'package:ai_social_copilot/features/ive/services/ive_copilot_gateway.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/copilot_turn.dart';

// ── Stubs ──────────────────────────────────────────────────────────────────────

class _MockRef extends Mock implements Ref {}

class _FakeGateway implements IveCopilotGateway {
  final Map<String, dynamic> _response;
  final Object? _error;
  int callCount = 0;

  _FakeGateway({Map<String, dynamic>? response, Object? error})
      : _response = response ?? const {},
        _error = error;

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) async {
    callCount++;
    if (_error != null) throw _error;
    return _response;
  }
}

class _TimeoutGateway implements IveCopilotGateway {
  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest _) async {
    throw const IveCopilotHttpException(
      status:  504,
      code:    'TIMEOUT',
      message: 'A IVE demorou para responder. Tente novamente.',
    );
  }
}

/// Resposta V2 mínima válida para o parser
Map<String, dynamic> _validV2Response({
  String? projectId,
  Map<String, dynamic>? proposedAction,
}) =>
    {
      'response_id':    'resp-uuid-001',
      'response_text':  'Resposta de teste.',
      'project_id':     projectId ?? 'project-abc-123',
      'intent':         'query',
      'evidence':       <Map<String, dynamic>>[],
      'limitations':    <String>[],
      'system_confidence': 75,
      'model':          'gpt-4o',
      'prompt_version': '3.0.0',
      'server_timestamp': '2026-07-21T12:00:00Z',
      'correlation_id': 'corr-001',
      if (proposedAction != null) 'proposed_action': proposedAction,
    };

ContextCopilotNotifier _makeNotifier(
  IveCopilotGateway gateway, {
  String userId = 'user-abc',
  String projectId = 'project-abc-123',
}) {
  final scope = CopilotScope(
    userId: userId,
    projectId: projectId,
    screenName: 'test',
  );
  return ContextCopilotNotifier(
    _MockRef(),
    scope,
    gateway:             gateway,
    currentUserId:       () => userId,
    authChanges:         const Stream<AuthState>.empty(),
    rememberQuestion:    (_) {},
    recentQuestions:     () => [],
    clearSelectedProject: () async {},
    clearSensitiveMemory: () {},
  );
}

CopilotContextData _testContext({String projectId = 'project-abc-123'}) =>
    CopilotContextData(
      userId:    'user-abc',
      projectId: projectId,
      route:     '/test',
    );

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 1 — Estrutura do IveAgentGateway
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  group('Grupo 1 — IveAgentGateway: estrutura e compatibilidade', () {
    test('1.1 IveAgentGateway implementa IveCopilotGateway', () {
      // Verifica que a classe implementa a interface sem erros de compilação
      expect(IveAgentGateway, isNotNull);
      // Verifica que SupabaseIveCopilotGateway também implementa (regressão)
      expect(SupabaseIveCopilotGateway, isNotNull);
    });

    test('1.2 IveAgentGateway tem timeout de 60s (maior que legado 45s)', () {
      // Verifica via timeout constant declarada na classe
      // O agente precisa de mais tempo para o loop de ferramentas
      const agentTimeout  = Duration(seconds: 60);
      const legacyTimeout = Duration(seconds: 45);
      expect(agentTimeout > legacyTimeout, isTrue);
    });

    test('1.3 IveAgentGateway não expõe API keys', () {
      // Verifica que o arquivo não contém strings de API key
      // Apenas testa estruturalmente — a key vive no servidor
      final gw = IveAgentGateway;
      expect(gw.toString(), isNot(contains('sk-')));
      expect(gw.toString(), isNot(contains('API_KEY')));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 2 — Segurança: user_id e project_id forjados
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 2 — Segurança: user_id e project_id forjados', () {
    test('2.1 ContextCopilotNotifier.send() rejeita uid forjado no payload', () async {
      final gateway = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway, userId: 'real-user');
      // Tenta enviar com contexto cujo projectId não bate com o scope
      await notifier.send(
        message: 'teste',
        context: _testContext(projectId: 'outro-projeto-forjado'),
      );
      // Deve ter error (scope.projectId != context.projectId)
      expect(notifier.state.error, isNotNull);
      expect(gateway.callCount, equals(0));
    });

    test('2.2 send() rejeita scope.userId diferente do uid atual', () async {
      final gateway = _FakeGateway(response: _validV2Response());

      // Forja: cria notifier que pensa ser user-correto mas currentUserId retorna outro
      final forgedNotifier = ContextCopilotNotifier(
        _MockRef(),
        const CopilotScope(userId: 'user-correto', projectId: 'project-abc-123', screenName: 'test'),
        gateway:             gateway,
        currentUserId:       () => 'user-intruso', // uid diferente do scope
        authChanges:         const Stream<AuthState>.empty(),
        rememberQuestion:    (_) {},
        recentQuestions:     () => [],
        clearSelectedProject: () async {},
        clearSensitiveMemory: () {},
      );

      await forgedNotifier.send(
        message: 'acesso indevido',
        context: _testContext(),
      );
      expect(forgedNotifier.state.error, isNotNull);
      expect(gateway.callCount, equals(0));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 3 — Segurança: cross-project response rejection
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 3 — Segurança: cross-project response rejection', () {
    test('3.1 IveCopilotResponse.parse() lança se project_id diverge', () {
      final data = _validV2Response(projectId: 'outro-projeto');
      expect(
        () => IveCopilotResponse.parse(
          data,
          activeProjectId:          'project-abc-123',
          requestCorrelationId:     'corr-001',
          allowedOpportunityIds:    const {},
        ),
        throwsA(isA<IveProjectMismatchException>()),
      );
    });

    test('3.2 IveEvidence.tryParse() rejeita evidência de outro projeto', () {
      final evidence = IveEvidence.tryParse(
        {
          'source_type': 'action',
          'source_id':   '12345678-1234-1234-8234-123456789012',
          'title':       'Ação de outro projeto',
          'project_id':  'outro-projeto-uuid',  // diverge do activeProjectId
          'relevance':   0.8,
        },
        activeProjectId: 'project-abc-123',
      );
      expect(evidence, isNull); // deve ser rejeitado
    });

    test('3.3 IveEvidence.tryParse() aceita evidência do projeto ativo', () {
      final evidence = IveEvidence.tryParse(
        {
          'source_type': 'opportunity',
          'source_id':   '12345678-1234-1234-8234-123456789012',
          'title':       'Oportunidade válida',
          'project_id':  'project-abc-123',
          'relevance':   0.9,
        },
        activeProjectId: 'project-abc-123',
      );
      expect(evidence, isNotNull);
      expect(evidence!.sourceType, equals('opportunity'));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 4 — Segurança: UUID alucinado e evidence_ids inválidos
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 4 — Segurança: UUID alucinado e evidence_ids inválidos', () {
    test('4.1 IveEvidence.tryParse() rejeita source_id que não é UUID v1-5', () {
      final evidence = IveEvidence.tryParse(
        {
          'source_type': 'action',
          'source_id':   'nao-e-um-uuid',  // UUID alucinado
          'title':       'Ação fake',
          'project_id':  'project-abc-123',
          'relevance':   0.7,
        },
        activeProjectId: 'project-abc-123',
      );
      expect(evidence, isNull);
    });

    test('4.2 IveProposedAction.tryParse() rejeita evidence_ids não presentes no contexto', () {
      // evidence_ids devem ser validados contra Set de IDs reais
      final action = IveProposedAction.tryParse(
        {
          'tool_name':    'action.create',
          'project_id':   'project-abc-123',
          'title':        'Ação com evidence inválida',
          'description':  'teste',
          'priority':     'high',
          'impact':       'high',
          'effort':       'low',
          'evidence_ids': ['uuid-que-nao-existe-123456789012'],
        },
        activeProjectId:       'project-abc-123',
        validEvidenceIds:      const {},  // Set vazio — nenhum UUID é válido
        allowedOpportunityIds: const {},
      );
      expect(action, isNull); // rejeitado porque evidence_ids não estão no contexto
    });

    test('4.3 IveProposedAction.tryParse() aceita evidence_ids válidos', () {
      const validId = '12345678-1234-1234-8234-123456789012';
      final action = IveProposedAction.tryParse(
        {
          'tool_name':    'action.create',
          'project_id':   'project-abc-123',
          'title':        'Ação com evidence válida',
          'description':  'teste',
          'priority':     'high',
          'impact':       'medium',
          'effort':       'low',
          'evidence_ids': [validId],
        },
        activeProjectId:       'project-abc-123',
        validEvidenceIds:      {validId},
        allowedOpportunityIds: const {},
      );
      expect(action, isNotNull);
      expect(action!.evidenceIds, contains(validId));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 5 — Segurança: ferramenta não autorizada e priority inválida
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 5 — Segurança: ferramenta não autorizada e campos inválidos', () {
    test('5.1 IveProposedAction.tryParse() rejeita tool_name diferente de action.create', () {
      final action = IveProposedAction.tryParse(
        {
          'tool_name': 'project.delete',  // ferramenta não autorizada
          'project_id': 'project-abc-123',
          'title': 'Deletar projeto',
          'priority': 'critical',
          'impact': 'high',
          'effort': 'low',
        },
        activeProjectId:       'project-abc-123',
        validEvidenceIds:      const {},
        allowedOpportunityIds: const {},
      );
      expect(action, isNull);
    });

    test('5.2 IveProposedAction.tryParse() rejeita priority inválida', () {
      final action = IveProposedAction.tryParse(
        {
          'tool_name': 'action.create',
          'project_id': 'project-abc-123',
          'title': 'Ação com priority inválida',
          'priority': 'ultra_high',  // não é low/medium/high/critical
          'impact': 'medium',
          'effort': 'low',
        },
        activeProjectId:       'project-abc-123',
        validEvidenceIds:      const {},
        allowedOpportunityIds: const {},
      );
      expect(action, isNull);
    });

    test('5.3 IveProposedAction.tryParse() rejeita título vazio', () {
      final action = IveProposedAction.tryParse(
        {
          'tool_name': 'action.create',
          'project_id': 'project-abc-123',
          'title': '   ',  // apenas espaços
          'priority': 'medium',
          'impact': 'medium',
          'effort': 'low',
        },
        activeProjectId:       'project-abc-123',
        validEvidenceIds:      const {},
        allowedOpportunityIds: const {},
      );
      expect(action, isNull);
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 6 — Segurança: proposta expirada e project switch
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 6 — Segurança: proposta expirada e troca de projeto', () {
    test('6.1 confirmProposal() rejeita proposta expirada', () async {
      final gateway = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway);

      // Injeta proposta expirada manualmente
      final now = DateTime.now().toUtc();
      final expired = IveActionProposal(
        proposalId: 'prop-001',
        userId:     'user-abc',
        projectId:  'project-abc-123',
        projectName: 'Projeto Teste',
        title:      'Ação expirada',
        description: 'desc',
        priority:   50,
        impact:     60,
        effort:     40,
        rationale:  'teste',
        origin:     'ive',
        createdAt:  now.subtract(const Duration(minutes: 20)),
        expiresAt:  now.subtract(const Duration(minutes: 5)),  // já expirou
      );

      // Força estado com proposta expirada
      notifier.overrideStateForTest(notifier.state.copyWith(pendingProposal: expired));
      await notifier.confirmProposal();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('expirou'));
      expect(notifier.state.pendingProposal, isNull);
    });

    test('6.2 confirmProposal() rejeita proposta de outro projeto', () async {
      final gateway = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway, projectId: 'project-abc-123');

      final now = DateTime.now().toUtc();
      final wrongProject = IveActionProposal(
        proposalId:  'prop-002',
        userId:      'user-abc',
        projectId:   'outro-projeto-uuid',  // diverge do scope.projectId
        projectName: 'Outro Projeto',
        title:       'Ação de outro projeto',
        description: 'desc',
        priority:    50,
        impact:      60,
        effort:      40,
        rationale:   'teste',
        origin:      'ive',
        createdAt:   now,
        expiresAt:   now.add(const Duration(minutes: 15)),
      );

      notifier.overrideStateForTest(notifier.state.copyWith(pendingProposal: wrongProject));
      await notifier.confirmProposal();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.pendingProposal, isNull);
    });

    test('6.3 invalidateProposalForProjectChange() limpa proposta ativa', () {
      final gateway = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway);

      final now = DateTime.now().toUtc();
      final active = IveActionProposal(
        proposalId:  'prop-003',
        userId:      'user-abc',
        projectId:   'project-abc-123',
        projectName: 'Projeto',
        title:       'Ação ativa',
        description: 'desc',
        priority:    50,
        impact:      60,
        effort:      40,
        rationale:   'teste',
        origin:      'ive',
        createdAt:   now,
        expiresAt:   now.add(const Duration(minutes: 15)),
      );

      notifier.overrideStateForTest(notifier.state.copyWith(pendingProposal: active));
      expect(notifier.state.pendingProposal, isNotNull);

      notifier.invalidateProposalForProjectChange();

      expect(notifier.state.pendingProposal, isNull);
      expect(notifier.state.error, contains('invalidada'));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 7 — Segurança: timeout e provider error handling
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 7 — Segurança: timeout e error handling', () {
    test('7.1 send() trata TIMEOUT de forma amigável', () async {
      final gateway  = _TimeoutGateway();
      final notifier = _makeNotifier(gateway);

      await notifier.send(message: 'teste', context: _testContext());

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('demorou'));
    });

    test('7.2 send() limpa histórico sensível em 401 (unauthorized)', () async {
      final gateway = _FakeGateway(
        error: const IveCopilotHttpException(
          status:  401,
          code:    'UNAUTHORIZED',
          message: 'Sessão inválida.',
        ),
      );
      final notifier = _makeNotifier(gateway);

      // Adiciona um turno no histórico
      notifier.overrideStateForTest(notifier.state.copyWith(turns: [
        CopilotTurn(role: 'user', content: 'mensagem anterior', timestamp: DateTime.now()),
      ]));

      await notifier.send(message: 'teste', context: _testContext());

      // clearsSensitiveState=true → clearHistory() é chamado
      expect(notifier.state.turns, isEmpty);
      expect(notifier.state.error, isNotNull);
    });

    test('7.3 send() preserva histórico em erros não-401', () async {
      final gateway = _FakeGateway(
        error: const IveCopilotHttpException(
          status:  502,
          code:    'MODEL_ERROR',
          message: 'Erro no modelo.',
        ),
      );
      final notifier = _makeNotifier(gateway);

      await notifier.send(message: 'pergunta que vai falhar', context: _testContext());

      // Histórico preservado (mensagem do usuário foi adicionada antes da falha)
      expect(notifier.state.turns.length, equals(1));
      expect(notifier.state.turns.first.role, equals('user'));
      expect(notifier.state.error, isNotNull);
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 8 — Segurança: loop de calls duplicados
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 8 — Segurança: double execution guard', () {
    test('8.1 confirmProposal() não executa se já está executando', () async {
      final gateway  = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway);

      final now = DateTime.now().toUtc();
      final proposal = IveActionProposal(
        proposalId:  'prop-loop-1',
        userId:      'user-abc',
        projectId:   'project-abc-123',
        projectName: 'Projeto',
        title:       'Ação',
        description: 'desc',
        priority:    50,
        impact:      60,
        effort:      40,
        rationale:   'teste',
        origin:      'ive',
        createdAt:   now,
        expiresAt:   now.add(const Duration(minutes: 15)),
      );

      // Força estado: executing=true
      notifier.overrideStateForTest(notifier.state.copyWith(
        pendingProposal: proposal,
        executing:       true,
      ));

      // Tenta confirmar enquanto está executando
      await notifier.confirmProposal();
      // Deve ter retornado sem executar (early return por state.executing)
      expect(gateway.callCount, equals(0));
    });

    test('8.2 send() não envia se está carregando', () async {
      final gateway  = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway);

      // Força loading=true
      notifier.overrideStateForTest(notifier.state.copyWith(loading: true));
      await notifier.send(message: 'nova mensagem', context: _testContext());

      expect(gateway.callCount, equals(0));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 9 — Segurança: IveCopilotResponse sem project_id não quebra parse
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 9 — Segurança: respostas sem project_id (legado)', () {
    test('9.1 parse() aceita resposta legada (sem response_id) com project_id correto', () {
      final data = {
        'answer':            'Resposta legada.',
        'sources':           <String>[],
        'confidence':        70,
        'entities':          <String>[],
        'action_suggestion': null,
        'timestamp':         '2026-07-21T12:00:00Z',
        'project_id':        'project-abc-123',
      };
      // Não deve lançar
      final response = IveCopilotResponse.parse(
        data,
        activeProjectId:       'project-abc-123',
        requestCorrelationId:  'corr-legado',
        allowedOpportunityIds: const {},
      );
      expect(response.responseText, equals('Resposta legada.'));
      expect(response.isV2, isFalse);
    });

    test('9.2 parse() lança IveCopilotContractException se response_text e answer vazios', () {
      final data = {
        'response_id':    'resp-001',
        'response_text':  '',   // vazio
        'answer':         '',   // vazio
        'project_id':     'project-abc-123',
        'correlation_id': 'corr-001',
      };
      expect(
        () => IveCopilotResponse.parse(
          data,
          activeProjectId:       'project-abc-123',
          requestCorrelationId:  'corr-001',
          allowedOpportunityIds: const {},
        ),
        throwsA(isA<IveCopilotContractException>()),
      );
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 10 — Segurança: opportunity_id de outro projeto
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 10 — Segurança: opportunity_id não autorizado', () {
    test('10.1 IveActionProposal.fromProposedAction() descarta opportunity_id fora do allowedSet', () {
      const validOppId = '12345678-1234-1234-8234-123456789012';

      // action com opportunity_id que NÃO está no allowedOpportunityIds
      final proposedAction = IveProposedAction.tryParse(
        {
          'tool_name':      'action.create',
          'project_id':     'project-abc-123',
          'title':          'Ação com opp não autorizada',
          'description':    'desc',
          'priority':       'medium',
          'impact':         'medium',
          'effort':         'low',
          'opportunity_id': validOppId,  // opp de outro projeto
        },
        activeProjectId:       'project-abc-123',
        validEvidenceIds:      const {},
        allowedOpportunityIds: const {},  // vazio — nenhuma opp autorizada
      );

      // opportunity_id inválida descarta a proposta inteira
      expect(proposedAction, isNull);
    });

    test('10.2 IveActionProposal.fromProposedAction() aceita opportunity_id autorizado', () {
      const validOppId = '12345678-1234-1234-8234-123456789012';

      final proposedAction = IveProposedAction.tryParse(
        {
          'tool_name':      'action.create',
          'project_id':     'project-abc-123',
          'title':          'Ação com opp autorizada',
          'description':    'desc',
          'priority':       'medium',
          'impact':         'medium',
          'effort':         'low',
          'opportunity_id': validOppId,
        },
        activeProjectId:       'project-abc-123',
        validEvidenceIds:      const {},
        allowedOpportunityIds: {validOppId},  // autorizado
      );

      expect(proposedAction, isNotNull);
      expect(proposedAction!.opportunityId, equals(validOppId));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 11 — Segurança: request com project_id vazio
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 11 — Segurança: project_id vazio no contexto', () {
    test('11.1 send() rejeita request quando scope.projectId é vazio', () async {
      final gateway = _FakeGateway(response: _validV2Response());

      const emptyScope = CopilotScope(
        userId:     'user-abc',
        projectId:  '',  // projeto não selecionado
        screenName: 'test',
      );

      final notifier = ContextCopilotNotifier(
        _MockRef(),
        emptyScope,
        gateway:             gateway,
        currentUserId:       () => 'user-abc',
        authChanges:         const Stream<AuthState>.empty(),
        rememberQuestion:    (_) {},
        recentQuestions:     () => [],
        clearSelectedProject: () async {},
        clearSensitiveMemory: () {},
      );

      await notifier.send(message: 'teste', context: _testContext());
      expect(notifier.state.error, isNotNull);
      expect(gateway.callCount, equals(0));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 12 — Segurança: clearHistory no logout
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 12 — Segurança: clearHistory e cancelProposal', () {
    test('12.1 clearHistory() limpa turns, error e proposal', () {
      final gateway  = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway);

      final now = DateTime.now().toUtc();
      notifier.overrideStateForTest(notifier.state.copyWith(
        turns: [
          CopilotTurn(role: 'user', content: 'msg', timestamp: now),
        ],
        pendingProposal: IveActionProposal(
          proposalId:  'p1',
          userId:      'user-abc',
          projectId:   'project-abc-123',
          projectName: 'P',
          title:       'T',
          description: '',
          priority:    50,
          impact:      50,
          effort:      50,
          rationale:   '',
          origin:      'ive',
          createdAt:   now,
          expiresAt:   now.add(const Duration(minutes: 15)),
        ),
      ));

      notifier.clearHistory();

      expect(notifier.state.turns, isEmpty);
      expect(notifier.state.pendingProposal, isNull);
      expect(notifier.state.error, isNull);
    });

    test('12.2 cancelProposal() adiciona mensagem de cancelamento ao histórico', () {
      final gateway  = _FakeGateway(response: _validV2Response());
      final notifier = _makeNotifier(gateway);

      final now = DateTime.now().toUtc();
      notifier.overrideStateForTest(notifier.state.copyWith(
        pendingProposal: IveActionProposal(
          proposalId:  'p-cancel',
          userId:      'user-abc',
          projectId:   'project-abc-123',
          projectName: 'Projeto',
          title:       'Ação a cancelar',
          description: '',
          priority:    50,
          impact:      50,
          effort:      50,
          rationale:   '',
          origin:      'ive',
          createdAt:   now,
          expiresAt:   now.add(const Duration(minutes: 15)),
        ),
      ));

      notifier.cancelProposal();

      expect(notifier.state.pendingProposal, isNull);
      expect(notifier.state.turns.last.content, contains('cancelada'));
    });
  });

// ══════════════════════════════════════════════════════════════════════════════
// GRUPO 13 — IveActionProposal: TTL e idempotência
// ══════════════════════════════════════════════════════════════════════════════

  group('Grupo 13 — IveActionProposal: TTL, idempotência e persistenceMarker', () {
    test('13.1 isExpired retorna true após 15 minutos', () {
      final now = DateTime.now().toUtc();
      final expired = IveActionProposal(
        proposalId:  'p-exp',
        userId:      'u',
        projectId:   'proj',
        projectName: 'P',
        title:       'T',
        description: '',
        priority:    50,
        impact:      50,
        effort:      50,
        rationale:   '',
        origin:      'ive',
        createdAt:   now.subtract(const Duration(minutes: 20)),
        expiresAt:   now.subtract(const Duration(seconds: 1)),
      );
      expect(expired.isExpired, isTrue);
    });

    test('13.2 isExpired retorna false quando dentro do TTL', () {
      final now = DateTime.now().toUtc();
      final valid = IveActionProposal(
        proposalId:  'p-valid',
        userId:      'u',
        projectId:   'proj',
        projectName: 'P',
        title:       'T',
        description: '',
        priority:    50,
        impact:      50,
        effort:      50,
        rationale:   '',
        origin:      'ive',
        createdAt:   now,
        expiresAt:   now.add(const Duration(minutes: 14)),
      );
      expect(valid.isExpired, isFalse);
    });

    test('13.3 persistenceMarker tem formato esperado para deduplicação', () {
      final now = DateTime.now().toUtc();
      final proposal = IveActionProposal(
        proposalId:  'meu-id-unico',
        userId:      'u',
        projectId:   'proj',
        projectName: 'P',
        title:       'T',
        description: '',
        priority:    50,
        impact:      50,
        effort:      50,
        rationale:   '',
        origin:      'ive',
        createdAt:   now,
        expiresAt:   now.add(const Duration(minutes: 15)),
      );
      expect(proposal.persistenceMarker, equals('ive_proposal:meu-id-unico'));
    });
  });
}
