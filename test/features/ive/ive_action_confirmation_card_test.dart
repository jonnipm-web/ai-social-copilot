import 'package:ai_social_copilot/features/ive/domain/ive_action_proposal.dart';
import 'package:ai_social_copilot/shared/widgets/ive_action_confirmation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IveActionProposal proposal() {
    final now = DateTime.now().toUtc();
    return IveActionProposal(
      proposalId: 'proposal-1',
      userId: 'user-1',
      projectId: 'project-1',
      projectName: 'Projeto principal',
      title: 'Validar oferta',
      description: 'Entrevistar cinco clientes',
      priority: 80,
      impact: 90,
      effort: 30,
      rationale: 'Reduz o risco principal.',
      origin: 'ive',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }

  testWidgets('exibe escopo e exige clique explícito para confirmar',
      (tester) async {
    var confirmations = 0;
    var cancellations = 0;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: SingleChildScrollView(
          child: IveActionConfirmationCard(
            proposal: proposal(),
            executing: false,
            onConfirm: () => confirmations++,
            onCancel: () => cancellations++,
            onEdit: ({
              required title,
              required description,
              required priority,
              required impact,
              required effort,
            }) {},
          ),
        ),
      ),
    ));

    expect(find.text('Confirme antes de executar'), findsOneWidget);
    expect(
      find.textContaining('Projeto principal', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Validar oferta', findRichText: true),
      findsOneWidget,
    );
    expect(confirmations, 0);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(confirmations, 1);
    expect(cancellations, 0);
  });

  testWidgets('estado de execução bloqueia confirmação, edição e cancelamento',
      (tester) async {
    var interactions = 0;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: SingleChildScrollView(
          child: IveActionConfirmationCard(
            proposal: proposal(),
            executing: true,
            onConfirm: () => interactions++,
            onCancel: () => interactions++,
            onEdit: ({
              required title,
              required description,
              required priority,
              required impact,
              required effort,
            }) =>
                interactions++,
          ),
        ),
      ),
    ));

    expect(find.text('Criando…'), findsOneWidget);
    await tester.tap(find.text('Criando…'));
    await tester.tap(find.text('Cancelar'));
    await tester.tap(find.text('Editar'));
    await tester.pump();
    expect(interactions, 0);
  });
}
