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

  // ── Audit fields ──────────────────────────────────────────────
  final String?      description;
  final String       origin;
  final List<String> sources;
  final String?      rationale;
  final List<String> plan;
  final List<String> risks;
  final DateTime?    updatedAt;

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
    this.description,
    this.origin = 'manual',
    this.sources = const [],
    this.rationale,
    this.plan = const [],
    this.risks = const [],
    this.updatedAt,
  });

  static const List<String> statusValues = [
    'pending',
    'approved',
    'executing',
    'completed',
    'cancelled',
  ];

  static const Map<String, String> originLabels = {
    'manual':           'Adicionado manualmente',
    'opportunity_lab':  'Opportunity Lab',
    'market_analysis':  'Análise de Mercado',
    'auto_bootstrap':   'Bootstrap Automático',
    'knowledge_engine': 'Knowledge Engine',
  };

  String get originLabel => originLabels[origin] ?? origin;

  static List<String> _parseList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory ActionQueueItem.fromMap(Map<String, dynamic> map) => ActionQueueItem(
        id:               map['id'] as String,
        userId:           map['user_id'] as String,
        projectId:        map['project_id'] as String?,
        opportunityLabId: map['opportunity_lab_id'] as String?,
        actionType:       map['action_type'] as String? ?? 'task',
        title:            map['title'] as String? ?? '',
        priority:         map['priority'] as int? ?? 0,
        impactScore:      map['impact_score'] as int? ?? 0,
        effortScore:      map['effort_score'] as int? ?? 0,
        roiScore:         map['roi_score'] as int? ?? 0,
        status:           map['status'] as String? ?? 'pending',
        createdAt:        DateTime.parse(map['created_at'] as String),
        description:      map['description'] as String?,
        origin:           map['origin'] as String? ?? 'manual',
        sources:          _parseList(map['sources']),
        rationale:        map['rationale'] as String?,
        plan:             _parseList(map['plan']),
        risks:            _parseList(map['risks']),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id':            userId,
        'project_id':         projectId,
        'opportunity_lab_id': opportunityLabId,
        'action_type':        actionType,
        'title':              title,
        'priority':           priority,
        'impact_score':       impactScore,
        'effort_score':       effortScore,
        'roi_score':          roiScore,
        'status':             status,
        if (description != null) 'description': description,
        'origin':             origin,
        'sources':            sources,
        if (rationale != null) 'rationale': rationale,
        'plan':               plan,
        'risks':              risks,
      };
}
