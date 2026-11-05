import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/modules/module_definition.dart';
import '../../core/modules/module_registry.dart';
import '../../data/models/profile.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import 'package:ai_social_copilot/core/theme/app_motion.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';

/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — navegação comercial dirigida
/// pelo Module Registry (lib/core/modules/module_registry.dart), não mais
/// uma lista fixa. Usuários normais só veem módulos com
/// `commercialEnabled: true` permitidos pelo próprio plano -- o catálogo
/// completo (incluindo Beta/Em desenvolvimento/Interno) só existe no
/// Painel Admin, nunca aqui. Isto NÃO substitui autorização de servidor:
/// acesso direto por URL continua protegido por RLS/gates de cada tela.
// IVE-COMMERCIAL-FOUNDATION-11 — extraída como função pura (mesmo padrão
// já usado em ive_context_provider.dart's selectKnowledgeForGrounding/
// selectProjectFocus) especificamente para permitir testar a correção do
// duplicado "Planos/Plano" (docs/commercial/MODULE_LIFECYCLE_MATRIX.md
// §3) sem precisar montar uma árvore de widgets completa com GoRouter e
// AppLocalizations só para isso.
//
// routeUpgrade é explicitamente excluído: o item fixo "Plano / Upgrade"
// (ver _DrawerContent.build, após o Divider) já cobre essa rota. Antes
// desta correção, o item gerado pelo registro (`plans-upgrade`, "Planos
// / Upgrade") e o item fixo apareciam AMBOS na gaveta, navegando para a
// mesma rota com rótulos singular/plural inconsistentes.
List<ModuleDefinition> visibleDrawerModules({
  required bool isAdmin,
  required bool isPro,
  bool isPremium = false,
  // Codex Tranche 2 audit, P3 — injectable so tests can exercise this real
  // function (not just ModuleDefinition.visibleFor in isolation) against a
  // synthetic ModulePlan.premium entry, since kModuleRegistry itself has
  // none yet. Production code never passes this; it always defaults to the
  // real registry.
  List<ModuleDefinition> modules = kModuleRegistry,
}) {
  return modules.where((m) {
    if (m.route == null) return false;
    if (m.route == AppConstants.routeUpgrade) return false;
    return m.visibleFor(isAdmin: isAdmin, isPro: isPro, isPremium: isPremium) &&
        m.commercialEnabled;
  }).toList();
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.lg)),
      ),
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _DrawerContent(profile: null),
        data: (profile) => _DrawerContent(profile: profile),
      ),
    );
  }
}

