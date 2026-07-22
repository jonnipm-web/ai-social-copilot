import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/copilot_context_data.dart';
import '../data/models/copilot_turn.dart';
import '../features/ive/domain/ive_action_proposal.dart';
import '../features/ive/domain/ive_copilot_contract.dart';
import '../features/ive/services/ive_action_executor.dart';
import '../features/ive/services/ive_copilot_gateway.dart';
import 'action_queue_provider.dart';
import 'ecosystem_intelligence_provider.dart';
import 'ive_context_provider.dart';
import 'ive_memory_provider.dart';
import 'selected_project_provider.dart';

class CopilotScope {
  final String userId;
  final String projectId;
  final String screenName;

  const CopilotScope({
    required this.userId,
    required this.projectId,
    required this.screenName,
  });

  @override
  bool operator ==(Object other) =>
      other is CopilotScope &&
      other.userId == userId &&
      other.projectId == projectId &&
      other.screenName == screenName;

  @override
  int get hashCode => Object.hash(userId, projectId, screenName);
}

class CopilotState {
  final List<CopilotTurn> turns;
  final bool loading;
  final String? error;
  final IveActionProposal? pendingProposal;
  final IveActionExecutionResult? lastExecution;
  final bool executing;
  final List<IveEvidence> evidence;
  final List<String> limitations;
  final String? responseId;
  final String? correlationId;
  final String? gatewayUsed;
  final Map<String, String> sourceStatus;

  const CopilotState({
    this.turns = const [],
    this.loading = false,
    this.error,
    this.pendingProposal,
    this.lastExecution,
    this.executing = false,
    this.evidence = const [],
    this.limitations = const [],
    this.responseId,
    this.correlationId,
    this.gatewayUsed,
    this.sourceStatus = const {},
  });

  CopilotState copyWith({
    List<CopilotTurn>? turns,
    bool? loading,
    String? error,
    bool clearError = false,
    IveActionProposal? pendingProposal,
    bool clearProposal = false,
    IveActionExecutionResult? lastExecution,
    bool clearExecution = false,
    bool? executing,
    List<IveEvidence>? evidence,
    List<String>? limitations,
    String? responseId,
    String? correlationId,
    String? gatewayUsed,
    Map<String, String>? sourceStatus,
    bool clearResponseContext = false,
  }) =>
      CopilotState(
        turns: turns ?? this.turns,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        pendingProposal:
            clearProposal ? null : (pendingProposal ?? this.pendingProposal),
        lastExecution:
            clearExecution ? null : (lastExecution ?? this.lastExecution),
        executing: executing ?? this.executing,
        evidence: clearResponseContext ? const [] : (evidence ?? this.evidence),
        limitations:
            clearResponseContext ? const [] : (limitations ?? this.limitations),
        responseId:
            clearResponseContext ? null : (responseId ?? this.responseId),
        correlationId:
            clearResponseContext ? null : (correlationId ?? this.correlationId),
        gatewayUsed:
            clearResponseContext ? null : (gatewayUsed ?? this.gatewayUsed),
        sourceStatus: clearResponseContext
            ? const {}
            : (sourceStatus ?? this.sourceStatus),
      );

  CopilotState preserveForFailure(String message) => copyWith(
        loading: false,
        executing: false,
        error: message,
      );

  static CopilotState unauthorized(String message) =>
      CopilotState(error: message);

  CopilotState invalidProject(String message) => copyWith(
        loading: false,
        executing: false,
        error: message,
        clearProposal: true,
        clearExecution: true,
        clearResponseContext: true,
      );
}

