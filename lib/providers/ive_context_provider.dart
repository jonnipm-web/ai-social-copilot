import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ecosystem_score.dart';
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
  // IVE-COMMERCIAL-FOUNDATION-11 — o project_id efetivamente usado para
  // escopar este contexto (o mesmo passado à family, quando não-nulo, ou
  // null quando o contexto é o resumo global do ecossistema). Não afeta
  // nenhum comportamento existente — apenas torna explícito, para quem
  // consome IveContextData, se este resultado está de fato project-scoped
  // ou é o resumo ambiente system-wide.
  final String? scopedProjectId;
  // true quando um projectId explícito foi pedido mas o projeto não foi
  // encontrado em ecosystemScoresProvider (deletado, inacessível, ainda
  // não sincronizado) — falha segura: nunca cai de volta para o projeto
  // de maior score do sistema todo.
  final bool projectUnavailable;

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
    this.scopedProjectId,
    this.projectUnavailable          = false,
  });
}

// ── Seleção de conhecimento para grounding — extraída como função pura ────────
//
// IVE-COMMERCIAL-TARGETED-REMEDIATION-04 (achado P1 do Codex Gate): a versão
// anterior (inline no provider) usava `projectItems.isNotEmpty ? projectItems
// : knowledgeRaw`, que caía em knowledgeRaw (TODO o conhecimento do usuário,
// de todos os projetos) sempre que o projeto ativo existia mas tinha zero
// itens vinculados -- vazando conhecimento de OUTROS projetos do mesmo
// usuário para o grounding deste projeto, violando o critério de isolamento
// por projeto desta própria missão. O fallback para "todo o conhecimento do
// usuário" só é correto quando NÃO HÁ projeto ativo algum (projectId ==
// null); quando há um projeto ativo, o resultado deve respeitar seu
// isolamento mesmo que fique vazio.
//
// Extraída como função pura (sem tocar Supabase/providers) especificamente
// para permitir teste automatizado direto do isolamento, sem precisar mockar
// a cadeia de providers que o restante deste arquivo deliberadamente não
// mocka (ver nota de escopo em test/data/models/copilot_context_data_test.dart).
List<KnowledgeItem> selectKnowledgeForGrounding(
  List<KnowledgeItem> knowledgeRaw,
  String? activeProjectId,
) {
  if (activeProjectId == null) return knowledgeRaw;
  return knowledgeRaw.where((k) => k.projectId == activeProjectId).toList();
}

// ── Seleção do projeto em foco — extraída como função pura ────────────────────
//
// IVE-COMMERCIAL-FOUNDATION-11 (Project Context Contract, Phase A) —
// mesmo padrão de selectKnowledgeForGrounding acima: extraída pura,
// sem tocar Supabase/providers, especificamente para permitir testar a
// garantia central deste contrato (projeto pedido != projeto de maior
// score do sistema; projeto inexistente falha seguro) sem mockar a
// cadeia inteira de providers de ecossistema.
class ProjectFocusResult {
  const ProjectFocusResult({required this.focus, required this.unavailable});
  final EcosystemScore? focus;
  // true apenas quando um projectId explícito foi pedido e não foi
  // encontrado em `scores` — NUNCA quando projectId é null (esse é o
  // caso ecosystem-wide legítimo, não uma falha).
  final bool unavailable;
}

ProjectFocusResult selectProjectFocus(
  List<EcosystemScore> scores,
  String? projectId,
) {
  if (projectId == null) {
    final sorted = [...scores]
      ..sort((a, b) => b.ecosystemScore.compareTo(a.ecosystemScore));
    return ProjectFocusResult(
      focus: sorted.isNotEmpty ? sorted.first : null,
      unavailable: false,
    );
  }
  for (final s in scores) {
    if (s.project.id == projectId) {
      return ProjectFocusResult(focus: s, unavailable: false);
    }
  }
  // Falha segura: projeto pedido não encontrado (deletado/inacessível) —
  // NUNCA cai de volta para o projeto de maior score do sistema todo,
  // que seria exatamente o vazamento cross-project que este contrato
  // existe para eliminar.
  return const ProjectFocusResult(focus: null, unavailable: true);
}

