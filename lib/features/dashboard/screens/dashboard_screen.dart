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
import 'package:ai_social_copilot/core/theme/app_motion.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';
import 'package:ai_social_copilot/shared/ui/iv_charts.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';

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
    final usageAsync = ref.watch(currentQuotaProvider);

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
    final pendingAsync = ref.watch(pendingActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const _BrandTitle(),
      ),
      drawer: const AppDrawer(),
      body: profileAsync.when(
        loading: () => const _DashboardSkeleton(),
        error: (e, _) => Center(child: Text(l10n.commonError)),
        data: (profile) {
          final isAdmin = profile?.isAdmin ?? false;
          final isPro = profile?.isPro ?? false;

          // COMMERCIAL-V1-UX-RECONCILIATION — Pro-gated modules route through
          // isModuleActionable (commercialEnabled only); the route guard
          // itself sends a Free user to /upgrade. _ModuleTile shows the PRO
          // badge, benefit and access state BEFORE the tap.
          VoidCallback shortcutTap(String moduleId, String route) {
            if (isModuleActionable(moduleId, isAdmin: isAdmin)) {
              return () => context.go(route);
            }
            return () => showInfoSnack(
                  context,
                  l10n.dashFeatureUnavailable,
                );
          }

          final projects = projectsAsync.valueOrNull ?? const <Project>[];
          final analyses =
              analysesAsync.valueOrNull ?? const <MarketAnalysis>[];
          final pending =
              pendingAsync.valueOrNull ?? const <ActionQueueItem>[];
          final hasProAccess = isPro || isAdmin;

          final topAnalyses = [...analyses]
            ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));

          final mainItems = <Widget>[
                    // ── Hero ────────────────────────────────────────────
                    _Hero(
                      title: l10n.dashWelcome,
                      planLabel:
                          l10n.dashPlanLabel(profile?.roleLabel ?? 'Free'),
                      isPro: hasProAccess,
                    ),

                    // ── Primary action ──────────────────────────────────
                    IvPrimaryAction(
                      icon: Icons.auto_fix_high_rounded,
                      label: l10n.dashImproveWithAi,
                      subtitle: l10n.dashImproveWithAiSubtitle,
                      onTap: () => context.go(AppConstants.routeGenerate),
                    ),

                    // ── Portfolio KPIs (INFORMATION) ────────────────────
                    if (projects.isNotEmpty)
                      _PortfolioSummaryRow(
                        activeProjects: projects
                            .where((p) =>
                                p.status == 'active' || p.status == 'executing')
                            .length,
                        analysesCount: analyses.length,
                        avgScore: _avgOpportunityScore(analyses),
                        l10n: l10n,
                      ),

                    // ── Score chart (real analyses only; a ranking needs 2+) ─
                    if (topAnalyses.length >= 2)
                      IvCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            IvSectionHeader(
                              title: l10n.dashScoreChartTitle,
                              icon: Icons.insights_rounded,
                              iconColor: AppColors.info,
                            ),
                            const SizedBox(height: AppSpace.s4),
                            IvBarList(
                              max: 100,
                              data: [
                                for (final a in topAnalyses.take(6))
                                  IvBarDatum(a.niche ?? a.input,
                                      a.opportunityScore.toDouble()),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // ── Modules ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: IvEyebrow(l10n.dashModulesTitle),
                    ),
                    IvGrid(
                      minTileWidth: 150,
                      children: [
                        _ModuleTile(
                          icon: Icons.groups_2_rounded,
                          color: AppColors.accent,
                          label: l10n.dashShortcutPersonas,
                          benefit: l10n.dashProBenefitPersonas,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'personas', AppConstants.routePersonas),
                        ),
                        _ModuleTile(
                          icon: Icons.perm_media_rounded,
                          color: AppColors.info,
                          label: l10n.dashShortcutLibrary,
                          benefit: l10n.dashProBenefitLibrary,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'content-library', AppConstants.routeContent),
                        ),
                        _ModuleTile(
                          icon: Icons.calendar_month_rounded,
                          color: AppColors.warning,
                          label: l10n.dashShortcutCalendar,
                          benefit: l10n.dashProBenefitCalendar,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'calendar', AppConstants.routeCalendar),
                        ),
                        _ModuleTile(
                          icon: Icons.history_rounded,
                          color: AppColors.inkMuted,
                          label: l10n.dashShortcutHistory,
                          onTap: () => context.push(AppConstants.routeHistory),
                        ),
                        _ModuleTile(
                          icon: Icons.auto_stories_rounded,
                          color: AppColors.accent,
                          label: l10n.dashShortcutVault,
                          onTap: () => context.go(AppConstants.routeKnowledge),
                        ),
                        // GATE-17-FINAL-CLOSURE — reports its geometry so the
                        // floating IVE avatar's resting corner steers clear.
                        IveExclusionRegion(
                          child: _ModuleTile(
                            icon: Icons.campaign_rounded,
                            color: AppColors.positive,
                            label: l10n.dashShortcutCampaigns,
                            benefit: l10n.dashProBenefitCampaigns,
                            pro: true,
                            hasAccess: hasProAccess,
                            l10n: l10n,
                            onTap: shortcutTap(
                                'campaigns', AppConstants.routeCampaigns),
                          ),
                        ),
                        _ModuleTile(
                          icon: Icons.language_rounded,
                          color: AppColors.info,
                          label: l10n.dashShortcutWebsiteAnalyzer,
                          onTap: () =>
                              context.go(AppConstants.routeWebsiteAnalyzer),
                        ),
                        _ModuleTile(
                          icon: Icons.insights_rounded,
                          color: AppColors.accent,
                          label: l10n.dashShortcutPerformance,
                          benefit: l10n.dashProBenefitPerformance,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'performance', AppConstants.routePerformance),
                        ),
                      ],
                    ),

                    // ── Admin ───────────────────────────────────────────
                    if (isAdmin) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s4),
                        child: IvEyebrow(l10n.dashAdminSectionTitle,
                            color: AppColors.gold),
                      ),
                      _AdminStats(ref: ref, l10n: l10n),
                      IvCard(
                        accent: AppColors.gold,
                        onTap: () => context.go(AppConstants.routeAdmin),
                        child: Row(
                          children: [
                            const IvIconTile(
                                Icons.admin_panel_settings_rounded,
                                color: AppColors.gold),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.dashAdminPanelButton,
                                      style: const TextStyle(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w600)),
                                  Text(l10n.dashAdminPanelSubtitle,
                                      style: const TextStyle(
                                          color: AppColors.inkMuted,
                                          fontSize: AppType.caption)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkSubtle),
                          ],
                        ),
                      ),
                    ],

          ];
          final sideItems = <Widget>[
                    // ── Quota ───────────────────────────────────────────
                    usageAsync.when(
                      loading: () => const IvSkeleton(height: 96),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (quota) => _UsageCard(
                          used: quota.used, limit: quota.limit, l10n: l10n),
                    ),

                    // ── Recommendations (INTERPRETATION + PRIORITY) ─────
                    _ExecutiveRecommendationsCard(
                      projects: projects,
                      analyses: analyses,
                      pending: pending,
                      l10n: l10n,
                    ),

                    // ── Pending actions (PRIORITY → ACTION) ─────────────
                    _DashboardPendingActionsCard(
                      pending: pending,
                      l10n: l10n,
                    ),

          ];
          final singleItems = <Widget>[
                    // ── Hero ────────────────────────────────────────────
                    _Hero(
                      title: l10n.dashWelcome,
                      planLabel:
                          l10n.dashPlanLabel(profile?.roleLabel ?? 'Free'),
                      isPro: hasProAccess,
                    ),

                    // ── Primary action ──────────────────────────────────
                    IvPrimaryAction(
                      icon: Icons.auto_fix_high_rounded,
                      label: l10n.dashImproveWithAi,
                      subtitle: l10n.dashImproveWithAiSubtitle,
                      onTap: () => context.go(AppConstants.routeGenerate),
                    ),

                    // ── Quota ───────────────────────────────────────────
                    usageAsync.when(
                      loading: () => const IvSkeleton(height: 96),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (quota) => _UsageCard(
                          used: quota.used, limit: quota.limit, l10n: l10n),
                    ),

                    // ── Portfolio KPIs (INFORMATION) ────────────────────
                    if (projects.isNotEmpty)
                      _PortfolioSummaryRow(
                        activeProjects: projects
                            .where((p) =>
                                p.status == 'active' || p.status == 'executing')
                            .length,
                        analysesCount: analyses.length,
                        avgScore: _avgOpportunityScore(analyses),
                        l10n: l10n,
                      ),

                    // ── Score chart (real analyses only; a ranking needs 2+) ─
                    if (topAnalyses.length >= 2)
                      IvCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            IvSectionHeader(
                              title: l10n.dashScoreChartTitle,
                              icon: Icons.insights_rounded,
                              iconColor: AppColors.info,
                            ),
                            const SizedBox(height: AppSpace.s4),
                            IvBarList(
                              max: 100,
                              data: [
                                for (final a in topAnalyses.take(6))
                                  IvBarDatum(a.niche ?? a.input,
                                      a.opportunityScore.toDouble()),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // ── Recommendations (INTERPRETATION + PRIORITY) ─────
                    _ExecutiveRecommendationsCard(
                      projects: projects,
                      analyses: analyses,
                      pending: pending,
                      l10n: l10n,
                    ),

                    // ── Pending actions (PRIORITY → ACTION) ─────────────
                    _DashboardPendingActionsCard(
                      pending: pending,
                      l10n: l10n,
                    ),

                    // ── Modules ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: IvEyebrow(l10n.dashModulesTitle),
                    ),
                    IvGrid(
                      minTileWidth: 150,
                      children: [
                        _ModuleTile(
                          icon: Icons.groups_2_rounded,
                          color: AppColors.accent,
                          label: l10n.dashShortcutPersonas,
                          benefit: l10n.dashProBenefitPersonas,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'personas', AppConstants.routePersonas),
                        ),
                        _ModuleTile(
                          icon: Icons.perm_media_rounded,
                          color: AppColors.info,
                          label: l10n.dashShortcutLibrary,
                          benefit: l10n.dashProBenefitLibrary,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'content-library', AppConstants.routeContent),
                        ),
                        _ModuleTile(
                          icon: Icons.calendar_month_rounded,
                          color: AppColors.warning,
                          label: l10n.dashShortcutCalendar,
                          benefit: l10n.dashProBenefitCalendar,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'calendar', AppConstants.routeCalendar),
                        ),
                        _ModuleTile(
                          icon: Icons.history_rounded,
                          color: AppColors.inkMuted,
                          label: l10n.dashShortcutHistory,
                          onTap: () => context.push(AppConstants.routeHistory),
                        ),
                        _ModuleTile(
                          icon: Icons.auto_stories_rounded,
                          color: AppColors.accent,
                          label: l10n.dashShortcutVault,
                          onTap: () => context.go(AppConstants.routeKnowledge),
                        ),
                        // GATE-17-FINAL-CLOSURE — reports its geometry so the
                        // floating IVE avatar's resting corner steers clear.
                        IveExclusionRegion(
                          child: _ModuleTile(
                            icon: Icons.campaign_rounded,
                            color: AppColors.positive,
                            label: l10n.dashShortcutCampaigns,
                            benefit: l10n.dashProBenefitCampaigns,
                            pro: true,
                            hasAccess: hasProAccess,
                            l10n: l10n,
                            onTap: shortcutTap(
                                'campaigns', AppConstants.routeCampaigns),
                          ),
                        ),
                        _ModuleTile(
                          icon: Icons.language_rounded,
                          color: AppColors.info,
                          label: l10n.dashShortcutWebsiteAnalyzer,
                          onTap: () =>
                              context.go(AppConstants.routeWebsiteAnalyzer),
                        ),
                        _ModuleTile(
                          icon: Icons.insights_rounded,
                          color: AppColors.accent,
                          label: l10n.dashShortcutPerformance,
                          benefit: l10n.dashProBenefitPerformance,
                          pro: true,
                          hasAccess: hasProAccess,
                          l10n: l10n,
                          onTap: shortcutTap(
                              'performance', AppConstants.routePerformance),
                        ),
                      ],
                    ),

                    // ── Admin ───────────────────────────────────────────
                    if (isAdmin) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s4),
                        child: IvEyebrow(l10n.dashAdminSectionTitle,
                            color: AppColors.gold),
                      ),
                      _AdminStats(ref: ref, l10n: l10n),
                      IvCard(
                        accent: AppColors.gold,
                        onTap: () => context.go(AppConstants.routeAdmin),
                        child: Row(
                          children: [
                            const IvIconTile(
                                Icons.admin_panel_settings_rounded,
                                color: AppColors.gold),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.dashAdminPanelButton,
                                      style: const TextStyle(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w600)),
                                  Text(l10n.dashAdminPanelSubtitle,
                                      style: const TextStyle(
                                          color: AppColors.inkMuted,
                                          fontSize: AppType.caption)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkSubtle),
                          ],
                        ),
                      ),
                    ],

          ];

          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  wide ? AppSpace.s8 : AppSpace.s4,
                  AppSpace.s2,
                  wide ? AppSpace.s8 : AppSpace.s4,
                  AppSpace.s12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: wide ? 1160 : AppConstants.maxBodyWidth),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: IvStagger(
                                  gap: AppSpace.s4, children: mainItems),
                            ),
                            const SizedBox(width: AppSpace.s6),
                            SizedBox(
                              width: 380,
                              child: IvStagger(
                                  gap: AppSpace.s4, children: sideItems),
                            ),
                          ],
                        )
                      : IvStagger(gap: AppSpace.s4, children: singleItems),
                ),
              ),
            );
          });
        },
      ),
    );
  }
}

