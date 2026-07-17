import '../../core/utils/date_parser.dart';

class Competitor {
  final String id;
  final String userId;
  final String? marketAnalysisId;
  final String name;
  final String url;
  final String type;
  final int similarityScore;
  final int authorityScore;
  final int relevanceScore;
  final Map<String, dynamic> detailsJson;
  final DateTime createdAt;

  const Competitor({
    required this.id,
    required this.userId,
    this.marketAnalysisId,
    required this.name,
    required this.url,
    this.type = 'direct',
    this.similarityScore = 0,
    this.authorityScore = 0,
    this.relevanceScore = 0,
    this.detailsJson = const {},
    required this.createdAt,
  });

  int get overallScore => ((similarityScore + authorityScore + relevanceScore) / 3).round();

  List<String> get strengths => _list(detailsJson['strengths']);
  List<String> get weaknesses => _list(detailsJson['weaknesses']);
  List<String> get opportunities => _list(detailsJson['opportunities']);
  String get description => detailsJson['description'] as String? ?? '';

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory Competitor.fromMap(Map<String, dynamic> map) {
    return Competitor(
      id:                 map['id'] as String,
      userId:             map['user_id'] as String,
      marketAnalysisId:   map['market_analysis_id'] as String?,
      name:               map['name'] as String,
      url:                map['url'] as String,
      type:               map['type'] as String? ?? 'direct',
      similarityScore:    map['similarity_score'] as int? ?? 0,
      authorityScore:     map['authority_score'] as int? ?? 0,
      relevanceScore:     map['relevance_score'] as int? ?? 0,
      detailsJson:        map['details_json'] is Map
          ? Map<String, dynamic>.from(map['details_json'] as Map)
          : {},
      createdAt: DateParser.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'market_analysis_id': marketAnalysisId,
    'name':               name,
    'url':                url,
    'type':               type,
    'similarity_score':   similarityScore,
    'authority_score':    authorityScore,
    'relevance_score':    relevanceScore,
    'details_json':       detailsJson,
  };
}
