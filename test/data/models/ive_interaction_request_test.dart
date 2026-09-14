import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/ive_interaction_request.dart';
import 'package:ai_social_copilot/data/models/copilot_context_data.dart';

void main() {
  group('IveInteractionRequest', () {
    test('carrega project/module/entity/operation corretamente', () {
      final req = IveInteractionRequest(
        projectId: 'project-1',
        sourceModule: 'opportunity_lab',
        sourceEntityType: 'opportunity',
        sourceEntityId: 'opp-1',
        operationType: IveOperationType.analyze,
      );

      expect(req.projectId, 'project-1');
      expect(req.sourceModule, 'opportunity_lab');
      expect(req.sourceEntityType, 'opportunity');
      expect(req.sourceEntityId, 'opp-1');
      expect(req.operationType, IveOperationType.analyze);
    });

    test('gera um correlationId automaticamente quando nenhum é passado', () {
      final req = IveInteractionRequest(
        sourceModule: 'global_overlay',
        operationType: IveOperationType.ask,
      );
      expect(req.correlationId, isNotEmpty);
    });

    test('duas requests sucessivas geram correlationIds diferentes', () {
      final a = IveInteractionRequest(sourceModule: 'x', operationType: IveOperationType.ask);
      final b = IveInteractionRequest(sourceModule: 'x', operationType: IveOperationType.ask);
      expect(a.correlationId, isNot(b.correlationId));
    });

    test('preserva um correlationId explicitamente passado, sem gerar outro', () {
      final req = IveInteractionRequest(
        sourceModule: 'x',
        operationType: IveOperationType.ask,
        correlationId: 'fixed-correlation-id',
      );
      expect(req.correlationId, 'fixed-correlation-id');
    });

    test('projectId null é preservado como null (não confundido com ausência de campo)', () {
      final req = IveInteractionRequest(
        sourceModule: 'global_overlay',
        operationType: IveOperationType.ask,
      );
      expect(req.projectId, isNull);
    });
  });

  group('CopilotContextData.withIdentity', () {
    test('aplica todos os campos de identidade da request', () {
      const base = CopilotContextData(opportunities: [
        {'title': 'x'}
      ]);
      final req = IveInteractionRequest(
        projectId: 'project-1',
        sourceModule: 'market_intelligence',
        sourceEntityType: 'gap_analysis',
        sourceEntityId: 'gap-1',
        operationType: IveOperationType.analyze,
        correlationId: 'corr-1',
      );

      final withId = base.withIdentity(req);

      expect(withId.projectId, 'project-1');
      expect(withId.sourceModule, 'market_intelligence');
      expect(withId.sourceEntityType, 'gap_analysis');
      expect(withId.sourceEntityId, 'gap-1');
      expect(withId.correlationId, 'corr-1');
      // Preserva os dados de negócio já presentes, não os descarta.
      expect(withId.opportunities, base.opportunities);
    });
  });
}
