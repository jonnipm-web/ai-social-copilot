class OpportunityLabItem {
  final String id;
  final String userId;
  final String? projectId;
  final String? marketAnalysisId;
  final String opportunityType;
  final String title;
  final String description;
  final int marketScore;
  final int revenueScore;
  final int competitionScore;
  final int synergyScore;
  final int strategicFit;
  final int finalScore;
  final String status;
  final DateTime createdAt;

  // ── Audit fields ──────────────────────────────────────────────
  final String         origin;
  final List<String>   sources;
  final String?        rationale;
  final int            confidence;
  final List<String>   risks;
  final List<String>   actionSteps;

  const OpportunityLabItem({
    required this.id,
    required this.userId,
    this.projectId,
    this.marketAnalysisId,
    this.opportunityType = 'expansão',
    required this.title,
    this.description = '',
    this.marketScore = 0,
    this.revenueScore = 0,
    this.competitionScore = 0,
    this.synergyScore = 0,
    this.strategicFit = 0,
    this.finalScore = 0,
    this.status = 'pending',
    required this.createdAt,
    this.origin = 'manual',
    this.sources = const [],
    this.rationale,
    this.confidence = 0,
    this.risks = const [],
    this.actionSteps = const [],
  });

  static const List<String> types = [
    'expansão',
    'novo produto',
    'novo nicho',
    'afiliado',
    'SaaS',
    'ebook',
    'curso',
    'assinatura',
  ];

  static const List<String> statusValues = [
    'pending',
    'analyzing',
    'approved',
    'rejected',
    'executing',
  ];

  static const Map<String, String> originLabels = {
    'manual':           'Adicionado manualmente',
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

  factory OpportunityLabItem.fromMap(Map<String, dynamic> map) =>
      OpportunityLabItem(
        id:               map['id'] as String,
        userId:           map['user_id'] as String,
        projectId:        map['project_id'] as String?,
        marketAnalysisId: map['market_analysis_id'] as String?,
        opportunityType:  map['opportunity_type'] as String? ?? 'expansão',
        title:            map['title'] as String? ?? '',
        description:      map['description'] as String? ?? '',
        marketScore:      map['market_score'] as int? ?? 0,
        revenueScore:     map['revenue_score'] as int? ?? 0,
        competitionScore: map['competition_score'] as int? ?? 0,
        synergyScore:     map['synergy_score'] as int? ?? 0,
        strategicFit:     map['strategic_fit'] as int? ?? 0,
        finalScore:       map['final_score'] as int? ?? 0,
        status:           map['status'] as String? ?? 'pending',
        createdAt:        DateTime.parse(map['created_at'] as String),
        origin:           map['origin'] as String? ?? 'manual',
        sources:          _parseList(map['sources']),
        rationale:        map['rationale'] as String?,
        confidence:       map['confidence'] as int? ?? 0,
        risks:            _parseList(map['risks']),
        actionSteps:      _parseList(map['action_steps']),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id':             userId,
        'project_id':          projectId,
        'market_analysis_id':  marketAnalysisId,
        'opportunity_type':    opportunityType,
        'title':               title,
        'description':         description,
        'market_score':        marketScore,
        'revenue_score':       revenueScore,
        'competition_score':   competitionScore,
        'synergy_score':       synergyScore,
        'strategic_fit':       strategicFit,
        'final_score':         finalScore,
        'status':              status,
        'origin':              origin,
        'sources':             sources,
        if (rationale != null) 'rationale': rationale,
        'confidence':          confidence,
        'risks':               risks,
        'action_steps':        actionSteps,
      };

  OpportunityLabItem copyWith({
    String? status,
    String? rationale,
    int? confidence,
    List<String>? risks,
    List<String>? actionSteps,
    List<String>? sources,
    String? origin,
  }) =>
      OpportunityLabItem(
        id:               id,
        userId:           userId,
        projectId:        projectId,
        marketAnalysisId: marketAnalysisId,
        opportunityType:  opportunityType,
        title:            title,
        description:      description,
        marketScore:      marketScore,
        revenueScore:     revenueScore,
        competitionScore: competitionScore,
        synergyScore:     synergyScore,
        strategicFit:     strategicFit,
        finalScore:       finalScore,
        status:           status ?? this.status,
        createdAt:        createdAt,
        origin:           origin ?? this.origin,
        sources:          sources ?? this.sources,
        rationale:        rationale ?? this.rationale,
        confidence:       confidence ?? this.confidence,
        risks:            risks ?? this.risks,
        actionSteps:      actionSteps ?? this.actionSteps,
      );
}
