class CopilotTurn {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<String> sources;
  final List<String> entities;
  final int confidence;
  final CopilotActionSuggestion? actionSuggestion;
  final DateTime timestamp;

  const CopilotTurn({
    required this.role,
    required this.content,
    this.sources = const [],
    this.entities = const [],
    this.confidence = 70,
    this.actionSuggestion,
    required this.timestamp,
  });

  Map<String, dynamic> toHistoryMap() => {'role': role, 'content': content};

  CopilotTurn copyWith({String? content}) => CopilotTurn(
        role:             role,
        content:          content ?? this.content,
        sources:          sources,
        entities:         entities,
        confidence:       confidence,
        actionSuggestion: actionSuggestion,
        timestamp:        timestamp,
      );
}

class CopilotActionSuggestion {
  final String type;
  final String label;
  final Map<String, dynamic> data;

  const CopilotActionSuggestion({
    required this.type,
    required this.label,
    required this.data,
  });

  factory CopilotActionSuggestion.fromMap(Map<String, dynamic> m) =>
      CopilotActionSuggestion(
        type:  m['type'] as String? ?? '',
        label: m['label'] as String? ?? '',
        data:  m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : {},
      );
}
