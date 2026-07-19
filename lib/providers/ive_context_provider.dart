import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/copilot_context_data.dart';
import 'action_queue_provider.dart';
import 'ecosystem_intelligence_provider.dart';
import 'knowledge_provider.dart';
import 'opportunity_lab_provider.dart';
import 'profile_provider.dart';
import 'selected_project_provider.dart';

/// Snapshot estritamente limitado ao usuário autenticado e ao projeto ativo.
class IveContextData {
  final String userId;
  final String userName;
  final String? activeProjectId;
  final String? activeProjectName;
  final String? activeProjectDescription;
  final String? activeProjectType;
  final String? activeProjectStatus;
  final int healthScore;
  final int opportunityScore;
  final int marketScore;
  final int strategicFit;
  final int synergyScore;
  final int roiScore;
  final int momentumScore;
  final int projectCount;
  final int pendingActionsCount;
  final int pendingOpportunitiesCount;
  final int? executionScore;
  final bool hasAlert;
  final String alertMessage;
  final String alertId;
  final List<Map<String, dynamic>> knowledgeItemsSummary;
  final List<Map<String, dynamic>> pendingOpportunitiesSummary;
  final List<Map<String, dynamic>> pendingActionsSummary;
  final List<String> sourceLimitations;

  const IveContextData({
    this.userId = '',
    this.userName = '',
    this.activeProjectId,
    this.activeProjectName,
    this.activeProjectDescription,
    this.activeProjectType,
    this.activeProjectStatus,
    this.healthScore = 0,
    this.opportunityScore = 0,
    this.marketScore = 0,
    this.strategicFit = 0,
    this.synergyScore = 0,
    this.roiScore = 0,
    this.momentumScore = 0,
    this.projectCount = 0,
    this.pendingActionsCount = 0,
    this.pendingOpportunitiesCount = 0,
    this.executionScore,
    this.hasAlert = false,
    this.alertMessage = '',
    this.alertId = '',
    this.knowledgeItemsSummary = const [],
    this.pendingOpportunitiesSummary = const [],
    this.pendingActionsSummary = const [],
    this.sourceLimitations = const [],
  });

  bool get hasActiveProject =>
      activeProjectId != null && activeProjectId!.isNotEmpty;

  CopilotContextData toCopilotContext({required String route}) =>
      CopilotContextData(
        userId: userId,
        projectId: activeProjectId,
        route: route,
        project: hasActiveProject
            ? {
                'id': activeProjectId,
                'name': activeProjectName ?? '',
                'description': activeProjectDescription ?? '',
                'objective': activeProjectDescription ?? '',
                'stage': activeProjectType ?? '',
                'type': activeProjectType ?? '',
                'status': activeProjectStatus ?? '',
              }
            : null,
        scores: hasActiveProject
            ? {
                'ecosystem': healthScore,
                'execution': executionScore ?? 0,
                'opportunity': opportunityScore,
                'market': marketScore,
                'strategic_fit': strategicFit,
                'synergy': synergyScore,
                'roi': roiScore,
                'momentum': momentumScore,
                'recommendation': _recommendation(healthScore),
              }
            : null,
        documents: knowledgeItemsSummary,
        opportunities: pendingOpportunitiesSummary,
        actions: pendingActionsSummary,
        sourceLimitations: sourceLimitations,
      );

  static String _recommendation(int health) {
    if (health >= 70) {
      return 'Projeto saudável. Priorize oportunidades de maior impacto.';
    }
    if (health >= 40) {
      return 'Execução moderada. Priorize ações pendentes de alto impacto.';
    }
    return 'Atenção: o projeto precisa de intervenção e validação dos dados.';
  }
}

