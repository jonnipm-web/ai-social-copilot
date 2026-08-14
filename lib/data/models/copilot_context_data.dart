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
