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
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id':             userId,
        'project_id':          projectId,
        'market_analysis_id':  marketAnalysisId,
        'opportunity_type':    opportunityType,
        'title':            title,
        'description':      description,
        'market_score':     marketScore,
        'revenue_score':    revenueScore,
        'competition_score': competitionScore,
        'synergy_score':    synergyScore,
        'strategic_fit':    strategicFit,
        'final_score':      finalScore,
        'status':           status,
      };
}
