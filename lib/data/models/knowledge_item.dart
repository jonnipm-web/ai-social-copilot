class KnowledgeItem {
  final String id;
  final String userId;
  final String? projectId;
  final String title;
  final String sourceType;
  final String? sourceUrl;
  final String? fileName;
  final String content;
  final String? niche;
  final String? targetAudience;
  final String language;
  final String? personaId;
  final String status;
  final int opportunityScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const sourceTypes = ['manual', 'url', 'file'];

  static const sourceTypeLabels = {
    'manual': 'Texto Manual',
    'url':    'URL / Site',
    'file':   'Arquivo',
  };

  static const statuses = ['pending', 'processing', 'analyzed', 'error'];

  static const statusLabels = {
    'pending':    'Pendente',
    'processing': 'Processando',
    'analyzed':   'Analisado',
    'error':      'Erro',
  };

  const KnowledgeItem({
    required this.id,
    required this.userId,
    this.projectId,
    required this.title,
    this.sourceType = 'manual',
    this.sourceUrl,
    this.fileName,
    this.content = '',
    this.niche,
    this.targetAudience,
    this.language = 'pt-BR',
    this.personaId,
    this.status = 'pending',
    this.opportunityScore = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  String get sourceTypeLabel => sourceTypeLabels[sourceType] ?? sourceType;
  String get statusLabel     => statusLabels[status]         ?? status;

  factory KnowledgeItem.fromMap(Map<String, dynamic> map) {
    return KnowledgeItem(
      id:             map['id'] as String,
      userId:         map['user_id'] as String,
      projectId:      map['project_id'] as String?,
      title:          map['title'] as String,
      sourceType:     map['source_type'] as String? ?? 'manual',
      sourceUrl:      map['source_url'] as String?,
      fileName:       map['file_name'] as String?,
      content:        map['content'] as String? ?? '',
      niche:          map['niche'] as String?,
      targetAudience: map['target_audience'] as String?,
      language:       map['language'] as String? ?? 'pt-BR',
      personaId:      map['persona_id'] as String?,
      status:         map['status'] as String? ?? 'pending',
      opportunityScore: map['opportunity_score'] as int? ?? 0,
      createdAt:      map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt:      map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':        userId,
    if (projectId != null) 'project_id': projectId,
    'title':          title,
    'source_type':    sourceType,
    'source_url':     sourceUrl,
    'file_name':      fileName,
    'content':        content,
    'niche':          niche,
    'target_audience': targetAudience,
    'language':       language,
    'persona_id':     personaId,
    'status':         status,
    'opportunity_score': opportunityScore,
  };

  KnowledgeItem copyWith({
    String? projectId,
    String? title,
    String? sourceType,
    String? sourceUrl,
    String? fileName,
    String? content,
    String? niche,
    String? targetAudience,
    String? language,
    String? personaId,
    String? status,
    int? opportunityScore,
  }) {
    return KnowledgeItem(
      id:             id,
      userId:         userId,
      projectId:      projectId      ?? this.projectId,
      title:          title          ?? this.title,
      sourceType:     sourceType     ?? this.sourceType,
      sourceUrl:      sourceUrl      ?? this.sourceUrl,
      fileName:       fileName       ?? this.fileName,
      content:        content        ?? this.content,
      niche:          niche          ?? this.niche,
      targetAudience: targetAudience ?? this.targetAudience,
      language:       language       ?? this.language,
      personaId:      personaId      ?? this.personaId,
      status:         status         ?? this.status,
      opportunityScore: opportunityScore ?? this.opportunityScore,
      createdAt:      createdAt,
      updatedAt:      DateTime.now(),
    );
  }
}
