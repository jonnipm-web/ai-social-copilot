import '../../l10n/app_localizations.dart';

class ActionQueueItem {
  /// R16: detected source language when the presentation text of this row
  /// was translated for display (null = shown in its original language).
  final String? localizedFrom;

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

  // ── Opportunity scores (preserved from OpportunityLabItem) ────
  final int     marketScore;
  final int     confidence;
  final String? marketAnalysisId;

  // ── AEF governance provenance (INSIGHTVALUES-PRODUCTIZATION-MACRO-03) ──
  // Null on every item never routed through the governed execute path
  // (the common case: a self-performed real-world task, never AEF's
  // concern). Set only by a real action-engine-runtime response — never
  // client-invented.
  final String? aefOperationId;
  final String? aefReceiptId;
  final String? aefReceiptOutcome;

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
    this.marketScore     = 0,
    this.confidence      = 0,
    this.marketAnalysisId,
    this.aefOperationId,
    this.aefReceiptId,
    this.aefReceiptOutcome,
    this.localizedFrom,
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

  /// Legacy PT-only label. R16: UI must use [localizedOriginLabel]; this
  /// getter remains only for callers not yet migrated.
  String get originLabel => originLabels[origin] ?? origin;

  /// R16 — origin label in the presentation language of [l10n]; unknown
  /// origins are shown verbatim.
  String localizedOriginLabel(AppLocalizations l10n) =>
      originLabelFor(origin, l10n);

  static String originLabelFor(String origin, AppLocalizations l10n) {
    switch (origin) {
      case 'manual':           return l10n.uxOriginManual;
      case 'opportunity_lab':  return 'Opportunity Lab';
      case 'market_analysis':  return l10n.uxOriginMarketAnalysis;
      case 'auto_bootstrap':   return l10n.uxOriginAutoBootstrap;
      case 'knowledge_engine': return 'Knowledge Engine';
      default:                 return origin;
    }
  }

  /// The ONLY condition under which this item's completion may be shown as
  /// AEF-verified rather than self-attested: a real, persisted
  /// ExecutionReceipt with outcome SUCCESS. Mirrors AefRuntimeResult's own
  /// isCompleted rule (lib/data/models/aef_runtime.dart) so the two never
  /// silently disagree about what "done" means.
  bool get isAefVerifiedComplete => aefReceiptOutcome == 'SUCCESS';

  static List<String> _parseList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory ActionQueueItem.fromMap(Map<String, dynamic> map) => ActionQueueItem(
        id:               map['id'] as String,
        localizedFrom: map['r16_localized_from'] as String?,
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
        marketScore:      map['market_score'] as int? ?? 0,
        confidence:       map['confidence'] as int? ?? 0,
        marketAnalysisId: map['market_analysis_id'] as String?,
        aefOperationId:    map['aef_operation_id'] as String?,
        aefReceiptId:      map['aef_receipt_id'] as String?,
        aefReceiptOutcome: map['aef_receipt_outcome'] as String?,
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
        'market_score':       marketScore,
        'confidence':         confidence,
        if (marketAnalysisId != null) 'market_analysis_id': marketAnalysisId,
      };
}