// ── App bar brand ───────────────────────────────────────────────────────────
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.info],
            ),
          ),
          child: const Icon(Icons.insights_rounded,
              size: 14, color: AppColors.onAccent),
        ),
        const SizedBox(width: AppSpace.s2),
        const Flexible(
          child: Text(
            AppConstants.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Hero ────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.planLabel,
    required this.isPro,
  });

  final String title;
  final String planLabel;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [AppColors.ink, Color(0xFFB8C4CF)],
            ).createShader(r),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          IvBadge(
            planLabel,
            color: isPro ? AppColors.gold : AppColors.inkMuted,
            icon: isPro
                ? Icons.workspace_premium_rounded
                : Icons.person_outline_rounded,
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ────────────────────────────────────────────────────────
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IvSkeleton(height: 56, radius: AppRadius.md),
              SizedBox(height: AppSpace.s4),
              IvSkeleton(height: 76),
              SizedBox(height: AppSpace.s4),
              IvSkeleton(height: 96),
              SizedBox(height: AppSpace.s4),
              IvSkeleton(height: 160),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quota ───────────────────────────────────────────────────────────────────
class _UsageCard extends StatelessWidget {
  const _UsageCard(
      {required this.used, required this.limit, required this.l10n});
  final int used;
  final int limit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final remaining = (limit - used).clamp(0, limit);
    final pct = limit > 0 ? used / limit : 0.0;
    final isFull = remaining <= 0;
    final color = isFull
        ? AppColors.negative
        : pct > 0.8
            ? AppColors.warning
            : AppColors.accent;

    return IvCard(
      child: Row(
        children: [
          IvRingGauge(
            value: used.toDouble(),
            max: limit <= 0 ? 1 : limit.toDouble(),
            color: color,
            size: 58,
            stroke: 6,
            semanticsLabel: '$used / $limit',
            center: Icon(
              isFull ? Icons.lock_outline_rounded : Icons.bolt_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: IvEyebrow(l10n.dashQuotaTitle)),
                    Text(
                      l10n.dashUsageThisMonth,
                      style: const TextStyle(
                          color: AppColors.inkSubtle,
                          fontSize: AppType.caption),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // COMMERCIAL-EXPERIENCE-CLOSURE-16R — dynamic text, ellipsis
                // keeps it readable at narrow widths.
                Text(
                  isFull
                      ? l10n.dashUsageLimitReached
                      : l10n.dashUsageRemaining(
                          remaining.toString(), limit.toString()),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFull ? AppColors.negative : AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
                  duration: AppMotion.reduced(context)
                      ? Duration.zero
                      : AppMotion.chart,
                  curve: AppMotion.emphasized,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: v,
                      backgroundColor: AppColors.line,
                      color: color,
                      minHeight: 5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Module tile ─────────────────────────────────────────────────────────────
// COMMERCIAL-V1-UX-RECONCILIATION (Section A) — INFORMATION FIRST for a
// Pro-gated module: name, benefit, PRO badge and access state visible
// BEFORE the tap. onTap still goes through shortcutTap + the route guard.
class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.benefit,
    this.pro = false,
    this.hasAccess = true,
    this.l10n,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? benefit;
  final bool pro;
  final bool hasAccess;
  final AppLocalizations? l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = pro && !hasAccess;
    return IvCard(
      onTap: onTap,
      accent: locked ? AppColors.gold : color,
      padding: const EdgeInsets.all(AppSpace.s3 + 2),
      child: SizedBox(
        height: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IvIconTile(icon, color: locked ? AppColors.inkMuted : color,
                    size: 36),
                const Spacer(),
                if (pro && l10n != null)
                  IvBadge(
                    l10n!.dashProBadge,
                    color: hasAccess ? AppColors.positive : AppColors.gold,
                    icon: hasAccess
                        ? Icons.check_rounded
                        : Icons.lock_outline_rounded,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (benefit != null) ...[
              const SizedBox(height: 2),
              Text(
                benefit!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.inkSubtle,
                    fontSize: AppType.caption,
                    height: 1.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Admin stats ─────────────────────────────────────────────────────────────
class _AdminStats extends ConsumerWidget {
  const _AdminStats({required this.ref, required this.l10n});
  final WidgetRef ref;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allProfilesProvider);
    final personasAsync = ref.watch(personasProvider);
    final contentAsync = ref.watch(contentItemsProvider);
    final knowledgeAsync = ref.watch(knowledgeItemsProvider);
    final campaignsAsync = ref.watch(campaignsProvider);

    Widget stat(String label, int? value, IconData icon) => IvStatCard(
          label: label,
          value: value ?? 0,
          valueText: value == null ? '—' : null,
          icon: icon,
          color: AppColors.gold,
        );

    return IvGrid(
      minTileWidth: 150,
      children: [
        stat(l10n.dashAdminStatUsers, usersAsync.valueOrNull?.length,
            Icons.people_rounded),
        stat(l10n.dashAdminStatPersonas, personasAsync.valueOrNull?.length,
            Icons.groups_2_rounded),
        stat(l10n.dashAdminStatContent, contentAsync.valueOrNull?.length,
            Icons.perm_media_rounded),
        stat(l10n.dashAdminStatVault, knowledgeAsync.valueOrNull?.length,
            Icons.auto_stories_rounded),
        stat(l10n.dashAdminStatCampaigns, campaignsAsync.valueOrNull?.length,
            Icons.campaign_rounded),
        stat(
            l10n.dashAdminStatAnalyzed,
            knowledgeAsync.valueOrNull
                ?.where((i) => i.status == 'analyzed')
                .length,
            Icons.analytics_rounded),
      ],
    );
  }
}

// COMMERCIAL-V1-UX-RECONCILIATION (R6) — helper ported unchanged from the
// orphaned ExecutiveDashboardScreen's _DashboardBody._avgScore.
int _avgOpportunityScore(List<MarketAnalysis> analyses) {
  if (analyses.isEmpty) return 0;
  final sum =
      analyses.map((a) => a.opportunityScore).fold<int>(0, (s, v) => s + v);
  return (sum / analyses.length).round();
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
    return IvGrid(
      minTileWidth: 150,
      maxColumns: 3,
      children: [
        IvStatCard(
          label: l10n.dashPortfolioActiveProjects,
          value: activeProjects,
          icon: Icons.rocket_launch_rounded,
          color: AppColors.accent,
        ),
        IvStatCard(
          label: l10n.dashPortfolioAnalyses,
          value: analysesCount,
          icon: Icons.analytics_rounded,
          color: AppColors.info,
        ),
        IvStatCard(
          label: l10n.dashPortfolioAvgScore,
          value: avgScore,
          valueText: avgScore > 0 ? null : '—',
          icon: Icons.speed_rounded,
          color: avgScore > 0 ? ivScoreColor(avgScore) : AppColors.inkSubtle,
          trailing: avgScore > 0
              ? IvRingGauge(
                  value: avgScore.toDouble(),
                  size: 44,
                  stroke: 5,
                  center: const SizedBox.shrink(),
                )
              : null,
        ),
      ],
    );
  }
}

// ── R6: Executive recommendations (INTERPRETATION + PRIORITY) ──────────────
// Every entry is conditioned on real data -- R8 "no fabricated
// intelligence" by construction.
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
      recs.add(_Rec(Icons.add_business_rounded, AppColors.accent,
          l10n.dashRecEmptyProjectTitle, l10n.dashRecEmptyProjectBody));
    } else if (analyses.isEmpty) {
      final projectName = projects.first.name;
      recs.add(_Rec(
          Icons.analytics_rounded,
          AppColors.info,
          l10n.dashRecEmptyAnalysisTitle,
          l10n.dashRecEmptyAnalysisBody(projectName)));
    }

    if (pending.isNotEmpty) {
      recs.add(_Rec(
          Icons.bolt_rounded,
          AppColors.gold,
          l10n.dashRecPendingActionsTitle(pending.length),
          l10n.dashRecPendingActionsBody));
    }

    final topAnalyses = analyses.where((a) => a.opportunityScore >= 75).toList()
      ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));
    if (topAnalyses.isNotEmpty) {
      final top = topAnalyses.first;
      recs.add(_Rec(
        Icons.star_rounded,
        AppColors.positive,
        l10n.dashRecTopOpportunityTitle(top.niche ?? top.input),
        l10n.dashRecTopOpportunityBody(top.opportunityScore),
      ));
    }

    if (recs.isEmpty) return const SizedBox.shrink();

    return IvCard(
      highlight: true,
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IvSectionHeader(
            title: l10n.dashRecommendationsTitle,
            icon: Icons.lightbulb_rounded,
            iconColor: AppColors.gold,
          ),
          const SizedBox(height: AppSpace.s4),
          for (var i = 0; i < recs.take(4).length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpace.s3),
                child: Divider(height: 1),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IvIconTile(recs[i].icon, color: recs[i].color, size: 34),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recs[i].title,
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(recs[i].body,
                          style: const TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: AppType.label,
                              height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
  const _DashboardPendingActionsCard(
      {required this.pending, required this.l10n});
  final List<ActionQueueItem> pending;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return IvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IvSectionHeader(
            title: l10n.dashPendingActionsTitle,
            icon: Icons.bolt_rounded,
            iconColor: AppColors.warning,
            actionLabel: l10n.dashPendingActionsViewAll,
            onAction: () => context.push(AppConstants.routeActionEngine),
          ),
          const SizedBox(height: AppSpace.s3),
          if (pending.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: AppColors.inkSubtle),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    l10n.dashPendingActionsEmpty,
                    style: const TextStyle(
                        color: AppColors.inkSubtle,
                        fontSize: AppType.label,
                        height: 1.5),
                  ),
                ),
              ],
            )
          else
            for (final item in pending.take(5))
              Container(
                margin: const EdgeInsets.only(top: AppSpace.s2),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3, vertical: AppSpace.s3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.warning.withOpacity(0.5),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              color: AppColors.ink, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (item.roiScore > 0)
                      IvBadge('ROI ${item.roiScore}', color: AppColors.gold),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
