import '../../providers/ive_context_provider.dart' show IveContextData;

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
  });

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