// ── Campos comparativos cross-project — extraídos como função pura ───────────
//
// IVE-COMMERCIAL-FOUNDATION-11 (Codex Gate 1, round 1, P1, ACCEPTED) —
// `topProjectsSnapshot` (top 3 projetos por score) e `bottleneck` (projeto
// com pior execução) são, por natureza, comparações ENTRE projetos — não
// dados de um único projeto. São um resumo ecosystem-wide legítimo quando
// projectId é null (overlay global, sem projeto em foco), mas vazariam
// nome/descrição/score de um projeto DIFERENTE do pedido para dentro de
// uma interação escopada a um projeto específico se incluídos
// incondicionalmente. Extraída pura para permitir testar essa garantia
// diretamente (test/providers/ive_project_context_test.dart), sem mockar
// a cadeia de providers de ecossistema.
class EcosystemWideFields {
  const EcosystemWideFields({required this.topProjectsSnapshot, required this.bottleneck});
  final List<Map<String, dynamic>> topProjectsSnapshot;
  final EcosystemScore? bottleneck;
}

EcosystemWideFields selectEcosystemWideFields(
  List<EcosystemScore> scores,
  String? projectId,
) {
  // Escopado a um único projeto: nenhum campo comparativo cross-project
  // é incluído — vazio/nulo, não "deixado como estava".
  if (projectId != null) {
    return const EcosystemWideFields(topProjectsSnapshot: [], bottleneck: null);
  }
  final sorted = [...scores]
    ..sort((a, b) => b.ecosystemScore.compareTo(a.ecosystemScore));
  final topThree = sorted.take(3).map((s) => {
        'name':        s.project.name,
        'description': s.project.description,
        'type':        s.project.type,
        'status':      s.project.status,
        'score':       s.ecosystemScore,
        'opportunity': s.project.opportunityScore,
      }).toList();
  final bottleneck = scores.isNotEmpty
      ? scores.reduce((a, b) => a.executionScore < b.executionScore ? a : b)
      : null;
  return EcosystemWideFields(topProjectsSnapshot: topThree, bottleneck: bottleneck);
}

