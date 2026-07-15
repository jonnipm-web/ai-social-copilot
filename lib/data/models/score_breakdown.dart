class ScoreComponent {
  final String name;
  final int rawValue;
  final int maxValue;
  final double weight;
  final String formula;
  final String explanation;
  final List<String> dataSources;
  final bool hasData;

  const ScoreComponent({
    required this.name,
    required this.rawValue,
    required this.maxValue,
    required this.weight,
    required this.formula,
    required this.explanation,
    required this.dataSources,
    this.hasData = true,
  });

  int get weightedContribution => (rawValue * weight).round();
  String get displayWeight => '${(weight * 100).round()}%';
  double get completeness => maxValue == 0 ? 0 : rawValue / maxValue;
}

class ScoreBreakdown {
  final String projectId;
  final String projectName;
  final ScoreComponent opportunity;
  final ScoreComponent strategicFit;
  final ScoreComponent synergy;
  final ScoreComponent roi;
  final ScoreComponent momentum;
  final int finalScore;
  final String recommendation;
  final List<String> allDataSources;
  final List<String> missingData;
  final int confidence;

  const ScoreBreakdown({
    required this.projectId,
    required this.projectName,
    required this.opportunity,
    required this.strategicFit,
    required this.synergy,
    required this.roi,
    required this.momentum,
    required this.finalScore,
    required this.recommendation,
    required this.allDataSources,
    required this.missingData,
    required this.confidence,
  });

  String get weightedFormula =>
      'Ecosystem = Opp×25% + Fit×25% + Sin×20% + ROI×20% + Mom×10%\n'
      '= ${opportunity.rawValue}×0.25 + ${strategicFit.rawValue}×0.25'
      ' + ${synergy.rawValue}×0.20 + ${roi.rawValue}×0.20'
      ' + ${momentum.rawValue}×0.10\n'
      '= ${opportunity.weightedContribution}'
      ' + ${strategicFit.weightedContribution}'
      ' + ${synergy.weightedContribution}'
      ' + ${roi.weightedContribution}'
      ' + ${momentum.weightedContribution}\n'
      '= $finalScore';

  bool get isDataSufficient => missingData.length <= 2;
}
