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
  final int analysisPoints;
  final int knowledgePoints;
  final int actionPoints;
  final int opportunityPoints;
  final int revenuePoints;
  final List<String> gaps;
  final List<String> strengths;

  const KnowledgeCoverage({
    required this.projectId,
    required this.projectName,
    required this.score,
    required this.analysisPoints,
    required this.knowledgePoints,
    required this.actionPoints,
    required this.opportunityPoints,
    required this.revenuePoints,
    required this.gaps,
    required this.strengths,
  });

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

  static KnowledgeCoverage compute({
    required Project project,
    required MarketAnalysis? analysis,
    required int knowledgeItemCount,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required RevenuePlan? revenuePlan,
  }) {
    final analysisPts    = analysis != null ? 30 : 0;
    final knowledgePts   = math.min(25, knowledgeItemCount * 5);
    final actionPts      = math.min(20, actions.length * 4);
    final opportunityPts = math.min(15, labItems.length * 5);
    final revenuePts     = revenuePlan != null ? 10 : 0;
    final total          = analysisPts + knowledgePts + actionPts + opportunityPts + revenuePts;

    final gaps = <String>[];
    if (analysis == null)       gaps.add('Análise de mercado pendente');
    if (knowledgeItemCount < 3) gaps.add('Adicione mais documentos ao cofre');
    if (actions.isEmpty)        gaps.add('Nenhuma ação definida para o projeto');
    if (labItems.isEmpty)       gaps.add('Sem oportunidades mapeadas no Lab');
    if (revenuePlan == null)    gaps.add('Plano de receita não criado');

    final strengths = <String>[];
    if (analysis != null)        strengths.add('Análise de mercado concluída');
    if (knowledgeItemCount >= 3) strengths.add('Base de conhecimento estabelecida');
    if (actions.length >= 3)     strengths.add('Ações planejadas');
    if (labItems.length >= 2)    strengths.add('Oportunidades mapeadas');
    if (revenuePlan != null)     strengths.add('Plano de receita projetado');

    return KnowledgeCoverage(
      projectId:         project.id,
      projectName:       project.name,
      score:             total.clamp(0, 100),
      analysisPoints:    analysisPts,
      knowledgePoints:   knowledgePts,
      actionPoints:      actionPts,
      opportunityPoints: opportunityPts,
      revenuePoints:     revenuePts,
      gaps:              gaps,
      strengths:         strengths,
    );
  }
}