class ContextCopilotNotifier extends StateNotifier<CopilotState> {
  ContextCopilotNotifier(
    this._ref,
    this.scope, {
    IveCopilotGateway? gateway,
    String? Function()? currentUserId,
    Stream<AuthState>? authChanges,
    void Function(String)? rememberQuestion,
    List<String> Function()? recentQuestions,
    Future<void> Function()? clearSelectedProject,
    void Function()? clearSensitiveMemory,
  }) : super(const CopilotState()) {
    _gateway = gateway ?? _ref.read(iveCopilotGatewayProvider);
    _currentUserId =
        currentUserId ?? () => Supabase.instance.client.auth.currentUser?.id;
    _rememberQuestion = rememberQuestion ??
        (question) =>
            _ref.read(iveMemoryProvider.notifier).addQuestion(question);
    _recentQuestions =
        recentQuestions ?? () => _ref.read(iveMemoryProvider).recentQuestions;
    _clearSelectedProject = clearSelectedProject ??
        () => _ref.read(selectedProjectProvider.notifier).clear();
    _clearSensitiveMemory = clearSensitiveMemory ??
        () => _ref.read(iveMemoryProvider.notifier).clearSensitiveSession();

    final stream =
        authChanges ?? Supabase.instance.client.auth.onAuthStateChange;
    _authSub = stream.listen((event) {
      if (event.event == AuthChangeEvent.signedOut ||
          event.session?.user.id != scope.userId) {
        clearHistory();
      }
    });
  }

  final Ref _ref;
  final CopilotScope scope;
  late final IveCopilotGateway _gateway;
  late final String? Function() _currentUserId;
  late final void Function(String) _rememberQuestion;
  late final List<String> Function() _recentQuestions;
  late final Future<void> Function() _clearSelectedProject;
  late final void Function() _clearSensitiveMemory;
  StreamSubscription<AuthState>? _authSub;

  Future<void> send({
    required String message,
    required CopilotContextData context,
    String? selectedEntityType,
    String? selectedEntityId,
  }) async {
    if (state.loading || state.executing) return;
    final uid = _currentUserId();
    if (uid == null || uid != scope.userId) {
      state = CopilotState.unauthorized(
        'Sessão inválida. Entre novamente.',
      );
      return;
    }
    if (scope.projectId.isEmpty || context.projectId != scope.projectId) {
      state = state.copyWith(
        error: 'Selecione um projeto antes de conversar com a IVE.',
      );
      return;
    }

    final request = IveCopilotRequest.fromConversation(
      message: message,
      projectId: scope.projectId,
      route: context.route,
      screenName: scope.screenName,
      context: context,
      turns: state.turns,
      recentQuestions: _recentQuestions(),
      selectedEntityType: selectedEntityType,
      selectedEntityId: selectedEntityId,
    );
    final userTurn = CopilotTurn(
      role: 'user',
      content: message.trim(),
      timestamp: DateTime.now(),
    );
    _rememberQuestion(message);
    state = state.copyWith(
      turns: [...state.turns, userTurn],
      loading: true,
      clearError: true,
      clearExecution: true,
    );

    try {
      final data = await _gateway.invoke(request);
      final allowedOpportunityIds = context.opportunities
          .map((item) => item['id'])
          .whereType<String>()
          .toSet();
      final response = IveCopilotResponse.parse(
        data,
        activeProjectId: scope.projectId,
        requestCorrelationId: request.correlationId,
        allowedOpportunityIds: allowedOpportunityIds,
      );
      debugPrint('IVE_GATEWAY_USED: ${response.gatewayUsed ?? 'unknown'}');

      IveActionProposal? proposal;
      if (response.proposedAction != null) {
        proposal = IveActionProposal.fromProposedAction(
          action: response.proposedAction!,
          userId: uid,
          projectName: context.project?['name'] as String? ?? 'Projeto',
          correlationId: response.correlationId,
        );
      } else if (response.legacySuggestion != null &&
          (response.legacySuggestion!.type == 'create_action' ||
              response.legacySuggestion!.type == 'action.create')) {
        try {
          proposal = IveActionProposal.fromSuggestion(
            suggestion: response.legacySuggestion!,
            userId: uid,
            projectId: scope.projectId,
            projectName: context.project?['name'] as String? ?? 'Projeto',
            allowedOpportunityIds: allowedOpportunityIds,
            correlationId: response.correlationId,
          );
        } on FormatException {
          proposal = null;
        }
      }

      final assistantTurn = CopilotTurn(
        role: 'assistant',
        content: response.responseText,
        sources: response.isV2 ? const [] : response.legacySources,
        entities: response.entities,
        confidence: response.confidence,
        actionSuggestion: response.legacySuggestion,
        timestamp: response.serverTimestamp ?? DateTime.now(),
      );
      state = state.copyWith(
        turns: [...state.turns, assistantTurn],
        loading: false,
        pendingProposal: proposal,
        clearProposal: proposal == null,
        evidence: response.evidence,
        limitations: response.limitations,
        responseId: response.responseId,
        correlationId: response.correlationId,
        gatewayUsed: response.gatewayUsed,
        sourceStatus: response.sourceStatus,
        clearError: true,
      );
    } on IveCopilotHttpException catch (error) {
      if (error.clearsSensitiveState) {
        _clearSensitiveMemory();
        state = CopilotState.unauthorized(_friendlyError(error));
      } else if (error.clearsSelectedProject) {
        await _clearSelectedProject();
        state = state.invalidProject(_friendlyError(error));
      } else {
        state = state.preserveForFailure(_friendlyError(error));
      }
    } catch (error) {
      state = state.preserveForFailure(_friendlyError(error));
    }
  }

