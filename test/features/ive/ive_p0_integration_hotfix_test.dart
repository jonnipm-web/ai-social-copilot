import 'package:ai_social_copilot/features/ive/domain/ive_action_proposal.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_presentation_sanitizer.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart';
import 'package:ai_social_copilot/shared/widgets/ive_action_confirmation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parser preserva estados distintos de disponibilidade', () {
    final response = IveCopilotResponse.parse(
      {
        'response_text': 'Dados consultados.',
        'project_id': 'project-1',
        'source_status': {
          'opportunities': 'AVAILABLE',
          'actions': 'EMPTY',
          'knowledge': 'NOT_LINKED',
          'assets': 'UNAVAILABLE',
        },
      },
      activeProjectId: 'project-1',
      requestCorrelationId: 'correlation-1',
      allowedOpportunityIds: const {},
    );

    expect(response.sourceStatus['opportunities'], 'AVAILABLE');
    expect(response.sourceStatus['actions'], 'EMPTY');
    expect(response.sourceStatus['knowledge'], 'NOT_LINKED');
    expect(response.sourceStatus['assets'], 'UNAVAILABLE');
  });

  test('UUID e label interno somem apenas da apresentação', () {
    const uuid = '123e4567-e89b-42d3-a456-426614174000';
    final evidence = IveEvidence.tryParse(
      {
        'source_type': 'opportunity',
        'source_id': uuid,
        'project_id': 'project-1',
        'title': 'Expansão enterprise',
        'relevance': 0.9,
      },
      activeProjectId: 'project-1',
    );

    final visible = sanitizeIvePresentationText(
      'Projeto $uuid [PROJECT_SCORES] recomenda prioridade alta.',
    );

    expect(visible, isNot(contains(uuid)));
    expect(visible, contains('Indicadores estratégicos'));
    expect(evidence?.sourceId, uuid);
  });

  testWidgets(
      'viewport pequena permite rolar proposta inteira e acessar confirmação',
      (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var confirmed = false;
    final now = DateTime.now().toUtc();
    final proposal = IveActionProposal(
      proposalId: 'proposal-scroll',
      userId: 'user-1',
      projectId: 'project-1',
      projectName: 'AI SOCIAL COPILOT™',
      title: 'Validar a principal oportunidade com clientes prioritários',
      description: List.filled(
        12,
        'Entrevistar clientes, registrar evidências e revisar os indicadores.',
      ).join(' '),
      priority: 80,
      impact: 90,
      effort: 40,
      rationale: List.filled(
        6,
        'Esta ação reduz o risco estratégico antes de ampliar o investimento.',
      ).join(' '),
      origin: 'ive',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 420,
          child: IveConversationScroll(
            controller: controller,
            children: [
              const Text('Resposta executiva longa',
                  style: TextStyle(fontSize: 24)),
              IveActionConfirmationCard(
                proposal: proposal,
                executing: false,
                onConfirm: () => confirmed = true,
                onCancel: () {},
                onEdit: ({
                  required title,
                  required description,
                  required priority,
                  required impact,
                  required effort,
                }) {},
              ),
            ],
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(controller.position.maxScrollExtent, greaterThan(0));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('Confirmar').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Confirmar').hitTestable());
    await tester.pump();

    expect(confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
