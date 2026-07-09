class ContentCluster {
  final String id;
  final String userId;
  final String? marketAnalysisId;
  final String mainKeyword;
  final List<Map<String, dynamic>> clusters;
  final List<Map<String, dynamic>> silos;
  final List<Map<String, dynamic>> articles;
  final List<Map<String, dynamic>> editorialRoadmap;
  final Map<String, dynamic> seoStructure;
  final DateTime createdAt;

  const ContentCluster({
    required this.id,
    required this.userId,
    this.marketAnalysisId,
    required this.mainKeyword,
    this.clusters = const [],
    this.silos = const [],
    this.articles = const [],
    this.editorialRoadmap = const [],
    this.seoStructure = const {},
    required this.createdAt,
  });

  static List<Map<String, dynamic>> _mapList(dynamic v) {
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  factory ContentCluster.fromMap(Map<String, dynamic> map) {
    return ContentCluster(
      id:                 map['id'] as String,
      userId:             map['user_id'] as String,
      marketAnalysisId:   map['market_analysis_id'] as String?,
      mainKeyword:        map['main_keyword'] as String,
      clusters:           _mapList(map['clusters']),
      silos:              _mapList(map['silos']),
      articles:           _mapList(map['articles']),
      editorialRoadmap:   _mapList(map['editorial_roadmap']),
      seoStructure:       map['seo_structure'] is Map
          ? Map<String, dynamic>.from(map['seo_structure'] as Map)
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'market_analysis_id': marketAnalysisId,
    'main_keyword':       mainKeyword,
    'clusters':           clusters,
    'silos':              silos,
    'articles':           articles,
    'editorial_roadmap':  editorialRoadmap,
    'seo_structure':      seoStructure,
  };
}
