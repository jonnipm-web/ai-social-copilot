import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_item.dart';
import '../data/models/opportunity_lab_item.dart';
import '../data/services/document_context_builder.dart';
import 'ecosystem_intelligence_provider.dart';
import 'action_queue_provider.dart';
import 'opportunity_lab_provider.dart';
import 'knowledge_provider.dart';

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
  // Top knowledge items filtrados pelo projeto ativo, com content_excerpt grounded
  final List<Map<String, dynamic>> knowledgeItemsSummary;
  // Cobertura de grounding: quantos docs vinculados, processados, usados
  final Map<String, dynamic> documentCoverage;
  // Avisos de grounding (conteúdo vazio, budget excedido, etc.)
  final List<String> documentWarnings;
  // Top 3 oportunidades pendentes — alimenta opportunities no chat
  final List<Map<String, dynamic>> pendingOpportunitiesSummary;
  // Top 3 ações pendentes com campos de auditoria
  final List<Map<String, dynamic>> pendingActionsSummary;

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
    this.knowledgeItemsSummary      = const [],
    this.documentCoverage           = const {},
    this.documentWarnings           = const [],
    this.pendingOpportunitiesSummary = const [],
    this.pendingActionsSummary       = const [],
  });
}

// ── Provider — FutureProvider derivado dos providers de ecossistema ───────────

