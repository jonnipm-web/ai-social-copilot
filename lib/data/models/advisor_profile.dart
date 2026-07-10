class AdvisorProfile {
  final String id;
  final String userId;
  final String advisorName;
  final String advisorRole;
  final String advisorStyle;
  final String advisorAvatar;
  final Map<String, dynamic> advisorPersonalityJson;
  final DateTime createdAt;

  const AdvisorProfile({
    required this.id,
    required this.userId,
    this.advisorName = 'Atlas',
    this.advisorRole = 'Geral',
    this.advisorStyle = 'Executivo',
    this.advisorAvatar = '',
    this.advisorPersonalityJson = const {},
    required this.createdAt,
  });

  static const List<String> nameOptions = [
    'Atlas',
    'Aurora',
    'Mentor',
    'Nexus',
  ];

  static const List<String> roleOptions = [
    'Estratégia',
    'Marketing',
    'SEO',
    'Monetização',
    'Negócios',
    'Geral',
  ];

  static const List<String> styleOptions = [
    'Executivo',
    'Analítico',
    'Professor',
    'Mentor',
    'Direto',
  ];

  factory AdvisorProfile.fromMap(Map<String, dynamic> map) => AdvisorProfile(
        id:                    map['id'] as String,
        userId:                map['user_id'] as String,
        advisorName:           map['advisor_name'] as String? ?? 'Atlas',
        advisorRole:           map['advisor_role'] as String? ?? 'Geral',
        advisorStyle:          map['advisor_style'] as String? ?? 'Executivo',
        advisorAvatar:         map['advisor_avatar'] as String? ?? '',
        advisorPersonalityJson: map['advisor_personality_json'] is Map
            ? Map<String, dynamic>.from(map['advisor_personality_json'] as Map)
            : {},
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id':                  userId,
        'advisor_name':             advisorName,
        'advisor_role':             advisorRole,
        'advisor_style':            advisorStyle,
        'advisor_avatar':           advisorAvatar,
        'advisor_personality_json': advisorPersonalityJson,
      };
}
