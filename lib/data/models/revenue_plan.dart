class RevenuePlan {
  final String id;
  final String userId;
  final String? marketAnalysisId;
  final String projectName;
  final double monthlyConservative;
  final double monthlyModerate;
  final double monthlyAggressive;
  final double annualConservative;
  final double annualModerate;
  final double annualAggressive;
  final Map<String, dynamic> planJson;
  final DateTime createdAt;

  const RevenuePlan({
    required this.id,
    required this.userId,
    this.marketAnalysisId,
    required this.projectName,
    this.monthlyConservative = 0,
    this.monthlyModerate = 0,
    this.monthlyAggressive = 0,
    this.annualConservative = 0,
    this.annualModerate = 0,
    this.annualAggressive = 0,
    this.planJson = const {},
    required this.createdAt,
  });

  List<Map<String, dynamic>> get revenueSources {
    final v = planJson['revenue_sources'];
    if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get milestones {
    final v = planJson['milestones'];
    if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<String> get assumptions {
    final v = planJson['assumptions'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory RevenuePlan.fromMap(Map<String, dynamic> map) {
    double _d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return RevenuePlan(
      id:                   map['id'] as String,
      userId:               map['user_id'] as String,
      marketAnalysisId:     map['market_analysis_id'] as String?,
      projectName:          map['project_name'] as String,
      monthlyConservative:  _d(map['monthly_conservative']),
      monthlyModerate:      _d(map['monthly_moderate']),
      monthlyAggressive:    _d(map['monthly_aggressive']),
      annualConservative:   _d(map['annual_conservative']),
      annualModerate:       _d(map['annual_moderate']),
      annualAggressive:     _d(map['annual_aggressive']),
      planJson:             map['plan_json'] is Map
          ? Map<String, dynamic>.from(map['plan_json'] as Map)
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':              userId,
    'market_analysis_id':   marketAnalysisId,
    'project_name':         projectName,
    'monthly_conservative': monthlyConservative,
    'monthly_moderate':     monthlyModerate,
    'monthly_aggressive':   monthlyAggressive,
    'annual_conservative':  annualConservative,
    'annual_moderate':      annualModerate,
    'annual_aggressive':    annualAggressive,
    'plan_json':            planJson,
  };
}
