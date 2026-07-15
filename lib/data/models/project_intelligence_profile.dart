import 'knowledge_coverage.dart';
import 'market_analysis.dart';
import 'project.dart';

class ProjectIntelligenceProfile {
  final Project project;
  final MarketAnalysis? analysis;
  final KnowledgeCoverage coverage;
  final String maturityStage;        // 'ideia' | 'validando' | 'crescendo' | 'maduro'
  final List<String> relatedProjectNames;
  final List<String> identifiedTopics;
  final List<String> missingKnowledge;
  final String niche;
  final String targetAudience;
  final String monetizationModel;
  final String valueProposition;
  final DateTime computedAt;

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
  });

  String get maturityLabel {
    switch (maturityStage) {
      case 'maduro':    return 'Maduro';
      case 'crescendo': return 'Crescendo';
      case 'validando': return 'Validando';
      default:          return 'Ideia';
    }
  }

  String get maturityEmoji {
    switch (maturityStage) {
      case 'maduro':    return '🌳';
      case 'crescendo': return '🌱';
      case 'validando': return '🔬';
      default:          return '💡';
    }
  }

  bool get hasEnoughData => coverage.score >= 30 && analysis != null;

  String? get dataWarning {
    if (analysis == null) return 'Execute uma análise de mercado para obter inteligência.';
    if (coverage.score < 20) return 'Dados insuficientes. Adicione ações e oportunidades.';
    return null;
  }
}
