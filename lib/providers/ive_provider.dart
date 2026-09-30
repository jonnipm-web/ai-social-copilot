import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/language_utils.dart';
import '../core/services/ive_event_bus.dart';
import '../data/models/ecosystem_score.dart';
import '../data/models/ive_event.dart';
import '../data/models/ive_issue.dart';
import '../data/models/ive_state.dart';
import '../l10n/app_localizations.dart';
import 'ecosystem_intelligence_provider.dart';
import 'ive_context_provider.dart';
import 'ive_memory_provider.dart';

// ── Screen context messages ────────────────────────────────────────────────

/// R16 — per-route IVE greetings/suggestions, in the presentation language.
/// Built from [AppLocalizations] (never hard-coded PT) so an English UI never
/// shows a Portuguese bubble. Returns an empty list for unmapped routes.
List<String> iveRouteMessages(String route, AppLocalizations l10n) {
  switch (route) {
    case AppConstants.routeProjects:
      return [l10n.ctxIveProjectsMsg1, l10n.ctxIveProjectsMsg2, l10n.ctxIveProjectsMsg3];
    case AppConstants.routeOpportunityLab:
      return [l10n.ctxIveOppLabMsg1, l10n.ctxIveOppLabMsg2, l10n.ctxIveOppLabMsg3];
    case AppConstants.routeEcosystem:
      return [l10n.ctxIveEcosystemMsg1, l10n.ctxIveEcosystemMsg2, l10n.ctxIveEcosystemMsg3];
    case AppConstants.routeEcosystemBriefing:
      return [l10n.ctxIveBriefingMsg1, l10n.ctxIveBriefingMsg2, l10n.ctxIveBriefingMsg3];
    case AppConstants.routePersonas:
      return [l10n.ctxIvePersonasMsg1, l10n.ctxIvePersonasMsg2, l10n.ctxIvePersonasMsg3];
    case AppConstants.routeKnowledge:
      return [l10n.ctxIveKnowledgeMsg1, l10n.ctxIveKnowledgeMsg2, l10n.ctxIveKnowledgeMsg3];
    case AppConstants.routeActionEngine:
      return [l10n.ctxIveActionsMsg1, l10n.ctxIveActionsMsg2, l10n.ctxIveActionsMsg3];
    case AppConstants.routeIntelligenceDebug:
      return [l10n.ctxIveDebugMsg1, l10n.ctxIveDebugMsg2, l10n.ctxIveDebugMsg3];
  }
  return const [];
}

/// R16 — deterministic context-aware bubble text, in the presentation
/// language. Pure (no Ref) so it is unit-testable per locale.
String buildIveContextMessage(IveContextData ctx, String route, AppLocalizations l10n) {
  if (ctx.healthScore == 0) return '';

  switch (route) {
    case AppConstants.routeEcosystem:
      final bottleneck = ctx.mainBottleneckName ?? l10n.ctxIveCtxBottleneckFallback;
      return l10n.ctxIveCtxEcosystem(ctx.healthScore, bottleneck);

    case AppConstants.routeProjects:
      if (ctx.topProjectName != null) {
        final tail = ctx.pendingActionsCount > 0
            ? l10n.ctxIveCtxPendingDetected(ctx.pendingActionsCount)
            : l10n.ctxIveCtxAnalyzeOpportunities;
        return '${l10n.ctxIveCtxProjectLeads(ctx.topProjectName!, ctx.topProjectScore ?? 0)} $tail';
      }
      break;

    case AppConstants.routeOpportunityLab:
      if (ctx.pendingOpportunitiesCount > 0) {
        return l10n.ctxIveCtxOppLab(ctx.pendingOpportunitiesCount);
      }
      break;

    case AppConstants.routeEcosystemBriefing:
      return l10n.ctxIveCtxBriefing(ctx.healthScore);

    case AppConstants.routeActionEngine:
      if (ctx.pendingActionsCount > 0) {
        return l10n.ctxIveCtxActions(ctx.pendingActionsCount);
      }
      break;
  }
  return '';
}

const _kExpressions = <String, IveExpression>{
  AppConstants.routeProjects:          IveExpression.excited,
  AppConstants.routeOpportunityLab:    IveExpression.excited,
  AppConstants.routeEcosystem:         IveExpression.thinking,
  AppConstants.routeEcosystemBriefing: IveExpression.happy,
  AppConstants.routePersonas:          IveExpression.winking,
  AppConstants.routeKnowledge:         IveExpression.happy,
  AppConstants.routeActionEngine:      IveExpression.thinking,
  AppConstants.routeIntelligenceDebug: IveExpression.neutral,
};

