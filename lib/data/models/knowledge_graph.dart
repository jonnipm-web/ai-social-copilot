class GraphEdge {
  final String sourceType;   // 'project' | 'persona' | 'knowledge' | 'opportunity'
  final String sourceId;
  final String sourceName;
  final String targetType;
  final String targetId;
  final String targetName;
  final String relationship; // 'compartilha_nicho' | 'usa_conhecimento' | 'oportunidade_de' | 'persona_conhece'
  final double weight;       // 0.0-1.0

  const GraphEdge({
    required this.sourceType,
    required this.sourceId,
    required this.sourceName,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.relationship,
    required this.weight,
  });

  String get relationshipLabel {
    switch (relationship) {
      case 'compartilha_nicho': return 'Compartilha nicho';
      case 'usa_conhecimento':  return 'Usa conhecimento';
      case 'oportunidade_de':   return 'Oportunidade de';
      case 'persona_conhece':   return 'Persona conhece';
      default:                  return relationship;
    }
  }

  String get description => '$sourceName ↔ $targetName';
  String get fullDescription => '$sourceName → ${relationshipLabel.toLowerCase()} → $targetName';
}

class KnowledgeGraph {
  final List<GraphEdge> edges;
  final int nodeCount;
  final DateTime computedAt;

  const KnowledgeGraph({
    required this.edges,
    required this.nodeCount,
    required this.computedAt,
  });

  List<GraphEdge> edgesFor(String entityId) =>
      edges.where((e) => e.sourceId == entityId || e.targetId == entityId).toList();

  List<String> relatedNamesFor(String entityId) =>
      edgesFor(entityId)
          .map((e) => e.sourceId == entityId ? e.targetName : e.sourceName)
          .toSet()
          .toList();

  List<GraphEdge> get projectConnections =>
      edges.where((e) => e.sourceType == 'project' && e.targetType == 'project').toList();

  List<GraphEdge> get personaConnections =>
      edges.where((e) => e.sourceType == 'persona').toList();
}