class _DrawerContent extends ConsumerWidget {
  const _DrawerContent({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final isAdmin = profile?.isAdmin ?? false;
    final isPro = profile?.isPro ?? false;
    final isPremium = profile?.isPremium ?? false;
    final current = GoRouterState.of(context).fullPath ?? '';

    // Navegação comercial: só módulos habilitados para o plano do usuário,
    // com rota própria. Ver visibleDrawerModules() acima para a razão de
    // routeUpgrade ser excluído deste loop.
    final visibleModules = visibleDrawerModules(
        isAdmin: false, isPro: isPro, isPremium: isPremium);

    return SafeArea(
      child: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s4, AppSpace.s6, AppSpace.s4, AppSpace.s4),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1.0, -1.2),
                radius: 1.6,
                colors: [
                  AppColors.accent.withOpacity(0.20),
                  AppColors.surface.withOpacity(0.0),
                ],
              ),
              border: const Border(
                bottom: BorderSide(color: AppColors.line),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.accent, AppColors.info],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.insights_rounded,
                          color: AppColors.onAccent, size: 20),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Text(
                        AppConstants.appName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
                Row(
                  children: [
                    IvBadge(
                      profile?.roleLabel ?? 'Free',
                      color: isPro || isPremium
                          ? AppColors.gold
                          : AppColors.inkMuted,
                      icon: isPro || isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.person_outline_rounded,
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Text(
                        profile?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkSubtle,
                          fontSize: AppType.caption,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Itens de navegação — gerados a partir do Module Registry
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                children: [
                  for (final module in visibleModules)
                    _NavItem(
                      icon: _iconFor(module.moduleId),
                      label: isEnglish ? module.nameEn : module.namePt,
                      route: module.route!,
                      current: current,
                    ),
                ],
              ),
            ),
          ),

          // Itens de configuração sempre visíveis (fora do Expanded para
          // não serem ocultos quando há muitos módulos — WEB-007).
          // push:true mantém o comportamento corrigido da CLOSURE-16 §27/35:
          // estas telas empilham sobre o stack existente em vez de substituir.
          const Divider(color: AppColors.line, height: 1),
          _NavItem(
            icon: Icons.workspace_premium_rounded,
            label: t.navUpgrade,
            route: AppConstants.routeUpgrade,
            current: current,
            push: true,
          ),
          _NavItem(
            icon: Icons.manage_accounts_rounded,
            label: t.navAccount,
            route: AppConstants.routeAccount,
            current: current,
            push: true,
          ),
          _NavItem(
            icon: Icons.help_outline_rounded,
            label: t.navHelpSupport,
            route: AppConstants.routeSupport,
            current: current,
            push: true,
          ),
          _NavItem(
            icon: Icons.info_outline_rounded,
            label: t.navAbout,
            route: AppConstants.routeAbout,
            current: current,
            push: true,
          ),
          if (isAdmin) ...[
            const Divider(color: AppColors.line, height: 1),
            _NavItem(
              icon: Icons.admin_panel_settings_rounded,
              label: t.navAdminPanel,
              route: AppConstants.routeAdmin,
              current: current,
              isAdmin: true,
              push: true,
            ),
          ],

          // Sair
          const Divider(color: AppColors.line, height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: AppColors.inkMuted, size: 20),
            title: Text(
              t.authSignOut,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppConstants.routeLogin);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _iconFor(String moduleId) => drawerIconFor(moduleId);
}

// IVE-COMMERCIAL-FOUNDATION-11 — extraída como função pura top-level
// (Codex adversarial review, Architecture-10 mission, round 1, P2,
// ACCEPTED: "route_policy.dart's kRouteModuleOwnership... and app_drawer.
// dart's _iconFor map... a new registry entry silently gets a generic
// fallback icon if this map isn't updated alongside it"). Extracting it
// enables the coverage test in test/shared/widgets/app_drawer_test.dart
// without needing a full widget tree — the map itself is UNCHANGED, this
// only makes its silent-fallback behavior testable.
IconData drawerIconFor(String moduleId) {
  const icons = <String, IconData>{
    // INSIGHTVALUES-COMMERCIAL-MACRO-01 -- 'command-center' entry removed
    // (Codex audit P3): that module has route: null since the dashboard
    // consolidation, so it never reaches this map; drawer_test.dart's own
    // fallback-icon test still covers any truly-unmapped moduleId.
    'business-dashboard': Icons.dashboard_rounded,
    'projects': Icons.rocket_launch_rounded,
    'knowledge-vault': Icons.auto_stories_rounded,
    'website-analyzer': Icons.language_rounded,
    'market-intelligence': Icons.analytics_rounded,
    'opportunity-lab': Icons.science_rounded,
    'action-engine': Icons.bolt_rounded,
    // INSIGHTVALUES-COMMERCIAL-MACRO-01 Tranche 2 -- Growth Intelligence
    // commercially launched (commercialEnabled:true, ModulePlan.pro); each
    // now needs a dedicated icon per this map's own coverage contract.
    'improve-post': Icons.auto_fix_high_rounded,
    'personas': Icons.groups_2_rounded,
    'content-library': Icons.perm_media_rounded,
    'calendar': Icons.calendar_month_rounded,
    'campaigns': Icons.campaign_rounded,
    'performance': Icons.insights_rounded,
    'roi-tracker': Icons.trending_up_rounded,
    // INSIGHTVALUES-FINANCIAL-PRODUCT-MACRO-08 -- Strategy Lab commercially
    // enabled (COMMERCIAL/free); dedicated icon per this map's own coverage
    // contract (app_drawer_test.dart's drawerIconFor coverage check).
    'strategy-builder': Icons.candlestick_chart_rounded,
  };
  return icons[moduleId] ?? Icons.circle_outlined;
}

// Codex Gate (COMMERCIAL-EXPERIENCE-CLOSURE-16, P2 ACCEPTED) — the five
// routes _NavItem's push:true covers (see call sites above). Kept as its
// own named set (not inferred from the `push` flags scattered across the
// call sites) so the pushReplacement guard below stays correct even if a
// future edit reorders those call sites.
const Set<String> _kSettingsStyleRoutes = {
  AppConstants.routeUpgrade,
  AppConstants.routeAccount,
  AppConstants.routeSupport,
  AppConstants.routeAbout,
  AppConstants.routeAdmin,
};

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
    this.isAdmin = false,
    this.push = false,
  });

  final IconData icon;
  final String label;
  final String route;
  final String current;
  final bool isAdmin;
  // See the call-site comment above (Section 27/35) -- true for drill-in
  // destinations that must leave a back-stack entry so the AppBar shows a
  // back arrow and Android's system back button returns here instead of
  // exiting the app.
  final bool push;

  @override
  Widget build(BuildContext context) {
    final isSelected = current == route;
    final color = isAdmin
        ? AppColors.gold
        : isSelected
            ? AppColors.accent
            : AppColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2, vertical: 1),
      child: ListTile(
      leading: AnimatedContainer(
        duration: AppMotion.short,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          color: isSelected
              ? AppColors.accent.withOpacity(0.18)
              : Colors.transparent,
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.ink : color,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.accent.withOpacity(0.08),
      hoverColor: AppColors.ink.withOpacity(0.04),
      dense: true,
      horizontalTitleGap: AppSpace.s3,
      minLeadingWidth: 32,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
      onTap: () {
        Navigator.of(context).pop();
        if (push) {
          // Codex Gate (P2 ACCEPTED) — plain push() on these drill-in
          // destinations lets the back-stack grow without bound if the
          // user bounces between them (Account -> drawer -> Support ->
          // drawer -> About -> ...), each one stacking on the last
          // instead of replacing it. Already being on one of these five
          // settings-style screens and picking another replaces it
          // in-place instead — caps the stack at one settings screen deep
          // while still preserving the single real back-entry to
          // whatever the user was doing before opening the drawer.
          if (_kSettingsStyleRoutes.contains(current)) {
            context.pushReplacement(route);
          } else {
            context.push(route);
          }
        } else {
          context.go(route);
        }
      },
    ),
    );
  }
}
