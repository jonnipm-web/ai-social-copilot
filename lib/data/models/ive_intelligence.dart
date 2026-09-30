import 'package:flutter/foundation.dart';

import '../../core/modules/module_registry.dart';
import 'aef_runtime.dart';

/// IVE-INTELLIGENCE-CORE-01 — client side of the server IVE Intelligence Core
/// contract (supabase/functions/_shared/ive/contracts.ts).
///
/// The client sends ONLY: the question, the project it is looking at (a
/// request the server verifies), surface, locale, the visible transcript and
/// correlation/idempotency hints. It never sends plan, role, entitlements,
/// documents or memory: the server derives all of that itself. Android and
/// Web build the exact same request — the surface only changes UX.

/// Must match the server's surface vocabulary. Only [android] and [web] are
/// active today; others are rejected server-side (SURFACE_NOT_SUPPORTED).
enum IveSurface { android, web, ios, desktop }

IveSurface currentIveSurface() {
  if (kIsWeb) return IveSurface.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => IveSurface.android,
    TargetPlatform.iOS => IveSurface.ios,
    _ => IveSurface.desktop,
  };
}

/// Language code → server locale ('pt-BR' | 'en').
String iveLocaleFor(String languageCode) => languageCode.toLowerCase().startsWith('pt') ? 'pt-BR' : 'en';

