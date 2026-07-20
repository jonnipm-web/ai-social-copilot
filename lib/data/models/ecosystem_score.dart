import 'project.dart';

class EcosystemScore {
  final Project project;
  final int opportunityScore;
  final int strategicFit;
  final int synergyScore;
  final int roiScore;
  final int momentumScore;
  final int ecosystemScore;
  final String recommendation;
  final List<String> strengths;
  final List<String> risks;
  final List<String> quickWins;
  final double totalRoi;
  final int actionCount;
  final int completedActions;
  final int labItemCount;
  // Phase 10I — new fields
  final int marketScore;
  final int executionScore;
  final bool hasEnoughData;
  // Hotfix: distingue "ROI calculado como 0" de "sem dados de ROI"
  final bool hasRoiData;

  const EcosystemScore({
    required this.project,
    required this.opportunityScore,
    required this.strategicFit,
    required this.synergyScore,
    required this.roiScore,
    required this.momentumScore,
    required this.ecosystemScore,
    required this.recommendation,
    required this.strengths,
    required this.risks,
    required this.quickWins,
    required this.totalRoi,
    required this.actionCount,
    required this.completedActions,
    required this.labItemCount,
    this.marketScore    = 0,
    this.executionScore = 0,
    this.hasEnoughData  = true,
    this.hasRoiData     = false,
  });

  String get recommendationEmoji {
    switch (recommendation) {
      case 'ESCALAR':              return '⚡';
      case 'ACELERAR':             return '🚀';
      case 'MANTER':               return '✅';
      case 'VALIDAR':              return '🔍';
      case 'ANÁLISE INCOMPLETA':   return '📊';
      default:                     return '⏸️'; // PAUSAR
    }
  }

  int get completionRate =>
      actionCount == 0 ? 0 : (completedActions / actionCount * 100).round();
}
