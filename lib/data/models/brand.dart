class Brand {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String niche;
  final String targetAudience;
  final String toneOfVoice;
  final String primaryLanguage;
  final List<String> platforms;
  final List<String> defaultCtas;
  final List<String> allowedTopics;
  final List<String> forbiddenTopics;
  final String writingStyle;
  final String brandPrompt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Brand({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.niche,
    required this.targetAudience,
    required this.toneOfVoice,
    required this.primaryLanguage,
    required this.platforms,
    required this.defaultCtas,
    required this.allowedTopics,
    required this.forbiddenTopics,
    required this.writingStyle,
    required this.brandPrompt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isArchived => status == 'archived';

  factory Brand.fromMap(Map<String, dynamic> m) => Brand(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        niche: m['niche'] as String? ?? '',
        targetAudience: m['target_audience'] as String? ?? '',
        toneOfVoice: m['tone_of_voice'] as String? ?? '',
        primaryLanguage: m['primary_language'] as String? ?? 'pt-BR',
        platforms: _toList(m['platforms']),
        defaultCtas: _toList(m['default_ctas']),
        allowedTopics: _toList(m['allowed_topics']),
        forbiddenTopics: _toList(m['forbidden_topics']),
        writingStyle: m['writing_style'] as String? ?? '',
        brandPrompt: m['brand_prompt'] as String? ?? '',
        status: m['status'] as String? ?? 'active',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'description': description,
        'niche': niche,
        'target_audience': targetAudience,
        'tone_of_voice': toneOfVoice,
        'primary_language': primaryLanguage,
        'platforms': platforms,
        'default_ctas': defaultCtas,
        'allowed_topics': allowedTopics,
        'forbidden_topics': forbiddenTopics,
        'writing_style': writingStyle,
        'brand_prompt': brandPrompt,
        'status': status,
      };

  Brand copyWith({
    String? name,
    String? description,
    String? niche,
    String? targetAudience,
    String? toneOfVoice,
    String? primaryLanguage,
    List<String>? platforms,
    List<String>? defaultCtas,
    List<String>? allowedTopics,
    List<String>? forbiddenTopics,
    String? writingStyle,
    String? brandPrompt,
    String? status,
  }) =>
      Brand(
        id: id,
        userId: userId,
        name: name ?? this.name,
        description: description ?? this.description,
        niche: niche ?? this.niche,
        targetAudience: targetAudience ?? this.targetAudience,
        toneOfVoice: toneOfVoice ?? this.toneOfVoice,
        primaryLanguage: primaryLanguage ?? this.primaryLanguage,
        platforms: platforms ?? this.platforms,
        defaultCtas: defaultCtas ?? this.defaultCtas,
        allowedTopics: allowedTopics ?? this.allowedTopics,
        forbiddenTopics: forbiddenTopics ?? this.forbiddenTopics,
        writingStyle: writingStyle ?? this.writingStyle,
        brandPrompt: brandPrompt ?? this.brandPrompt,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static List<String> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.cast<String>();
    return [];
  }
}
