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
  });

  String get recommendationEmoji {
    switch (recommendation) {
      case 'ACELERAR': return '🚀';
      case 'MANTER':   return '✅';
      case 'REVISAR':  return '⚠️';
      default:         return '⏸️';
    }
  }

  int get completionRate =>
      actionCount == 0 ? 0 : (completedActions / actionCount * 100).round();
}
