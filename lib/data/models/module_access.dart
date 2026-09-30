/// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — the server's answer to "which
/// modules may I use?" (Edge Function `module-access`, computed by
/// supabase/functions/_shared/entitlement.ts).
///
/// This is a CACHE for UX and for IVE capability discovery, never an
/// authority: every protected Edge Function re-checks entitlement on each
/// call, so nothing in this object — or any locally edited copy of it —
/// can unlock a capability. Parsing is default-deny: an unknown module, a
/// malformed entry or a malformed payload is reported as not allowed.
class ModuleAccessEntry {
  const ModuleAccessEntry({required this.allowed, this.code, this.requiredPlan});

  final bool allowed;

  /// Public denial code (PLAN_REQUIRED, MODULE_NOT_AVAILABLE, ...), null when allowed.
  final String? code;
  final String? requiredPlan;
}

class ServerModuleAccess {
  const ServerModuleAccess({
    required this.plan,
    required this.roles,
    required this.modules,
    required this.correlationId,
  });

  final String? plan;
  final Set<String> roles;
  final Map<String, ModuleAccessEntry> modules;
  final String? correlationId;

  /// Default deny: a module the server did not list is not available.
  bool isAllowed(String moduleId) => modules[moduleId]?.allowed ?? false;

  /// Module ids the server authorized — what IVE may offer to the user.
  Set<String> get allowedModuleIds =>
      {for (final e in modules.entries) if (e.value.allowed) e.key};

  factory ServerModuleAccess.fromMap(Map<String, dynamic> map) {
    final subject = map['subject'];
    final rawModules = map['modules'];
    if (subject is! Map || rawModules is! List) {
      throw const FormatException('module-access: malformed payload');
    }
    final modules = <String, ModuleAccessEntry>{};
    for (final raw in rawModules) {
      if (raw is! Map) continue;
      final id = raw['module_id'];
      if (id is! String || id.isEmpty) continue;
      modules[id] = ModuleAccessEntry(
        // Only a literal `true` grants — anything else is a denial.
        allowed: raw['allowed'] == true,
        code: raw['code'] is String ? raw['code'] as String : null,
        requiredPlan: raw['required_plan'] is String ? raw['required_plan'] as String : null,
      );
    }
    final roles = subject['roles'];
    return ServerModuleAccess(
      plan: subject['plan'] is String ? subject['plan'] as String : null,
      roles: roles is List ? roles.whereType<String>().toSet() : const {},
      modules: modules,
      correlationId: map['correlation_id'] is String ? map['correlation_id'] as String : null,
    );
  }
}