final iveContextDataProvider =
    FutureProvider.autoDispose<IveContextData>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const IveContextData();

  final project = ref.watch(selectedProjectProvider);
  final profile = await ref.watch(currentProfileProvider.future).then(
        (value) => value,
        onError: (_, __) => null,
      );

  if (project == null) {
    return IveContextData(
      userId: user.id,
      userName: profile?.fullName?.trim() ?? '',
      sourceLimitations: const [
        'Nenhum projeto foi selecionado; dados de negócio não foram carregados.',
      ],
    );
  }

  if (project.userId != user.id) {
    throw Exception('Projeto não pertence ao usuário');
  }

  final results = await Future.wait<dynamic>([
    ref.watch(ecosystemScoresProvider.future).then(
          (value) => value,
          onError: (_, __) => <dynamic>[],
        ),
    ref.watch(actionQueueByProjectProvider(project.id).future).then(
          (value) => value,
          onError: (_, __) => <dynamic>[],
        ),
    ref.watch(opportunityLabByProjectProvider(project.id).future).then(
          (value) => value,
          onError: (_, __) => <dynamic>[],
        ),
    ref.watch(knowledgeItemsByProjectProvider(project.id).future).then(
          (value) => value,
          onError: (_, __) => <dynamic>[],
        ),
  ]);

  final scores = results[0] as List;
  final actions = results[1] as List;
  final opportunities = results[2] as List;
  final knowledge = results[3] as List;

  final selectedScores =
      scores.where((score) => score.project.id == project.id).toList();
  final score = selectedScores.isEmpty ? null : selectedScores.first;

  final pendingActions = actions
      .where((action) => action.status == 'pending')
      .toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));
  final pendingOpportunities = opportunities
      .where((opportunity) => opportunity.status == 'pending')
      .toList()
    ..sort((a, b) => b.finalScore.compareTo(a.finalScore));
  final rankedOpportunities = [...opportunities]
    ..sort((a, b) => b.finalScore.compareTo(a.finalScore));
  final rankedActions = [...actions]
    ..sort((a, b) => b.priority.compareTo(a.priority));
  final knowledgeSorted = [...knowledge]
    ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));

  final knowledgeSummary = knowledgeSorted
      .take(5)
      .map((item) => {
            'id': item.id,
            'title': item.title,
            'score': item.opportunityScore,
            'status': item.status,
            if (item.niche != null) 'niche': item.niche,
          })
      .toList();

  final opportunitySummary = rankedOpportunities
      .take(5)
      .map((item) => {
            'id': item.id,
            'project_id': item.projectId,
            'title': item.title,
            'description': item.description,
            'final_score': item.finalScore,
            'market_score': item.marketScore,
            'revenue_score': item.revenueScore,
            'competition_score': item.competitionScore,
            'strategic_fit': item.strategicFit,
            'synergy_score': item.synergyScore,
            'opportunity_type': item.opportunityType,
            'status': item.status,
            'origin': item.originLabel,
            'confidence': item.confidence,
            if (item.rationale != null && item.rationale!.isNotEmpty)
              'rationale': item.rationale,
            if (item.risks.isNotEmpty) 'risks': item.risks.take(3).toList(),
            if (item.actionSteps.isNotEmpty)
              'next_steps': item.actionSteps.take(3).toList(),
          })
      .toList();

  final actionSummary = rankedActions
      .take(5)
      .map((item) => {
            'id': item.id,
            'project_id': item.projectId,
            'title': item.title,
            'status': item.status,
            'priority': item.priority,
            'impact_score': item.impactScore,
            'effort_score': item.effortScore,
            'roi_score': item.roiScore,
            'market_score': item.marketScore,
            'origin': item.originLabel,
            if (item.rationale != null && item.rationale!.isNotEmpty)
              'rationale': item.rationale,
          })
      .toList();

  final health = score?.ecosystemScore ?? 0;
  final hasAlert = health > 0 && health < 40;

  return IveContextData(
    userId: user.id,
    userName: profile?.fullName?.trim() ?? '',
    activeProjectId: project.id,
    activeProjectName: project.name,
    activeProjectDescription: project.description,
    activeProjectType: project.type,
    activeProjectStatus: project.status,
    healthScore: health,
    opportunityScore: score?.opportunityScore ?? 0,
    marketScore: score?.marketScore ?? 0,
    strategicFit: score?.strategicFit ?? 0,
    synergyScore: score?.synergyScore ?? 0,
    roiScore: score?.roiScore ?? 0,
    momentumScore: score?.momentumScore ?? 0,
    projectCount: 1,
    executionScore: score?.executionScore,
    pendingActionsCount: pendingActions.length,
    pendingOpportunitiesCount: pendingOpportunities.length,
    hasAlert: hasAlert,
    alertId: hasAlert ? 'project_health_low_${project.id}_$health' : '',
    alertMessage: hasAlert
        ? '${project.name} está com saúde $health/100. Posso priorizar uma ação.'
        : '',
    knowledgeItemsSummary: knowledgeSummary,
    pendingOpportunitiesSummary: opportunitySummary,
    pendingActionsSummary: actionSummary,
    sourceLimitations: const [
      'A Knowledge Base fornece apenas metadados e análises disponíveis; o conteúdo integral dos documentos não foi lido nesta conversa.',
      'Recomendações dependem da atualidade dos dados registrados no projeto.',
    ],
  );
});
