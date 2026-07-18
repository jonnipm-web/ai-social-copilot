import '../../../core/utils/date_parser.dart';
import '../../../data/models/copilot_context_data.dart';
import '../../../data/models/copilot_turn.dart';

class IveCopilotRequest {
  static int _correlationSequence = 0;

  final String message;
  final String projectId;
  final String route;
  final String screenName;
  final String? selectedEntityType;
  final String? selectedEntityId;
  final String contextVersion;
  final List<Map<String, String>> history;
  final List<String> recentQuestions;
  final Map<String, dynamic> contextHints;
  final String correlationId;

  IveCopilotRequest({
    required this.message,
    required this.projectId,
    required this.route,
    required this.screenName,
    this.selectedEntityType,
    this.selectedEntityId,
    this.contextVersion = '2.0',
    this.history = const [],
    this.recentQuestions = const [],
    this.contextHints = const {},
    String? correlationId,
  }) : correlationId = correlationId ?? _newCorrelationId();

  factory IveCopilotRequest.fromConversation({
    required String message,
    required String projectId,
    required String route,
    required String screenName,
    required CopilotContextData context,
    required List<CopilotTurn> turns,
    required List<String> recentQuestions,
    String? selectedEntityType,
    String? selectedEntityId,
    String? correlationId,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty || normalizedMessage.length > 2000) {
      throw const FormatException(
          'A mensagem deve ter entre 1 e 2.000 caracteres.');
    }
    if (projectId.trim().isEmpty) {
      throw const FormatException('O projeto ativo é obrigatório.');
    }

    final limitedHistory = turns
        .where((turn) => turn.role == 'user' || turn.role == 'assistant')
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map((turn) => {
              'role': turn.role,
              'content': _truncate(turn.content, 800),
            })
        .toList();

    return IveCopilotRequest(
      message: normalizedMessage,
      projectId: projectId,
      route: route,
      screenName: screenName,
      selectedEntityType: selectedEntityType,
      selectedEntityId: selectedEntityId,
      history: limitedHistory,
      recentQuestions:
          recentQuestions.take(5).map((q) => _truncate(q, 800)).toList(),
      contextHints: context.toServerHints(),
      correlationId: correlationId,
    );
  }

  Map<String, dynamic> toMap() => {
        'message': message,
        'project_id': projectId,
        if (route.isNotEmpty) 'route': route,
        if (screenName.isNotEmpty) 'screen_name': screenName,
        if (selectedEntityType != null)
          'selected_entity_type': selectedEntityType,
        if (selectedEntityId != null) 'selected_entity_id': selectedEntityId,
        'context_version': contextVersion,
        if (contextHints.isNotEmpty) 'context': contextHints,
        if (history.isNotEmpty) 'history': history,
        if (recentQuestions.isNotEmpty) 'recent_questions': recentQuestions,
        'client_correlation_id': correlationId,
      };

  static String _truncate(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit);

  static String _newCorrelationId() {
    final sequence = _correlationSequence++;
    return 'ive_req_${DateTime.now().toUtc().microsecondsSinceEpoch}_$sequence';
  }
}

class IveEvidence {
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static const allowedSourceTypes = {
    'project',
    'opportunity',
    'action',
    'kb_item',
  };

  final String sourceType;
  final String sourceId;
  final String title;
  final Map<String, dynamic>? structuredValue;
  final String? excerpt;
  final String? projectId;
  final DateTime? timestamp;
  final double relevance;

  const IveEvidence({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    this.structuredValue,
    this.excerpt,
    this.projectId,
    this.timestamp,
    required this.relevance,
  });

