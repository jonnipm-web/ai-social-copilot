import 'dart:math' as math;

import 'action_queue_item.dart';
import 'market_analysis.dart';
import 'opportunity_lab_item.dart';
import 'project.dart';
import 'revenue_plan.dart';

class KnowledgeCoverage {
  final String projectId;
  final String projectName;
  final int score;
  final int docPoints;
  final int oppPoints;
  final int actionPoints;
  final int roadmapPoints;
  final int revenuePoints;
  final int personaPoints;
  final List<String> gaps;
  final List<String> strengths;

  const KnowledgeCoverage({
    required this.projectId,
    required this.projectName,
    required this.score,
    required this.docPoints,
    required this.oppPoints,
    required this.actionPoints,
    required this.roadmapPoints,
    required this.revenuePoints,
    required this.personaPoints,
    required this.gaps,
    required this.strengths,
  });

  // Legacy aliases used by existing widgets
  int get analysisPoints  => 0;
  int get knowledgePoints => docPoints;
  int get opportunityPoints => oppPoints;

  String get coverageLabel {
    if (score >= 80) return 'Excelente';
    if (score >= 60) return 'Bom';
    if (score >= 40) return 'Moderado';
    if (score >= 20) return 'Básico';
    return 'Mínimo';
  }

  String get coverageEmoji {
    if (score >= 80) return '🟢';
    if (score >= 60) return '🔵';
    if (score >= 40) return '🟡';
    if (score >= 20) return '🟠';
    return '🔴';
  }

  // ── Coverage 2.0 ──────────────────────────────────────────────────────────
  // Documentos  25 pts  — conhecimento bruto indexado
  // Oportunidades 20 pts  — inteligência de oportunidades
  // Ações       20 pts  — plano de execução
  // Roadmap     15 pts  — visão estruturada de futuro
  // Revenue Plan 10 pts  — viabilidade financeira
  // Personas    10 pts  — capacidade de comunicação treinada
  // Total       100 pts
  static KnowledgeCoverage compute({
    required Project project,
    required MarketAnalysis? analysis,       // kept for compat; no longer scores
    required int knowledgeItemCount,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required RevenuePlan? revenuePlan,
    int trainedPersonaCount = 0,
  }) {
    final docPts      = math.min(25, knowledgeItemCount * 5);
    final oppPts      = math.min(20, labItems.length * 7);
    final actionPts   = math.min(20, actions.length * 4);
    final hasRoadmap  = _projectHasRoadmap(project);
    final roadmapPts  = hasRoadmap ? 15 : 0;
    final revenuePts  = revenuePlan != null ? 10 : 0;
    final personaPts  = math.min(10, trainedPersonaCount * 5);

    final total = docPts + oppPts + actionPts + roadmapPts + revenuePts + personaPts;

    final gaps = <String>[];
    if (knowledgeItemCount == 0) gaps.add('Adicione documentos ao Cofre de Conhecimento');
    if (labItems.isEmpty)        gaps.add('Sem oportunidades — execute o Knowledge → Action Engine');
    if (actions.isEmpty)         gaps.add('Sem ações definidas para o projeto');
    if (!hasRoadmap)             gaps.add('Roadmap não gerado — execute o Bootstrap');
    if (revenuePlan == null)     gaps.add('Plano de receita não criado');
    if (trainedPersonaCount == 0) gaps.add('Personas sem treinamento de conhecimento');

    final strengths = <String>[];
    if (knowledgeItemCount >= 3) strengths.add('Base de conhecimento estabelecida');
    if (labItems.length >= 3)    strengths.add('Oportunidades mapeadas');
    if (actions.length >= 3)     strengths.add('Ações planejadas');
    if (hasRoadmap)              strengths.add('Roadmap estruturado');
    if (revenuePlan != null)     strengths.add('Plano de receita projetado');
    if (trainedPersonaCount > 0) strengths.add('Personas com conhecimento treinado');

    return KnowledgeCoverage(
      projectId:      project.id,
      projectName:    project.name,
      score:          total.clamp(0, 100),
      docPoints:      docPts,
      oppPoints:      oppPts,
      actionPoints:   actionPts,
      roadmapPoints:  roadmapPts,
      revenuePoints:  revenuePts,
      personaPoints:  personaPts,
      gaps:           gaps,
      strengths:      strengths,
    );
  }

  static bool _projectHasRoadmap(Project project) {
    final details = project.detailsJson;
    final roadmap = details['roadmap'];
    if (roadmap == null) return false;
    if (roadmap is Map) {
      final items = [
        ...(roadmap['short_term'] as List? ?? []),
        ...(roadmap['medium_term'] as List? ?? []),
        ...(roadmap['long_term'] as List? ?? []),
      ];
      return items.isNotEmpty;
    }
    return false;
  }
}