// ── Provider — FutureProvider derivado dos providers de ecossistema ───────────
//
// IVE-COMMERCIAL-FOUNDATION-11 (Project Context Contract, Phase A) — antes
// desta missão este era um `FutureProvider.autoDispose` SEM parâmetro: TODA
// interação com a IVE (de qualquer tela, sobre qualquer projeto) recebia o
// mesmo grounding computado a partir de "qual projeto tem o maior score no
// sistema todo", nunca do projeto que o usuário estava efetivamente olhando.
// Isso é a causa raiz confirmada, em docs/commercial/
// PROJECT_CONTEXT_CONTRACT.md, das reclamações do dono sobre "perguntas
// antigas da IVE" e respostas fora de contexto.
//
// Agora é `.family<IveContextData, String?>`, chaveado POR PROJECT_ID
// APENAS (não pelo objeto de interação inteiro — ver a correção do Codex
// round 1 registrada no mesmo documento: chavear pelo request inteiro,
// incluindo correlationId por-chamada, fragmentaria o cache em vez de
// corrigi-lo).
//
//   projectId != null → grounding escopado EXATAMENTE a esse projeto
//     (knowledge, oportunidades e ações pendentes filtrados por projectId;
//     se o projeto não for encontrado em ecosystemScoresProvider —
//     deletado, inacessível — falha seguro com `projectUnavailable: true`,
//     NUNCA cai de volta para o projeto de maior score do sistema).
//   projectId == null → comportamento de resumo ecosystem-wide preservado
//     EXATAMENTE como antes (destaca o projeto de maior score como sinal
//     de saúde do ecossistema). Este é um caso de uso legítimo e distinto
//     — o overlay global de chat, aberto de uma tela sem projeto em foco,
//     mostrando "que projeto está indo melhor/pior" como contexto de
//     ecossistema — não é o mesmo bug que motivou esta mudança (que era
//     usar esse mesmo valor como se fosse "o projeto que o usuário está
//     vendo" quando na verdade é um projeto diferente).
final iveContextDataProvider =
    FutureProvider.autoDispose.family<IveContextData, String?>((ref, projectId) async {
  // Lê dados existentes — não cria nova lógica, apenas agrega
  final health     = await ref.watch(ecosystemHealthProvider.future);
  final scores     = await ref.watch(ecosystemScoresProvider.future);
  final pending    = await ref.watch(pendingActionsProvider.future);
  final labSummary = await ref.watch(opportunityLabSummaryProvider.future);

  final focusResult = selectProjectFocus(scores, projectId);
  final top = focusResult.focus;
  final projectUnavailable = focusResult.unavailable;

  // ── Knowledge items — filtrados pelo projeto ativo quando disponível ──────────
  final knowledgeRaw = await ref.watch(knowledgeItemsProvider.future).then(
    (v) => v,
    onError: (_, __) => <KnowledgeItem>[],
  );

  // Quando um projectId explícito foi pedido, o escopo é SEMPRE esse
  // projectId (mesmo que `top` seja null por projectUnavailable — nesse
  // caso selectKnowledgeForGrounding filtra por um ID que não bate com
  // nenhum item, retornando lista vazia, o que é o resultado seguro
  // correto, não um erro).
  final effectiveProjectId = projectId ?? top?.project.id;
  final knowledgeForGrounding = selectKnowledgeForGrounding(knowledgeRaw, effectiveProjectId);

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
  // source_id + delivered_chars + grounded permitem source disclosure explícita.
  final knowledgeSummary = topItems.map((k) {
    final excerptText = excerptTextByDoc[k.id];
    final deliveredChars = grounding.excerpts
        .where((e) => e.documentId == k.id)
        .fold(0, (sum, e) => sum + e.charCount);
    return <String, dynamic>{
      'title':           k.title,
      'score':           k.opportunityScore,
      'status':          k.status,
      'source_id':       k.id,
      'grounded':        excerptText != null,
      'delivered_chars': deliveredChars,
      if (k.niche != null) 'niche': k.niche,
      if (excerptText != null) 'content_excerpt': excerptText,
    };
  }).toList();

  // Coverage: total_linked reflete TODOS os docs do projeto, não só os top-5.
  // used_ids e not_used_count habilitam auditoria de quais docs foram excluídos.
  final usedDocIds = grounding.excerpts.map((e) => e.documentId).toSet().toList();
  final notUsedCount = totalLinkedCount - topItems.length;
  final documentCoverage = {
    ...grounding.coverage.toMap(),
    'total_linked': totalLinkedCount,
    'used_ids':     usedDocIds,
    'not_used_count': notUsedCount,
  };

  // Top-5 transparency: aviso explícito quando documentos são excluídos pelo limite.
  final mutableWarnings = grounding.warnings.map((w) => w.message).toList();
  if (totalLinkedCount > topItems.length) {
    mutableWarnings.insert(
      0,
      '$totalLinkedCount fontes vinculadas · ${topItems.length} utilizadas nesta análise'
      ' · $notUsedCount não utilizadas nesta execução.',
    );
  }
  final documentWarnings = mutableWarnings;

  // ── Oportunidades pendentes — top 3 por finalScore ───────────────────────────
  // IVE-COMMERCIAL-FOUNDATION-11: quando projectId explícito foi pedido,
  // filtra por esse projeto — antes desta missão, uma interação sobre o
  // Projeto A podia receber oportunidades pendentes de QUALQUER projeto do
  // usuário no grounding. Quando projectId é null (resumo ecosystem-wide),
  // mantém o comportamento original (top 3 do sistema todo).
  final opportunities = await ref.watch(opportunityLabProvider.future).then(
    (v) => v,
    onError: (_, __) => <OpportunityLabItem>[],
  );
  final opportunitiesInScope = projectId != null
      ? opportunities.where((o) => o.projectId == projectId)
      : opportunities;
  final pendingOpportunities = [...opportunitiesInScope.where((o) => o.status == 'pending')]
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
  // Mesma lógica de escopo por projeto que as oportunidades acima.
  final pendingInScope = projectId != null
      ? pending.where((a) => a.projectId == projectId)
      : pending;
  final pendingActionsSorted = [...pendingInScope]
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

  // ── Campos comparativos cross-project (ver selectEcosystemWideFields) ────────
  final ecosystemWideFields = selectEcosystemWideFields(scores, projectId);
  final bottleneck = ecosystemWideFields.bottleneck;

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

  final topThree = ecosystemWideFields.topProjectsSnapshot;

  return IveContextData(
    healthScore:                 health,
    projectCount:                scores.length,
    pendingActionsCount:         pendingInScope.length,
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
    scopedProjectId:             projectId,
    projectUnavailable:          projectUnavailable,
  );
});
