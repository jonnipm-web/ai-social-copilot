import '../../core/utils/date_parser.dart';

class BusinessMemory {
  final String id;
  final String userId;
  final String? projectId;
  final String memoryType;
  final String title;
  final String content;
  final int confidenceScore;
  final String source;
  final DateTime createdAt;

  const BusinessMemory({
    required this.id,
    required this.userId,
    this.projectId,
    required this.memoryType,
    required this.title,
    this.content = '',
    this.confidenceScore = 50,
    this.source = '',
    required this.createdAt,
  });

  static const List<String> types = [
    'opportunity',
    'campaign',
    'strategy',
    'revenue',
    'decision',
    'success',
    'failure',
  ];

  factory BusinessMemory.fromMap(Map<String, dynamic> map) => BusinessMemory(
        id:              map['id'] as String,
        userId:          map['user_id'] as String,
        projectId:       map['project_id'] as String?,
        memoryType:      map['memory_type'] as String? ?? 'decision',
        title:           map['title'] as String? ?? '',
        content:         map['content'] as String? ?? '',
        confidenceScore: map['confidence_score'] as int? ?? 50,
        source:          map['source'] as String? ?? '',
        createdAt:       DateParser.parse(map['created_at']),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id':          userId,
        'project_id':       projectId,
        'memory_type':      memoryType,
        'title':            title,
        'content':          content,
        'confidence_score': confidenceScore,
        'source':           source,
      };
}
