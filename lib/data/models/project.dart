class Project {
  /// R16: detected source language when the presentation text of this row
  /// was translated for display (null = shown in its original language).
  final String? localizedFrom;
  /// R16: description translated for display; [description] keeps the
  /// ORIGINAL text so edit forms never overwrite it with a translation.
  final String? descriptionLocalized;
  String get presentedDescription =>
      (descriptionLocalized != null && descriptionLocalized!.trim().isNotEmpty)
          ? descriptionLocalized!
          : description;

  final String id;
  final String userId;
  final String name;
  final String description;
  final String type;
  final String? url;
  final int opportunityScore;
  final double revenuePotential;
  final int complexityScore;
  final int priorityScore;
  final int timeToRevenueDays;
  final String status;
  final String? marketAnalysisId;
  final Map<String, dynamic> detailsJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    this.type = 'website',
    this.url,
    this.opportunityScore = 0,
    this.revenuePotential = 0,
    this.complexityScore = 0,
    this.priorityScore = 0,
    this.timeToRevenueDays = 0,
    this.status = 'idea',
    this.marketAnalysisId,
    this.detailsJson = const {},
    required this.createdAt,
    required this.updatedAt,
    this.localizedFrom,
    this.descriptionLocalized,
  });

  List<String> get nextActions => _list(detailsJson['next_actions']);
  List<String> get risks => _list(detailsJson['risks']);
  String get summary => detailsJson['summary'] as String? ?? '';

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    double _d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return Project(
      id:                  map['id'] as String,
      localizedFrom: map['r16_localized_from'] as String?,
      descriptionLocalized: map['description_localized'] as String?,
      userId:              map['user_id'] as String,
      name:                map['name'] as String,
      description:         map['description'] as String? ?? '',
      type:                map['type'] as String? ?? 'website',
      url:                 map['url'] as String?,
      opportunityScore:    map['opportunity_score'] as int? ?? 0,
      revenuePotential:    _d(map['revenue_potential']),
      complexityScore:     map['complexity_score'] as int? ?? 0,
      priorityScore:       map['priority_score'] as int? ?? 0,
      timeToRevenueDays:   map['time_to_revenue_days'] as int? ?? 0,
      status:              map['status'] as String? ?? 'idea',
      marketAnalysisId:    map['market_analysis_id'] as String?,
      detailsJson:         map['details_json'] is Map
          ? Map<String, dynamic>.from(map['details_json'] as Map)
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':               userId,
    'name':                  name,
    'description':           description,
    'type':                  type,
    'url':                   url,
    'opportunity_score':     opportunityScore,
    'revenue_potential':     revenuePotential,
    'complexity_score':      complexityScore,
    'priority_score':        priorityScore,
    'time_to_revenue_days':  timeToRevenueDays,
    'status':                status,
    'market_analysis_id':    marketAnalysisId,
    'details_json':          detailsJson,
  };

  Project copyWith({String? status, int? priorityScore}) {
    return Project(
      id:                  id,
      localizedFrom: localizedFrom,
      descriptionLocalized: descriptionLocalized,
      userId:              userId,
      name:                name,
      description:         description,
      type:                type,
      url:                 url,
      opportunityScore:    opportunityScore,
      revenuePotential:    revenuePotential,
      complexityScore:     complexityScore,
      priorityScore:       priorityScore ?? this.priorityScore,
      timeToRevenueDays:   timeToRevenueDays,
      status:              status ?? this.status,
      marketAnalysisId:    marketAnalysisId,
      detailsJson:         detailsJson,
      createdAt:           createdAt,
      updatedAt:           updatedAt,
    );
  }
}
