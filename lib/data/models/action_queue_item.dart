class ActionQueueItem {
  final String id;
  final String userId;
  final String? projectId;
  final String? opportunityLabId;
  final String actionType;
  final String title;
  final int priority;
  final int impactScore;
  final int effortScore;
  final int roiScore;
  final String status;
  final DateTime createdAt;

  const ActionQueueItem({
    required this.id,
    required this.userId,
    this.projectId,
    this.opportunityLabId,
    this.actionType = 'task',
    required this.title,
    this.priority = 0,
    this.impactScore = 0,
    this.effortScore = 0,
    this.roiScore = 0,
    this.status = 'pending',
    required this.createdAt,
  });

  static const List<String> statusValues = [
    'pending',
    'approved',
    'executing',
    'completed',
    'cancelled',
  ];

  factory ActionQueueItem.fromMap(Map<String, dynamic> map) => ActionQueueItem(
        id:               map['id'] as String,
        userId:           map['user_id'] as String,
        projectId:        map['project_id'] as String?,
        opportunityLabId: map['opportunity_lab_id'] as String?,
        actionType:       map['action_type'] as String? ?? 'task',
        title:       map['title'] as String? ?? '',
        priority:    map['priority'] as int? ?? 0,
        impactScore: map['impact_score'] as int? ?? 0,
        effortScore: map['effort_score'] as int? ?? 0,
        roiScore:    map['roi_score'] as int? ?? 0,
        status:      map['status'] as String? ?? 'pending',
        createdAt:   DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id':           userId,
        'project_id':        projectId,
        'opportunity_lab_id': opportunityLabId,
        'action_type':       actionType,
        'title':        title,
        'priority':     priority,
        'impact_score': impactScore,
        'effort_score': effortScore,
        'roi_score':    roiScore,
        'status':       status,
      };
}
