import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/diagnostics/diagnostic_logger_service.dart';
import '../core/diagnostics/diagnostic_models.dart';
import '../data/models/copilot_context_data.dart';
import '../data/models/copilot_turn.dart';
import '../data/models/ive_intelligence.dart';
import '../data/services/ive_intelligence_service.dart';
import 'diagnostic_session_provider.dart';
import 'ive_memory_provider.dart';
import 'ive_provider.dart';
import 'language_provider.dart';
import 'quota_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

/// IVE-INTELLIGENCE-CORE-01 — routes the chat through the server IVE
/// Intelligence Core (`ive-intelligence`) instead of the legacy
/// client-built context. Compile-time switch
/// (`--dart-define=IVE_INTELLIGENCE_CORE=true`): OFF by default, because the
/// new Edge Function is not deployed; the commercial path stays unchanged.
const bool kIveIntelligenceCoreEnabled = bool.fromEnvironment('IVE_INTELLIGENCE_CORE');

final iveIntelligenceServiceProvider = Provider<IveIntelligenceService>((_) => IveIntelligenceService());

/// Overridable in tests; production value is the compile-time switch.
final iveIntelligenceCoreEnabledProvider = Provider<bool>((_) => kIveIntelligenceCoreEnabled);

class CopilotState {
  final List<CopilotTurn> turns;
  final bool loading;
  final String? error;

  /// Structured failure from the Intelligence Core (translated by the UI).
  final IveFailure? failure;

  const CopilotState({
    this.turns   = const [],
    this.loading = false,
    this.error,
    this.failure,
  });