class IveConversationTurn {
  const IveConversationTurn({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final String content;
}

/// Server limits mirrored so the client trims instead of being rejected.
const int kIveMaxConversationTurns = 10;
const int kIveMaxTurnChars = 2000;
const int kIveMaxMessageChars = 4000;

class IveIntelligenceRequest {
  const IveIntelligenceRequest({
    required this.message,
    required this.surface,
    required this.locale,
    this.projectId,
    this.conversation = const [],
    this.sourceModule,
    this.idempotencyKey,
    this.correlationId,
  });

  final String message;
  final IveSurface surface;
  final String locale;
  final String? projectId;
  final List<IveConversationTurn> conversation;
  final String? sourceModule;
  final String? idempotencyKey;
  final String? correlationId;

  /// The complete wire payload. There is deliberately no field for plan,
  /// role, entitlements, context, documents or memory.
  Map<String, dynamic> toJson() {
    final turns = conversation
        .where((t) => t.role == 'user' || t.role == 'assistant')
        .toList();
    final recent = turns.length > kIveMaxConversationTurns
        ? turns.sublist(turns.length - kIveMaxConversationTurns)
        : turns;
    return {
      'message': message.length > kIveMaxMessageChars ? message.substring(0, kIveMaxMessageChars) : message,
      'surface': surface.name,
      'locale': locale,
      if (projectId != null) 'project_id': projectId,
      if (recent.isNotEmpty)
        'conversation': [
          for (final t in recent)
            {
              'role': t.role,
              'content': t.content.length > kIveMaxTurnChars ? t.content.substring(0, kIveMaxTurnChars) : t.content,
            },
        ],
      if (sourceModule != null && RegExp(r'^[A-Za-z0-9._:-]{1,200}$').hasMatch(sourceModule!)) 'source_module': sourceModule,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (correlationId != null && RegExp(r'^[A-Za-z0-9._:-]{1,200}$').hasMatch(correlationId!)) 'correlation_id': correlationId,
    };
  }
}

class IveSuggestedAction {
  const IveSuggestedAction({required this.kind, required this.capabilityId, required this.available, this.requiredPlan});
  final String kind; // open_module | upgrade
  final String capabilityId;
  final bool available;
  final String? requiredPlan;
}

class IveIntelligenceResult {
  const IveIntelligenceResult({
    required this.requiresAef,
    required this.answer,
    required this.sourceLabels,
    required this.suggestedActions,
    required this.degraded,
    required this.memoryCandidates,
    required this.correlationId,
    this.actionIntent,
  });

  final bool requiresAef;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 — the validated IVE suggestion when
  /// [requiresAef]; a suggestion only, never an authorization.
  final IveActionIntentData? actionIntent;
  final String? answer;
  final List<String> sourceLabels;
  final List<IveSuggestedAction> suggestedActions;
  final List<String> degraded;
  final List<({String category, String text})> memoryCandidates;
  final String? correlationId;

  static final Set<String> _knownModules = {for (final m in kModuleRegistry) m.moduleId};

  /// Default-safe parsing: an unknown status is not treated as an answer,
  /// and a suggested action is kept only if its capability id exists in the
  /// registry and its kind is one the UI knows (never free text → action).
  factory IveIntelligenceResult.fromMap(Map<String, dynamic> map) {
    final status = map['status'];
    if (status != 'ANSWERED' && status != 'ACTION_REQUIRES_AEF') {
      throw const FormatException('ive-intelligence: unexpected status');
    }
    final requiresAef = status == 'ACTION_REQUIRES_AEF' || map['requiresAef'] == true;
    final actions = <IveSuggestedAction>[];
    if (!requiresAef && map['suggestedActions'] is List) {
      for (final a in map['suggestedActions'] as List) {
        if (a is! Map) continue;
        final kind = a['kind'];
        final id = a['capabilityId'];
        if ((kind != 'open_module' && kind != 'upgrade') || id is! String || !_knownModules.contains(id)) continue;
        actions.add(IveSuggestedAction(
          kind: kind as String,
          capabilityId: id,
          available: kind == 'open_module' && a['available'] == true,
          requiredPlan: a['requiredPlan'] is String ? a['requiredPlan'] as String : null,
        ));
      }
    }
    return IveIntelligenceResult(
      requiresAef: requiresAef,
      answer: requiresAef ? null : (map['answer'] is String ? map['answer'] as String : null),
      sourceLabels: [
        if (map['sources'] is List)
          for (final s in map['sources'] as List)
            if (s is Map && s['label'] is String && (s['label'] as String).isNotEmpty) s['label'] as String,
      ],
      suggestedActions: actions,
      degraded: [if (map['degraded'] is List) ...(map['degraded'] as List).whereType<String>()],
      memoryCandidates: [
        if (map['memoryCandidates'] is List)
          for (final c in map['memoryCandidates'] as List)
            if (c is Map && c['category'] is String && c['text'] is String)
              (category: c['category'] as String, text: c['text'] as String),
      ],
      correlationId: map['correlationId'] is String ? map['correlationId'] as String : null,
      actionIntent: requiresAef ? IveActionIntentData.tryParse(map['actionIntent']) : null,
    );
  }
}

/// Stable failure codes (server contract). Anything else maps to
/// [IveFailure.unknown] — never to a success.
enum IveFailure {
  authRequired,
  invalidRequest,
  surfaceNotSupported,
  projectForbidden,
  contextUnavailable,
  modelUnavailable,
  quotaExceeded,
  accessDenied,
  entitlementUnavailable,
  unknown;

  static IveFailure fromCode(Object? code) => switch (code) {
        'AUTH_REQUIRED' || 'Unauthorized' => IveFailure.authRequired,
        'INVALID_REQUEST' || 'INVALID_IDEMPOTENCY_KEY' => IveFailure.invalidRequest,
        'SURFACE_NOT_SUPPORTED' => IveFailure.surfaceNotSupported,
        'PROJECT_FORBIDDEN' => IveFailure.projectForbidden,
        'CONTEXT_UNAVAILABLE' => IveFailure.contextUnavailable,
        'MODEL_UNAVAILABLE' => IveFailure.modelUnavailable,
        'QUOTA_EXCEEDED' => IveFailure.quotaExceeded,
        'MODULE_NOT_AVAILABLE' || 'MODULE_DISABLED' || 'PLAN_REQUIRED' => IveFailure.accessDenied,
        'ENTITLEMENT_UNAVAILABLE' => IveFailure.entitlementUnavailable,
        _ => IveFailure.unknown,
      };
}

class IveIntelligenceException implements Exception {
  const IveIntelligenceException(this.failure);
  final IveFailure failure;
  @override
  String toString() => 'IveIntelligenceException(${failure.name})';
}
