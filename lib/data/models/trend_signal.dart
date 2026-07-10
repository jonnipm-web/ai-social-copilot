class TrendSignal {
  final String id;
  final String userId;
  final String source;
  final String keyword;
  final int trendScore;
  final double growthRate;
  final DateTime detectedAt;

  const TrendSignal({
    required this.id,
    required this.userId,
    required this.source,
    required this.keyword,
    this.trendScore = 0,
    this.growthRate = 0.0,
    required this.detectedAt,
  });

  factory TrendSignal.fromMap(Map<String, dynamic> map) => TrendSignal(
        id:         map['id'] as String,
        userId:     map['user_id'] as String,
        source:     map['source'] as String? ?? '',
        keyword:    map['keyword'] as String? ?? '',
        trendScore: map['trend_score'] as int? ?? 0,
        growthRate: _toDouble(map['growth_rate']),
        detectedAt: DateTime.parse(map['detected_at'] as String),
      );

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toInsertMap() => {
        'user_id':     userId,
        'source':      source,
        'keyword':     keyword,
        'trend_score': trendScore,
        'growth_rate': growthRate,
      };
}
