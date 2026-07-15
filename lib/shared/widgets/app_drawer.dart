import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

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
    final isAdmin = profile?.isAdmin ?? false;
    final isPro   = profile?.isPro   ?? false;
    final current = GoRouterState.of(context).fullPath ?? '';

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

          // Itens de navegação
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: Icons.hub_rounded,
                  label: 'OS Command Center',
                  route: AppConstants.routeHome,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Business Dashboard',
                  route: AppConstants.routeDashboard,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Melhorar Post',
                  route: AppConstants.routeGenerate,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.person_pin_rounded,
                  label: 'Personas / Marcas',
                  route: AppConstants.routePersonas,
                  current: current,
                  locked: !isPro && !isAdmin,
                ),
                _NavItem(
                  icon: Icons.library_books_rounded,
                  label: 'Biblioteca',
                  route: AppConstants.routeContent,
                  current: current,
                  locked: !isPro && !isAdmin,
                ),
                _NavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Calendário',
                  route: AppConstants.routeCalendar,
                  current: current,
                  locked: !isPro && !isAdmin,
                ),
                _NavItem(
                  icon: Icons.auto_stories_rounded,
                  label: 'Cofre de Conhecimento',
                  route: AppConstants.routeKnowledge,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.campaign_rounded,
                  label: 'Campanhas',
                  route: AppConstants.routeCampaigns,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.language_rounded,
                  label: 'Website Analyzer',
                  route: AppConstants.routeWebsiteAnalyzer,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Performance',
                  route: AppConstants.routePerformance,
                  current: current,
                ),
                const Divider(color: Colors.white12, height: 24),
                _NavItem(
                  icon: Icons.analytics_rounded,
                  label: 'Market Intelligence',
                  route: AppConstants.routeMarketIntelligence,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.rocket_launch_rounded,
                  label: 'Projetos',
                  route: AppConstants.routeProjects,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.insights_rounded,
                  label: 'ROI Tracker',
                  route: AppConstants.routeRoiTracker,
                  current: current,
                ),
                const Divider(color: Colors.white12, height: 24),
                // ── Fase 10A — Business OS ─────────────────────
                _NavItem(
                  icon: Icons.speed_rounded,
                  label: 'Executive Dashboard',
                  route: AppConstants.routeExecutiveDashboard,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.hub_rounded,
                  label: 'Decision Center',
                  route: AppConstants.routeEcosystem,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.schedule_rounded,
                  label: 'Alocação de Recursos',
                  route: AppConstants.routeEcosystemResources,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.summarize_rounded,
                  label: 'Briefing Semanal',
                  route: AppConstants.routeEcosystemBriefing,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.science_rounded,
                  label: 'Opportunity Lab',
                  route: AppConstants.routeOpportunityLab,
                  current: current,
                ),
                _NavItem(
                  icon: Icons.bolt_rounded,
                  label: 'Action Engine',
                  route: AppConstants.routeActionEngine,
                  current: current,
                ),
                const Divider(color: Colors.white12, height: 24),
                _NavItem(
                  icon: Icons.history_rounded,
                  label: 'Histórico',
                  route: AppConstants.routeHistory,
                  current: current,
                ),
                const Divider(color: Colors.white12, height: 24),
                _NavItem(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Plano / Upgrade',
                  route: AppConstants.routeUpgrade,
                  current: current,
                ),
                const Divider(color: Colors.white12, height: 24),
                _NavItem(
                  icon: Icons.bug_report_rounded,
                  label: 'Intelligence Debug',
                  route: AppConstants.routeIntelligenceDebug,
                  current: current,
                ),
                if (isAdmin) ...[
                  const Divider(color: Colors.white12, height: 24),
                  _NavItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Painel Admin',
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
            title: const Text(
              'Sair',
              style: TextStyle(color: Colors.white54, fontSize: 14),
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
