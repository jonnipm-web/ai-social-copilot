import 'aef_runtime.dart';
import 'ive_intelligence.dart';

class CopilotTurn {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<String> sources;
  final List<String> entities;
  final int confidence;
  final CopilotActionSuggestion? actionSuggestion;
  final DateTime timestamp;

  /// IVE-INTELLIGENCE-CORE-01 — the server routed this request to AEF
  /// (consequential action); the UI shows a localized explanation instead
  /// of an answer. Nothing was executed.
  final bool requiresAef;

  /// Server-validated capability suggestions (never derived from free text).
  final List<IveSuggestedAction> suggestedActions;

  /// Part of the optional context (knowledge/memory/project state) could not
  /// be loaded; the UI flags the answer as partial.
  final bool degradedContext;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 — IVE's suggestion for a consequential
  /// action (LAB Human Gate card). Never an authorization.
  final IveActionIntentData? actionIntent;

  const CopilotTurn({
    required this.role,
    required this.content,
    this.sources = const [],
    this.entities = const [],
    this.confidence = 70,
    this.actionSuggestion,
    required this.timestamp,
    this.requiresAef = false,
    this.suggestedActions = const [],
    this.degradedContext = false,
    this.actionIntent,
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
        requiresAef:      requiresAef,
        suggestedActions: suggestedActions,
        degradedContext:  degradedContext,
        actionIntent:     actionIntent,
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
