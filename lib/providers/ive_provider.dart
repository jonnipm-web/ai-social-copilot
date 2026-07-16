import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../data/models/ive_state.dart';

// ── Screen context messages ────────────────────────────────────────────────

const _kMessages = <String, List<String>>{
  AppConstants.routeProjects: [
    'Quer saber qual projeto tem maior potencial?',
    'Posso analisar seu portfólio agora.',
    'Algum projeto precisa de atenção especial?',
  ],
  AppConstants.routeOpportunityLab: [
    'Encontrei oportunidades interessantes para você.',
    'Posso explicar qual tem maior ROI.',
    'Quer que eu priorize as melhores oportunidades?',
  ],
  AppConstants.routeEcosystem: [
    'Quer entender como esse score foi calculado?',
    'Posso simular cenários para você.',
    'Alguma decisão estratégica que posso ajudar?',
  ],
  AppConstants.routeEcosystemBriefing: [
    'Posso explicar este relatório.',
    'Quer um resumo executivo desta semana?',
    'Posso destacar os pontos mais críticos.',
  ],
  AppConstants.routePersonas: [
    'Qual persona está avançando mais rápido?',
    'Posso comparar o desempenho das suas personas.',
    'Quer explorar novos nichos para suas marcas?',
  ],
  AppConstants.routeKnowledge: [
    'Posso mostrar o que você mais aprendeu.',
    'Qual documento mais impacta seu projeto?',
    'Quer que eu conecte conhecimentos entre projetos?',
  ],
  AppConstants.routeActionEngine: [
    'Quais ações estão mais atrasadas?',
    'Posso ajudar a priorizar sua fila de ações.',
    'Quer um plano de execução para esta semana?',
  ],
  AppConstants.routeIntelligenceDebug: [
    'Posso explicar qualquer score ou cálculo.',
    'Quer entender por que um score mudou?',
    'Posso auditar a lógica de qualquer indicador.',
  ],
};

const _kExpressions = <String, IveExpression>{
  AppConstants.routeProjects:         IveExpression.excited,
  AppConstants.routeOpportunityLab:   IveExpression.excited,
  AppConstants.routeEcosystem:        IveExpression.thinking,
  AppConstants.routeEcosystemBriefing:         IveExpression.happy,
  AppConstants.routePersonas:         IveExpression.winking,
  AppConstants.routeKnowledge:        IveExpression.happy,
  AppConstants.routeActionEngine:     IveExpression.thinking,
  AppConstants.routeIntelligenceDebug: IveExpression.neutral,
};

// ── Notifier ──────────────────────────────────────────────────────────────────

class IveNotifier extends StateNotifier<IveState> {
  IveNotifier() : super(const IveState());

  Timer? _dismissTimer;
  Timer? _cycleTimer;
  int    _msgIndex = 0;
  String _currentRoute = '';

  void setRoute(String route) {
    if (route == _currentRoute) return;
    _currentRoute = route;
    _msgIndex = 0;
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
      _msgIndex++;
      _showMessage(route, _msgIndex);
    });
  }

  void dismissBubble() {
    _dismissTimer?.cancel();
    state = state.copyWith(bubbleVisible: false);
  }

  void showMessage(String message, {IveExpression expression = IveExpression.happy}) {
    state = state.copyWith(
      message:       message,
      expression:    expression,
      bubbleVisible: true,
    );
    _scheduleDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _cycleTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final iveProvider = StateNotifierProvider<IveNotifier, IveState>(
  (_) => IveNotifier(),
);