  CopilotState copyWith({
    List<CopilotTurn>? turns,
    bool? loading,
    String? error,
    IveFailure? failure,
  }) =>
      CopilotState(
        turns:   turns   ?? this.turns,
        loading: loading ?? this.loading,
        error:   error,
        failure: failure,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ContextCopilotNotifier extends StateNotifier<CopilotState> {
  ContextCopilotNotifier(this._ref) : super(const CopilotState());

  final Ref _ref;
  // IVE-COMMERCIAL-FOUNDATION-11 — lazy getter, not an eager field
  // initializer: the old `final _client = Supabase.instance.client;` ran
  // at CONSTRUCTION time, so merely instantiating a ContextCopilotNotifier
  // (e.g. via `ProviderContainer.read(contextCopilotProvider(key).notifier)`
  // in a test that never calls `send()`) crashed with "You must
  // initialize the supabase instance before calling Supabase.instance" —
  // Supabase.initialize() is never called in a plain widget/unit test
  // process. Deferring the access to first real use (inside `send()`,
  // exactly like the app's own normal flow, where Supabase is always
  // initialized long before any chat message is sent) fixes this without
  // any production behavior change.
  SupabaseClient get _client => Supabase.instance.client;

  /// IVE-COMMERCIAL-QUOTA-HARDENING-13 — [idempotencyKey] is optional so
  /// any other/future caller keeps compiling, but the real call site
  /// through context_copilot_widget.dart's `_CopilotSheet` (the single
  /// choke point this mission gates) now supplies one, generated once per
  /// confirmed chat session and reused for that session's messages — see
  /// `_CopilotSheetState._ensureConfirmed`.
  Future<void> send({
    required String message,
    required String screenName,
    required CopilotContextData context,
    String? idempotencyKey,
  }) async {
    if (_ref.read(iveIntelligenceCoreEnabledProvider)) {
      return _sendViaCore(
        message: message,
        screenName: screenName,
        context: context,
        idempotencyKey: idempotencyKey,
      );
    }

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

    // Drives the Avatar's visual state through the real request lifecycle
    // (thinking while awaiting, speaking while presenting the answer). The
    // token guards against a stale response overwriting a newer request's
    // visual state — see IveNotifier.beginThinking/completeInteraction.
    final interactionToken = _ref.read(iveProvider.notifier).beginThinking();

    // IVE-COMMERCIAL-OBSERVABILITY-07A — IVE + AI categories share this one
    // call site (context-copilot IS the IVE assistant's backend request).
    // correlationId links the "started" event to whichever of
    // success/failure follows, across the await below. Never logs the
    // question/answer text itself — only shape (lengths/counts) and
    // outcome, per mission section 04/05.
    //
    // IVE-EXPERIENCE-V1-06 (Section 08) — prefer the ID the interaction was
    // actually opened with (`IveInteractionRequest.correlationId`, carried
    // on `context` since `showCopilotChat`'s `withIdentity` call) instead of
    // minting a fresh one here. One user-initiated interaction now keeps ONE
    // correlation identity end-to-end: UI → IveInteractionRequest →
    // CopilotContextData → this diagnostic event → the Edge Function request
    // body (`context.toMap()`'s `identity.correlation_id`) → the Edge
    // Function's own log line. Falls back to a new ID only for a
    // `CopilotContextData` built without identity (there is no such call
    // site today — `showCopilotChat` is the sole choke point — but `send()`
    // is public API and must not crash if one is ever missing).
    final correlationId = context.correlationId ?? newDiagnosticCorrelationId();
    final stopwatch = Stopwatch()..start();
    _ref.read(diagnosticSessionProvider.notifier).logEvent(
      category: DiagnosticCategory.ive,
      eventName: 'copilot_request_started',
      operation: screenName,
      correlationId: correlationId,
      status: 'started',
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
          // IVE-COMMERCIAL-QUOTA-HARDENING-13 (Codex Gate 2 round-2
          // finding) — [idempotencyKey] was accepted as a parameter and
          // documented as wired, but never actually reached this body:
          // the single confirmed choke point in context_copilot_widget.
          // dart was silently falling back to the legacy unconditional
          // reserve path on every message despite showing a confirmation
          // dialog.
          if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
        },
      );

      // IVE-INTELLIGENCE-CORE-01 — the conversation may have been disposed
      // while awaiting (sign-out / user change resets it): a late response
      // must neither touch a disposed notifier nor reach another session.
      if (!mounted) return;

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
      _ref.read(iveProvider.notifier).completeInteraction(interactionToken, success: true);
      _ref.read(diagnosticSessionProvider.notifier).logEvent(
        category: DiagnosticCategory.ai,
        eventName: 'copilot_request_completed',
        operation: screenName,
        correlationId: correlationId,
        status: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
        metadata: {
          'response_length': (data['answer'] as String? ?? '').length,
          'grounding_count': sources.length,
        },
      );

      // IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — o overlay da IVE fica
      // visível em toda tela (inclusive Conta/Upgrade) sem nunca desmontar
      // currentQuotaProvider, então uma cota reservada aqui pelo backend
      // nunca aparecia sozinha na tela de Conta já aberta. Invalida o
      // provider para refletir o consumo real assim que o backend confirma
      // a resposta — o servidor continua sendo a única fonte de verdade,
      // isto só força a UI a reconsultá-lo.
      _ref.invalidate(currentQuotaProvider);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        error:   e.toString(),
      );
      _ref.read(iveProvider.notifier).completeInteraction(interactionToken, success: false);
      _ref.read(diagnosticSessionProvider.notifier).logEvent(
        category: DiagnosticCategory.ai,
        eventName: 'copilot_request_completed',
        operation: screenName,
        correlationId: correlationId,
        status: 'failure',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
      );
    }
  }

  /// IVE-INTELLIGENCE-CORE-01 — Android and Web send the SAME minimal
  /// request; the server assembles identity, capabilities, project,
  /// knowledge and memory itself. Only the project id (a request the server
  /// verifies) is taken from the screen's context; the screen-built
  /// documents/opportunities/etc. and device-local recent questions are not
  /// sent at all.
  Future<void> _sendViaCore({
    required String message,
    required String screenName,
    required CopilotContextData context,
    String? idempotencyKey,
  }) async {
    final previousTurns = state.turns;
    final userTurn = CopilotTurn(role: 'user', content: message, timestamp: DateTime.now());
    state = state.copyWith(turns: [...previousTurns, userTurn], loading: true);
    final interactionToken = _ref.read(iveProvider.notifier).beginThinking();
    final correlationId = context.correlationId ?? newDiagnosticCorrelationId();
    final stopwatch = Stopwatch()..start();

    final request = IveIntelligenceRequest(
      message: message,
      surface: currentIveSurface(),
      locale: iveLocaleFor(_ref.read(languageProvider).languageCode),
      projectId: context.projectId,
      conversation: _historyForCore(previousTurns),
      sourceModule: context.sourceModule ?? screenName,
      idempotencyKey: idempotencyKey,
      correlationId: correlationId,
    );

    try {
      final result = await _ref.read(iveIntelligenceServiceProvider).ask(request);
      // IVE-INTELLIGENCE-CORE-01 — the conversation may have been disposed
      // while awaiting (sign-out / user change resets it): a late response
      // must neither touch a disposed notifier nor reach another session.
      if (!mounted) return;
      final assistantTurn = CopilotTurn(
        role: 'assistant',
        content: result.answer ?? '',
        sources: result.sourceLabels,
        requiresAef: result.requiresAef,
        suggestedActions: result.suggestedActions,
        degradedContext: result.degraded.isNotEmpty,
        actionIntent: result.actionIntent,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(turns: [...state.turns, assistantTurn], loading: false);
      _ref.read(iveProvider.notifier).completeInteraction(interactionToken, success: true);
      _ref.read(diagnosticSessionProvider.notifier).logEvent(
        category: DiagnosticCategory.ai,
        eventName: 'ive_core_request_completed',
        operation: screenName,
        correlationId: correlationId,
        status: result.requiresAef ? 'requires_aef' : 'success',
        durationMs: stopwatch.elapsedMilliseconds,
        metadata: {'sources': result.sourceLabels.length, 'degraded': result.degraded.length},
      );
      if (!result.requiresAef) _ref.invalidate(currentQuotaProvider);
    } catch (e) {
      if (!mounted) return;
      final failure = e is IveIntelligenceException ? e.failure : IveFailure.unknown;
      state = state.copyWith(loading: false, failure: failure);
      _ref.read(iveProvider.notifier).completeInteraction(interactionToken, success: false);
      _ref.read(diagnosticSessionProvider.notifier).logEvent(
        category: DiagnosticCategory.ai,
        eventName: 'ive_core_request_completed',
        operation: screenName,
        correlationId: correlationId,
        status: 'failure',
        durationMs: stopwatch.elapsedMilliseconds,
        metadata: {'failure': failure.name},
      );
    }
  }

  /// The visible transcript minus every AEF exchange (the consequential
  /// request AND the AEF notice): the server re-scans recent user turns for
  /// consequential intents, so resending "publique o post" would keep
  /// routing the next, unrelated questions to AEF.
  static List<IveConversationTurn> _historyForCore(List<CopilotTurn> turns) {
    final out = <IveConversationTurn>[];
    for (var i = 0; i < turns.length; i++) {
      final t = turns[i];
      if (t.requiresAef) continue;
      final nextIsAef = i + 1 < turns.length && turns[i + 1].requiresAef;
      if (t.role == 'user' && nextIsAef) continue;
      out.add(IveConversationTurn(role: t.role, content: t.content));
    }
    return out;
  }

  void clearHistory() => state = const CopilotState();
}

