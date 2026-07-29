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
    this.turns = const [],
    this.loading = false,
    this.error,
  });

  CopilotState copyWith({
    List<CopilotTurn>? turns,
    bool? loading,
    String? error,
  }) =>
      CopilotState(
        turns: turns ?? this.turns,
        loading: loading ?? this.loading,
        error: error,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ContextCopilotNotifier extends StateNotifier<CopilotState> {
  ContextCopilotNotifier(this._ref) : super(const CopilotState());

  final Ref _ref;
  // late: initialized on first use; test subclasses that override send() never trigger this
  late final _client = Supabase.instance.client;

  Future<void> send({
    required String message,
    required String screenName,
    required CopilotContextData context,
  }) async {
    final userTurn = CopilotTurn(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );

    _ref.read(iveMemoryProvider.notifier).addQuestion(message);

    state = state.copyWith(
      turns: [...state.turns, userTurn],
      loading: true,
    );

    // Guard: responder localmente quando não há dados suficientes
    if (context.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 300));
      final noDataTurn = CopilotTurn(
        role: 'assistant',
        content: 'Ainda não possuo dados suficientes para gerar uma recomendação confiável.\n\n'
            'O que falta:\n'
            '• Adicionar projetos ao seu portfólio\n'
            '• Executar análises de mercado\n'
            '• Registrar ações e oportunidades\n\n'
            'Configure seu perfil e adicione projetos para que eu possa ajudar com precisão.',
        confidence: 0,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        turns: [...state.turns, noDataTurn],
        loading: false,
      );
      return;
    }

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
          'message': message,
          'screen_name': screenName,
          'context': context.toMap(),
          'history': history,
          if (recentQuestions.isNotEmpty) 'recent_questions': recentQuestions,
        },
      );

      final data = res.data as Map<String, dynamic>? ?? {};

      final sources =
          (data['sources'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final entities =
          (data['entities'] as List?)?.map((e) => e.toString()).toList() ?? [];

      CopilotActionSuggestion? actionSuggestion;
      if (data['action_suggestion'] is Map) {
        actionSuggestion = CopilotActionSuggestion.fromMap(
          Map<String, dynamic>.from(data['action_suggestion'] as Map),
        );
      }

      final assistantTurn = CopilotTurn(
        role: 'assistant',
        content: data['answer'] as String? ?? '—',
        sources: sources,
        entities: entities,
        confidence: (data['confidence'] as num?)?.toInt() ?? 70,
        actionSuggestion: actionSuggestion,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        turns: [...state.turns, assistantTurn],
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: _friendlyError(e.toString()),
      );
    }
  }

  static String _friendlyError(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('429') || l.contains('rate limit') || l.contains('too many requests')) {
      return 'Serviço temporariamente indisponível. Tente novamente em alguns instantes.';
    }
    if (l.contains('401') || l.contains('unauthorized') || l.contains('jwt')) {
      return 'Sessão expirada. Saia e entre novamente no aplicativo.';
    }
    if (l.contains('timeout') || l.contains('timed out')) {
      return 'A resposta demorou muito. Tente novamente.';
    }
    if (l.contains('network') || l.contains('socket') || l.contains('connection')) {
      return 'Sem conexão. Verifique sua internet e tente novamente.';
    }
    return 'Não foi possível obter resposta. Tente novamente.';
  }

  void clearHistory() => state = const CopilotState();
}

// ── Provider ──────────────────────────────────────────────────────────────────
// Sem autoDispose: histórico do chat persiste enquanto o app estiver aberto.
// Family key = screenName → um estado por tela, nunca compartilhado.
final contextCopilotProvider =
    StateNotifierProvider.family<ContextCopilotNotifier, CopilotState, String>(
  (ref, screenName) => ContextCopilotNotifier(ref),
);
