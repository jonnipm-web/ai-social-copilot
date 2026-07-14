enum RecommendationType {
  investProject,
  executeOpportunity,
  runAction,
  pauseProject,
  mitigateRisk,
  quickWin,
  waste,
}

class PriorityRecommendation {
  final String title;
  final String reason;
  final String dataUsed;
  final String expectedImpact;
  final int confidence;
  final RecommendationType type;
  final String? entityId;
  final String? entityName;

  const PriorityRecommendation({
    required this.title,
    required this.reason,
    required this.dataUsed,
    required this.expectedImpact,
    required this.confidence,
    required this.type,
    this.entityId,
    this.entityName,
  });

  String get typeLabel {
    switch (type) {
      case RecommendationType.investProject:    return 'Investir';
      case RecommendationType.executeOpportunity: return 'Executar';
      case RecommendationType.runAction:        return 'Ação';
      case RecommendationType.pauseProject:     return 'Pausar';
      case RecommendationType.mitigateRisk:     return 'Risco';
      case RecommendationType.quickWin:         return 'Ganho Rápido';
      case RecommendationType.waste:            return 'Desperdício';
    }
  }
}
