class Persona {
  final String id;
  final String userId;
  final String brandId;
  final String name;
  final String description;
  final String audienceProfile;
  final List<String> painPoints;
  final List<String> desires;
  final List<String> objections;
  final String communicationStyle;
  final List<String> preferredHooks;
  final List<String> avoidedLanguage;
  final String personaPrompt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Persona({
    required this.id,
    required this.userId,
    required this.brandId,
    required this.name,
    required this.description,
    required this.audienceProfile,
    required this.painPoints,
    required this.desires,
    required this.objections,
    required this.communicationStyle,
    required this.preferredHooks,
    required this.avoidedLanguage,
    required this.personaPrompt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  factory Persona.fromMap(Map<String, dynamic> m) => Persona(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        brandId: m['brand_id'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        audienceProfile: m['audience_profile'] as String? ?? '',
        painPoints: _toList(m['pain_points']),
        desires: _toList(m['desires']),
        objections: _toList(m['objections']),
        communicationStyle: m['communication_style'] as String? ?? '',
        preferredHooks: _toList(m['preferred_hooks']),
        avoidedLanguage: _toList(m['avoided_language']),
        personaPrompt: m['persona_prompt'] as String? ?? '',
        status: m['status'] as String? ?? 'active',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'brand_id': brandId,
        'name': name,
        'description': description,
        'audience_profile': audienceProfile,
        'pain_points': painPoints,
        'desires': desires,
        'objections': objections,
        'communication_style': communicationStyle,
        'preferred_hooks': preferredHooks,
        'avoided_language': avoidedLanguage,
        'persona_prompt': personaPrompt,
        'status': status,
      };

  static List<String> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.cast<String>();
    return [];
  }
}
