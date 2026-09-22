/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — modelo do Module Registry.
///
/// Single source of truth por trás de duas superfícies de visibilidade
/// distintas: o Admin Control Plane (vê tudo, com status) e a navegação
/// comercial normal (só o que `commercialEnabled` autoriza para o plano do
/// usuário). Visibilidade aqui é só apresentação -- nunca substitui RLS/
/// autorização de servidor, que continua sendo a fonte real de verdade.
library;

enum ModuleStatus {
  active,
  beta,
  inDevelopment,
  disabled,
  planned,
  internal;

  String get labelPt => switch (this) {
        ModuleStatus.active => 'Ativo',
        ModuleStatus.beta => 'Beta',
        ModuleStatus.inDevelopment => 'Em desenvolvimento',
        ModuleStatus.disabled => 'Desativado',
        ModuleStatus.planned => 'Planejado',
        ModuleStatus.internal => 'Interno',
      };

  String get labelEn => switch (this) {
        ModuleStatus.active => 'Active',
        ModuleStatus.beta => 'Beta',
        ModuleStatus.inDevelopment => 'In development',
        ModuleStatus.disabled => 'Disabled',
        ModuleStatus.planned => 'Planned',
        ModuleStatus.internal => 'Internal',
      };
}

/// Plano COMERCIAL mínimo exigido quando o módulo está liberado.
///
/// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — só planos pagos/gratuitos reais
/// (os mesmos de `profiles.role`: free/pro/premium). Admin e beta_tester são
/// PAPÉIS, não planos: "só admin" é expresso pelo [ModuleLifecycle]
/// (INTERNAL/EXPERIMENTAL), nunca por um plano. Ordem = hierarquia.
enum ModulePlan {
  free,
  pro,
  premium;

  String get labelPt => switch (this) {
        ModulePlan.free => 'Gratuito',
        ModulePlan.pro => 'Pro',
        ModulePlan.premium => 'Premium',
      };

  String get labelEn => switch (this) {
        ModulePlan.free => 'Free',
        ModulePlan.pro => 'Pro',
        ModulePlan.premium => 'Premium',
      };

  /// Valor no contrato do servidor (supabase/functions/_shared/module_policy.ts).
  String get wireName => name;
}

/// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — lifecycle do Promotion Gate
/// (docs/architecture/modules/MODULE_PROMOTION_GATE.md). Espelha o
/// `lifecycle` do manifesto do servidor; a paridade é verificada por
/// test/core/modules/server_module_policy_drift_test.dart.
enum ModuleLifecycle {
  experimental('EXPERIMENTAL'),
  internal('INTERNAL'),
  alpha('ALPHA'),
  beta('BETA'),
  releaseCandidate('RELEASE_CANDIDATE'),
  commercial('COMMERCIAL'),
  deprecated('DEPRECATED');

  const ModuleLifecycle(this.wireName);
  final String wireName;

  /// Lifecycles alcançáveis por quem tem o papel beta_tester.
  bool get betaReachable =>
      this == ModuleLifecycle.alpha ||
      this == ModuleLifecycle.beta ||
      this == ModuleLifecycle.releaseCandidate;
}

/// Classificação de release -- não controla visibilidade por si só
/// (`commercialEnabled` faz isso); é metadado para o Admin entender ONDE
/// no roadmap um módulo está.
enum ModuleReleaseClass {
  commercialV1,
  postV1,
  betaProgram,
  internalTooling,
  externalPlanned;

  String get labelPt => switch (this) {
        ModuleReleaseClass.commercialV1 => 'Comercial V1',
        ModuleReleaseClass.postV1 => 'Pós-V1',
        ModuleReleaseClass.betaProgram => 'Programa Beta',
        ModuleReleaseClass.internalTooling => 'Ferramenta interna',
        ModuleReleaseClass.externalPlanned => 'Externo/planejado',
      };

  String get labelEn => switch (this) {
        ModuleReleaseClass.commercialV1 => 'Commercial V1',
        ModuleReleaseClass.postV1 => 'Post-V1',
        ModuleReleaseClass.betaProgram => 'Beta program',
        ModuleReleaseClass.internalTooling => 'Internal tooling',
        ModuleReleaseClass.externalPlanned => 'External/planned',
      };
}

class ModuleDefinition {
  const ModuleDefinition({
    required this.moduleId,
    required this.namePt,
    required this.nameEn,
    required this.status,
    required this.adminVisible,
    required this.adminClickable,
    required this.commercialEnabled,
    required this.minimumPlan,
    this.route,
    this.backendDependencies = const [],
    this.edgeFunctions = const [],
    this.databaseDependencies = const [],
    this.aiDependency = false,
    required this.readinessPt,
    required this.readinessEn,
    required this.releaseClassification,
    this.notes = '',
    this.lifecycleOverride,
  });

  final String moduleId;
  final String namePt;
  final String nameEn;
  final ModuleStatus status;

  /// Admin vê este módulo no inventário completo (mission section 01: quase
  /// sempre true -- a exceção seria algo removido/descontinuado por completo).
  final bool adminVisible;

  /// Admin pode de fato abrir/navegar até este módulo (false só quando
  /// tecnicamente inseguro, ex: uma feature parcialmente implementada que
  /// quebraria a UI).
  final bool adminClickable;

  /// Aparece na navegação comercial normal (sujeito também a `minimumPlan`).
  final bool commercialEnabled;

  final ModulePlan minimumPlan;

  /// Rota GoRouter, quando existe uma (alguns módulos são overlays/globais,
  /// ex: Context Copilot).
  final String? route;

  final List<String> backendDependencies;
  final List<String> edgeFunctions;
  final List<String> databaseDependencies;
  final bool aiDependency;

  final String readinessPt;
  final String readinessEn;
  final ModuleReleaseClass releaseClassification;
  final String notes;

  /// Só para lifecycles que não derivam dos campos legados (ALPHA/BETA/
  /// RELEASE_CANDIDATE para o programa beta). Nulo = derivado ([lifecycle]).
  final ModuleLifecycle? lifecycleOverride;

  /// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — derivação determinística que
  /// preserva exatamente o comportamento legado: liberado → COMMERCIAL;
  /// planejado/em desenvolvimento → EXPERIMENTAL; desativado → DEPRECATED;
  /// qualquer outro não liberado → INTERNAL (só admin, como sempre foi).
  ModuleLifecycle get lifecycle {
    final override = lifecycleOverride;
    if (override != null) return override;
    if (commercialEnabled) return ModuleLifecycle.commercial;
    return switch (status) {
      ModuleStatus.planned || ModuleStatus.inDevelopment => ModuleLifecycle.experimental,
      ModuleStatus.disabled => ModuleLifecycle.deprecated,
      ModuleStatus.active || ModuleStatus.beta || ModuleStatus.internal => ModuleLifecycle.internal,
    };
  }

  /// Visibilidade no drawer (apresentação, não autorização — o servidor
  /// decide o acesso real, supabase/functions/_shared/entitlement.ts).
  bool visibleFor({required bool isAdmin, required bool isPro, bool isPremium = false}) {
    if (isAdmin) return adminVisible;
    if (!commercialEnabled) return false;
    return switch (minimumPlan) {
      ModulePlan.free => true,
      ModulePlan.pro => isPro,
      ModulePlan.premium => isPremium,
    };
  }
}
