import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ecosystem_intelligence_provider.dart';
import 'action_queue_provider.dart';
import 'opportunity_lab_provider.dart';

// ── IveContextData — dados em tempo real do ecossistema para a IVE ────────────

class IveContextData {
  final int    healthScore;
  final int    projectCount;
  final int    pendingActionsCount;
  final int    pendingOpportunitiesCount;
  final String? topProjectName;
  final String? topProjectDescription;
  final String? topProjectType;
  final int?    topProjectScore;
  final String? mainBottleneckName;
  final int?    mainBottleneckScore;
  final bool   hasAlert;
  final String alertMessage;
  final String alertId;
  // Snapshot das top 3 projetos para contexto rico no chat
  final List<Map<String, dynamic>> topProjectsSnapshot;

  const IveContextData({
    this.healthScore                = 0,
    this.projectCount               = 0,
    this.pendingActionsCount        = 0,
    this.pendingOpportunitiesCount  = 0,
    this.topProjectName,
    this.topProjectDescription,
    this.topProjectType,
    this.topProjectScore,
    this.mainBottleneckName,
    this.mainBottleneckScore,
    this.hasAlert                   = false,
    this.alertMessage               = '',
    this.alertId                    = '',
    this.topProjectsSnapshot        = const [],
  });
}

// ── Provider — FutureProvider derivado dos providers de ecossistema ───────────

final iveContextDataProvider = FutureProvider.autoDispose<IveContextData>((ref) async {
  // Lê dados existentes — não cria nova lógica, apenas agrega
  final health    = await ref.watch(ecosystemHealthProvider.future);
  final scores    = await ref.watch(ecosystemScoresProvider.future);
  final pending   = await ref.watch(pendingActionsProvider.future);
  final labSummary = await ref.watch(opportunityLabSummaryProvider.future);

  // Projeto de maior score
  final sorted = [...scores]
    ..sort((a, b) => b.ecosystemScore.compareTo(a.ecosystemScore));
  final top = sorted.isNotEmpty ? sorted.first : null;

  // Projeto com pior execução (principal gargalo)
  final bottleneck = scores.isNotEmpty
      ? scores.reduce(
          (a, b) => a.executionScore < b.executionScore ? a : b)
      : null;

  final pendingLab = labSummary['pending'] ?? 0;

  // ── Detecção de alertas ───────────────────────────────────────────────────
  bool hasAlert     = false;
  String alertMsg   = '';
  String alertId    = '';

  final criticals = scores.where((s) => s.ecosystemScore < 30).toList();

  if (health < 40) {
    hasAlert  = true;
    alertId   = 'health_low_$health';
    alertMsg  = 'Saúde do ecossistema em $health/100. '
                'Ação imediata recomendada.';
  } else if (criticals.isNotEmpty) {
    final c   = criticals.first;
    hasAlert  = true;
    alertId   = 'score_critical_${c.project.id}';
    alertMsg  = '${c.project.name} com score crítico (${c.ecosystemScore}/100). '
                'Posso identificar o que está limitando.';
  } else if (pending.length > 5) {
    hasAlert  = true;
    alertId   = 'actions_overdue_${pending.length}';
    alertMsg  = '${pending.length} ações pendentes acumuladas. '
                'Isso está impactando seu score de execução.';
  }

  final topThree = sorted.take(3).map((s) => {
    'name':        s.project.name,
    'description': s.project.description,
    'type':        s.project.type,
    'status':      s.project.status,
    'score':       s.ecosystemScore,
    'opportunity': s.project.opportunityScore,
  }).toList();

  return IveContextData(
    healthScore:               health,
    projectCount:              scores.length,
    pendingActionsCount:       pending.length,
    pendingOpportunitiesCount: pendingLab,
    topProjectName:            top?.project.name,
    topProjectDescription:     top?.project.description,
    topProjectType:            top?.project.type,
    topProjectScore:           top?.ecosystemScore,
    mainBottleneckName:        bottleneck?.project.name,
    mainBottleneckScore:       bottleneck?.executionScore,
    hasAlert:                  hasAlert,
    alertMessage:              alertMsg,
    alertId:                   alertId,
    topProjectsSnapshot:       topThree,
  );
});
