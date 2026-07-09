class WebsiteAnalysis {
  final String id;
  final String userId;
  final String? knowledgeItemId;
  final String url;
  final String? title;
  final String? description;
  final int scoreWebsite;
  final int scoreAdsense;
  final int scoreSeo;
  final int scoreMonetization;
  final Map<String, dynamic> analysisJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WebsiteAnalysis({
    required this.id,
    required this.userId,
    this.knowledgeItemId,
    required this.url,
    this.title,
    this.description,
    this.scoreWebsite = 0,
    this.scoreAdsense = 0,
    this.scoreSeo = 0,
    this.scoreMonetization = 0,
    this.analysisJson = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get strengths => _list(analysisJson['strengths']);
  List<String> get weaknesses => _list(analysisJson['weaknesses']);
  List<String> get criticalIssues => _list(analysisJson['critical_issues']);
  List<String> get quickWins => _list(analysisJson['quick_wins']);
  List<String> get plan7Days => _list(analysisJson['plan_7_days']);
  List<String> get plan30Days => _list(analysisJson['plan_30_days']);
  List<String> get articleIdeas => _list(analysisJson['article_ideas']);
  List<String> get contentIdeas => _list(analysisJson['content_ideas']);
  List<String> get commercialOpportunities => _list(analysisJson['commercial_opportunities']);
  List<String> get monetizationOpportunities => _list(analysisJson['monetization_opportunities']);
  Map<String, dynamic> get seoAnalysis => _map(analysisJson['seo_analysis']);
  Map<String, dynamic> get adsenseAnalysis => _map(analysisJson['adsense_analysis']);
  Map<String, dynamic> get monetizationPlan => _map(analysisJson['monetization_plan']);
  Map<String, dynamic> get personaTraining => _map(analysisJson['persona_training']);

  static List<String> _list(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static Map<String, dynamic> _map(dynamic v) {
    if (v == null) return {};
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  factory WebsiteAnalysis.fromMap(Map<String, dynamic> map) {
    return WebsiteAnalysis(
      id:                map['id'] as String,
      userId:            map['user_id'] as String,
      knowledgeItemId:   map['knowledge_item_id'] as String?,
      url:               map['url'] as String,
      title:             map['title'] as String?,
      description:       map['description'] as String?,
      scoreWebsite:      map['score_website'] as int? ?? 0,
      scoreAdsense:      map['score_adsense'] as int? ?? 0,
      scoreSeo:          map['score_seo'] as int? ?? 0,
      scoreMonetization: map['score_monetization'] as int? ?? 0,
      analysisJson:      map['analysis_json'] is Map
          ? Map<String, dynamic>.from(map['analysis_json'] as Map)
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'knowledge_item_id':  knowledgeItemId,
    'url':                url,
    'title':              title,
    'description':        description,
    'score_website':      scoreWebsite,
    'score_adsense':      scoreAdsense,
    'score_seo':          scoreSeo,
    'score_monetization': scoreMonetization,
    'analysis_json':      analysisJson,
  };
}
