import '../../core/utils/date_parser.dart';

class Opportunity {
  final String id;
  final String userId;
  final String? marketAnalysisId;
  final String title;
  final String type;
  final String description;
  final int opportunityScore;
  final int marketScore;
  final int growthScore;
  final int competitionScore;
  final int monetizationScore;
  final int difficultyScore;
  final Map<String, dynamic> detailsJson;
  final DateTime createdAt;

  const Opportunity({
    required this.id,
    required this.userId,
    this.marketAnalysisId,
    required this.title,
    this.type = 'content',
    this.description = '',
    this.opportunityScore = 0,
    this.marketScore = 0,
    this.growthScore = 0,
    this.competitionScore = 0,
    this.monetizationScore = 0,
    this.difficultyScore = 0,
    this.detailsJson = const {},
    required this.createdAt,
  });

  List<String> get actionSteps => _list(detailsJson['action_steps']);
  List<String> get risks => _list(detailsJson['risks']);
  String get timeframe => detailsJson['timeframe'] as String? ?? '';
  String get effort => detailsJson['effort'] as String? ?? '';

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory Opportunity.fromMap(Map<String, dynamic> map) {
    return Opportunity(
      id:                 map['id'] as String,
      userId:             map['user_id'] as String,
      marketAnalysisId:   map['market_analysis_id'] as String?,
      title:              map['title'] as String,
      type:               map['type'] as String? ?? 'content',
      description:        map['description'] as String? ?? '',
      opportunityScore:   map['opportunity_score'] as int? ?? 0,
      marketScore:        map['market_score'] as int? ?? 0,
      growthScore:        map['growth_score'] as int? ?? 0,
      competitionScore:   map['competition_score'] as int? ?? 0,
      monetizationScore:  map['monetization_score'] as int? ?? 0,
      difficultyScore:    map['difficulty_score'] as int? ?? 0,
      detailsJson:        map['details_json'] is Map
          ? Map<String, dynamic>.from(map['details_json'] as Map)
          : {},
      createdAt: DateParser.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'market_analysis_id': marketAnalysisId,
    'title':              title,
    'type':               type,
    'description':        description,
    'opportunity_score':  opportunityScore,
    'market_score':       marketScore,
    'growth_score':       growthScore,
    'competition_score':  competitionScore,
    'monetization_score': monetizationScore,
    'difficulty_score':   difficultyScore,
    'details_json':       detailsJson,
  };
}
