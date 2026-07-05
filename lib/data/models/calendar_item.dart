class CalendarItem {
  final String id;
  final String userId;
  final String? personaId;
  final String? contentItemId;
  final DateTime? suggestedDate;
  final String? platform;
  final String? theme;
  final String? format;
  final String? objective;
  final String? cta;
  final String status;
  final String? generatedContent;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const statuses = [
    'ideia', 'planejado', 'gerado', 'aprovado', 'publicado', 'arquivado'
  ];

  static const statusLabels = {
    'ideia':     'Ideia',
    'planejado': 'Planejado',
    'gerado':    'Gerado',
    'aprovado':  'Aprovado',
    'publicado': 'Publicado',
    'arquivado': 'Arquivado',
  };

  static const platforms = [
    'instagram', 'facebook', 'linkedin', 'twitter', 'youtube', 'email',
  ];

  static const formats = [
    'post_curto', 'post_longo', 'carrossel', 'reels',
    'email', 'artigo', 'cta', 'thread',
  ];

  static const formatLabels = {
    'post_curto': 'Post Curto',
    'post_longo': 'Post Longo',
    'carrossel':  'Carrossel',
    'reels':      'Reels/Vídeo',
    'email':      'E-mail',
    'artigo':     'Artigo SEO',
    'cta':        'CTA de Venda',
    'thread':     'Thread/X',
  };

  const CalendarItem({
    required this.id,
    required this.userId,
    this.personaId,
    this.contentItemId,
    this.suggestedDate,
    this.platform,
    this.theme,
    this.format,
    this.objective,
    this.cta,
    this.status = 'ideia',
    this.generatedContent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarItem.fromMap(Map<String, dynamic> map) {
    return CalendarItem(
      id:               map['id'] as String,
      userId:           map['user_id'] as String,
      personaId:        map['persona_id'] as String?,
      contentItemId:    map['content_item_id'] as String?,
      suggestedDate:    map['suggested_date'] != null
          ? DateTime.parse(map['suggested_date'] as String)
          : null,
      platform:         map['platform'] as String?,
      theme:            map['theme'] as String?,
      format:           map['format'] as String?,
      objective:        map['objective'] as String?,
      cta:              map['cta'] as String?,
      status:           map['status'] as String? ?? 'ideia',
      generatedContent: map['generated_content'] as String?,
      createdAt:        DateTime.parse(map['created_at'] as String),
      updatedAt:        DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':           userId,
    'persona_id':        personaId,
    'content_item_id':   contentItemId,
    'suggested_date':    suggestedDate?.toIso8601String().substring(0, 10),
    'platform':          platform,
    'theme':             theme,
    'format':            format,
    'objective':         objective,
    'cta':               cta,
    'status':            status,
    'generated_content': generatedContent,
  };

  CalendarItem copyWith({String? status, String? generatedContent}) =>
      CalendarItem(
        id:               id,
        userId:           userId,
        personaId:        personaId,
        contentItemId:    contentItemId,
        suggestedDate:    suggestedDate,
        platform:         platform,
        theme:            theme,
        format:           format,
        objective:        objective,
        cta:              cta,
        status:           status ?? this.status,
        generatedContent: generatedContent ?? this.generatedContent,
        createdAt:        createdAt,
        updatedAt:        DateTime.now(),
      );
}
