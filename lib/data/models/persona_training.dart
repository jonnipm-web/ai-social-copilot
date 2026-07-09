class PersonaTraining {
  final String id;
  final String userId;
  final String personaId;
  final String? knowledgeItemId;
  final String? trainingSummary;
  final Map<String, dynamic> toneProfileJson;
  final List<String> vocabularyJson;
  final List<String> brandValuesJson;
  final Map<String, dynamic> positioningJson;
  final Map<String, dynamic> audienceJson;
  final List<String> examplesJson;
  final DateTime createdAt;

  const PersonaTraining({
    required this.id,
    required this.userId,
    required this.personaId,
    this.knowledgeItemId,
    this.trainingSummary,
    this.toneProfileJson = const {},
    this.vocabularyJson = const [],
    this.brandValuesJson = const [],
    this.positioningJson = const {},
    this.audienceJson = const {},
    this.examplesJson = const [],
    required this.createdAt,
  });

  String get tone => toneProfileJson['tone'] as String? ?? '';
  String get style => toneProfileJson['communication_style'] as String? ?? '';

  factory PersonaTraining.fromMap(Map<String, dynamic> map) {
    List<String> toList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }
    Map<String, dynamic> toMap(dynamic v) {
      if (v == null) return {};
      if (v is Map) return Map<String, dynamic>.from(v);
      return {};
    }

    return PersonaTraining(
      id:               map['id'] as String,
      userId:           map['user_id'] as String,
      personaId:        map['persona_id'] as String,
      knowledgeItemId:  map['knowledge_item_id'] as String?,
      trainingSummary:  map['training_summary'] as String?,
      toneProfileJson:  toMap(map['tone_profile_json']),
      vocabularyJson:   toList(map['vocabulary_json']),
      brandValuesJson:  toList(map['brand_values_json']),
      positioningJson:  toMap(map['positioning_json']),
      audienceJson:     toMap(map['audience_json']),
      examplesJson:     toList(map['examples_json']),
      createdAt:        DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':            userId,
    'persona_id':         personaId,
    'knowledge_item_id':  knowledgeItemId,
    'training_summary':   trainingSummary,
    'tone_profile_json':  toneProfileJson,
    'vocabulary_json':    vocabularyJson,
    'brand_values_json':  brandValuesJson,
    'positioning_json':   positioningJson,
    'audience_json':      audienceJson,
    'examples_json':      examplesJson,
  };
}
