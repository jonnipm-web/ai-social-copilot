import 'executive_context.dart';
import 'executive_relationship.dart';
import 'knowledge_coverage.dart';
import 'market_analysis.dart';
import 'project.dart';

class ProjectIntelligenceProfile {
  final Project project;
  final MarketAnalysis? analysis;
  final KnowledgeCoverage coverage;
  final String maturityStage; // 'ideia' | 'validando' | 'crescendo' | 'maduro'
  final List<String> relatedProjectNames;
  final List<String> identifiedTopics;
  final List<String> missingKnowledge;
  final String niche;
  final String targetAudience;
  final String monetizationModel;
  final String valueProposition;
  final DateTime computedAt;

  // Fase 11 — Executive Intelligence
  final ExecutiveHealth? executiveHealth;
  final List<ExecutiveRelationship> relationships;
  final bool checkInDue;
  final DateTime? lastAnalysisAt;
  final int executivePriorityScore;

  const ProjectIntelligenceProfile({
    required this.project,
    this.analysis,
    required this.coverage,
    required this.maturityStage,
    required this.relatedProjectNames,
    required this.identifiedTopics,
    required this.missingKnowledge,
    required this.niche,
    required this.targetAudience,
    required this.monetizationModel,
    required this.valueProposition,
    required this.computedAt,
    this.executiveHealth,
    this.relationships = const [],
    this.checkInDue = false,
    this.lastAnalysisAt,
    this.executivePriorityScore = 0,
  });

  String get maturityLabel {
    switch (maturityStage) {
      case 'maduro':
        return 'Maduro';
      case 'crescendo':
        return 'Crescendo';
      case 'validando':
        return 'Validando';
      default:
        return 'Ideia';
    }
  }

  String get maturityEmoji {
    switch (maturityStage) {
      case 'maduro':
        return '🌳';
      case 'crescendo':
        return '🌱';
      case 'validando':
        return '🔬';
      default:
        return '💡';
    }
  }

  bool get hasEnoughData => coverage.score >= 30 && analysis != null;

  String? get dataWarning {
    if (analysis == null)
      return 'Execute uma análise de mercado para obter inteligência.';
    if (coverage.score < 20)
      return 'Dados insuficientes. Adicione ações e oportunidades.';
    return null;
  }

  // Fase 11 — Idea Interview Engine trigger
  bool get shouldInterview =>
      coverage.score < 30 &&
      niche == 'Não definido' &&
      targetAudience == 'Não definido';

  // Relações que requerem atenção imediata
  List<ExecutiveRelationship> get criticalRelationships =>
      relationships.where((r) => r.requiresAttention).toList();

  // Score de prioridade dinâmica (0-100)
  int get dynamicPriority {
    if (executivePriorityScore > 0) return executivePriorityScore;
    var score = 0;
    score += (project.opportunityScore * 0.4).round();
    score += (coverage.score * 0.2).round();
    if (analysis != null) score += ((analysis!.scoreGrowth ?? 0) * 0.2).round();
    if (maturityStage == 'crescendo') score += 10;
    if (maturityStage == 'validando') score += 5;
    if (checkInDue) score -= 10;
    return score.clamp(0, 100);
  }
}
