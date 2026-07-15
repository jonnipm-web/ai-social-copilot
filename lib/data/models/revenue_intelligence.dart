import 'revenue_plan.dart';

class RevenueIntelligence {
  final String projectId;
  final String projectName;
  final double monthlyConservative;
  final double monthlyModerate;
  final double monthlyAggressive;
  final double annualModerate;
  final double estimatedTicket;
  final int estimatedClients;
  final int confidence;
  final bool hasRealPlan;
  final String explanation;
  final List<String> revenueSources;

  const RevenueIntelligence({
    required this.projectId,
    required this.projectName,
    required this.monthlyConservative,
    required this.monthlyModerate,
    required this.monthlyAggressive,
    required this.annualModerate,
    required this.estimatedTicket,
    required this.estimatedClients,
    required this.confidence,
    required this.hasRealPlan,
    required this.explanation,
    required this.revenueSources,
  });

  String get monthlyLabel => 'R\$ ${monthlyModerate.toStringAsFixed(0)}';
  String get annualLabel  => 'R\$ ${annualModerate.toStringAsFixed(0)}';

  int get roiScoreFromPlan {
    if (monthlyModerate <= 0) return 0;
    // R$10k/mês = 100 pts; R$5k = 50pts; R$1k = 10pts
    return (monthlyModerate / 100).round().clamp(0, 100);
  }

  static RevenueIntelligence fromPlan(RevenuePlan plan) {
    final sources = plan.revenueSources
        .map((s) {
          final m = s as Map?;
          return m?['source']?.toString() ?? '';
        })
        .where((s) => s.isNotEmpty)
        .toList();

    final milestones = plan.milestones;
    String firstMilestone = '';
    if (milestones.isNotEmpty) {
      final first = milestones.first;
      if (first is Map) {
        firstMilestone = (first['description'] as String?) ?? '';
      }
    }

    return RevenueIntelligence(
      projectId:            plan.marketAnalysisId ?? plan.projectName,
      projectName:          plan.projectName,
      monthlyConservative:  plan.monthlyConservative,
      monthlyModerate:      plan.monthlyModerate,
      monthlyAggressive:    plan.monthlyAggressive,
      annualModerate:       plan.annualModerate,
      estimatedTicket:      _estimateTicket(plan),
      estimatedClients:     _estimateClients(plan),
      confidence:           plan.monthlyModerate > 0 ? 70 : 30,
      hasRealPlan:          true,
      explanation:
          'Plano de receita moderado: R\$${plan.monthlyModerate.toStringAsFixed(0)}/mês.'
          '${firstMilestone.isNotEmpty ? " Marco: $firstMilestone." : ""}',
      revenueSources: sources,
    );
  }

  static RevenueIntelligence empty(String projectId, String projectName) =>
      RevenueIntelligence(
        projectId:            projectId,
        projectName:          projectName,
        monthlyConservative:  0,
        monthlyModerate:      0,
        monthlyAggressive:    0,
        annualModerate:       0,
        estimatedTicket:      0,
        estimatedClients:     0,
        confidence:           0,
        hasRealPlan:          false,
        explanation:          'Nenhum plano de receita encontrado.',
        revenueSources:       [],
      );

  static double _estimateTicket(RevenuePlan plan) {
    try {
      final ps = plan.planJson['pricing_strategy'] as Map?;
      if (ps != null) {
        final price = ps['price'];
        if (price is num) return price.toDouble();
      }
    } catch (_) {}
    if (plan.monthlyModerate > 0) return plan.monthlyModerate / 10;
    return 0;
  }

  static int _estimateClients(RevenuePlan plan) {
    if (_estimateTicket(plan) > 0) {
      return (plan.monthlyModerate / _estimateTicket(plan)).round().clamp(0, 9999);
    }
    return 0;
  }
}
