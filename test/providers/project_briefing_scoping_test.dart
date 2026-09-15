/// IVE-COMMERCIAL-EXPERIENCE-14, Phase B Section 23 — testa a lógica de
/// escopo por projeto do projectBriefingProvider (lib/providers/
/// ecosystem_intelligence_provider.dart). Replica aqui apenas o filtro
/// (`scores.where((s) => s.project.id == projectId)`) e chama o mesmo
/// EcosystemIntelligenceService.generateBriefing() real usado pelo provider
/// — não reimplementa a lógica de geração do briefing, apenas prova que a
/// filtragem por projeto, feita ANTES de chamar generateBriefing(), impede
/// que dados de outros projetos apareçam no resultado (mission Section 05:
/// "Never present global information as project-specific").
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/ecosystem_intelligence_service.dart';

Project _p(String id, String name) => Project(
      id:        id,
      userId:    'uid',
      name:      name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

EcosystemScore _score(
  Project p,
  int ecoScore, {
  String recommendation = 'ESCALAR',
}) =>
    EcosystemScore(
      project:          p,
      opportunityScore: ecoScore,
      strategicFit:     50,
      synergyScore:     50,
      roiScore:         50,
      momentumScore:    50,
      ecosystemScore:   ecoScore,
      recommendation:   recommendation,
      strengths:        const ['Forte diferencial'],
      risks:            const ['Concorrência alta'],
      quickWins:        const [],
      totalRoi:         0,
      actionCount:      0,
      completedActions: 0,
      labItemCount:     0,
    );

final _service = EcosystemIntelligenceService();

void main() {
  group('projectBriefingProvider scoping — sem vazamento entre projetos', () {
    test('whatGrew de um projeto nunca cita o nome de outro projeto', () {
      final a = _p('proj-a', 'Projeto Alfa');
      final b = _p('proj-b', 'Projeto Beta');

      final allScores = [
        _score(a, 85, recommendation: 'ESCALAR'),
        _score(b, 90, recommendation: 'ESCALAR'),
      ];

      final scopedToA =
          allScores.where((s) => s.project.id == a.id).toList();

      final briefing = _service.generateBriefing(
        scores:     scopedToA,
        analyses:   const [],
        actions:    const [],
        labItems:   const [],
        roiMetrics: const [],
      );

      expect(briefing.whatGrew, hasLength(1));
      expect(briefing.whatGrew.single.title, contains('Projeto Alfa'));
      expect(
        briefing.whatGrew.every((i) => !i.title.contains('Projeto Beta')),
        isTrue,
      );
    });

    test('projeto sem scores próprios recebe briefing vazio, não o de outro projeto', () {
      final a = _p('proj-a', 'Projeto Alfa');
      final c = _p('proj-c', 'Projeto Gama (sem dados ainda)');

      final allScores = [_score(a, 95, recommendation: 'ESCALAR')];

      final scopedToC =
          allScores.where((s) => s.project.id == c.id).toList();

      final briefing = _service.generateBriefing(
        scores:     scopedToC,
        analyses:   const [],
        actions:    const [],
        labItems:   const [],
        roiMetrics: const [],
      );

      expect(scopedToC, isEmpty);
      expect(briefing.whatGrew, isEmpty);
      expect(briefing.whatDeclined, isEmpty);
      // Fallback seguro do service quando não há atividade — nunca lança
      // exceção e nunca herda o item de outro projeto.
      expect(briefing.whatChanged, hasLength(1));
      expect(
        briefing.whatChanged.single.title,
        'Nenhuma atividade nova esta semana',
      );
    });

    test('projeto deletado/inexistente (id sem correspondência) não quebra e não vaza dados', () {
      final a = _p('proj-a', 'Projeto Alfa');
      final allScores = [_score(a, 95, recommendation: 'ESCALAR')];

      const deletedProjectId = 'proj-does-not-exist';
      final scoped =
          allScores.where((s) => s.project.id == deletedProjectId).toList();

      expect(scoped, isEmpty);

      final briefing = _service.generateBriefing(
        scores:     scoped,
        analyses:   const [],
        actions:    const [],
        labItems:   const [],
        roiMetrics: const [],
      );
      expect(briefing.whatGrew, isEmpty);
      expect(briefing.overallHealthScore, 0);
    });

    test('whatDeclined também é escopado por projeto (PAUSAR)', () {
      final a = _p('proj-a', 'Projeto Alfa');
      final b = _p('proj-b', 'Projeto Beta');

      final allScores = [
        _score(a, 20, recommendation: 'PAUSAR'),
        _score(b, 15, recommendation: 'PAUSAR'),
      ];

      final scopedToB =
          allScores.where((s) => s.project.id == b.id).toList();

      final briefing = _service.generateBriefing(
        scores:     scopedToB,
        analyses:   const [],
        actions:    const [],
        labItems:   const [],
        roiMetrics: const [],
      );

      expect(briefing.whatDeclined, hasLength(1));
      expect(briefing.whatDeclined.single.title, contains('Projeto Beta'));
    });
  });
}
