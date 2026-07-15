class ExecutionScore {
  final String projectId;
  final int score;
  final int completedActions;
  final int totalActions;
  final int approvedOpportunities;
  final int totalOpportunities;
  final bool hasRoadmap;
  final List<String> explanation;

  const ExecutionScore({
    required this.projectId,
    required this.score,
    required this.completedActions,
    required this.totalActions,
    required this.approvedOpportunities,
    required this.totalOpportunities,
    required this.hasRoadmap,
    required this.explanation,
  });

  double get completionRate =>
      totalActions == 0 ? 0 : completedActions / totalActions;

  double get approvalRate =>
      totalOpportunities == 0 ? 0 : approvedOpportunities / totalOpportunities;

  String get scoreLabel {
    if (score >= 80) return 'Excelente';
    if (score >= 60) return 'Bom';
    if (score >= 40) return 'Regular';
    if (score >= 20) return 'Iniciando';
    return 'Sem Execução';
  }
}
