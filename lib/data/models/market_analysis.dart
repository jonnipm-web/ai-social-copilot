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

  // ── Getters básicos ──────────────────────────────────────────────────────
  List<String> get recommendations => _list(analysisJson['recommendations']);
  List<String> get strengths       => _list(analysisJson['strengths']);
  List<String> get weaknesses      => _list(analysisJson['weaknesses']);
  List<String> get marketTrends    => _list(analysisJson['market_trends']);
  String get executiveSummary      => analysisJson['executive_summary']      as String? ?? '';
  String get competitiveLandscape  => analysisJson['competitive_landscape']  as String? ?? '';

  // ── Getters Sprint 9.5 — Investment ──────────────────────────────────────
  String get investmentRecommendation {
    final v = analysisJson['investment_recommendation'] as String?;
    if (v != null) return v;
    if (opportunityScore >= 70) return 'SIM';
    if (opportunityScore >= 50) return 'CONDICIONAL';
    return 'NÃO';
  }

  int get investmentScore =>
      analysisJson['investment_score'] as int? ?? opportunityScore;

  String get investmentJustification =>
      analysisJson['investment_justification'] as String? ?? executiveSummary;

  // ── Getters Sprint 9.5 — Revenue ─────────────────────────────────────────
  double get revenueMonthlyMin  => _toDouble(analysisJson['revenue_monthly_min']);
  double get revenueMonthlyMax  => _toDouble(analysisJson['revenue_monthly_max']);
  int    get monthsToRevenue    => analysisJson['months_to_revenue']   as int? ?? 90;
  int    get revenueConfidence  => analysisJson['revenue_confidence']  as int? ?? 60;

  // ── Getters Sprint 9.5 — Score Breakdown ─────────────────────────────────
  int get scoreSeo          => analysisJson['score_seo']          as int? ?? (opportunityScore * 0.90).round().clamp(0, 100);
  int get scoreMonetization => analysisJson['score_monetization'] as int? ?? opportunityScore;
  int get scoreCompetition  => analysisJson['score_competition']  as int? ?? (opportunityScore * 0.85).round().clamp(0, 100);
  int get scoreGrowth       => analysisJson['score_growth']       as int? ?? (opportunityScore * 0.95).round().clamp(0, 100);

  // ── Getters Sprint 9.5 — Priority Actions ────────────────────────────────
  List<Map<String, dynamic>> get priorityActions {
    final raw = analysisJson['priority_actions'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    // Fallback: derive from recommendations with default impact/effort
    return recommendations.asMap().entries.map((e) => <String, dynamic>{
      'action':       e.value,
      'impact':       e.key == 0 ? 'Alto' : e.key <= 2 ? 'Médio' : 'Baixo',
      'effort':       'Médio',
      'roi_expected': 'A calcular',
      'priority':     e.key + 1,
    }).toList();
  }

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
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
