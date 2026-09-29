import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/modules/route_policy.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/action_queue_item.dart';
import '../../../data/models/market_analysis.dart';
import '../../../data/models/project.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/campaign_provider.dart';
import '../../../providers/content_provider.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/persona_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/project_provider.dart';
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

    // COMMERCIAL-V1-UX-RECONCILIATION (Section R6, Owner-approved Option C)
    // — the Business Dashboard stays the ONE canonical entry point
    // (INSIGHTVALUES-COMMERCIAL-MACRO-01 consolidation is NOT reverted),
    // but is enriched with the real executive-intelligence components
    // selectively ported from the orphaned ExecutiveDashboardScreen (kept
    // in the tree for historical reference per module_registry.dart's own
    // note, never routed) rather than reactivating that whole screen or
    // duplicating a second dashboard. Same providers that screen already
    // used; no new data source.
    final projectsAsync = ref.watch(projectsProvider);
    final analysesAsync = ref.watch(marketAnalysesProvider);
    final pendingAsync  = ref.watch(pendingActionsProvider);

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

                    // COMMERCIAL-V1-UX-RECONCILIATION (R6) — INFORMATION
                    // (portfolio KPIs) -> INTERPRETATION/PRIORITY (executive
                    // recommendations) -> PRIORITY (pending actions), all
                    // ahead of the ACTION buttons below, per the owner's
                    // explicit ordering rule. Ported from the orphaned
                    // ExecutiveDashboardScreen's _SidebarKpiCard/
                    // _ExecutiveRecommendations/_PendingActionsCard (same
                    // providers, same no-fabricated-data guards), not
                    // reactivating that screen.
                    if (projectsAsync.valueOrNull?.isNotEmpty ?? false) ...[
                      _PortfolioSummaryRow(
                        activeProjects: (projectsAsync.valueOrNull ?? const [])
                            .where((p) => p.status == 'active' || p.status == 'executing')
                            .length,
                        analysesCount: analysesAsync.valueOrNull?.length ?? 0,
                        avgScore: _avgOpportunityScore(analysesAsync.valueOrNull ?? const []),
                        l10n: l10n,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ExecutiveRecommendationsCard(
                      projects:  projectsAsync.valueOrNull ?? const [],
                      analyses:  analysesAsync.valueOrNull ?? const [],
                      pending:   pendingAsync.valueOrNull ?? const [],
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    _DashboardPendingActionsCard(
                      pending: pendingAsync.valueOrNull ?? const [],
                      l10n: l10n,
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

// COMMERCIAL-V1-UX-RECONCILIATION (R6) — helper functions ported
// unchanged from the orphaned ExecutiveDashboardScreen's own
// _DashboardBody._avgScore.
int _avgOpportunityScore(List<MarketAnalysis> analyses) {
  if (analyses.isEmpty) return 0;
  final sum = analyses.map((a) => a.opportunityScore).fold<int>(0, (s, v) => s + v);
  return (sum / analyses.length).round();
}

Color _execScoreColor(int score) {
  if (score >= 80) return const Color(0xFF4CAF50);
  if (score >= 60) return const Color(0xFFFF9800);
  return const Color(0xFFF44336);
}

// ── R6: Portfolio summary (INFORMATION) ─────────────────────────────────────
class _PortfolioSummaryRow extends StatelessWidget {
  const _PortfolioSummaryRow({
    required this.activeProjects,
    required this.analysesCount,
    required this.avgScore,
    required this.l10n,
  });

  final int activeProjects;
  final int analysesCount;
  final int avgScore;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                  textAlign: TextAlign.center),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          stat('$activeProjects', l10n.dashPortfolioActiveProjects, const Color(0xFF6C63FF)),
          stat('$analysesCount', l10n.dashPortfolioAnalyses, const Color(0xFF00BCD4)),
          stat(
            avgScore > 0 ? '$avgScore' : '—',
            l10n.dashPortfolioAvgScore,
            avgScore > 0 ? _execScoreColor(avgScore) : Colors.white38,
          ),
        ],
      ),
    );
  }
}

// ── R6: Executive recommendations (INTERPRETATION + PRIORITY) ──────────────
// Ported from ExecutiveDashboardScreen's _ExecutiveRecommendations: every
// entry is conditioned on real data (empty projects/analyses, real pending
// count, real top-scored analysis, real zero-revenue check) -- R8 "no
// fabricated intelligence" by construction, not an added guard.
class _ExecutiveRecommendationsCard extends StatelessWidget {
  const _ExecutiveRecommendationsCard({
    required this.projects,
    required this.analyses,
    required this.pending,
    required this.l10n,
  });

  final List<Project> projects;
  final List<MarketAnalysis> analyses;
  final List<ActionQueueItem> pending;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final recs = <_Rec>[];

    if (projects.isEmpty) {
      recs.add(_Rec(Icons.add_business_rounded, const Color(0xFF6C63FF),
          l10n.dashRecEmptyProjectTitle, l10n.dashRecEmptyProjectBody));
    } else if (analyses.isEmpty) {
      final projectName = projects.first.name;
      recs.add(_Rec(Icons.analytics_rounded, const Color(0xFF00BCD4),
          l10n.dashRecEmptyAnalysisTitle, l10n.dashRecEmptyAnalysisBody(projectName)));
    }

    if (pending.isNotEmpty) {
      recs.add(_Rec(Icons.bolt_rounded, const Color(0xFFFFD700),
          l10n.dashRecPendingActionsTitle(pending.length), l10n.dashRecPendingActionsBody));
    }

    final topAnalyses = analyses.where((a) => a.opportunityScore >= 75).toList()
      ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));
    if (topAnalyses.isNotEmpty) {
      final top = topAnalyses.first;
      recs.add(_Rec(
        Icons.star_rounded,
        const Color(0xFF4CAF50),
        l10n.dashRecTopOpportunityTitle(top.niche ?? top.input),
        l10n.dashRecTopOpportunityBody(top.opportunityScore),
      ));
    }

    if (recs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(l10n.dashRecommendationsTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recs.take(4).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration:
                          BoxDecoration(color: r.color.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(r.icon, color: r.color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(r.body,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _Rec {
  const _Rec(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

// ── R6: Pending actions (PRIORITY, feeds directly into ACTION) ─────────────
class _DashboardPendingActionsCard extends StatelessWidget {
  const _DashboardPendingActionsCard({required this.pending, required this.l10n});
  final List<ActionQueueItem> pending;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFFFF9800), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.dashPendingActionsTitle,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => context.push(AppConstants.routeActionEngine),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(l10n.dashPendingActionsViewAll,
                    style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.dashPendingActionsEmpty,
                style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              ),
            )
          else
            ...pending.take(5).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            const BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.title,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (item.roiScore > 0)
                        Text('ROI: ${item.roiScore}',
                            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
