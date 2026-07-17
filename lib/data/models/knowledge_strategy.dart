import '../../core/utils/date_parser.dart';

class KnowledgeStrategy {
  final String id;
  final String knowledgeItemId;
  final String userId;
  final Map<String, dynamic> strategyJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnowledgeStrategy({
    required this.id,
    required this.knowledgeItemId,
    required this.userId,
    this.strategyJson = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory KnowledgeStrategy.fromMap(Map<String, dynamic> map) {
    return KnowledgeStrategy(
      id:               map['id'] as String,
      knowledgeItemId:  map['knowledge_item_id'] as String,
      userId:           map['user_id'] as String,
      strategyJson:     map['strategy_json'] is Map
          ? Map<String, dynamic>.from(map['strategy_json'] as Map)
          : {},
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'knowledge_item_id': knowledgeItemId,
    'user_id':           userId,
    'strategy_json':     strategyJson,
  };

  String get strategicSummary =>
      strategyJson['strategic_summary'] as String? ?? '';

  String get valueProposition =>
      strategyJson['value_proposition'] as String? ?? '';

  String get positioning =>
      strategyJson['positioning'] as String? ?? '';

  List<String> get quickWins {
    final v = strategyJson['quick_wins'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  List<String> get priorityKeywords {
    final v = strategyJson['priority_keywords'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  List<Map<String, dynamic>> get recommendedChannels {
    final v = strategyJson['recommended_channels'];
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Map<String, dynamic> get funnel {
    final v = strategyJson['funnel'];
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  Map<String, dynamic> get growthPlan {
    final v = strategyJson['growth_plan'];
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  List<Map<String, dynamic>> get commercialOpportunities {
    final v = strategyJson['commercial_opportunities'];
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}
