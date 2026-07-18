import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:ai_social_copilot/shared/widgets/ive_response_context_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('7 mostra evidence validada sem exibir id técnico',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: IveResponseContextPanel(
          evidence: [
            IveEvidence(
              sourceType: 'opportunity',
              sourceId: 'technical-evidence-id',
              title: 'Oportunidade validada',
              excerpt: 'Score 87 e status pending.',
              timestamp: null,
              relevance: 0.87,
            ),
          ],
          limitations: [],
        ),
      ),
    ));

    expect(find.text('Evidências verificadas'), findsOneWidget);
    expect(find.text('Oportunidade validada'), findsOneWidget);
    expect(find.text('Opportunity Lab · 87% relevante'), findsOneWidget);
    expect(find.text('Score 87 e status pending.'), findsOneWidget);
    expect(find.text('technical-evidence-id'), findsNothing);
  });

  testWidgets('9 mostra limitations de forma explícita', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: IveResponseContextPanel(
          evidence: [],
          limitations: [
            'Apenas metadados da Knowledge Base estavam disponíveis.',
          ],
        ),
      ),
    ));

    expect(find.text('Limitações desta resposta'), findsOneWidget);
    expect(
      find.text(
        '• Apenas metadados da Knowledge Base estavam disponíveis.',
      ),
      findsOneWidget,
    );
  });
}
