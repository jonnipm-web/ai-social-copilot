enum RelationshipType {
  sharedNiche, // compartilham nicho (>60% sobreposição)
  sharedAudience, // compartilham público-alvo
  complementary, // se complementam (nicho diferente, público semelhante)
  conflicting, // concorrentes internos (>80% sobreposição)
  synergistic, // sinergia explícita (um potencializa o outro)
  duplicate, // provável duplicata (>90% contexto igual)
}

class ExecutiveRelationship {
  final String projectAId;
  final String projectAName;
  final String projectBId;
  final String projectBName;
  final RelationshipType type;
  final double similarity; // 0.0-1.0
  final String description;
  final List<String> sharedTopics;
  final List<String> synergies;
  final List<String> conflicts;
  final String recommendation;

  const ExecutiveRelationship({
    required this.projectAId,
    required this.projectAName,
    required this.projectBId,
    required this.projectBName,
    required this.type,
    required this.similarity,
    required this.description,
    this.sharedTopics = const [],
    this.synergies = const [],
    this.conflicts = const [],
    this.recommendation = '',
  });

  String get typeEmoji {
    switch (type) {
      case RelationshipType.sharedNiche:
        return '🎯';
      case RelationshipType.sharedAudience:
        return '👥';
      case RelationshipType.complementary:
        return '🤝';
      case RelationshipType.conflicting:
        return '⚔️';
      case RelationshipType.synergistic:
        return '⚡';
      case RelationshipType.duplicate:
        return '⚠️';
    }
  }

  String get typeLabel {
    switch (type) {
      case RelationshipType.sharedNiche:
        return 'Nicho Compartilhado';
      case RelationshipType.sharedAudience:
        return 'Público Compartilhado';
      case RelationshipType.complementary:
        return 'Complementares';
      case RelationshipType.conflicting:
        return 'Conflitantes';
      case RelationshipType.synergistic:
        return 'Sinérgicos';
      case RelationshipType.duplicate:
        return 'Possível Duplicata';
    }
  }

  int get similarityPercent => (similarity * 100).round();

  bool get requiresAttention =>
      type == RelationshipType.conflicting ||
      type == RelationshipType.duplicate;
}
