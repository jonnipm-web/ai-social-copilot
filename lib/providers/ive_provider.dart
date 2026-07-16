import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/services/ive_event_bus.dart';
import '../data/models/ecosystem_score.dart';
import '../data/models/ive_event.dart';
import '../data/models/ive_issue.dart';
import '../data/models/ive_state.dart';
import 'auto_bootstrap_provider.dart';
import 'ecosystem_intelligence_provider.dart';
import 'ive_context_provider.dart';
import 'ive_memory_provider.dart';

// ── Screen context messages ────────────────────────────────────────────────

const _kMessages = <String, List<String>>{
  AppConstants.routeProjects: [
    'Olá! Sou a IVE, sua consultora executiva. Posso analisar seu portfólio agora.',
    'Quer saber qual projeto tem mais potencial de escala neste momento?',
    'Identifico padrões entre seus projetos. Alguma dúvida estratégica?',
  ],
  AppConstants.routeOpportunityLab: [
    'Identifiquei oportunidades com alto ROI nesta lista. Posso priorizar para você.',
    'Cada oportunidade aqui tem critérios mensuráveis. Posso explicar qualquer uma.',
    'Quer que eu indique quais oportunidades executar primeiro esta semana?',
  ],
  AppConstants.routeEcosystem: [
    'Este é seu centro de decisão. Posso explicar qualquer score em linguagem simples.',
    'Vejo projetos com potencial não explorado. Quer uma análise detalhada?',
    'Posso simular o impacto de aprovar oportunidades ou concluir ações.',
  ],
  AppConstants.routeEcosystemBriefing: [
    'Seu briefing executivo está pronto. Posso destacar o que é mais urgente.',
    'Quer que eu traduza este relatório em próximos passos concretos?',
    'Posso identificar o que mudou esta semana e por quê.',
  ],
  AppConstants.routePersonas: [
    'Suas personas são sua presença no mercado. Posso comparar o desempenho de cada uma.',
    'Quer saber qual persona tem maior potencial de crescimento agora?',
    'Posso recomendar estratégias específicas para cada nicho.',
  ],
  AppConstants.routeKnowledge: [
    'Seu cofre de conhecimento alimenta toda a inteligência do sistema.',
    'Qual documento quer que eu analise ou conecte com seus projetos?',
    'Posso mostrar quais conhecimentos estão gerando mais insights.',
  ],
  AppConstants.routeActionEngine: [
    'Sua fila de ações determina sua velocidade de execução.',
    'Posso ajudar a priorizar: quais ações têm maior impacto no score?',
    'Quer que eu identifique o que está bloqueando seu progresso?',
  ],
  AppConstants.routeIntelligenceDebug: [
    'Centro de observabilidade completo. Posso auditar qualquer cálculo.',
    'Quer entender como um score foi gerado? Basta perguntar.',
    'Posso rastrear a origem de qualquer dado ou recomendação.',
  ],
};

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
    _ref.listen<AsyncValue<IveContextData>>(
      iveContextDataProvider,
      (_, next) => next.whenData(_onContextData),
    );

    // Mantém snapshot de memória atualizado quando scores mudam
    _ref.listen<AsyncValue<List<EcosystemScore>>>(
      ecosystemScoresProvider,
      (_, next) => next.whenData((scores) {
        final snapshot = {
          for (final s in scores) s.project.id: s.ecosystemScore,
        };
        final health =
            _ref.read(iveContextDataProvider).valueOrNull?.healthScore ?? 0;
        _ref
            .read(iveMemoryProvider.notifier)
            .updateEcosystemSnapshot(health: health, scores: snapshot);
      }),
    );
  }

  final Ref _ref;
  StreamSubscription<IveEvent>? _eventSub;

  Timer? _dismissTimer;
  Timer? _cycleTimer;
  int    _msgIndex     = 0;
  String _currentRoute = '';

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
          _showTransient('Análise de "$name" concluída!', IveExpression.excited);
        }
        break;

      case IveEventType.assetAnalysisStarted:
        final name = event.entityName;
        if (name != null) {
          _showTransient('Analisando "$name"...', IveExpression.thinking);
        }
        break;

      case IveEventType.projectCreated:
        final name = event.entityName;
        if (name != null) {
          _showTransient(
            'Projeto "$name" criado! Iniciando análise automática...',
            IveExpression.excited,
          );
        }
        _ref.read(autoBootstrapNotifierProvider.notifier).runAll();
        break;

      case IveEventType.projectDeleted:
        final name = event.entityName;
        if (name != null) {
          _showTransient('Projeto "$name" removido.', IveExpression.neutral);
        }
        break;

      case IveEventType.projectStatusChanged:
        final name   = event.entityName;
        final status = event.payload['status'] as String?;
        if (name != null && status != null) {
          final label = status == 'active'
              ? 'ativado'
              : status == 'paused'
                  ? 'pausado'
                  : status == 'completed'
                      ? 'concluído'
                      : status;
          _showTransient('"$name" $label.', IveExpression.happy);
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
      message:       issue.userMessage,
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

  void setRoute(String route) {
    if (route == _currentRoute) return;
    _currentRoute = route;
    _msgIndex     = 0;
    // Limpa issue ao trocar de tela
    if (state.activeIssue != null) {
      state = state.copyWith(clearIssue: true, bubbleVisible: false);
    }
    _showMessage(route, 0);
    _scheduleCycle(route);
  }

  void _showMessage(String route, int index) {
    final msgs = _kMessages[route];
    if (msgs == null || msgs.isEmpty) {
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

  String _buildContextMessage(IveContextData ctx, String route) {
    if (ctx.healthScore == 0) return '';

    switch (route) {
      case AppConstants.routeEcosystem:
        final bottleneck = ctx.mainBottleneckName ?? 'execução';
        return 'Ecossistema em ${ctx.healthScore}/100. '
               'Principal gargalo: $bottleneck. '
               'Posso detalhar como melhorar.';

      case AppConstants.routeProjects:
        if (ctx.topProjectName != null) {
          return '${ctx.topProjectName} lidera com score ${ctx.topProjectScore}. '
                 '${ctx.pendingActionsCount > 0 ? "${ctx.pendingActionsCount} ações pendentes detectadas." : "Quer analisar oportunidades?"}';
        }
        break;

      case AppConstants.routeOpportunityLab:
        if (ctx.pendingOpportunitiesCount > 0) {
          return '${ctx.pendingOpportunitiesCount} oportunidades aguardando sua avaliação. '
                 'Posso priorizar as de maior ROI.';
        }
        break;

      case AppConstants.routeEcosystemBriefing:
        return 'Briefing gerado com saúde geral em ${ctx.healthScore}/100. '
               'Posso traduzir os dados em ações concretas.';

      case AppConstants.routeActionEngine:
        if (ctx.pendingActionsCount > 0) {
          return '${ctx.pendingActionsCount} ações pendentes. '
                 'Posso identificar as de maior impacto no score de execução.';
        }
        break;
    }
    return '';
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _dismissTimer?.cancel();
    _cycleTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final iveProvider = StateNotifierProvider<IveNotifier, IveState>(
  (ref) => IveNotifier(ref),
);
