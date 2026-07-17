import '../../core/utils/date_parser.dart';

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
  final String? campaignId;
  final String? publicationUrl;
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final String? externalPlatform;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const statuses = [
    'ideia', 'planejado', 'gerado', 'aprovado', 'pronto_publicar', 'publicado', 'falha_publicacao', 'arquivado'
  ];

  static const statusLabels = {
    'ideia':            'Ideia',
    'planejado':        'Planejado',
    'gerado':           'Gerado',
    'aprovado':         'Aprovado',
    'pronto_publicar':  'Pronto p/ Publicar',
    'publicado':        'Publicado',
    'falha_publicacao': 'Falha na Publicação',
    'arquivado':        'Arquivado',
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
    this.campaignId,
    this.publicationUrl,
    this.scheduledAt,
    this.publishedAt,
    this.externalPlatform,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarItem.fromMap(Map<String, dynamic> map) {
    return CalendarItem(
      id:               map['id'] as String,
      userId:           map['user_id'] as String,
      personaId:        map['persona_id'] as String?,
      contentItemId:    map['content_item_id'] as String?,
      suggestedDate:    DateParser.parseOrNull(map['suggested_date']),
      platform:         map['platform'] as String?,
      theme:            map['theme'] as String?,
      format:           map['format'] as String?,
      objective:        map['objective'] as String?,
      cta:              map['cta'] as String?,
      status:           map['status'] as String? ?? 'ideia',
      generatedContent: map['generated_content'] as String?,
      campaignId:       map['campaign_id'] as String?,
      publicationUrl:   map['publication_url'] as String?,
      scheduledAt:      DateParser.parseOrNull(map['scheduled_at']),
      publishedAt:      DateParser.parseOrNull(map['published_at']),
      externalPlatform: map['external_platform'] as String?,
      createdAt:        DateParser.parse(map['created_at']),
      updatedAt:        DateParser.parse(map['updated_at']),
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
    'campaign_id':       campaignId,
    'publication_url':   publicationUrl,
    'scheduled_at':      scheduledAt?.toUtc().toIso8601String(),
    'published_at':      publishedAt?.toUtc().toIso8601String(),
    'external_platform': externalPlatform,
  };

  CalendarItem copyWith({
    String? status,
    String? generatedContent,
    String? campaignId,
    String? publicationUrl,
    DateTime? scheduledAt,
    DateTime? publishedAt,
    String? externalPlatform,
  }) =>
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
        campaignId:       campaignId ?? this.campaignId,
        publicationUrl:   publicationUrl ?? this.publicationUrl,
        scheduledAt:      scheduledAt ?? this.scheduledAt,
        publishedAt:      publishedAt ?? this.publishedAt,
        externalPlatform: externalPlatform ?? this.externalPlatform,
        createdAt:        createdAt,
        updatedAt:        DateTime.now(),
      );
}
