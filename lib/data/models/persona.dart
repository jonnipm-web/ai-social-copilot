class Persona {
  final String id;
  final String? ownerId;
  final bool isGlobal;
  final String name;
  final String? description;
  final String? voiceTone;
  final String? targetAudience;
  final String? niche;
  final String? objectives;
  final String mainLanguage;
  final String? brandColors;
  final List<String> wordsToUse;
  final List<String> wordsToAvoid;
  final List<String> preferredContentTypes;
  final String? ctaStyle;
  final String? communicationExamples;
  final String? specificRules;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Persona({
    required this.id,
    this.ownerId,
    required this.isGlobal,
    required this.name,
    this.description,
    this.voiceTone,
    this.targetAudience,
    this.niche,
    this.objectives,
    this.mainLanguage = 'pt-BR',
    this.brandColors,
    this.wordsToUse = const [],
    this.wordsToAvoid = const [],
    this.preferredContentTypes = const [],
    this.ctaStyle,
    this.communicationExamples,
    this.specificRules,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Persona.fromMap(Map<String, dynamic> map) {
    List<String> _list(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return Persona(
      id:                     map['id'] as String,
      ownerId:                map['owner_id'] as String?,
      isGlobal:               map['is_global'] as bool? ?? false,
      name:                   map['name'] as String,
      description:            map['description'] as String?,
      voiceTone:              map['voice_tone'] as String?,
      targetAudience:         map['target_audience'] as String?,
      niche:                  map['niche'] as String?,
      objectives:             map['objectives'] as String?,
      mainLanguage:           map['main_language'] as String? ?? 'pt-BR',
      brandColors:            map['brand_colors'] as String?,
      wordsToUse:             _list(map['words_to_use']),
      wordsToAvoid:           _list(map['words_to_avoid']),
      preferredContentTypes:  _list(map['preferred_content_types']),
      ctaStyle:               map['cta_style'] as String?,
      communicationExamples:  map['communication_examples'] as String?,
      specificRules:          map['specific_rules'] as String?,
      isActive:               map['is_active'] as bool? ?? true,
      createdAt:              DateTime.parse(map['created_at'] as String),
      updatedAt:              DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'owner_id':               ownerId,
    'is_global':              isGlobal,
    'name':                   name,
    'description':            description,
    'voice_tone':             voiceTone,
    'target_audience':        targetAudience,
    'niche':                  niche,
    'objectives':             objectives,
    'main_language':          mainLanguage,
    'brand_colors':           brandColors,
    'words_to_use':           wordsToUse,
    'words_to_avoid':         wordsToAvoid,
    'preferred_content_types': preferredContentTypes,
    'cta_style':              ctaStyle,
    'communication_examples': communicationExamples,
    'specific_rules':         specificRules,
    'is_active':              isActive,
  };
}
