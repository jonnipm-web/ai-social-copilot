import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/modules/route_policy.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/campaign_provider.dart';
import '../../../providers/content_provider.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/persona_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/quota_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/ive_exclusion_region.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);
    // IVE-COMMERCIAL-OBSERVABILITY-07A — this used to read monthlyUsageProvider
    // (a count of the legacy post_generations table, entirely unrelated to
    // the commercial quota system), which is why a physical test found this
    // card disagreeing with Account/Upgrade (both already read
    // currentQuotaProvider, the actual ai_usage-backed source). Discovered
    // purely by reading the code while building this mission's quota
    // instrumentation -- an undeniable, one-provider-swap fix, not a new
    // remediation effort.
    final usageAsync   = ref.watch(currentQuotaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
      ),
      drawer: const AppDrawer(),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text(l10n.commonError)),
        data:    (profile) {
          final isAdmin = profile?.isAdmin ?? false;
          final isPro   = profile?.isPro ?? false;

          // COMMERCIAL-V1-UX-RECONCILIATION — Personas/Biblioteca/
          // Calendário/Campanhas/Performance were commercialEnabled:false
          // ("not released to anyone") when Remediation-06S wrote the note
          // this replaces. "Tranche 2: launch Growth Intelligence
          // commercially at Pro tier" (module_registry.dart) flipped all 5
          // to commercialEnabled:true / minimumPlan:pro — they are real,
          // released, Pro-gated modules now, not unreleased ones. onTap
          // still routes through isModuleActionable (commercialEnabled
          // only, never minimumPlan — see route_policy.dart's own doc
          // comment on isModuleActionable) so a tap always produces a real
          // navigation; the route guard itself sends a Free user to
          // /upgrade. The UX gap this mission section closes is different:
          // a Free user previously had to tap-and-get-redirected to
          // discover a card was Pro-gated at all. _ProShortcutCard below
          // shows the PRO badge, one-line benefit, and access state BEFORE
          // the tap.
          VoidCallback shortcutTap(String moduleId, String route) {
            if (isModuleActionable(moduleId, isAdmin: isAdmin)) {
              return () => context.go(route);
            }
            return () => showInfoSnack(
                  context,
                  l10n.dashFeatureUnavailable,
                );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Boas-vindas
                    Text(
                      l10n.dashWelcome,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.dashPlanLabel(profile?.roleLabel ?? 'Free'),
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Card de uso mensal
                    usageAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error:   (_, __) => const SizedBox.shrink(),
                      data:    (quota) => _UsageCard(used: quota.used, limit: quota.limit, l10n: l10n),
                    ),
                    const SizedBox(height: 16),

                    // Ação principal
                    _ActionButton(
                      icon: Icons.auto_fix_high_rounded,
                      label: l10n.dashImproveWithAi,
                      subtitle: l10n.dashImproveWithAiSubtitle,
                      color: const Color(0xFF6C63FF),
                      onTap: () => context.go(AppConstants.routeGenerate),
                    ),
                    const SizedBox(height: 12),

                    // Grid de atalhos
                    Row(
                      children: [
                        Expanded(
                          child: _ProShortcutCard(
                            icon: Icons.person_pin_rounded,
                            label: l10n.dashShortcutPersonas,
                            benefit: l10n.dashProBenefitPersonas,
                            hasAccess: isPro || isAdmin,
                            l10n: l10n,
                            onTap: shortcutTap('personas', AppConstants.routePersonas),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProShortcutCard(
                            icon: Icons.library_books_rounded,
                            label: l10n.dashShortcutLibrary,
                            benefit: l10n.dashProBenefitLibrary,
                            hasAccess: isPro || isAdmin,
                            l10n: l10n,
                            onTap: shortcutTap('content-library', AppConstants.routeContent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ProShortcutCard(
                            icon: Icons.calendar_month_rounded,
                            label: l10n.dashShortcutCalendar,
                            benefit: l10n.dashProBenefitCalendar,
                            hasAccess: isPro || isAdmin,
                            l10n: l10n,
                            onTap: shortcutTap('calendar', AppConstants.routeCalendar),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ShortcutCard(
                            icon: Icons.history_rounded,
                            label: l10n.dashShortcutHistory,
                            onTap: () => context.push(AppConstants.routeHistory),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ShortcutCard(
                            icon: Icons.auto_stories_rounded,
                            label: l10n.dashShortcutVault,
                            onTap: () => context.go(AppConstants.routeKnowledge),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          // GATE-17-FINAL-CLOSURE (IVE Adaptive Resting
                          // Placement) — physically reproduced collision:
                          // the floating IVE avatar's fixed resting corner
                          // sat on top of this card. Reports its geometry
                          // so the placement engine steers clear; renders
                          // unchanged otherwise (ive_exclusion_region.dart).
                          child: IveExclusionRegion(
                            child: _ProShortcutCard(
                              icon: Icons.campaign_rounded,
                              label: l10n.dashShortcutCampaigns,
                              benefit: l10n.dashProBenefitCampaigns,
                              hasAccess: isPro || isAdmin,
                              l10n: l10n,
                              onTap: shortcutTap('campaigns', AppConstants.routeCampaigns),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ShortcutCard(
                            icon: Icons.language_rounded,
                            label: l10n.dashShortcutWebsiteAnalyzer,
                            onTap: () => context.go(AppConstants.routeWebsiteAnalyzer),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProShortcutCard(
                            icon: Icons.bar_chart_rounded,
                            label: l10n.dashShortcutPerformance,
                            benefit: l10n.dashProBenefitPerformance,
                            hasAccess: isPro || isAdmin,
                            l10n: l10n,
                            onTap: shortcutTap('performance', AppConstants.routePerformance),
                          ),
                        ),
                      ],
                    ),

                    // Painel Admin
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 12),
                      Text(
                        l10n.dashAdminSectionTitle,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AdminStats(ref: ref, l10n: l10n),
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.admin_panel_settings_rounded,
                        label: l10n.dashAdminPanelButton,
                        subtitle: l10n.dashAdminPanelSubtitle,
                        color: const Color(0xFFFFD700),
                        onTap: () => context.go(AppConstants.routeAdmin),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.used, required this.limit, required this.l10n});
  final int used;
  final int limit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final remaining = (limit - used).clamp(0, limit);
    final pct = limit > 0 ? used / limit : 0.0;
    final isFull = remaining <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFull ? Icons.lock_outline_rounded : Icons.bolt_rounded,
                color: isFull ? Colors.red : Colors.teal,
                size: 18,
              ),
              const SizedBox(width: 8),
              // COMMERCIAL-EXPERIENCE-CLOSURE-16R (mission Section 03/09)
              // — sweep for the same class of defect as the 3 owner-
              // reported ones: this Text's content is dynamic ("$remaining
              // de $limit gerações restantes") with no Expanded/Flexible,
              // sharing a Row with a trailing Spacer + "este mês" -- at a
              // real narrow width this can overflow exactly like Knowledge
              // Vault's cards did. Expanded + ellipsis keeps the fixed-size
              // trailing label always visible and readable instead.
              Expanded(
                child: Text(
                  isFull
                      ? l10n.dashUsageLimitReached
                      : l10n.dashUsageRemaining(remaining.toString(), limit.toString()),
                  style: TextStyle(
                    color: isFull ? Colors.red : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.dashUsageThisMonth,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: isFull
                  ? Colors.red
                  : pct > 0.8
                      ? Colors.orange
                      : const Color(0xFF6C63FF),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Colors.white70;

    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// COMMERCIAL-V1-UX-RECONCILIATION (Section A) — INFORMATION FIRST for a
// released Pro-gated module: name, one-line benefit, a PRO badge and the
// user's actual access state are all visible BEFORE the tap, instead of
// the tap being the only way to discover a card is Pro-gated. `onTap`
// still goes through the caller's `shortcutTap` (routes through
// isModuleActionable + the route guard), so a Free user tapping still
// lands on /upgrade exactly as before — this only changes what's
// communicated before that tap, never the authorization path itself.
class _ProShortcutCard extends StatelessWidget {
  const _ProShortcutCard({
    required this.icon,
    required this.label,
    required this.benefit,
    required this.hasAccess,
    required this.l10n,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final String   benefit;
  final bool     hasAccess;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const proColor = Color(0xFFFFD700);
    final color = hasAccess ? Colors.white70 : Colors.white54;

    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasAccess ? Colors.white12 : proColor.withOpacity(0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const Spacer(),
                  if (!hasAccess)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: proColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: proColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        l10n.dashProBadge,
                        style: const TextStyle(
                          color: proColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                benefit,
                style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    hasAccess ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                    color: hasAccess ? const Color(0xFF4CAF50) : proColor,
                    size: 11,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hasAccess ? l10n.dashProIncluded : l10n.dashProUpgradeCta,
                      style: TextStyle(
                        color: hasAccess ? const Color(0xFF4CAF50) : proColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStats extends ConsumerWidget {
  const _AdminStats({required this.ref, required this.l10n});
  final WidgetRef ref;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync    = ref.watch(allProfilesProvider);
    final personasAsync = ref.watch(personasProvider);
    final contentAsync  = ref.watch(contentItemsProvider);
    final knowledgeAsync = ref.watch(knowledgeItemsProvider);
    final campaignsAsync = ref.watch(campaignsProvider);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: l10n.dashAdminStatUsers,
                value: usersAsync.valueOrNull?.length.toString() ?? '—',
                icon: Icons.people_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: l10n.dashAdminStatPersonas,
                value: personasAsync.valueOrNull?.length.toString() ?? '—',
                icon: Icons.person_pin_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: l10n.dashAdminStatContent,
                value: contentAsync.valueOrNull?.length.toString() ?? '—',
                icon: Icons.library_books_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: l10n.dashAdminStatSites,
                value: '—',
                icon: Icons.language_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: const SizedBox()),
            const SizedBox(width: 8),
            Expanded(child: const SizedBox()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: l10n.dashAdminStatVault,
                value: knowledgeAsync.valueOrNull?.length.toString() ?? '—',
                icon: Icons.auto_stories_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: l10n.dashAdminStatCampaigns,
                value: campaignsAsync.valueOrNull?.length.toString() ?? '—',
                icon: Icons.campaign_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: l10n.dashAdminStatAnalyzed,
                value: knowledgeAsync.valueOrNull
                        ?.where((i) => i.status == 'analyzed')
                        .length
                        .toString() ??
                    '—',
                icon: Icons.analytics_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String   label;
  final String   value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
