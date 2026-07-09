class PerformanceMetrics {
  final String id;
  final String userId;
  final String? campaignId;
  final String? contentId;
  final String? knowledgeItemId;
  final String platform;
  final int impressions;
  final int clicks;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int leads;
  final int sales;
  final double revenue;
  final double ctr;
  final double engagementRate;
  final double conversionRate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const platforms = [
    'instagram', 'facebook', 'linkedin', 'youtube', 'tiktok',
    'twitter', 'email', 'google', 'blog', 'hotmart', 'shopify', 'amazon',
  ];

  const PerformanceMetrics({
    required this.id,
    required this.userId,
    this.campaignId,
    this.contentId,
    this.knowledgeItemId,
    required this.platform,
    this.impressions = 0,
    this.clicks = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.leads = 0,
    this.sales = 0,
    this.revenue = 0,
    this.ctr = 0,
    this.engagementRate = 0,
    this.conversionRate = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalInteractions => likes + comments + shares + saves;
  double get performanceScore {
    double score = 0;
    if (impressions > 0) score += (clicks / impressions * 100).clamp(0, 30);
    if (clicks > 0) score += (leads / clicks * 100).clamp(0, 30);
    score += engagementRate.clamp(0, 20);
    score += conversionRate.clamp(0, 20);
    return score.clamp(0, 100);
  }

  factory PerformanceMetrics.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return PerformanceMetrics(
      id:               map['id'] as String,
      userId:           map['user_id'] as String,
      campaignId:       map['campaign_id'] as String?,
      contentId:        map['content_id'] as String?,
      knowledgeItemId:  map['knowledge_item_id'] as String?,
      platform:         map['platform'] as String,
      impressions:      map['impressions'] as int? ?? 0,
      clicks:           map['clicks'] as int? ?? 0,
      likes:            map['likes'] as int? ?? 0,
      comments:         map['comments'] as int? ?? 0,
      shares:           map['shares'] as int? ?? 0,
      saves:            map['saves'] as int? ?? 0,
      leads:            map['leads'] as int? ?? 0,
      sales:            map['sales'] as int? ?? 0,
      revenue:          toDouble(map['revenue']),
      ctr:              toDouble(map['ctr']),
      engagementRate:   toDouble(map['engagement_rate']),
      conversionRate:   toDouble(map['conversion_rate']),
      notes:            map['notes'] as String?,
      createdAt:        DateTime.parse(map['created_at'] as String),
      updatedAt:        DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':           userId,
    'campaign_id':       campaignId,
    'content_id':        contentId,
    'knowledge_item_id': knowledgeItemId,
    'platform':          platform,
    'impressions':       impressions,
    'clicks':            clicks,
    'likes':             likes,
    'comments':          comments,
    'shares':            shares,
    'saves':             saves,
    'leads':             leads,
    'sales':             sales,
    'revenue':           revenue,
    'ctr':               ctr,
    'engagement_rate':   engagementRate,
    'conversion_rate':   conversionRate,
    'notes':             notes,
  };
}