// ── Provider ──────────────────────────────────────────────────────────────────
// Sem autoDispose: histórico do chat persiste enquanto o app estiver aberto.
//
// IVE-COMMERCIAL-FOUNDATION-11 (Codex Gate 2, P1, ACCEPTED) — a chave era
// SOMENTE `screenName` (String). O Project Context Contract escopa
// corretamente o GROUNDING (`CopilotContextData.projectId`) por projeto,
// mas com a chave antiga o HISTÓRICO DE CONVERSA (`state.turns`, enviado
// como `history` em toda chamada — ver ContextCopilotNotifier.send) era
// compartilhado entre projetos diferentes na MESMA tela: perguntar sobre
// o Projeto A em "Decisões" e depois sobre o Projeto B na mesma tela
// reenviava as perguntas/respostas do Projeto A junto com o contexto
// (correto) do Projeto B — exatamente o vazamento que a missão Seção 04
// proíbe ("Project A → IVE then Project B → IVE must never reuse Project
// A's question/context"). Chave agora é um record `(screenName,
// projectId)`: trocar de projeto na mesma tela é uma chave DIFERENTE,
// logo uma conversa nova, sem precisar de nenhuma lógica de reset manual
// (mesmo raciocínio já aplicado a iveContextDataProvider).
typedef CopilotConversationKey = (String screenName, String? projectId);

final contextCopilotProvider = StateNotifierProvider.family<
    ContextCopilotNotifier, CopilotState, CopilotConversationKey>(
  (ref, key) => ContextCopilotNotifier(ref),
);
