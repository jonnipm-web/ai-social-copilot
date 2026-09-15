/// IVE-COMMERCIAL-OBSERVABILITY-07A — diagnostic session/event data model.
/// Mirrors supabase/migrations/20260913200000_diagnostic_logger.sql exactly
/// (enum values are the table's CHECK constraint values verbatim) so a
/// mismatch between client and schema fails fast/obviously rather than
/// silently.
library diagnostic_models;

enum DiagnosticSeverity { debug, info, warn, error, critical }

extension DiagnosticSeverityValue on DiagnosticSeverity {
  String get value => switch (this) {
        DiagnosticSeverity.debug => 'DEBUG',
        DiagnosticSeverity.info => 'INFO',
        DiagnosticSeverity.warn => 'WARN',
        DiagnosticSeverity.error => 'ERROR',
        DiagnosticSeverity.critical => 'CRITICAL',
      };
}

enum DiagnosticCategory {
  navigation,
  auth,
  quota,
  ai,
  knowledge,
  drive,
  ive,
  runtime,
}

extension DiagnosticCategoryValue on DiagnosticCategory {
  String get value => switch (this) {
        DiagnosticCategory.navigation => 'NAVIGATION',
        DiagnosticCategory.auth => 'AUTH',
        DiagnosticCategory.quota => 'QUOTA',
        DiagnosticCategory.ai => 'AI',
        DiagnosticCategory.knowledge => 'KNOWLEDGE',
        DiagnosticCategory.drive => 'DRIVE',
        DiagnosticCategory.ive => 'IVE',
        DiagnosticCategory.runtime => 'RUNTIME',
      };
}

/// Allowlisted metadata keys accepted anywhere in the app — see
/// diagnostic_sanitizer.dart's buildSafeMetadata. Deliberately one shared
/// set rather than one per category (mission: "do not over-engineer"); a
/// key not needed by a given event is simply never passed for it.
const Set<String> kDiagnosticMetadataKeys = {
  // navigation
  'from_route', 'to_route', 'redirect_reason', 'redirect_target',
  // auth / profile
  'method', 'role', 'is_admin', 'is_pro', 'reason', 'profile_resolved',
  // quota
  'used', 'limit', 'remaining', 'source_screen',
  // ai
  'module', 'provider_stage', 'response_length', 'grounding_count', 'success',
  // knowledge / import
  'file_type', 'file_size_bytes', 'stage', 'project_id',
  // drive
  'mime_type', 'size_bytes',
  // ive
  'knowledge_item_count', 'context_project_id',
  // runtime
  'widget', 'component', 'zone_name',
  // runtime — IVE-COMMERCIAL-STABILITY-09O uncaught-error forensic context
  // (see ive_forensic_snapshot.dart). Booleans/enums/route strings only —
  // never content, per mission section 05's explicit "do NOT log" list.
  'previous_route', 'lifecycle_state', 'overlay_mounted',
  'overlay_interaction_active', 'issue_present', 'project_context_present',
  'builder_child_was_null',
  // generic
  'attempt', 'count',
};
