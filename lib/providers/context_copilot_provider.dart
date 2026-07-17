import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../data/models/copilot_context_data.dart';
import '../data/models/copilot_turn.dart';
import 'ive_memory_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

class CopilotState {
  final List<CopilotTurn> turns;
  final bool loading;
  final String? error;

  const CopilotState({
    this.turns   = const [],
    this.loading = false,
    this.error,
  });

  CopilotState copyWith({
    List<CopilotTurn>? turns,
    bool? loading,
    String? error,
  }) =>
      CopilotState(
        turns:   turns   ?? this.turns,
        loading: loading ?? this.loading,
        error:   error,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ContextCopilotNotifier extends StateNotifier<CopilotState> {
  ContextCopilotNotifier(this._ref) : super(const CopilotState());

  final Ref _ref;
  final _client = Supabase.instance.client;

  Future<void> send({
    required String message,
    required String screenName,
    required CopilotContextData context,
  }) async {
    final userTurn = CopilotTurn(
      role:      'user',
      content:   message,
      timestamp: DateTime.now(),
    );

    // Persiste pergunta na memória da IVE — alimenta contexto futuro
    _ref.read(iveMemoryProvider.notifier).addQuestion(message);

    state = state.copyWith(
      turns:   [...state.turns, userTurn],
      loading: true,
    );

    try {
      final history = state.turns
          .where((t) => t.role == 'user' || t.role == 'assistant')
          .map((t) => t.toHistoryMap())
          .toList();

      // Perguntas recentes da memória enriquecem o contexto da IA
      final recentQuestions = _ref.read(iveMemoryProvider).recentQuestions;

      final res = await _client.functions.invoke(
        AppConstants.edgeFunctionContextCopilot,
        body: {
          'message':          message,
          'screen_name':      screenName,
          'context':          context.toMap(),
          'history':          history,
          if (recentQuestions.isNotEmpty)
            'recent_questions': recentQuestions,
        },
      );

      final data = res.data as Map<String, dynamic>? ?? {};

      final sources  = (data['sources']  as List?)?.map((e) => e.toString()).toList() ?? [];
      final entities = (data['entities'] as List?)?.map((e) => e.toString()).toList() ?? [];

      CopilotActionSuggestion? actionSuggestion;
      if (data['action_suggestion'] is Map) {
        actionSuggestion = CopilotActionSuggestion.fromMap(
          Map<String, dynamic>.from(data['action_suggestion'] as Map),
        );
      }

      final assistantTurn = CopilotTurn(
        role:             'assistant',
        content:          data['answer'] as String? ?? '—',
        sources:          sources,
        entities:         entities,
        confidence:       (data['confidence'] as num?)?.toInt() ?? 70,
        actionSuggestion: actionSuggestion,
        timestamp:        DateTime.now(),
      );

      state = state.copyWith(
        turns:   [...state.turns, assistantTurn],
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error:   e.toString(),
      );
    }
  }

  void clearHistory() => state = const CopilotState();
}

// ── Provider ──────────────────────────────────────────────────────────────────
// Sem autoDispose: histórico do chat persiste enquanto o app estiver aberto.
// Family key = screenName → um estado por tela, nunca compartilhado.
final contextCopilotProvider = StateNotifierProvider.family<
    ContextCopilotNotifier, CopilotState, String>(
  (ref, screenName) => ContextCopilotNotifier(ref),
);
