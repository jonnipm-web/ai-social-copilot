import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_action_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CopilotActionSuggestion suggestion({String? opportunityId}) =>
      CopilotActionSuggestion(
        type: 'action.create',
        label: 'Criar ação',
        data: {
          'title': 'Validar oferta',
          'description': 'Entrevistar cinco clientes',
          'priority': 85,
          'impact': 90,
          'effort': 30,
          'due_date': '2026-07-21T09:00:00Z',
          'rationale': 'A validação reduz o principal risco.',
          if (opportunityId != null) 'opportunity_id': opportunityId,
          // Valores não confiáveis enviados pelo modelo devem ser ignorados.
          'user_id': 'attacker',
          'project_id': 'other-project',
        },
      );

  test('injeta usuário e projeto confiáveis e aceita oportunidade do contexto',
      () {
    final proposal = IveActionProposal.fromSuggestion(
      suggestion: suggestion(opportunityId: 'opp-1'),
      userId: 'user-1',
      projectId: 'project-1',
      projectName: 'Projeto principal',
      allowedOpportunityIds: const {'opp-1'},
    );

    expect(proposal.userId, 'user-1');
    expect(proposal.projectId, 'project-1');
    expect(proposal.projectName, 'Projeto principal');
    expect(proposal.opportunityId, 'opp-1');
    expect(proposal.origin, 'opportunity_lab');
    expect(proposal.suggestedDueDate, DateTime.utc(2026, 7, 21, 9));
    expect(proposal.status, IveActionProposalStatus.pendingConfirmation);
  });

  test('descarta oportunidade que não pertence ao contexto ativo', () {
    final proposal = IveActionProposal.fromSuggestion(
      suggestion: suggestion(opportunityId: 'opp-other-project'),
      userId: 'user-1',
      projectId: 'project-1',
      projectName: 'Projeto principal',
      allowedOpportunityIds: const {'opp-1'},
    );

    expect(proposal.opportunityId, isNull);
    expect(proposal.origin, 'ive');
  });

  test('editar gera uma nova confirmação e uma nova chave idempotente', () {
    final original = IveActionProposal.fromSuggestion(
      suggestion: suggestion(),
      userId: 'user-1',
      projectId: 'project-1',
      projectName: 'Projeto principal',
      allowedOpportunityIds: const {},
    );

    final revised = original.revised(
      title: 'Validar oferta revisada',
      description: original.description,
      priority: 120,
      impact: original.impact,
      effort: -5,
      suggestedDueDate: original.suggestedDueDate,
    );

    expect(revised.proposalId, isNot(original.proposalId));
    expect(revised.idempotencyKey, isNot(original.idempotencyKey));
    expect(revised.status, IveActionProposalStatus.pendingConfirmation);
    expect(revised.priority, 100);
    expect(revised.effort, 0);
  });

  test('rejeita ferramenta fora da allowlist', () {
    expect(
      () => IveActionProposal.fromSuggestion(
        suggestion: const CopilotActionSuggestion(
          type: 'project.delete',
          label: 'Excluir',
          data: {'title': 'Excluir projeto'},
        ),
        userId: 'user-1',
        projectId: 'project-1',
        projectName: 'Projeto principal',
        allowedOpportunityIds: const {},
      ),
      throwsFormatException,
    );
  });
}
