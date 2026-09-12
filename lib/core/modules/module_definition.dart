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

/// Plano mínimo exigido para ver/usar o módulo quando `commercialEnabled`.
enum ModulePlan {
  free,
  pro,
  admin;

  String get labelPt => switch (this) {
        ModulePlan.free => 'Gratuito',
        ModulePlan.pro => 'Pro',
        ModulePlan.admin => 'Admin',
      };

  String get labelEn => switch (this) {
        ModulePlan.free => 'Free',
        ModulePlan.pro => 'Pro',
        ModulePlan.admin => 'Admin',
      };
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

  bool visibleFor({required bool isAdmin, required bool isPro}) {
    if (isAdmin) return adminVisible;
    if (!commercialEnabled) return false;
    if (minimumPlan == ModulePlan.admin) return false;
    if (minimumPlan == ModulePlan.pro) return isPro;
    return true;
  }
}
