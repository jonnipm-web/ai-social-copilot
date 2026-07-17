import '../../core/utils/date_parser.dart';

class Campaign {
  final String id;
  final String userId;
  final String? knowledgeItemId;
  final String title;
  final String objective;
  final int durationDays;
  final List<String> channels;
  final Map<String, dynamic> campaignJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Campaign({
    required this.id,
    required this.userId,
    this.knowledgeItemId,
    required this.title,
    required this.objective,
    required this.durationDays,
    this.channels    = const [],
    this.campaignJson = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Campaign.fromMap(Map<String, dynamic> map) {
    List<String> parseChannels(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return Campaign(
      id:               map['id'] as String,
      userId:           map['user_id'] as String,
      knowledgeItemId:  map['knowledge_item_id'] as String?,
      title:            map['title'] as String? ?? '',
      objective:        map['objective'] as String? ?? 'venda',
      durationDays:     (map['duration_days'] as int?) ?? 30,
      channels:         parseChannels(map['channels']),
      campaignJson:     map['campaign_json'] is Map
          ? Map<String, dynamic>.from(map['campaign_json'] as Map)
          : {},
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':           userId,
    'knowledge_item_id': knowledgeItemId,
    'title':             title,
    'objective':         objective,
    'duration_days':     durationDays,
    'channels':          channels,
    'campaign_json':     campaignJson,
  };

  String get tagline => campaignJson['tagline'] as String? ?? '';
  String get overview => campaignJson['overview'] as String? ?? '';

  List<Map<String, dynamic>> get calendar {
    final v = campaignJson['calendar'];
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  List<String> get keyMessages {
    final v = campaignJson['key_messages'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  List<String> get expectedResults {
    final v = campaignJson['expected_results'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}
