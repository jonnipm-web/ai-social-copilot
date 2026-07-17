import '../../core/utils/date_parser.dart';

class KnowledgeAnalysis {
  final String id;
  final String knowledgeItemId;
  final String userId;
  final String? summary;
  final List<String> keywordsPrimary;
  final List<String> keywordsSecondary;
  final List<String> keywordsLongtail;
  final List<String> entities;
  final List<String> topics;
  final List<String> contentPillars;
  final List<String> audiencePainPoints;
  final List<String> audienceDesires;
  final List<String> commercialAngles;
  final List<String> ctas;
  final List<String> campaignIdeas;
  final List<String> postIdeas;
  final List<String> articleIdeas;
  final List<String> seoOpportunities;
  final List<String> adsenseOpportunities;
  final List<String> amazonKdpOpportunities;
  final int scoreSeo;
  final int scoreAdsense;
  final int scoreAmazonKdp;
  final int scoreLinkedin;
  final int scoreSocial;
  final int scoreOpportunity;
  final int scoreHotmart;
  final int scoreShopify;
  final Map<String, dynamic> scoreDetails;
  final Map<String, dynamic> hotmartData;
  final Map<String, dynamic> shopifyData;
  final Map<String, dynamic> personaTraining;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? projectId;

  const KnowledgeAnalysis({
    required this.id,
    required this.knowledgeItemId,
    required this.userId,
    this.projectId,
    this.summary,
    this.keywordsPrimary      = const [],
    this.keywordsSecondary    = const [],
    this.keywordsLongtail     = const [],
    this.entities             = const [],
    this.topics               = const [],
    this.contentPillars       = const [],
    this.audiencePainPoints   = const [],
    this.audienceDesires      = const [],
    this.commercialAngles     = const [],
    this.ctas                 = const [],
    this.campaignIdeas        = const [],
    this.postIdeas            = const [],
    this.articleIdeas         = const [],
    this.seoOpportunities     = const [],
    this.adsenseOpportunities = const [],
    this.amazonKdpOpportunities = const [],
    this.scoreSeo             = 0,
    this.scoreAdsense         = 0,
    this.scoreAmazonKdp       = 0,
    this.scoreLinkedin        = 0,
    this.scoreSocial          = 0,
    this.scoreOpportunity     = 0,
    this.scoreHotmart         = 0,
    this.scoreShopify         = 0,
    this.scoreDetails         = const {},
    this.hotmartData          = const {},
    this.shopifyData          = const {},
    this.personaTraining      = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  factory KnowledgeAnalysis.fromMap(Map<String, dynamic> map) {
    return KnowledgeAnalysis(
      id:                       map['id'] as String,
      knowledgeItemId:          map['knowledge_item_id'] as String,
      userId:                   map['user_id'] as String,
      projectId:                map['project_id'] as String?,
      summary:                  map['summary'] as String?,
      keywordsPrimary:          _parseList(map['keywords_primary']),
      keywordsSecondary:        _parseList(map['keywords_secondary']),
      keywordsLongtail:         _parseList(map['keywords_longtail']),
      entities:                 _parseList(map['entities']),
      topics:                   _parseList(map['topics']),
      contentPillars:           _parseList(map['content_pillars']),
      audiencePainPoints:       _parseList(map['audience_pain_points']),
      audienceDesires:          _parseList(map['audience_desires']),
      commercialAngles:         _parseList(map['commercial_angles']),
      ctas:                     _parseList(map['ctas']),
      campaignIdeas:            _parseList(map['campaign_ideas']),
      postIdeas:                _parseList(map['post_ideas']),
      articleIdeas:             _parseList(map['article_ideas']),
      seoOpportunities:         _parseList(map['seo_opportunities']),
      adsenseOpportunities:     _parseList(map['adsense_opportunities']),
      amazonKdpOpportunities:   _parseList(map['amazon_kdp_opportunities']),
      scoreSeo:                 (map['score_seo'] as int?) ?? 0,
      scoreAdsense:             (map['score_adsense'] as int?) ?? 0,
      scoreAmazonKdp:           (map['score_amazon_kdp'] as int?) ?? 0,
      scoreLinkedin:            (map['score_linkedin'] as int?) ?? 0,
      scoreSocial:              (map['score_social'] as int?) ?? 0,
      scoreOpportunity:         (map['score_opportunity'] as int?) ?? 0,
      scoreHotmart:             (map['score_hotmart'] as int?) ?? 0,
      scoreShopify:             (map['score_shopify'] as int?) ?? 0,
      scoreDetails:             _parseMap(map['score_details']),
      hotmartData:              _parseMap(map['hotmart_data']),
      shopifyData:              _parseMap(map['shopify_data']),
      personaTraining:          _parseMap(map['persona_training']),
      createdAt:                DateParser.parse(map['created_at']),
      updatedAt:                DateParser.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'knowledge_item_id':      knowledgeItemId,
    'user_id':                userId,
    if (projectId != null) 'project_id': projectId,
    'summary':                summary,
    'keywords_primary':       keywordsPrimary,
    'keywords_secondary':     keywordsSecondary,
    'keywords_longtail':      keywordsLongtail,
    'entities':               entities,
    'topics':                 topics,
    'content_pillars':        contentPillars,
    'audience_pain_points':   audiencePainPoints,
    'audience_desires':       audienceDesires,
    'commercial_angles':      commercialAngles,
    'ctas':                   ctas,
    'campaign_ideas':         campaignIdeas,
    'post_ideas':             postIdeas,
    'article_ideas':          articleIdeas,
    'seo_opportunities':      seoOpportunities,
    'adsense_opportunities':  adsenseOpportunities,
    'amazon_kdp_opportunities': amazonKdpOpportunities,
    'score_seo':              scoreSeo,
    'score_adsense':          scoreAdsense,
    'score_amazon_kdp':       scoreAmazonKdp,
    'score_linkedin':         scoreLinkedin,
    'score_social':           scoreSocial,
    'score_opportunity':      scoreOpportunity,
    'score_hotmart':          scoreHotmart,
    'score_shopify':          scoreShopify,
    'score_details':          scoreDetails,
    'hotmart_data':           hotmartData,
    'shopify_data':           shopifyData,
    'persona_training':       personaTraining,
  };
}