  static IveEvidence? tryParse(dynamic value,
      {required String activeProjectId}) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final sourceType = map['source_type'] as String?;
    final sourceId = (map['source_id'] as String? ?? '').trim();
    final title = (map['title'] as String? ?? '').trim();
    final projectId = map['project_id'] as String?;
    final relevanceValue = map['relevance'];
    if (!allowedSourceTypes.contains(sourceType) ||
        sourceId.isEmpty ||
        !_uuidPattern.hasMatch(sourceId) ||
        title.isEmpty ||
        (projectId != null && projectId != activeProjectId) ||
        relevanceValue is! num ||
        relevanceValue < 0 ||
        relevanceValue > 1) {
      return null;
    }
    final excerpt = (map['excerpt'] as String?)?.trim();
    return IveEvidence(
      sourceType: sourceType!,
      sourceId: sourceId,
      title: title,
      structuredValue: map['structured_value'] is Map
          ? Map<String, dynamic>.from(map['structured_value'] as Map)
          : null,
      excerpt: excerpt == null || excerpt.isEmpty ? null : excerpt,
      projectId: projectId,
      timestamp: DateParser.parseOrNull(map['timestamp']),
      relevance: relevanceValue.toDouble(),
    );
  }

  String get sourceTypeLabel => switch (sourceType) {
        'project' => 'Projeto',
        'opportunity' => 'Opportunity Lab',
        'action' => 'Action Engine',
        'kb_item' => 'Knowledge Base',
        _ => 'Fonte',
      };
}

class IveProposedAction {
  static const priorities = {'low', 'medium', 'high', 'critical'};
  static const levels = {'low', 'medium', 'high'};

  final String projectId;
  final String title;
  final String description;
  final String priority;
  final String impact;
  final String effort;
  final DateTime? dueDate;
  final String rationale;
  final List<String> evidenceIds;
  final String? opportunityId;

  const IveProposedAction({
    required this.projectId,
    required this.title,
    required this.description,
    required this.priority,
    required this.impact,
    required this.effort,
    this.dueDate,
    required this.rationale,
    required this.evidenceIds,
    this.opportunityId,
  });

  static IveProposedAction? tryParse(
    dynamic value, {
    required String activeProjectId,
    required Set<String> validEvidenceIds,
    required Set<String> allowedOpportunityIds,
  }) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    if (map['tool_name'] != 'action.create' ||
        map['project_id'] != activeProjectId) {
      return null;
    }
    final title = (map['title'] as String? ?? '').trim();
    final description = (map['description'] as String? ?? '').trim();
    final rationale = (map['rationale'] as String? ?? '').trim();
    final priority = map['priority'] as String?;
    final impact = map['impact'] as String?;
    final effort = map['effort'] as String?;
    final evidenceIds =
        (map['evidence_ids'] as List?)?.whereType<String>().toList() ??
            <String>[];
    final opportunityId = map['opportunity_id'] as String?;
    if (title.isEmpty ||
        title.length > 200 ||
        description.length > 1000 ||
        rationale.length > 500 ||
        !priorities.contains(priority) ||
        !levels.contains(impact) ||
        !levels.contains(effort) ||
        evidenceIds.any((id) => !validEvidenceIds.contains(id)) ||
        (opportunityId != null &&
            !allowedOpportunityIds.contains(opportunityId))) {
      return null;
    }
    return IveProposedAction(
      projectId: activeProjectId,
      title: title,
      description: description,
      priority: priority!,
      impact: impact!,
      effort: effort!,
      dueDate: DateParser.parseOrNull(map['due_date']),
      rationale: rationale.isEmpty
          ? 'Recomendação baseada nas evidências autorizadas disponíveis.'
          : rationale,
      evidenceIds: evidenceIds,
      opportunityId: opportunityId,
    );
  }

  int get priorityScore => switch (priority) {
        'low' => 25,
        'medium' => 50,
        'high' => 80,
        'critical' => 100,
        _ => 50,
      };

  int get impactScore => _levelScore(impact);
  int get effortScore => _levelScore(effort);

  static int _levelScore(String value) => switch (value) {
        'low' => 30,
        'medium' => 60,
        'high' => 90,
        _ => 50,
      };
}

class IveCopilotResponse {
  final bool isV2;
  final String responseText;
  final String? responseId;
  final String correlationId;
  final String? intent;
  final String? projectId;
  final List<IveEvidence> evidence;
  final List<String> limitations;
  final IveProposedAction? proposedAction;
  final String? model;
  final String? promptVersion;
  final DateTime? serverTimestamp;
  final int confidence;
  final List<String> legacySources;
  final List<String> entities;
  final CopilotActionSuggestion? legacySuggestion;

  const IveCopilotResponse({
    required this.isV2,
    required this.responseText,
    this.responseId,
    required this.correlationId,
    this.intent,
    this.projectId,
    this.evidence = const [],
    this.limitations = const [],
    this.proposedAction,
    this.model,
    this.promptVersion,
    this.serverTimestamp,
    required this.confidence,
    this.legacySources = const [],
    this.entities = const [],
    this.legacySuggestion,
  });

