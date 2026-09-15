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

    // ── idempotencyKey — Codex Gate 1 / mission 13, Seções 05/14 ──────────
    final uuidV4Pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('gera um idempotencyKey automaticamente, com forma de UUID v4 real', () {
      final req = IveInteractionRequest(
        sourceModule: 'global_overlay',
        operationType: IveOperationType.ask,
      );
      expect(req.idempotencyKey, matches(uuidV4Pattern));
    });

    test('duas requests sucessivas geram idempotencyKeys diferentes', () {
      final a = IveInteractionRequest(sourceModule: 'x', operationType: IveOperationType.ask);
      final b = IveInteractionRequest(sourceModule: 'x', operationType: IveOperationType.ask);
      expect(a.idempotencyKey, isNot(b.idempotencyKey));
    });

    test('preserva um idempotencyKey explicitamente passado, sem gerar outro', () {
      final req = IveInteractionRequest(
        sourceModule: 'x',
        operationType: IveOperationType.ask,
        idempotencyKey: 'fixed-idempotency-key',
      );
      expect(req.idempotencyKey, 'fixed-idempotency-key');
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
