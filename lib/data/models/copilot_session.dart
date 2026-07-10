class CopilotSession {
  final String id;
  final String userId;
  final String title;
  final Map<String, dynamic> contextJson;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CopilotSession({
    required this.id,
    required this.userId,
    this.title = '',
    this.contextJson = const {},
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory CopilotSession.fromMap(Map<String, dynamic> map) => CopilotSession(
        id:          map['id'] as String,
        userId:      map['user_id'] as String,
        title:       map['title'] as String? ?? '',
        contextJson: map['context_json'] is Map
            ? Map<String, dynamic>.from(map['context_json'] as Map)
            : {},
        status:      map['status'] as String? ?? 'active',
        createdAt:   DateTime.parse(map['created_at'] as String),
        updatedAt:   DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id':      userId,
        'title':        title,
        'context_json': contextJson,
        'status':       status,
      };
}

class CopilotMessage {
  final String id;
  final String sessionId;
  final String userId;
  final String role;
  final String content;
  final DateTime createdAt;

  const CopilotMessage({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory CopilotMessage.fromMap(Map<String, dynamic> map) => CopilotMessage(
        id:        map['id'] as String,
        sessionId: map['session_id'] as String,
        userId:    map['user_id'] as String,
        role:      map['role'] as String? ?? 'user',
        content:   map['content'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'session_id': sessionId,
        'user_id':    userId,
        'role':       role,
        'content':    content,
      };
}