  factory IveCopilotResponse.parse(
    Map<String, dynamic> data, {
    required String activeProjectId,
    required String requestCorrelationId,
    required Set<String> allowedOpportunityIds,
  }) {
    if (data['error'] != null) {
      final error = data['error'];
      final message = error is Map
          ? error['message']?.toString() ?? 'Erro retornado pelo backend.'
          : error.toString();
      throw IveCopilotContractException(message);
    }
    final isV2 = data.containsKey('response_id') ||
        data.containsKey('response_text') ||
        data.containsKey('evidence') ||
        data.containsKey('proposed_action') ||
        data.containsKey('prompt_version');
    final projectId = data['project_id'] as String?;
    if ((isV2 && projectId != activeProjectId) ||
        (!isV2 && projectId != null && projectId != activeProjectId)) {
      throw IveProjectMismatchException(
        expectedProjectId: activeProjectId,
        receivedProjectId: projectId ?? 'null',
      );
    }

    final evidence = (data['evidence'] as List?)
            ?.map((item) => IveEvidence.tryParse(
                  item,
                  activeProjectId: activeProjectId,
                ))
            .whereType<IveEvidence>()
            .toList() ??
        <IveEvidence>[];
    final validEvidenceIds = evidence.map((item) => item.sourceId).toSet();
    final proposedAction = IveProposedAction.tryParse(
      data['proposed_action'],
      activeProjectId: activeProjectId,
      validEvidenceIds: validEvidenceIds,
      allowedOpportunityIds: allowedOpportunityIds,
    );

    CopilotActionSuggestion? legacySuggestion;
    if (!isV2 && data['action_suggestion'] is Map) {
      legacySuggestion = CopilotActionSuggestion.fromMap(
        Map<String, dynamic>.from(data['action_suggestion'] as Map),
      );
    }

    final responseText =
        ((isV2 ? data['response_text'] : null) as String?)?.trim().isNotEmpty ==
                true
            ? (data['response_text'] as String).trim()
            : (data['answer'] as String? ?? '').trim();
    if (responseText.isEmpty) {
      throw const IveCopilotContractException(
        'O backend não retornou uma resposta textual válida.',
      );
    }

    final limitations = (data['limitations'] as List?)
            ?.whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        <String>[];
    final confidenceValue = isV2
        ? data['system_confidence'] ?? data['confidence']
        : data['confidence'];

    return IveCopilotResponse(
      isV2: isV2,
      responseText: responseText,
      responseId: data['response_id'] as String?,
      correlationId: data['correlation_id'] as String? ?? requestCorrelationId,
      intent: data['intent'] as String?,
      projectId: projectId,
      evidence: evidence,
      limitations: limitations,
      proposedAction: proposedAction,
      model: data['model'] as String?,
      promptVersion: data['prompt_version'] as String?,
      serverTimestamp: DateParser.parseOrNull(
        data['server_timestamp'] ?? data['timestamp'],
      ),
      confidence: _confidence(confidenceValue),
      legacySources:
          (data['sources'] as List?)?.whereType<String>().toList() ?? const [],
      entities:
          (data['entities'] as List?)?.whereType<String>().toList() ?? const [],
      legacySuggestion: legacySuggestion,
    );
  }

  static int _confidence(dynamic value) {
    if (value is! num) return 0;
    return value.toInt().clamp(0, 100);
  }
}

class IveCopilotContractException implements Exception {
  final String message;
  const IveCopilotContractException(this.message);

  @override
  String toString() => message;
}

class IveProjectMismatchException extends IveCopilotContractException {
  final String expectedProjectId;
  final String receivedProjectId;

  IveProjectMismatchException({
    required this.expectedProjectId,
    required this.receivedProjectId,
  }) : super('A resposta pertence a outro projeto e foi rejeitada.');
}

class IveCopilotHttpException implements Exception {
  final int status;
  final String code;
  final String message;
  final String? correlationId;

  const IveCopilotHttpException({
    required this.status,
    required this.code,
    required this.message,
    this.correlationId,
  });

  bool get clearsSensitiveState => status == 401;
  bool get clearsSelectedProject => status == 404;
  bool get isTimeout => status == 504 || code == 'TIMEOUT';

  @override
  String toString() => message;
}
