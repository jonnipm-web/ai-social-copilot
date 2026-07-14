import 'ecosystem_score.dart';

class AllocationItem {
  final EcosystemScore score;
  final double allocation;
  final double percentage;
  final String reason;
  final int expectedRoiScore;

  const AllocationItem({
    required this.score,
    required this.allocation,
    required this.percentage,
    required this.reason,
    required this.expectedRoiScore,
  });
}

class ResourceAllocation {
  final double totalBudget;
  final String budgetType;
  final List<AllocationItem> items;
  final String summary;

  const ResourceAllocation({
    required this.totalBudget,
    required this.budgetType,
    required this.items,
    required this.summary,
  });

  String get budgetLabel => budgetType == 'hours' ? 'horas' : 'R\$';
}
