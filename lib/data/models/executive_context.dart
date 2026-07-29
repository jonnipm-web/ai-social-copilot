/// Pilar de saúde executiva de um projeto.
class HealthPillar {
  final String name;
  final String emoji;
  final int score;           // 0-100
  final int previousScore;   // para cálculo de trend
  final String status;       // 'forte' | 'atenção' | 'crítico'
  final List<String> strengths;
  final List<String> gaps;
  final String recommendation;

  const HealthPillar({
    required this.name,
    required this.emoji,
    required this.score,
    this.previousScore = 0,
    required this.status,
    this.strengths  = const [],
    this.gaps       = const [],
    this.recommendation = '',
  });

  int get trend => score - previousScore;

  String get trendEmoji {
    if (trend > 5)  return '📈';
    if (trend < -5) return '📉';
    return '➡️';
  }

  String get statusEmoji {
    switch (status) {
      case 'forte':   return '🟢';
      case 'atenção': return '🟡';
      default:        return '🔴';
    }
  }
}

/// Saúde executiva completa de um projeto (8 pilares).
class ExecutiveHealth {
  final HealthPillar knowledge;
  final HealthPillar market;
  final HealthPillar execution;
  final HealthPillar monetization;
  final HealthPillar validation;
  final HealthPillar risks;
  final HealthPillar technology;
  final HealthPillar strategy;
  final DateTime computedAt;

  const ExecutiveHealth({
    required this.knowledge,
    required this.market,
    required this.execution,
    required this.monetization,
    required this.validation,
    required this.risks,
    required this.technology,
    required this.strategy,
    required this.computedAt,
  });

  List<HealthPillar> get pillars => [
        knowledge, market, execution, monetization,
        risks, validation, technology, strategy,
      ];

  int get overallScore {
    final sum = pillars.fold(0, (s, p) => s + p.score);
    return sum ~/ pillars.length;
  }

  String get overallStatus {
    final s = overallScore;
    if (s >= 70) return 'forte';
    if (s >= 40) return 'atenção';
    return 'crítico';
  }

  HealthPillar get weakestPillar =>
      pillars.reduce((a, b) => a.score < b.score ? a : b);

  HealthPillar get strongestPillar =>
      pillars.reduce((a, b) => a.score > b.score ? a : b);
}

/// Contexto executivo persistente de um projeto.
class ExecutiveContext {
  final String projectId;
  final String userId;
  final String executiveSummary;
  final List<String> keyDecisions;
  final List<String> openRisks;
  final List<String> synergies;
  final String currentStage;
  final DateTime? lastAnalysisAt;
  final DateTime? lastCheckInAt;
  final DateTime? checkInDueAt;
  final int priorityScore;
  final Map<String, dynamic> metadata;
  final DateTime updatedAt;

  const ExecutiveContext({
    required this.projectId,
    required this.userId,
    this.executiveSummary = '',
    this.keyDecisions     = const [],
    this.openRisks        = const [],
    this.synergies        = const [],
    this.currentStage     = 'ideia',
    this.lastAnalysisAt,
    this.lastCheckInAt,
    this.checkInDueAt,
    this.priorityScore    = 0,
    this.metadata         = const {},
    required this.updatedAt,
  });

  bool get checkInDue {
    if (checkInDueAt == null) return false;
    return DateTime.now().isAfter(checkInDueAt!);
  }

  bool get stale {
    if (lastAnalysisAt == null) return true;
    return DateTime.now().difference(lastAnalysisAt!).inDays > 30;
  }

  factory ExecutiveContext.fromJson(Map<String, dynamic> json) => ExecutiveContext(
        projectId:       json['project_id'] as String,
        userId:          json['user_id'] as String,
        executiveSummary: json['executive_summary'] as String? ?? '',
        keyDecisions:    List<String>.from(json['key_decisions'] as List? ?? []),
        openRisks:       List<String>.from(json['open_risks'] as List? ?? []),
        synergies:       List<String>.from(json['synergies'] as List? ?? []),
        currentStage:    json['current_stage'] as String? ?? 'ideia',
        lastAnalysisAt:  json['last_analysis_at'] != null
            ? DateTime.tryParse(json['last_analysis_at'] as String)
            : null,
        lastCheckInAt:   json['last_check_in_at'] != null
            ? DateTime.tryParse(json['last_check_in_at'] as String)
            : null,
        checkInDueAt:    json['check_in_due_at'] != null
            ? DateTime.tryParse(json['check_in_due_at'] as String)
            : null,
        priorityScore:   json['priority_score'] as int? ?? 0,
        metadata:        (json['metadata'] as Map<String, dynamic>?) ?? {},
        updatedAt:       DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'project_id':        projectId,
        'user_id':           userId,
        'executive_summary': executiveSummary,
        'key_decisions':     keyDecisions,
        'open_risks':        openRisks,
        'synergies':         synergies,
        'current_stage':     currentStage,
        'last_analysis_at':  lastAnalysisAt?.toIso8601String(),
        'last_check_in_at':  lastCheckInAt?.toIso8601String(),
        'check_in_due_at':   checkInDueAt?.toIso8601String(),
        'priority_score':    priorityScore,
        'metadata':          metadata,
      };

  ExecutiveContext copyWith({
    String?    executiveSummary,
    List<String>? keyDecisions,
    List<String>? openRisks,
    List<String>? synergies,
    String?    currentStage,
    DateTime?  lastAnalysisAt,
    DateTime?  lastCheckInAt,
    DateTime?  checkInDueAt,
    int?       priorityScore,
    Map<String, dynamic>? metadata,
  }) =>
      ExecutiveContext(
        projectId:        projectId,
        userId:           userId,
        executiveSummary: executiveSummary ?? this.executiveSummary,
        keyDecisions:     keyDecisions     ?? this.keyDecisions,
        openRisks:        openRisks        ?? this.openRisks,
        synergies:        synergies        ?? this.synergies,
        currentStage:     currentStage     ?? this.currentStage,
        lastAnalysisAt:   lastAnalysisAt   ?? this.lastAnalysisAt,
        lastCheckInAt:    lastCheckInAt    ?? this.lastCheckInAt,
        checkInDueAt:     checkInDueAt     ?? this.checkInDueAt,
        priorityScore:    priorityScore    ?? this.priorityScore,
        metadata:         metadata         ?? this.metadata,
        updatedAt:        DateTime.now(),
      );
}
