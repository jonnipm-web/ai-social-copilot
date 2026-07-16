import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../data/models/simulation_result.dart';
import 'ive_context_provider.dart';
import 'ecosystem_intelligence_provider.dart';

// ── Estado da simulação ────────────────────────────────────────────────────────

class DecisionSimulatorState {
  final bool              isLoading;
  final SimulationResult? result;
  final String?           error;
  final String            lastScenario;

  const DecisionSimulatorState({
    this.isLoading    = false,
    this.result,
    this.error,
    this.lastScenario = '',
  });

  DecisionSimulatorState copyWith({
    bool?              isLoading,
    SimulationResult?  result,
    String?            error,
    String?            lastScenario,
  }) =>
      DecisionSimulatorState(
        isLoading:    isLoading    ?? this.isLoading,
        result:       result       ?? this.result,
        error:        error        ?? this.error,
        lastScenario: lastScenario ?? this.lastScenario,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DecisionSimulatorNotifier
    extends StateNotifier<DecisionSimulatorState> {
  DecisionSimulatorNotifier(this._ref)
      : super(const DecisionSimulatorState());

  final Ref _ref;

  Future<void> simulate(String scenario) async {
    if (scenario.trim().isEmpty) return;

    state = state.copyWith(
      isLoading:    true,
      error:        null,
      lastScenario: scenario,
    );

    try {
      // Agrega dados do ecossistema para contexto
      final ctx = _ref.read(iveContextDataProvider).valueOrNull;
      final scores = await _ref.read(ecosystemScoresProvider.future);

      final ecosystemPayload = {
        'healthScore':           ctx?.healthScore            ?? 0,
        'projectCount':          ctx?.projectCount           ?? 0,
        'pendingActions':        ctx?.pendingActionsCount    ?? 0,
        'pendingOpportunities':  ctx?.pendingOpportunitiesCount ?? 0,
      };

      final projectsPayload = scores.map((s) => {
        'name':              s.project.name,
        'ecosystemScore':    s.ecosystemScore,
        'executionScore':    s.executionScore,
        'opportunityScore':  s.opportunityScore,
      }).toList();

      final response = await Supabase.instance.client.functions.invoke(
        AppConstants.edgeFunctionDecisionSimulator,
        body: {
          'scenario':  scenario,
          'ecosystem': ecosystemPayload,
          'projects':  projectsPayload,
        },
      );

      if (response.status != 200) {
        throw Exception('Erro ${response.status} na simulação');
      }

      final data = response.data is String
          ? json.decode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      if (data['error'] != null) throw Exception(data['error']);

      state = state.copyWith(
        isLoading: false,
        result:    SimulationResult.fromJson(data),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     e.toString(),
      );
    }
  }

  void reset() => state = const DecisionSimulatorState();
}

// ── Provider global ───────────────────────────────────────────────────────────

final decisionSimulatorProvider =
    StateNotifierProvider<DecisionSimulatorNotifier, DecisionSimulatorState>(
  (ref) => DecisionSimulatorNotifier(ref),
);
