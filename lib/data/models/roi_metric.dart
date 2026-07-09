class RoiMetric {
  final String id;
  final String userId;
  final String? projectId;
  final String metricType;
  final double metricValue;
  final String? notes;
  final DateTime createdAt;

  const RoiMetric({
    required this.id,
    required this.userId,
    this.projectId,
    required this.metricType,
    this.metricValue = 0,
    this.notes,
    required this.createdAt,
  });

  factory RoiMetric.fromMap(Map<String, dynamic> map) {
    double _d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return RoiMetric(
      id:          map['id'] as String,
      userId:      map['user_id'] as String,
      projectId:   map['project_id'] as String?,
      metricType:  map['metric_type'] as String,
      metricValue: _d(map['metric_value']),
      notes:       map['notes'] as String?,
      createdAt:   DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':      userId,
    'project_id':   projectId,
    'metric_type':  metricType,
    'metric_value': metricValue,
    'notes':        notes,
  };
}