// ── Notifier ──────────────────────────────────────────────────────────────────

class IveNotifier extends StateNotifier<IveState> {
  IveNotifier(this._ref) : super(const IveState()) {
    // Escuta eventos do sistema (erros, conclusões de análise, etc.)
    _eventSub = IveEventBus.instance.stream.listen(_onEvent);

    // Escuta contexto do ecossistema — substitui ref.listen no overlay
    // IVE-COMMERCIAL-FOUNDATION-11: `null` = resumo ecosystem-wide global,
    // o caso correto para este listener (overlay montado uma única vez
    // para o app inteiro, sem projeto específico em foco).
    _ref.listen<AsyncValue<IveContextData>>(
      iveContextDataProvider(null),
      (_, next) => next.whenData((ctx) => _runSafely(() => _onContextData(ctx))),
    );

    // Mantém snapshot de memória atualizado quando scores mudam
    _ref.listen<AsyncValue<List<EcosystemScore>>>(
      ecosystemScoresProvider,
      (_, next) => next.whenData((scores) {
        final snapshot = {
          for (final s in scores) s.project.id: s.ecosystemScore,
        };
        final health =
            _ref.read(iveContextDataProvider(null)).valueOrNull?.healthScore ?? 0;
        _runSafely(() => _ref.read(iveMemoryProvider.notifier).updateEcosystemSnapshot(
              health: health,
              scores: snapshot,
            ));
      }),
    );
  }

