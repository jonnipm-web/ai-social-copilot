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
    // com rota própria (módulos sem rota, ex: Context Copilot, são
    // overlays/capacidades embutidas, não destinos de navegação).
    final visibleModules = kModuleRegistry.where((m) {
      if (m.route == null) return false;
      return m.visibleFor(isAdmin: false, isPro: isPro) && m.commercialEnabled;
    }).toList();

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
                _NavItem(
                  icon: Icons.workspace_premium_rounded,
                  label: t.navUpgrade,
                  route: AppConstants.routeUpgrade,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.manage_accounts_rounded,
                  label: t.navAccount,
                  route: AppConstants.routeAccount,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.help_outline_rounded,
                  label: t.navHelpSupport,
                  route: AppConstants.routeSupport,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.info_outline_rounded,
                  label: t.navAbout,
                  route: AppConstants.routeAbout,
                  current: current,
                ),
                if (isAdmin) ...[
                  const Divider(color: Colors.white12, height: 24),
                  _NavItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: t.navAdminPanel,
                    route: AppConstants.routeAdmin,
                    current: current,
                    isAdmin: true,
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

  IconData _iconFor(String moduleId) {
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
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
    this.locked  = false,
    this.isAdmin = false,
  });

  final IconData icon;
  final String   label;
  final String   route;
  final String   current;
  final bool     locked;
  final bool     isAdmin;

  @override
  Widget build(BuildContext context) {
    final isSelected = current == route;
    final color = isAdmin
        ? const Color(0xFFFFD700)
        : locked
            ? Colors.white24
            : isSelected
                ? const Color(0xFF6C63FF)
                : Colors.white70;

    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock_rounded, color: Colors.white24, size: 12),
          ],
        ],
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF6C63FF).withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: locked
          ? () {
              Navigator.of(context).pop();
              context.push(AppConstants.routeUpgrade);
            }
          : () {
              Navigator.of(context).pop();
              context.go(route);
            },
    );
  }
}
