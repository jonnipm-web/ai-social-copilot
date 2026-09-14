import '../../core/diagnostics/diagnostic_logger_service.dart' show newDiagnosticCorrelationId;

// IVE-COMMERCIAL-FOUNDATION-11 — canonical contract for every "Perguntar/
// Analisar/Comparar/Explicar com a IVE" invocation in the app (mission
// brief Section 06, docs/commercial/IVE_INTERACTION_AND_QUOTA_CONTRACT.md
// §2). Before this mission, each of the app's "Ask IVE" call sites built
// its own ad hoc combination of a screen name and a `CopilotContextData`
// snapshot, with no explicit identity attached — this is the single
// object every call site now constructs instead, so context threading is
// centralized rather than re-invented per screen.
//
// IMPORTANT (Codex adversarial review, round 1, on the Architecture-10
// mission): none of these fields — least of all [correlationId], which is
// unique per call — are used as Riverpod provider *cache keys*. Only
// [projectId] is (see `iveContextDataProvider`, a `.family<..., String?>`
// keyed by `projectId` alone). This class exists purely to carry
// request-scoped metadata alongside an interaction and its audit trail;
// treating any of these fields as cache identity would fragment the
// project-context cache instead of fixing the leak it exists to prevent.
enum IveOperationType { ask, analyze, compare, explain }

class IveInteractionRequest {
  /// Canonical project identity, when the interaction is unambiguously
  /// scoped to one project. `null` is the deliberate "no project in
  /// scope" case (e.g. a global, project-agnostic entry point) — never a
  /// forgotten field.
  final String? projectId;

  /// Which feature/module initiated this interaction (e.g.
  /// 'opportunity_lab', 'action_engine', 'project_command_center',
  /// 'global_overlay'). Free-form but should match an existing module id
  /// from `lib/core/modules/module_registry.dart` where one applies.
  final String sourceModule;

  /// The kind of item in view, if any (e.g. 'opportunity', 'action',
  /// 'competitor', 'gap_analysis').
  final String? sourceEntityType;

  /// The canonical ID of the item in view, if any. Never a display name.
  final String? sourceEntityId;

  final IveOperationType operationType;

  /// One correlation ID per user-initiated interaction, for audit tracing
  /// across the confirmation → reservation → execution → result sequence
  /// (see docs/commercial/IVE_INTERACTION_AND_QUOTA_CONTRACT.md §3.3).
  /// Reuses the same dart2js-safe generator already hardened for the
  /// diagnostic logger (`newDiagnosticCorrelationId`, fixed for the
  /// `1 << 32` web-compilation trap in IVE-COMMERCIAL-STABILITY-08) rather
  /// than introducing a second ID-generation scheme.
  final String correlationId;

  IveInteractionRequest({
    this.projectId,
    required this.sourceModule,
    this.sourceEntityType,
    this.sourceEntityId,
    required this.operationType,
    String? correlationId,
  }) : correlationId = correlationId ?? newDiagnosticCorrelationId();
}
