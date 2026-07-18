import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../data/models/copilot_context_data.dart';
import '../data/models/copilot_turn.dart';
import '../features/ive/domain/ive_action_proposal.dart';
import '../features/ive/services/ive_action_executor.dart';
import 'action_queue_provider.dart';
import 'ecosystem_intelligence_provider.dart';
import 'ive_context_provider.dart';
import 'ive_memory_provider.dart';

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

  const CopilotState({
    this.turns = const [],
    this.loading = false,
    this.error,
    this.pendingProposal,
    this.lastExecution,
    this.executing = false,
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
      );
}

class ContextCopilotNotifier extends StateNotifier<CopilotState> {
  ContextCopilotNotifier(this._ref, this.scope) : super(const CopilotState()) {
    _authSub = _client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut ||
          event.session?.user.id != scope.userId) {
        clearHistory();
      }
    });
  }

  final Ref _ref;
  final CopilotScope scope;
  final _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;

  Future<void> send({
    required String message,
    required CopilotContextData context,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid != scope.userId) {
      state = state.copyWith(error: 'Sessão inválida. Entre novamente.');
      return;
    }
    if (scope.projectId.isEmpty || context.projectId != scope.projectId) {
      state = state.copyWith(
        error: 'Selecione um projeto antes de conversar com a IVE.',
      );
      return;
    }

    final userTurn = CopilotTurn(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );
    _ref.read(iveMemoryProvider.notifier).addQuestion(message);
    state = state.copyWith(
      turns: [...state.turns, userTurn],
      loading: true,
      clearError: true,
      clearExecution: true,
    );

    try {
      final history = state.turns
          .where((turn) => turn.role == 'user' || turn.role == 'assistant')
          .map((turn) => turn.toHistoryMap())
          .toList();
      final recentQuestions = _ref.read(iveMemoryProvider).recentQuestions;

      final response = await _client.functions.invoke(
        AppConstants.edgeFunctionContextCopilot,
        body: {
          'message': message,
          'screen_name': scope.screenName,
          'user_id': uid,
          'project_id': scope.projectId,
          'context': context.toMap(),
          'history': history,
          if (recentQuestions.isNotEmpty) 'recent_questions': recentQuestions,
        },
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      if (data['error'] != null) throw Exception(data['error']);

      final sources =
          (data['sources'] as List?)?.map((item) => item.toString()).toList() ??
              [];
      final entities = (data['entities'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          [];
      CopilotActionSuggestion? suggestion;
      if (data['action_suggestion'] is Map) {
        suggestion = CopilotActionSuggestion.fromMap(
          Map<String, dynamic>.from(data['action_suggestion'] as Map),
        );
      }

      IveActionProposal? proposal;
      if (suggestion != null &&
          (suggestion.type == 'create_action' ||
              suggestion.type == 'action.create')) {
        final allowedOpportunityIds = context.opportunities
            .map((item) => item['id'])
            .whereType<String>()
            .toSet();
        proposal = IveActionProposal.fromSuggestion(
          suggestion: suggestion,
          userId: uid,
          projectId: scope.projectId,
          projectName: context.project?['name'] as String? ?? 'Projeto',
          allowedOpportunityIds: allowedOpportunityIds,
        );
      }

      final assistantTurn = CopilotTurn(
        role: 'assistant',
        content: data['answer'] as String? ?? 'Não recebi uma resposta válida.',
        sources: sources,
        entities: entities,
        confidence: _confidence(data['confidence']),
        actionSuggestion: suggestion,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        turns: [...state.turns, assistantTurn],
        loading: false,
        pendingProposal: proposal,
        clearProposal: proposal == null,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: _friendlyError(error),
      );
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
      state = state.copyWith(
        executing: false,
        error: _friendlyError(error),
      );
    }
  }

  void clearHistory() => state = const CopilotState();

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Não foi possível conectar. Verifique sua conexão e tente novamente.';
    }
    return text;
  }

  int _confidence(dynamic value) {
    if (value is! num) return 0;
    return value.toInt().clamp(0, 100);
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
