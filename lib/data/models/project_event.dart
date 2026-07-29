enum ProjectEventType {
  projectCreated,
  stageChanged,
  analysisCompleted,
  decisionTaken,
  opportunityCreated,
  documentAdded,
  actionCompleted,
  checkIn,
  interviewCompleted,
  relationshipDetected,
  healthChanged,
  priorityChanged,
}

class ProjectEvent {
  final String id;
  final String projectId;
  final String userId;
  final ProjectEventType eventType;
  final String title;
  final String description;
  final Map<String, dynamic> metadata;
  final String? sourceModule;
  final String? sourceEntityId;
  final String? idempotencyKey;
  final DateTime createdAt;

  const ProjectEvent({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.eventType,
    required this.title,
    required this.description,
    this.metadata = const {},
    this.sourceModule,
    this.sourceEntityId,
    this.idempotencyKey,
    required this.createdAt,
  });

  factory ProjectEvent.fromJson(Map<String, dynamic> json) => ProjectEvent(
        id:              json['id'] as String,
        projectId:       json['project_id'] as String,
        userId:          json['user_id'] as String,
        eventType:       _typeFromString(json['event_type'] as String? ?? ''),
        title:           json['title'] as String? ?? '',
        description:     json['description'] as String? ?? '',
        metadata:        (json['metadata'] as Map<String, dynamic>?) ?? {},
        sourceModule:    json['source_module'] as String?,
        sourceEntityId:  json['source_entity_id'] as String?,
        idempotencyKey:  json['idempotency_key'] as String?,
        createdAt:       DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'project_id':  projectId,
      'user_id':     userId,
      'event_type':  _typeToString(eventType),
      'title':       title,
      'description': description,
      'metadata':    metadata,
    };
    if (sourceModule != null)    map['source_module']    = sourceModule;
    if (sourceEntityId != null)  map['source_entity_id'] = sourceEntityId;
    if (idempotencyKey != null)  map['idempotency_key']  = idempotencyKey;
    return map;
  }

  String get emoji {
    switch (eventType) {
      case ProjectEventType.projectCreated:       return '🌱';
      case ProjectEventType.stageChanged:         return '📈';
      case ProjectEventType.analysisCompleted:    return '🔬';
      case ProjectEventType.decisionTaken:        return '✅';
      case ProjectEventType.opportunityCreated:   return '💡';
      case ProjectEventType.documentAdded:        return '📄';
      case ProjectEventType.actionCompleted:      return '⚡';
      case ProjectEventType.checkIn:              return '🔄';
      case ProjectEventType.interviewCompleted:   return '🎤';
      case ProjectEventType.relationshipDetected: return '🔗';
      case ProjectEventType.healthChanged:        return '❤️';
      case ProjectEventType.priorityChanged:      return '🎯';
    }
  }

  String get typeLabel {
    switch (eventType) {
      case ProjectEventType.projectCreated:       return 'Criação';
      case ProjectEventType.stageChanged:         return 'Mudança de Estágio';
      case ProjectEventType.analysisCompleted:    return 'Análise';
      case ProjectEventType.decisionTaken:        return 'Decisão';
      case ProjectEventType.opportunityCreated:   return 'Oportunidade';
      case ProjectEventType.documentAdded:        return 'Documento';
      case ProjectEventType.actionCompleted:      return 'Ação';
      case ProjectEventType.checkIn:              return 'Check-In';
      case ProjectEventType.interviewCompleted:   return 'Entrevista';
      case ProjectEventType.relationshipDetected: return 'Relação';
      case ProjectEventType.healthChanged:        return 'Saúde';
      case ProjectEventType.priorityChanged:      return 'Prioridade';
    }
  }

  // Grupos para filtros da timeline
  String get filterGroup {
    switch (eventType) {
      case ProjectEventType.analysisCompleted:
      case ProjectEventType.healthChanged:
      case ProjectEventType.priorityChanged:
        return 'Análises';
      case ProjectEventType.documentAdded:
      case ProjectEventType.interviewCompleted:
        return 'Conhecimento';
      case ProjectEventType.decisionTaken:
      case ProjectEventType.checkIn:
        return 'Decisões';
      case ProjectEventType.opportunityCreated:
        return 'Oportunidades';
      case ProjectEventType.actionCompleted:
        return 'Ações';
      case ProjectEventType.projectCreated:
      case ProjectEventType.stageChanged:
      case ProjectEventType.relationshipDetected:
        return 'Projeto';
    }
  }

  static ProjectEventType _typeFromString(String s) {
    const map = {
      'project_created':       ProjectEventType.projectCreated,
      'stage_changed':         ProjectEventType.stageChanged,
      'analysis_completed':    ProjectEventType.analysisCompleted,
      'decision_taken':        ProjectEventType.decisionTaken,
      'opportunity_created':   ProjectEventType.opportunityCreated,
      'document_added':        ProjectEventType.documentAdded,
      'action_completed':      ProjectEventType.actionCompleted,
      'check_in':              ProjectEventType.checkIn,
      'interview_completed':   ProjectEventType.interviewCompleted,
      'relationship_detected': ProjectEventType.relationshipDetected,
      'health_changed':        ProjectEventType.healthChanged,
      'priority_changed':      ProjectEventType.priorityChanged,
    };
    return map[s] ?? ProjectEventType.checkIn;
  }

  static String _typeToString(ProjectEventType t) {
    const map = {
      ProjectEventType.projectCreated:       'project_created',
      ProjectEventType.stageChanged:         'stage_changed',
      ProjectEventType.analysisCompleted:    'analysis_completed',
      ProjectEventType.decisionTaken:        'decision_taken',
      ProjectEventType.opportunityCreated:   'opportunity_created',
      ProjectEventType.documentAdded:        'document_added',
      ProjectEventType.actionCompleted:      'action_completed',
      ProjectEventType.checkIn:              'check_in',
      ProjectEventType.interviewCompleted:   'interview_completed',
      ProjectEventType.relationshipDetected: 'relationship_detected',
      ProjectEventType.healthChanged:        'health_changed',
      ProjectEventType.priorityChanged:      'priority_changed',
    };
    return map[t] ?? 'check_in';
  }
}
