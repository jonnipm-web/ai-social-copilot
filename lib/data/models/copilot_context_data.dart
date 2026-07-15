class CopilotContextData {
  final Map<String, dynamic>? project;
  final Map<String, dynamic>? scores;
  final List<Map<String, dynamic>> opportunities;
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> personas;
  final Map<String, dynamic>? revenue;
  final Map<String, dynamic>? market;

  const CopilotContextData({
    this.project,
    this.scores,
    this.opportunities = const [],
    this.actions       = const [],
    this.documents     = const [],
    this.personas      = const [],
    this.revenue,
    this.market,
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
