class SimulationResult {
  final String   analysis;
  final int      healthDelta;
  final int      executionDelta;
  final int      opportunityDelta;
  final double   roiEstimate;
  final String   riskLevel;
  final String   recommendation;
  final List<String> affectedProjects;
  final int      confidence;
  final int      timelineWeeks;

  const SimulationResult({
    required this.analysis,
    required this.healthDelta,
    required this.executionDelta,
    required this.opportunityDelta,
    required this.roiEstimate,
    required this.riskLevel,
    required this.recommendation,
    required this.affectedProjects,
    required this.confidence,
    required this.timelineWeeks,
  });

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      analysis:         json['analysis']          as String? ?? '',
      healthDelta:      (json['health_delta']      as num?)?.toInt()    ?? 0,
      executionDelta:   (json['execution_delta']   as num?)?.toInt()    ?? 0,
      opportunityDelta: (json['opportunity_delta'] as num?)?.toInt()    ?? 0,
      roiEstimate:      (json['roi_estimate']      as num?)?.toDouble() ?? 0.0,
      riskLevel:        json['risk_level']         as String? ?? 'médio',
      recommendation:   json['recommendation']     as String? ?? '',
      affectedProjects: (json['affected_projects'] as List<dynamic>?)
                            ?.cast<String>() ?? [],
      confidence:       (json['confidence']        as num?)?.toInt()    ?? 70,
      timelineWeeks:    (json['timeline_weeks']    as num?)?.toInt()    ?? 4,
    );
  }
}
