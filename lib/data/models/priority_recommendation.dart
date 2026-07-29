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

  // Fase 11 — Executive Decision fields
  final String costOfIgnoring;
  final List<String> evidences;
  final String priority;   // 'alta' | 'média' | 'baixa'

  const PriorityRecommendation({
    required this.title,
    required this.reason,
    required this.dataUsed,
    required this.expectedImpact,
    required this.confidence,
    required this.type,
    this.entityId,
    this.entityName,
    this.costOfIgnoring = '',
    this.evidences      = const [],
    this.priority       = 'média',
  });

  String get typeLabel {
    switch (type) {
      case RecommendationType.investProject:      return 'Investir';
      case RecommendationType.executeOpportunity: return 'Executar';
      case RecommendationType.runAction:          return 'Ação';
      case RecommendationType.pauseProject:       return 'Pausar';
      case RecommendationType.mitigateRisk:       return 'Risco';
      case RecommendationType.quickWin:           return 'Ganho Rápido';
      case RecommendationType.waste:              return 'Desperdício';
    }
  }

  String get priorityEmoji {
    switch (priority) {
      case 'alta':  return '🔴';
      case 'baixa': return '🟢';
      default:      return '🟡';
    }
  }
}