  void cancelProposal() {
    final proposal = state.pendingProposal;
    if (proposal == null || state.executing) return;
    state = state.copyWith(
      turns: [
        ...state.turns,
        CopilotTurn(
          role: 'assistant',
          content: 'Proposta cancelada. Nenhuma ação foi criada.',
          timestamp: DateTime.now(),
        ),
      ],
      clearProposal: true,
      clearError: true,
    );
  }

  void reviseProposal({
    required String title,
    required String description,
    required int priority,
    required int impact,
    required int effort,
    DateTime? suggestedDueDate,
  }) {
    final current = state.pendingProposal;
    if (current == null || state.executing || title.trim().isEmpty) return;
    state = state.copyWith(
      pendingProposal: current.revised(
        title: title,
        description: description,
        priority: priority,
        impact: impact,
        effort: effort,
        suggestedDueDate: suggestedDueDate,
      ),
      clearError: true,
    );
  }

  void invalidateProposalForProjectChange() {
    if (state.pendingProposal == null) return;
    state = state.copyWith(
      clearProposal: true,
      error: 'A proposta foi invalidada porque o projeto ativo mudou.',
    );
  }

  Future<void> confirmProposal() async {
    final proposal = state.pendingProposal;
    if (proposal == null || state.executing) return;
    if (proposal.projectId != scope.projectId) {
      invalidateProposalForProjectChange();
      return;
    }
    if (proposal.isExpired) {
      state = state.copyWith(
        clearProposal: true,
        error: 'A proposta expirou. Solicite uma nova recomendação.',
      );
      return;
    }

    state = state.copyWith(executing: true, clearError: true);
    try {
      final result =
          await _ref.read(iveActionExecutorProvider).execute(proposal.copyWith(
                status: IveActionProposalStatus.executing,
              ));

      _ref.invalidate(actionQueueByProjectProvider(scope.projectId));
      _ref.invalidate(actionQueueProvider);
      _ref.invalidate(pendingActionsProvider);
      _ref.invalidate(ecosystemScoresProvider);
      _ref.invalidate(iveContextDataProvider);

      state = state.copyWith(
        turns: [
          ...state.turns,
          CopilotTurn(
            role: 'assistant',
            content:
                'Ação criada com sucesso no projeto ${proposal.projectName}.',
            timestamp: DateTime.now(),
          ),
        ],
        executing: false,
        clearProposal: true,
        lastExecution: result,
        clearError: true,
      );
    } catch (error) {
      state = state.preserveForFailure(_friendlyError(error));
    }
  }

  void clearHistory() => state = const CopilotState();

  @visibleForTesting
  void overrideStateForTest(CopilotState s) => state = s;

  String _friendlyError(Object error) {
    if (error is IveCopilotHttpException) return error.message;
    if (error is IveCopilotContractException) return error.message;
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Não foi possível conectar. Verifique sua conexão e tente novamente.';
    }
    if (text.contains('TimeoutException')) {
      return 'A IVE demorou para responder. Tente novamente.';
    }
    return text;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final contextCopilotProvider = StateNotifierProvider.autoDispose
    .family<ContextCopilotNotifier, CopilotState, CopilotScope>(
  (ref, scope) => ContextCopilotNotifier(ref, scope),
);
