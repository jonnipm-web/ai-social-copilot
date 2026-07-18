import '../../../data/models/copilot_turn.dart';
import '../../../core/utils/date_parser.dart';
import 'ive_copilot_contract.dart';

enum IveActionProposalStatus {
  pendingConfirmation,
  executing,
  completed,
  cancelled,
  failed,
  expired,
}

class IveActionProposal {
  static int _idSequence = 0;

  final String proposalId;
  final String toolName;
  final String correlationId;
  final String userId;
  final String projectId;
  final String projectName;
  final String title;
  final String description;
  final int priority;
  final int impact;
  final int effort;
  final DateTime? suggestedDueDate;
  final String rationale;
  final String origin;
  final String? opportunityId;
  final List<String> evidenceIds;
  final DateTime createdAt;
  final DateTime expiresAt;
  final IveActionProposalStatus status;

  const IveActionProposal({
    required this.proposalId,
    this.toolName = 'action.create',
    this.correlationId = '',
    required this.userId,
    required this.projectId,
    required this.projectName,
    required this.title,
    required this.description,
    required this.priority,
    required this.impact,
    required this.effort,
    this.suggestedDueDate,
    required this.rationale,
    required this.origin,
    this.opportunityId,
    this.evidenceIds = const [],
    required this.createdAt,
    required this.expiresAt,
    this.status = IveActionProposalStatus.pendingConfirmation,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  String get idempotencyKey => 'ive_action_create_$proposalId';
  String get operationId => 'operation_$proposalId';
  String get persistenceMarker => 'ive_proposal:$proposalId';

  factory IveActionProposal.fromSuggestion({
    required CopilotActionSuggestion suggestion,
    required String userId,
    required String projectId,
    required String projectName,
    required Set<String> allowedOpportunityIds,
    Set<String>? allowedEvidenceIds,
    String correlationId = '',
  }) {
    if (suggestion.type != 'create_action' &&
        suggestion.type != 'action.create') {
      throw const FormatException('Ferramenta não permitida nesta sprint.');
    }

    final data = suggestion.data;
    if (data['_tool'] != null && data['_tool'] != 'action.create') {
      throw const FormatException('Ferramenta não permitida nesta sprint.');
    }
    final title = (data['title'] as String? ?? '').trim();
    if (title.isEmpty) {
      throw const FormatException('A proposta não possui um título válido.');
    }

    final rawOpportunityId = data['opportunity_id'] as String?;
    final opportunityId = rawOpportunityId != null &&
            allowedOpportunityIds.contains(rawOpportunityId)
        ? rawOpportunityId
        : null;
    final now = DateTime.now().toUtc();
    final evidenceIds =
        (data['evidence_ids'] as List?)?.whereType<String>().toList() ?? [];
    if (allowedEvidenceIds != null &&
        evidenceIds.any((id) => !allowedEvidenceIds.contains(id))) {
      throw const FormatException('A proposta contém evidência inválida.');
    }

    return IveActionProposal(
      proposalId: _newId(userId, projectId, now),
      correlationId: correlationId,
      userId: userId,
      projectId: projectId,
      projectName: projectName,
      title: title,
      description: (data['description'] as String? ?? '').trim(),
      priority: _score(data['priority'], fallback: 50),
      impact: _score(data['impact'] ?? data['impact_score'], fallback: 60),
      effort: _score(data['effort'] ?? data['effort_score'], fallback: 50),
      suggestedDueDate: _date(data['due_date']),
      rationale: (data['rationale'] as String? ??
              'Recomendação criada pela IVE com base no contexto disponível.')
          .trim(),
      origin: opportunityId == null ? 'ive' : 'opportunity_lab',
      opportunityId: opportunityId,
      evidenceIds: evidenceIds,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }

  factory IveActionProposal.fromProposedAction({
    required IveProposedAction action,
    required String userId,
    required String projectName,
    required String correlationId,
  }) {
    final now = DateTime.now().toUtc();
    return IveActionProposal(
      proposalId: _newId(userId, action.projectId, now),
      correlationId: correlationId,
      userId: userId,
      projectId: action.projectId,
      projectName: projectName,
      title: action.title,
      description: action.description,
      priority: action.priorityScore,
      impact: action.impactScore,
      effort: action.effortScore,
      suggestedDueDate: action.dueDate,
      rationale: action.rationale,
      origin: action.opportunityId == null ? 'ive' : 'opportunity_lab',
      opportunityId: action.opportunityId,
      evidenceIds: action.evidenceIds,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }

  IveActionProposal revised({
    required String title,
    required String description,
    required int priority,
    required int impact,
    required int effort,
    DateTime? suggestedDueDate,
  }) {
    final now = DateTime.now().toUtc();
    return IveActionProposal(
      proposalId: _newId(userId, projectId, now),
      correlationId: correlationId,
      userId: userId,
      projectId: projectId,
      projectName: projectName,
      title: title.trim(),
      description: description.trim(),
      priority: priority.clamp(0, 100),
      impact: impact.clamp(0, 100),
      effort: effort.clamp(0, 100),
      suggestedDueDate: suggestedDueDate,
      rationale: rationale,
      origin: origin,
      opportunityId: opportunityId,
      evidenceIds: evidenceIds,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }

  IveActionProposal copyWith({IveActionProposalStatus? status}) =>
      IveActionProposal(
        proposalId: proposalId,
        toolName: toolName,
        correlationId: correlationId,
        userId: userId,
        projectId: projectId,
        projectName: projectName,
        title: title,
        description: description,
        priority: priority,
        impact: impact,
        effort: effort,
        suggestedDueDate: suggestedDueDate,
        rationale: rationale,
        origin: origin,
        opportunityId: opportunityId,
        evidenceIds: evidenceIds,
        createdAt: createdAt,
        expiresAt: expiresAt,
        status: status ?? this.status,
      );

  static int _score(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt().clamp(0, 100);
    return fallback;
  }

  static DateTime? _date(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateParser.parseOrNull(value)?.toUtc();
  }

  static String _newId(String userId, String projectId, DateTime now) {
    final sequence = _idSequence++;
    return 'ive_${userId.hashCode.abs()}_${projectId.hashCode.abs()}_'
        '${now.microsecondsSinceEpoch}_$sequence';
  }
}