final iveContextDataProvider = FutureProvider.autoDispose<IveContextData>((ref) async {
  // Lê dados existentes — não cria nova lógica, apenas agrega
  final health     = await ref.watch(ecosystemHealthProvider.future);
  final scores     = await ref.watch(ecosystemScoresProvider.future);
  final pending    = await ref.watch(pendingActionsProvider.future);
  final labSummary = await ref.watch(opportunityLabSummaryProvider.future);

  // ── Projeto de maior score (computado antes dos knowledge items para filtrar) ─
  final sorted = [...scores]
    ..sort((a, b) => b.ecosystemScore.compareTo(a.ecosystemScore));
  final top = sorted.isNotEmpty ? sorted.first : null;

  // ── Knowledge items — filtrados pelo projeto ativo quando disponível ──────────
  final knowledgeRaw = await ref.watch(knowledgeItemsProvider.future).then(
    (v) => v,
    onError: (_, __) => <KnowledgeItem>[],
  );

  // Filtra por projeto ativo; fallback para todos os itens se nenhum vinculado
  final projectId = top?.project.id;
  final projectItems = projectId != null
      ? knowledgeRaw.where((k) => k.projectId == projectId).toList()
      : <KnowledgeItem>[];
  final knowledgeForGrounding = projectItems.isNotEmpty ? projectItems : knowledgeRaw;

  final knowledgeSorted = [...knowledgeForGrounding]
    ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));

  // Contexto textual do projeto para seleção de chunks relevantes
  final projectContext = [
    top?.project.name ?? '',
    top?.project.description ?? '',
  ].where((s) => s.isNotEmpty).join(' ');

  // Total de documentos vinculados ao projeto (para coverage real, antes de take(5))
  final totalLinkedCount = knowledgeSorted.length;

  // Grounding apenas nos top-5 que serão exibidos no summary.
  // Garante Source Manifest invariant:
  //   SET(grounding.excerpts) == SET(docs com content_excerpt no prompt do LLM)
  final topItems = knowledgeSorted.take(5).toList();

  final grounding = DocumentContextBuilder.buildGrounding(
    topItems.cast<KnowledgeItem>(),
    projectContext: projectContext,
  );

  // Mapa documentId → texto concatenado de todos os excerpts (Pass 2 pode gerar
  // múltiplos excerpts por documento; separados por "[...]" para o LLM).
  final excerptTextByDoc = <String, String>{};
  for (final e in grounding.excerpts) {
    if (excerptTextByDoc.containsKey(e.documentId)) {
      excerptTextByDoc[e.documentId] =
          '${excerptTextByDoc[e.documentId]!}\n\n[...]\n\n${e.text}';
    } else {
      excerptTextByDoc[e.documentId] = e.text;
    }
  }

  // Top 5 com content_excerpt quando grounded; sem excerpt: apenas metadados.
  // Mesmo conjunto passado ao buildGrounding — invariant mantido.
  final knowledgeSummary = topItems.map((k) {
    final excerptText = excerptTextByDoc[k.id];
    return <String, dynamic>{
      'title':  k.title,
      'score':  k.opportunityScore,
      'status': k.status,
      if (k.niche != null) 'niche': k.niche,
      if (excerptText != null) 'content_excerpt': excerptText,
    };
  }).toList();

  // Coverage: total_linked reflete TODOS os docs do projeto, não só os top-5
  final documentCoverage = {
    ...grounding.coverage.toMap(),
    'total_linked': totalLinkedCount,
  };
  final documentWarnings = grounding.warnings.map((w) => w.message).toList();

  // ── Oportunidades pendentes — top 3 por finalScore ───────────────────────────
  final opportunities = await ref.watch(opportunityLabProvider.future).then(
    (v) => v,
    onError: (_, __) => <OpportunityLabItem>[],
  );
  final pendingOpportunities = [...opportunities.where((o) => o.status == 'pending')]
    ..sort((a, b) => b.finalScore.compareTo(a.finalScore));
  final opportunitiesSummary = pendingOpportunities.take(3).map((o) => {
    'title':        o.title,
    'description':  o.description,
    'score':        o.finalScore,
    'type':         o.opportunityType,
    'origin':       o.originLabel,
    'confidence':   o.confidence,
    if (o.rationale != null && o.rationale!.isNotEmpty)
      'rationale': o.rationale,
    if (o.risks.isNotEmpty)        'risks':      o.risks.take(3).toList(),
    if (o.actionSteps.isNotEmpty)  'next_steps': o.actionSteps.take(3).toList(),
  }).toList();

  // ── Ações pendentes — top 3 por prioridade com campos de auditoria ───────────
  final pendingActionsSorted = [...pending]
    ..sort((a, b) => b.priority.compareTo(a.priority));
  final actionsSummary = pendingActionsSorted.take(3).map((a) => {
    'title':    a.title,
    'priority': a.priority,
    'impact':   a.impactScore,
    'origin':   a.originLabel,
    if (a.rationale != null && a.rationale!.isNotEmpty)
      'rationale': a.rationale,
    if (a.plan.isNotEmpty)   'plan':  a.plan.take(2).toList(),
    if (a.risks.isNotEmpty)  'risks': a.risks.take(2).toList(),
  }).toList();

  // ── Projeto com pior execução (principal gargalo) ────────────────────────────
  final bottleneck = scores.isNotEmpty
      ? scores.reduce(
          (a, b) => a.executionScore < b.executionScore ? a : b)
      : null;

  final pendingLab = labSummary['pending'] ?? 0;

  // ── Detecção de alertas ───────────────────────────────────────────────────────
  bool   hasAlert  = false;
  String alertMsg  = '';
  String alertId   = '';

  final criticals = scores.where((s) => s.ecosystemScore < 30).toList();

  if (health < 40) {
    hasAlert = true;
    alertId  = 'health_low_$health';
    alertMsg = 'Saúde do ecossistema em $health/100. '
               'Ação imediata recomendada.';
  } else if (criticals.isNotEmpty) {
    final c  = criticals.first;
    hasAlert = true;
    alertId  = 'score_critical_${c.project.id}';
    alertMsg = '${c.project.name} com score crítico (${c.ecosystemScore}/100). '
               'Posso identificar o que está limitando.';
  } else if (pending.length > 5) {
    hasAlert = true;
    alertId  = 'actions_overdue_${pending.length}';
    alertMsg = '${pending.length} ações pendentes acumuladas. '
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
    healthScore:                 health,
    projectCount:                scores.length,
    pendingActionsCount:         pending.length,
    pendingOpportunitiesCount:   pendingLab,
    topProjectName:              top?.project.name,
    topProjectDescription:       top?.project.description,
    topProjectType:              top?.project.type,
    topProjectScore:             top?.ecosystemScore,
    mainBottleneckName:          bottleneck?.project.name,
    mainBottleneckScore:         bottleneck?.executionScore,
    hasAlert:                    hasAlert,
    alertMessage:                alertMsg,
    alertId:                     alertId,
    topProjectsSnapshot:         topThree,
    knowledgeItemsSummary:       knowledgeSummary,
    documentCoverage:            documentCoverage,
    documentWarnings:            documentWarnings,
    pendingOpportunitiesSummary: opportunitiesSummary,
    pendingActionsSummary:       actionsSummary,
  );
});
