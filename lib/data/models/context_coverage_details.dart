enum CoverageDimensionStatus { sufficient, partial, missing }

class ContextCoverageDimension {
  final String id;
  final String label;
  final double score;
  final double weight;
  final CoverageDimensionStatus status;
  final List<String> fieldsPresent;
  final List<String> fieldsMissing;

  ContextCoverageDimension({
    required this.id,
    required this.label,
    required this.score,
    required this.weight,
    required this.status,
    this.fieldsPresent = const [],
    this.fieldsMissing = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'score': score,
        'weight': weight,
        'status': status.name,
        if (fieldsPresent.isNotEmpty) 'fields_present': fieldsPresent,
        if (fieldsMissing.isNotEmpty) 'fields_missing': fieldsMissing,
      };
}

class ContextCoverageDetails {
  static const String methodologyVersion = '2.0';

  final double overall;
  final List<ContextCoverageDimension> dimensions;
  final List<String> missingRequiredDimensions;
  final DateTime calculatedAt;

  ContextCoverageDetails({
    required this.overall,
    required this.dimensions,
    this.missingRequiredDimensions = const [],
    required this.calculatedAt,
  });

  factory ContextCoverageDetails.empty(DateTime at) => ContextCoverageDetails(
        overall: 0.0,
        dimensions: const [],
        calculatedAt: at,
      );

  ContextCoverageDimension? dimension(String id) {
    for (final d in dimensions) {
      if (d.id == id) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'methodology_version': methodologyVersion,
        'dimensions': dimensions.map((d) => d.toJson()).toList(),
        if (missingRequiredDimensions.isNotEmpty)
          'missing_required': missingRequiredDimensions,
        'calculated_at': calculatedAt.toIso8601String(),
      };
}
