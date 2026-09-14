import '../../providers/ive_context_provider.dart' show IveContextData;
import 'ive_interaction_request.dart';

class CopilotContextData {
  final Map<String, dynamic>? project;
  final Map<String, dynamic>? scores;
  final List<Map<String, dynamic>> opportunities;
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> personas;
  final Map<String, dynamic>? revenue;
  final Map<String, dynamic>? market;
  // Métricas de grounding: quantos docs vinculados vs processados vs usados
  final Map<String, dynamic>? documentCoverage;
  // Avisos de grounding enviados ao LLM para instrução de honestidade epistêmica
  final List<String> documentWarnings;

  // IVE-COMMERCIAL-FOUNDATION-11 (Project Context Contract, Phase A) —
  // identity fields. Before this mission this class had NONE of these —
  // every "Ask IVE" call site shared the same ecosystem-wide grounding
  // with no way to know which project/item/interaction it was actually
  // about (docs/commercial/PROJECT_CONTEXT_CONTRACT.md §2). These mirror
  // IveInteractionRequest 1:1 (see [withIdentity]) and exist on THIS
  // class — not just the request — so the identity travels with the
  // context all the way into the chat provider/audit trail, not just up
  // to the point `showCopilotChat` is called.
  final String? projectId;
  final String? sourceModule;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final String? correlationId;

  const CopilotContextData({
    this.project,
    this.scores,
    this.opportunities      = const [],
    this.actions            = const [],
    this.documents          = const [],
    this.personas           = const [],
    this.revenue,
    this.market,
    this.documentCoverage,
    this.documentWarnings   = const [],
    this.projectId,
    this.sourceModule,
    this.sourceEntityType,
    this.sourceEntityId,
    this.correlationId,
  });

  /// Returns a copy carrying [request]'s identity fields — the single
  /// choke point `showCopilotChat` uses (see context_copilot_widget.dart)
  /// so every chat invocation carries identity regardless of how its
  /// `contextData` was built upstream.
  CopilotContextData withIdentity(IveInteractionRequest request) => CopilotContextData(
        project:           project,
        scores:            scores,
        opportunities:     opportunities,
        actions:           actions,
        documents:         documents,
        personas:          personas,
        revenue:           revenue,
        market:            market,
        documentCoverage:  documentCoverage,
        documentWarnings:  documentWarnings,
        projectId:         request.projectId,
        sourceModule:      request.sourceModule,
        sourceEntityType:  request.sourceEntityType,
        sourceEntityId:    request.sourceEntityId,
        correlationId:     request.correlationId,
      );

  // IVE-COMMERCIAL-TARGETED-REMEDIATION-04 — fonte única desta conversão.
  // Antes desta correção, o overlay global (ive_overlay.dart) tinha sua
  // PRÓPRIA cópia privada desta lógica (_buildCopilotContext), e
  // ive_detail_sheet.dart's botão "Perguntar à IVE" não a usava de jeito
  // nenhum -- passava CopilotContextData() vazio direto, sem nenhuma
  // tentativa de ler o contexto real. Um usuário que abrisse o chat pelo
  // avatar global recebia grounding completo (projeto, documentos,
  // oportunidades); o mesmo usuário abrindo pelo botão "Perguntar à IVE"
  // dentro de um detail sheet recebia uma IVE sem memória nenhuma --
  // inconsistência silenciosa, sem nenhum erro visível. Consolidando aqui
  // garante que TODO ponto de entrada do chat (hoje: 2; qualquer um
  // futuro) monte o contexto da mesma forma.
  factory CopilotContextData.fromIveContext(IveContextData ctx) {
    return CopilotContextData(
      scores: {
        'ecosystem_health':          ctx.healthScore,
        'total_projects':            ctx.projectCount,
        'pending_actions':           ctx.pendingActionsCount,
        'pending_opportunities':     ctx.pendingOpportunitiesCount,
        if (ctx.topProjectName        != null) 'top_project_name':           ctx.topProjectName,
        if (ctx.topProjectDescription != null) 'top_project_description':    ctx.topProjectDescription,
        if (ctx.topProjectType        != null) 'top_project_type':           ctx.topProjectType,
        if (ctx.topProjectScore       != null) 'top_project_score':          ctx.topProjectScore,
        if (ctx.mainBottleneckName    != null) 'main_bottleneck':            ctx.mainBottleneckName,
        if (ctx.mainBottleneckScore   != null) 'bottleneck_execution_score': ctx.mainBottleneckScore,
        // IVE-COMMERCIAL-FOUNDATION-11 — falha segura e explícita: quando
        // um projectId foi pedido e não foi encontrado, diz isso ao LLM
        // em vez de silenciosamente devolver um contexto vazio que possa
        // ser confundido com "projeto sem dados ainda".
        if (ctx.projectUnavailable) 'project_unavailable': true,
      },
      project: ctx.topProjectsSnapshot.isNotEmpty
          ? {'projects': ctx.topProjectsSnapshot}
          : null,
      documents:        ctx.knowledgeItemsSummary,
      documentCoverage: ctx.documentCoverage.isNotEmpty ? ctx.documentCoverage : null,
      documentWarnings: ctx.documentWarnings,
      opportunities:    ctx.pendingOpportunitiesSummary,
      actions:          ctx.pendingActionsSummary,
    );
  }

  Map<String, dynamic> toMap() => {
    if (project      != null) 'project':       project,
    if (scores       != null) 'scores':        scores,
    if (opportunities.isNotEmpty) 'opportunities': opportunities,
    if (actions.isNotEmpty)       'actions':       actions,
    if (documents.isNotEmpty)     'documents':     documents,
    if (personas.isNotEmpty)      'personas':      personas,
    if (revenue      != null) 'revenue':       revenue,
    if (market       != null) 'market':        market,
    if (documentCoverage != null)         'document_coverage':  documentCoverage,
    if (documentWarnings.isNotEmpty)      'document_warnings':  documentWarnings,
  };

  bool get isEmpty =>
      project == null &&
      scores == null &&
      opportunities.isEmpty &&
      actions.isEmpty &&
      documents.isEmpty &&
      personas.isEmpty &&
      revenue == null &&
      market == null;
}