  // GATE-17-FINAL-CLOSURE (Section 12, physical crash found 2026-09-21,
  // root cause independently confirmed by Codex read-only trace back to
  // 0f080a9 -- pre-existing, not introduced by this session's auth work) —
  // both `ref.listen` callbacks above fire whenever THEIR provider emits,
  // which can land while Flutter is mid-frame (build/layout/paint) -- most
  // commonly right after the first auth event resolves and
  // IveOverlay/IveNotifier are constructed for the very first time. Both
  // callbacks end up assigning `state =` (the ecosystem-scores one via
  // iveMemoryProvider.notifier.updateEcosystemSnapshot(...), a DIFFERENT
  // provider; the context-data one via this notifier's OWN `state =` inside
  // _onContextData/_showTransient/etc.) -- Riverpod's build-time guard
  // rejects either kind of mutation identically when it happens
  // synchronously in that window ("Tried to modify a provider while the
  // widget tree was building", surfaced as a StateNotifierListenerError on
  // IveNotifier; reproduced on every physical cold start and on sign-out,
  // and fixing only the ecosystem-scores path first was NOT sufficient --
  // this one is independently reachable). A microtask is not reliable here
  // -- it can still run before the current frame finishes;
  // addPostFrameCallback guarantees the mutation only runs once the frame
  // is fully done. `mounted` guards against this notifier being disposed
  // before the deferred callback fires.
  void _runSafely(void Function() mutate) {
    void apply() {
      if (!mounted) return;
      mutate();
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      apply();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  final Ref _ref;

  /// R16 — presentation-language strings. Read (not watched) at display
  /// time, so every bubble reflects the language active when it is shown.
  AppLocalizations get _l10n => _ref.read(appL10nProvider);
  StreamSubscription<IveEvent>? _eventSub;

  Timer? _dismissTimer;
  Timer? _cycleTimer;
  int    _msgIndex     = 0;
  String _currentRoute = '';

  // ── Live chat interaction bridge ──────────────────────────────────────────
  // Single source of truth for the "thinking/speaking" overlay: a monotonic
  // token guards against a superseded request (e.g. a stale response, or a
  // second message sent before the first replied) clobbering the visual
  // state set by a more recent one. See IveVisualStateMapper.fromIveState().
  Timer? _speakingTimer;
  int    _interactionToken = 0;
  static const _kSpeakingDuration = Duration(milliseconds: 1500);

  // ── Event Bus ─────────────────────────────────────────────────────────────

  void _onEvent(IveEvent event) {
    switch (event.type) {
      case IveEventType.assetAnalysisFailed:
      case IveEventType.assetDownloadFailed:
      case IveEventType.actionMutationFailed:
        if (event.issue != null) _showIssue(event.issue!);
        break;

      case IveEventType.assetAnalysisCompleted:
        final name = event.entityName;
        if (name != null) {
          _showTransient(_l10n.ctxIveAnalysisCompleted(name), IveExpression.excited);
        }
        break;

      case IveEventType.assetAnalysisStarted:
        final name = event.entityName;
        if (name != null) {
          _showTransient(_l10n.ctxIveAnalyzing(name), IveExpression.thinking);
        }
        break;

      case IveEventType.projectCreated:
        final name = event.entityName;
        if (name != null) {
          _showTransient(_l10n.ctxIveProjectCreated(name), IveExpression.excited);
        }
        // IVE-COMMERCIAL-QUOTA-HARDENING-13 — this used to unconditionally
        // call runAll() here, silently reserving up to 3 quota units
        // (generate-project-opportunities, generate-project-actions,
        // revenue-planner — see AutoBootstrapService.bootstrapProject)
        // for every project needing bootstrap, with no confirmation and
        // no way for the user to decline. This notifier has no
        // BuildContext to show the standard confirm dialog, so the
        // trigger moved to project_command_center_screen.dart's _save()
        // — the one screen that actually creates a project and already
        // has a BuildContext — right after a successful creation,
        // wrapped in AiExecutionController.confirm(estimatedUnits: 3).
        break;

      case IveEventType.projectDeleted:
        final name = event.entityName;
        if (name != null) {
          _showTransient(_l10n.ctxIveProjectRemoved(name), IveExpression.neutral);
        }
        break;

      case IveEventType.projectStatusChanged:
        final name   = event.entityName;
        final status = event.payload['status'] as String?;
        if (name != null && status != null) {
          final l10n  = _l10n;
          final label = status == 'active'
              ? l10n.ctxIveStatusActivated
              : status == 'paused'
                  ? l10n.ctxIveStatusPaused
                  : status == 'completed'
                      ? l10n.ctxIveStatusCompleted
                      : status;
          _showTransient(l10n.ctxIveProjectStatusChanged(name, label), IveExpression.happy);
        }
        break;

      case IveEventType.projectUpdated:
        break;

      default:
        break;
    }
  }

  void _showIssue(IveIssue issue) {
    _cycleTimer?.cancel();
    _dismissTimer?.cancel();
    state = state.copyWith(
      message:       issue.localizedMessage(_l10n),
      expression:    issue.severity == IveIssueSeverity.critical
          ? IveExpression.neutral
          : IveExpression.thinking,
      bubbleVisible: true,
      activeIssue:   issue,
    );
    // Issues ficam visíveis por 15s (em vez de 7s)
    _dismissTimer = Timer(const Duration(seconds: 15), () {
      state = state.copyWith(bubbleVisible: false, clearIssue: true);
    });
  }

  void _showTransient(String message, IveExpression expression) {
    if (state.activeIssue != null && state.bubbleVisible) return;
    state = state.copyWith(
      message:       message,
      expression:    expression,
      bubbleVisible: true,
    );
    _scheduleDismiss();
  }

  // ── Context data handler (antes no IveOverlay) ────────────────────────────

  void _onContextData(IveContextData ctx) {
    // Não sobrescreve issue ativo
    if (state.activeIssue != null && state.bubbleVisible) return;

    final alertId = ctx.alertId;
    final memory  = _ref.read(iveMemoryProvider);

    if (ctx.hasAlert && alertId.isNotEmpty && !memory.isAlertDismissed(alertId)) {
      showContextAwareMessage(ctx, _currentRoute);
    } else if (!ctx.hasAlert) {
      showContextAwareMessage(ctx, _currentRoute);
    } else {
      // Alerta já dispensado — exibe mensagem contextual como fallback
      final msg = _buildContextMessage(ctx, _currentRoute);
      if (msg.isNotEmpty) {
        final expr = _kExpressions[_currentRoute] ?? IveExpression.happy;
        state = state.copyWith(
          message:       msg,
          expression:    expr,
          bubbleVisible: true,
        );
        _scheduleDismiss();
      }
    }
  }

  // ── Route control ─────────────────────────────────────────────────────────

  // GATE-17-FINAL-CLOSURE (Section 12, physical crash, 2026-09-21) — the
  // CONFIRMED trigger (full stack trace captured via a temporary debug
  // instrumentation pass, then removed): IveRouteObserver.didPush ->
  // IveRouteObserver._notify (ive_overlay.dart) -> iveRouteNotifier.value=
  // -> _IveOverlayState._onRouteChange -> setRoute() -> here. A
  // NavigatorObserver's didPush can fire synchronously during the
  // Navigator's own FIRST mount (NavigatorState.restoreState ->
  // RestorationMixin.didChangeDependencies -> StatefulElement._firstBuild),
  // which is squarely inside Flutter's build phase -- this has nothing to
  // do with auth/Supabase timing (both of those were real but separate
  // risks, already hardened above and in app.dart's GoRouterRefreshStream;
  // neither one is what this specific crash needed). Deferred the same way
  // via _runSafely.
  void setRoute(String route) {
    if (route == _currentRoute) return;
    _currentRoute = route;
    _msgIndex     = 0;
    _runSafely(() {
      // Limpa issue ao trocar de tela
      if (state.activeIssue != null) {
        state = state.copyWith(clearIssue: true, bubbleVisible: false);
      }
      _showMessage(route, 0);
    });
    _scheduleCycle(route);
  }

  void _showMessage(String route, int index) {
    final msgs = iveRouteMessages(route, _l10n);
    if (msgs.isEmpty) {
      state = state.copyWith(bubbleVisible: false);
      return;
    }
    final msg  = msgs[index % msgs.length];
    final expr = _kExpressions[route] ?? IveExpression.happy;
    state = state.copyWith(
      screenName:    route,
      message:       msg,
      expression:    expr,
      bubbleVisible: true,
    );
    _scheduleDismiss();
  }

  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 7), () {
      state = state.copyWith(bubbleVisible: false);
    });
  }

  void _scheduleCycle(String route) {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      // Não interrompe issue ativo
      if (state.activeIssue != null && state.bubbleVisible) return;
      _msgIndex++;
      _showMessage(route, _msgIndex);
    });
  }

  // ── Live chat interaction bridge (IVE-AVATAR-STATE-MACHINE-02) ────────────
  // Called by ContextCopilotNotifier.send() around the real request
  // lifecycle. Does NOT snapshot/restore business state: `expression` and
  // `activeIssue` keep live-updating in the background (via the listeners
  // above) while `interaction` is set, so clearing it always recomputes
  // against current state instead of a stale one.

  /// Call when a copilot request starts. Returns a token that must be
  /// passed to [completeInteraction] — a response for an older token is
  /// ignored, so a superseded request can never overwrite a newer one's
  /// visual state.
  int beginThinking() {
    final token = ++_interactionToken;
    if (!mounted) return token;
    _speakingTimer?.cancel();
    state = state.copyWith(interaction: IveInteractionState.thinking);
    return token;
  }

  /// Call when the request settles (success or failure). No-op if [token]
  /// was superseded by a newer [beginThinking] call in the meantime.
  void completeInteraction(int token, {required bool success}) {
    if (token != _interactionToken || !mounted) return;

    if (!success) {
      state = state.copyWith(clearInteraction: true);
      return;
    }

    state = state.copyWith(interaction: IveInteractionState.speaking);
    _speakingTimer?.cancel();
    _speakingTimer = Timer(_kSpeakingDuration, () {
      if (!mounted || token != _interactionToken) return;
      state = state.copyWith(clearInteraction: true);
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void dismissBubble() {
    _dismissTimer?.cancel();
    state = state.copyWith(bubbleVisible: false, clearIssue: true);
  }

  void clearActiveIssue() {
    state = state.copyWith(clearIssue: true);
  }

  void showMessage(
    String message, {
    IveExpression expression = IveExpression.happy,
  }) {
    state = state.copyWith(
      message:       message,
      expression:    expression,
      bubbleVisible: true,
    );
    _scheduleDismiss();
  }

  void showContextAwareMessage(IveContextData ctx, String route) {
    if (ctx.hasAlert && ctx.alertMessage.isNotEmpty) {
      state = state.copyWith(
        message:       ctx.alertMessage,
        expression:    IveExpression.neutral,
        bubbleVisible: true,
      );
      _scheduleDismiss();
      return;
    }

    final msg = _buildContextMessage(ctx, route);
    if (msg.isNotEmpty) {
      final expr = _kExpressions[route] ?? IveExpression.happy;
      state = state.copyWith(
        message:       msg,
        expression:    expr,
        bubbleVisible: true,
      );
      _scheduleDismiss();
    }
  }

  String _buildContextMessage(IveContextData ctx, String route) =>
      buildIveContextMessage(ctx, route, _l10n);

  @override
  void dispose() {
    _eventSub?.cancel();
    _dismissTimer?.cancel();
    _cycleTimer?.cancel();
    _speakingTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final iveProvider = StateNotifierProvider<IveNotifier, IveState>(
  (ref) => IveNotifier(ref),
);
