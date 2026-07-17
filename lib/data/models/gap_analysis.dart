import '../../core/utils/date_parser.dart';

class GapAnalysis {
  final String id;
  final String userId;
  final String? marketAnalysisId;
  final List<String> contentGaps;
  final List<String> seoGaps;
  final List<String> authorityGaps;
  final List<String> monetizationGaps;
  final List<String> productGaps;
  final Map<String, dynamic> analysisJson;
  final DateTime createdAt;

  const GapAnalysis({
    required this.id,
    required this.userId,
    this.marketAnalysisId,
    this.contentGaps = const [],
    this.seoGaps = const [],
    this.authorityGaps = const [],
    this.monetizationGaps = const [],
    this.productGaps = const [],
    this.analysisJson = const {},
    required this.createdAt,
  });

  int get totalGaps =>
      contentGaps.length +
      seoGaps.length +
      authorityGaps.length +
      monetizationGaps.length +
      productGaps.length;

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory GapAnalysis.fromMap(Map<String, dynamic> map) {
    return GapAnalysis(
      id:                 map['id'] as String,
      userId:             map['user_id'] as String,
      marketAnalysisId:   map['market_analysis_id'] as String?,
      contentGaps:        _list(map['content_gaps']),
      seoGaps:            _list(map['seo_gaps']),
      authorityGaps:      _list(map['authority_gaps']),
      monetizationGaps:   _list(map['monetization_gaps']),
      productGaps:        _list(map['product_gaps']),
      analysisJson:       map['analysis_json'] is Map
          ? Map<String, dynamic>.from(map['analysis_json'] as Map)
          : {},
      createdAt: DateParser.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'market_analysis_id': marketAnalysisId,
    'content_gaps':       contentGaps,
    'seo_gaps':           seoGaps,
    'authority_gaps':     authorityGaps,
    'monetization_gaps':  monetizationGaps,
    'product_gaps':       productGaps,
    'analysis_json':      analysisJson,
  };
}
