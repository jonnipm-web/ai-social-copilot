class NicheRanking {
  final String id;
  final String userId;
  final String? marketAnalysisId;
  final String name;
  final String level;
  final String description;
  final int competitionScore;
  final int potentialScore;
  final int growthScore;
  final int monetizationScore;
  final int difficultyScore;
  final int trendScore;
  final int overallScore;
  final Map<String, dynamic> detailsJson;
  final DateTime createdAt;

  const NicheRanking({
    required this.id,
    required this.userId,
    this.marketAnalysisId,
    required this.name,
    this.level = 'niche',
    this.description = '',
    this.competitionScore = 0,
    this.potentialScore = 0,
    this.growthScore = 0,
    this.monetizationScore = 0,
    this.difficultyScore = 0,
    this.trendScore = 0,
    this.overallScore = 0,
    this.detailsJson = const {},
    required this.createdAt,
  });

  List<String> get keywords => _list(detailsJson['keywords']);
  List<String> get monetizationMethods => _list(detailsJson['monetization_methods']);
  String get why => detailsJson['why'] as String? ?? '';

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory NicheRanking.fromMap(Map<String, dynamic> map) {
    return NicheRanking(
      id:                 map['id'] as String,
      userId:             map['user_id'] as String,
      marketAnalysisId:   map['market_analysis_id'] as String?,
      name:               map['name'] as String,
      level:              map['level'] as String? ?? 'niche',
      description:        map['description'] as String? ?? '',
      competitionScore:   map['competition_score'] as int? ?? 0,
      potentialScore:     map['potential_score'] as int? ?? 0,
      growthScore:        map['growth_score'] as int? ?? 0,
      monetizationScore:  map['monetization_score'] as int? ?? 0,
      difficultyScore:    map['difficulty_score'] as int? ?? 0,
      trendScore:         map['trend_score'] as int? ?? 0,
      overallScore:       map['overall_score'] as int? ?? 0,
      detailsJson:        map['details_json'] is Map
          ? Map<String, dynamic>.from(map['details_json'] as Map)
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'market_analysis_id': marketAnalysisId,
    'name':               name,
    'level':              level,
    'description':        description,
    'competition_score':  competitionScore,
    'potential_score':    potentialScore,
    'growth_score':       growthScore,
    'monetization_score': monetizationScore,
    'difficulty_score':   difficultyScore,
    'trend_score':        trendScore,
    'overall_score':      overallScore,
    'details_json':       detailsJson,
  };
}
