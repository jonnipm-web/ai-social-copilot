class CopilotContextData {
  final String? userId;
  final String? projectId;
  final String route;
  final Map<String, dynamic>? project;
  final Map<String, dynamic>? scores;
  final List<Map<String, dynamic>> opportunities;
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> personas;
  final Map<String, dynamic>? revenue;
  final Map<String, dynamic>? market;
  final List<String> sourceLimitations;

  const CopilotContextData({
    this.userId,
    this.projectId,
    this.route = '',
    this.project,
    this.scores,
    this.opportunities = const [],
    this.actions = const [],
    this.documents = const [],
    this.personas = const [],
    this.revenue,
    this.market,
    this.sourceLimitations = const [],
  });

  Map<String, dynamic> toMap() => {
        if (userId != null) 'user_id': userId,
        if (projectId != null) 'project_id': projectId,
        if (route.isNotEmpty) 'route': route,
        if (project != null) 'project': project,
        if (scores != null) 'scores': scores,
        if (opportunities.isNotEmpty) 'opportunities': opportunities,
        if (actions.isNotEmpty) 'actions': actions,
        if (documents.isNotEmpty) 'documents': documents,
        if (personas.isNotEmpty) 'personas': personas,
        if (revenue != null) 'revenue': revenue,
        if (market != null) 'market': market,
        if (sourceLimitations.isNotEmpty)
          'source_limitations': sourceLimitations,
      };

  /// Apenas hints não autoritativos aceitos pelo contrato backend V2.
  Map<String, dynamic> toServerHints() => {
        if (scores != null) 'scores': scores,
        if (market != null) 'market': market,
        if (personas.isNotEmpty) 'personas': personas,
        if (revenue != null) 'revenue': revenue,
      };

  bool get isEmpty =>
      userId == null &&
      projectId == null &&
      project == null &&
      scores == null &&
      opportunities.isEmpty &&
      actions.isEmpty &&
      documents.isEmpty &&
      personas.isEmpty &&
      revenue == null &&
      market == null;
}
