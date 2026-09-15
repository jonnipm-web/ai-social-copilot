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

  // IVE-EXPERIENCE-V1-06 (Section 07/33) — Codex adversarial review of
  // IVE-EXPERIENCE-V1-05 found that `withIdentity()` attached identity
  // fields to the Dart object, but `CopilotContextData.toMap()` (what
  // actually reaches the Edge Function's request body) silently dropped
  // them — the envelope stopped at the Dart boundary. These tests prove
  // the full chain: constructing a request, attaching identity, and
  // serializing to the wire all carry the SAME identity, so this specific
  // regression cannot reappear silently.
  group('CopilotContextData.toMap() — propagação de identidade (P1 fix)', () {
    test('toMap() inclui todos os campos de identidade sob a chave "identity"', () {
      final req = IveInteractionRequest(
        projectId: 'project-1',
        sourceModule: 'website_analyzer',
        sourceEntityType: 'analysis',
        sourceEntityId: 'analysis-1',
        operationType: IveOperationType.explain,
        correlationId: 'corr-xyz',
      );
      final map = const CopilotContextData().withIdentity(req).toMap();

      expect(map['identity'], isNotNull);
      expect(map['identity']['project_id'], 'project-1');
      expect(map['identity']['source_module'], 'website_analyzer');
      expect(map['identity']['source_entity_type'], 'analysis');
      expect(map['identity']['source_entity_id'], 'analysis-1');
      expect(map['identity']['correlation_id'], 'corr-xyz');
    });

    test('a mesma correlationId de IveInteractionRequest sobrevive request → CopilotContextData → toMap()', () {
      final req = IveInteractionRequest(
        sourceModule: 'market_intelligence',
        operationType: IveOperationType.compare,
      );
      final map = const CopilotContextData().withIdentity(req).toMap();

      // Uma interação mantém UMA identidade de correlação — não uma cópia
      // reformatada nem um ID diferente mintado no caminho.
      expect(map['identity']['correlation_id'], req.correlationId);
    });

    test('toMap() sem identidade nenhuma não inclui a chave "identity"', () {
      final map = const CopilotContextData().toMap();
      expect(map.containsKey('identity'), isFalse);
    });

    test('toMap() preserva as seções de grounding existentes junto da identidade (não substitui)', () {
      final req = IveInteractionRequest(
        projectId: 'project-2',
        sourceModule: 'knowledge_vault',
        operationType: IveOperationType.explain,
      );
      const base = CopilotContextData(scores: {'ecosystem_health': 80});
      final map = base.withIdentity(req).toMap();

      expect(map['scores'], {'ecosystem_health': 80});
      expect(map['identity']['project_id'], 'project-2');
    });
  });
}
