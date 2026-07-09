class MarketAnalysis {
  final String id;
  final String userId;
  final String input;
  final String inputType;
  final String? niche;
  final String? subNiche;
  final String? targetAudience;
  final String? businessType;
  final String? valueProposition;
  final String? positioning;
  final String? monetizationModel;
  final int opportunityScore;
  final String status;
  final Map<String, dynamic> analysisJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MarketAnalysis({
    required this.id,
    required this.userId,
    required this.input,
    this.inputType = 'url',
    this.niche,
    this.subNiche,
    this.targetAudience,
    this.businessType,
    this.valueProposition,
    this.positioning,
    this.monetizationModel,
    this.opportunityScore = 0,
    this.status = 'pending',
    this.analysisJson = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get recommendations => _list(analysisJson['recommendations']);
  List<String> get strengths => _list(analysisJson['strengths']);
  List<String> get weaknesses => _list(analysisJson['weaknesses']);
  List<String> get marketTrends => _list(analysisJson['market_trends']);
  String get executiveSummary => analysisJson['executive_summary'] as String? ?? '';
  String get competitiveLandscape => analysisJson['competitive_landscape'] as String? ?? '';

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory MarketAnalysis.fromMap(Map<String, dynamic> map) {
    return MarketAnalysis(
      id:                 map['id'] as String,
      userId:             map['user_id'] as String,
      input:              map['input'] as String,
      inputType:          map['input_type'] as String? ?? 'url',
      niche:              map['niche'] as String?,
      subNiche:           map['sub_niche'] as String?,
      targetAudience:     map['target_audience'] as String?,
      businessType:       map['business_type'] as String?,
      valueProposition:   map['value_proposition'] as String?,
      positioning:        map['positioning'] as String?,
      monetizationModel:  map['monetization_model'] as String?,
      opportunityScore:   map['opportunity_score'] as int? ?? 0,
      status:             map['status'] as String? ?? 'pending',
      analysisJson:       map['analysis_json'] is Map
          ? Map<String, dynamic>.from(map['analysis_json'] as Map)
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'input':              input,
    'input_type':         inputType,
    'niche':              niche,
    'sub_niche':          subNiche,
    'target_audience':    targetAudience,
    'business_type':      businessType,
    'value_proposition':  valueProposition,
    'positioning':        positioning,
    'monetization_model': monetizationModel,
    'opportunity_score':  opportunityScore,
    'status':             status,
    'analysis_json':      analysisJson,
  };
}
