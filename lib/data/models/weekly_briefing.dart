class BriefingItem {
  final String title;
  final String detail;
  final int impact;

  const BriefingItem({
    required this.title,
    required this.detail,
    this.impact = 0,
  });
}

class WeeklyBriefing {
  final DateTime generatedAt;
  final int overallHealthScore;
  final int healthDelta;
  final List<BriefingItem> whatChanged;
  final List<BriefingItem> whatGrew;
  final List<BriefingItem> whatDeclined;
  final List<BriefingItem> topPriorities;
  final List<BriefingItem> toPause;
  final List<BriefingItem> newOpportunities;
  final List<BriefingItem> risks;
  final String executiveSummary;

  // ── Metadados de auditoria ────────────────────────────────────────────────
  final List<String> analyzedProjectNames;
  final int projectCount;
  final int analysisCount;
  final int actionsCount;
  final int opportunitiesCount;

  const WeeklyBriefing({
    required this.generatedAt,
    required this.overallHealthScore,
    this.healthDelta = 0,
    required this.whatChanged,
    required this.whatGrew,
    required this.whatDeclined,
    required this.topPriorities,
    required this.toPause,
    required this.newOpportunities,
    required this.risks,
    required this.executiveSummary,
    this.analyzedProjectNames = const [],
    this.projectCount         = 0,
    this.analysisCount        = 0,
    this.actionsCount         = 0,
    this.opportunitiesCount   = 0,
  });

  String get healthEmoji {
    if (overallHealthScore >= 70) return '🟢';
    if (overallHealthScore >= 45) return '🟡';
    return '🔴';
  }
}
