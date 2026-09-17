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
}) {
  return kModuleRegistry.where((m) {
    if (m.route == null) return false;
    if (m.route == AppConstants.routeUpgrade) return false;
    return m.visibleFor(isAdmin: isAdmin, isPro: isPro) && m.commercialEnabled;
  }).toList();
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Drawer(
      backgroundColor: const Color(0xFF0F0F1A),
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (_, __) => _DrawerContent(profile: null),
        data:    (profile) => _DrawerContent(profile: profile),
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
    final isPro   = profile?.isPro   ?? false;
    final current = GoRouterState.of(context).fullPath ?? '';

    // Navegação comercial: só módulos habilitados para o plano do usuário,
    // com rota própria. Ver visibleDrawerModules() acima para a razão de
    // routeUpgrade ser excluído deste loop.
    final visibleModules = visibleDrawerModules(isAdmin: false, isPro: isPro);

    return SafeArea(
      child: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF),
                  const Color(0xFF6C63FF).withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profile?.roleLabel ?? 'Free',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Itens de navegação — gerados a partir do Module Registry
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final module in visibleModules)
                  _NavItem(
                    icon: _iconFor(module.moduleId),
                    label: isEnglish ? module.nameEn : module.namePt,
                    route: module.route!,
                    current: current,
                  ),
                const Divider(color: Colors.white12, height: 24),
                // COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 27/35,
                // physical Android E2E) — these five are drill-in
                // "settings-style" destinations, not primary app sections.
                // They used context.go() like every other drawer item,
                // which REPLACES GoRouter's whole route stack instead of
                // pushing onto it -- so Navigator.canPop() was false,
                // AppBar auto-hid its back arrow, and Android's system
                // back button had nothing to pop and closed the app
                // entirely. Found live on a physical device (Samsung
                // SM-S938B, Android 16): opened "Conta e Configurações"
                // from the drawer, then back button exited the app rather
                // than returning to the previous screen. push:true fixes
                // this for exactly these five (Upgrade/Account/Support/
                // About/Admin) without touching the dynamic module list's
                // own navigation semantics, which is a separate, broader
                // surface this fix deliberately leaves alone.
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
                  const Divider(color: Colors.white12, height: 24),
                  _NavItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: t.navAdminPanel,
                    route: AppConstants.routeAdmin,
                    current: current,
                    isAdmin: true,
                    push: true,
                  ),
                ],
              ],
            ),
          ),

          // Sair
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
            title: Text(
              t.authSignOut,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
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
    'command-center': Icons.hub_rounded,
    'business-dashboard': Icons.dashboard_rounded,
    'projects': Icons.rocket_launch_rounded,
    'knowledge-vault': Icons.auto_stories_rounded,
    'website-analyzer': Icons.language_rounded,
    'market-intelligence': Icons.analytics_rounded,
    'opportunity-lab': Icons.science_rounded,
    'action-engine': Icons.bolt_rounded,
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
  final String   label;
  final String   route;
  final String   current;
  final bool     isAdmin;
  // See the call-site comment above (Section 27/35) -- true for drill-in
  // destinations that must leave a back-stack entry so the AppBar shows a
  // back arrow and Android's system back button returns here instead of
  // exiting the app.
  final bool     push;

  @override
  Widget build(BuildContext context) {
    final isSelected = current == route;
    final color = isAdmin
        ? const Color(0xFFFFD700)
        : isSelected
            ? const Color(0xFF6C63FF)
            : Colors.white70;

    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF6C63FF).withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
    );
  }
}
