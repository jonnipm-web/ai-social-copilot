import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/weekly_briefing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

const _kCard = AppColors.ground;
const _kBorder = AppColors.surface;
const _kPrimary = AppColors.accent;
const _kGreen = AppColors.positive;
const _kOrange = AppColors.warning;
const _kRed = AppColors.negative;
const _kGold = AppColors.gold;
const _kCyan = AppColors.info;

// ════════════════════════════════════════════════════════════════════════════
// Weekly Executive Briefing Screen — Módulo 7
// ════════════════════════════════════════════════════════════════════════════
class WeeklyBriefingScreen extends ConsumerWidget {
  const WeeklyBriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(weeklyBriefingProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppConstants.routeEcosystem),
        ),
        title: Text(l10n.ecoWeeklyBriefingTitle,
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.inkMuted),
            onPressed: () {
              ref.invalidate(projectsProvider);
              ref.invalidate(opportunityLabProvider);
              ref.invalidate(actionQueueProvider);
              ref.invalidate(marketAnalysesProvider);
              ref.invalidate(ecosystemScoresProvider);
              ref.invalidate(weeklyBriefingProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: briefingAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _kPrimary)),
          error: (e, _) => Center(
              child: Text(l10n.ecoBriefingError(extractErrorMessage(e, l10n)),
                  style: const TextStyle(color: _kRed),
                  textAlign: TextAlign.center)),
          data: (b) => _BriefingBody(briefing: b),
        ),
      ),
    );
  }
}

class _BriefingBody extends StatelessWidget {
  final WeeklyBriefing briefing;
  const _BriefingBody({required this.briefing});

  @override
  Widget build(BuildContext context) {
    final day = briefing.generatedAt.day.toString().padLeft(2, '0');
    final month = briefing.generatedAt.month.toString().padLeft(2, '0');
    final year = briefing.generatedAt.year;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final hPad = isDesktop ? 32.0 : 16.0;

        final header =
            _Header(briefing: briefing, dateStr: '$day/$month/$year');
        final dataOrigin = _DataOriginCard(briefing: briefing);
        final summary = _SummaryCard(text: briefing.executiveSummary);

        final mainSections = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
                title: l10n.ecoBriefSectionChanged,
                color: _kCyan,
                items: briefing.whatChanged),
            const SizedBox(height: 12),
            _Section(
                title: l10n.ecoBriefSectionGrew,
                color: _kGreen,
                items: briefing.whatGrew),
            const SizedBox(height: 12),
            _Section(
                title: l10n.ecoBriefSectionDeclined,
                color: _kRed,
                items: briefing.whatDeclined),
            const SizedBox(height: 12),
            _Section(
                title: l10n.ecoBriefSectionPriorities,
                color: _kGold,
                items: briefing.topPriorities),
            const SizedBox(height: 12),
            _Section(
                title: l10n.ecoBriefSectionPause,
                color: _kOrange,
                items: briefing.toPause),
            const SizedBox(height: 12),
            _Section(
                title: l10n.ecoBriefSectionNewOpps,
                color: _kCyan,
                items: briefing.newOpportunities),
          ],
        );

        final sidebar = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HealthSideCard(briefing: briefing),
            const SizedBox(height: 12),
            _Section(
                title: l10n.ecoBriefSectionRisks,
                color: _kRed,
                items: briefing.risks),
          ],
        );

        Widget body;
        if (isDesktop) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: mainSections),
              const SizedBox(width: 20),
              SizedBox(width: 300, child: sidebar),
            ],
          );
        } else {
          body = Column(
            children: [
              mainSections,
              const SizedBox(height: 12),
              _Section(
                  title: l10n.ecoBriefSectionRisksIdentified,
                  color: _kRed,
                  items: briefing.risks),
            ],
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16 + bottomPad),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 10),
                  dataOrigin,
                  const SizedBox(height: 16),
                  summary,
                  const SizedBox(height: 16),
                  body,
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HealthSideCard extends StatelessWidget {
  const _HealthSideCard({required this.briefing});
  final WeeklyBriefing briefing;

  Color _healthColor(int h) {
    if (h >= 70) return _kGreen;
    if (h >= 45) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final hc = _healthColor(briefing.overallHealthScore);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: hc.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(briefing.healthEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(l10n.ecoBriefOverallHealth,
                  style: TextStyle(
                      color: hc, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${briefing.overallHealthScore}/100',
                  style: TextStyle(
                      color: hc, fontSize: 22, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: briefing.overallHealthScore / 100,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation(hc),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            minHeight: 6,
          ),
          if (briefing.overallHealthScore < 50) ...[
            const SizedBox(height: 8),
            Text(
              l10n.ecoBriefLowScoreHint,
              style: const TextStyle(
                  color: AppColors.warning, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final WeeklyBriefing briefing;
  final String dateStr;
  const _Header({required this.briefing, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.ground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _kPrimary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.ecoBriefHeaderLabel,
                    style: const TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(l10n.ecoBriefWeekOf(dateStr),
                    style:
                        const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                    '${briefing.healthEmoji}  ${l10n.ecoBriefOverallHealthValue(briefing.overallHealthScore)}',
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: briefing.overallHealthScore / 100,
                  strokeWidth: 6,
                  backgroundColor: AppColors.line,
                  valueColor: AlwaysStoppedAnimation(
                      _healthColor(briefing.overallHealthScore)),
                ),
                Text('${briefing.overallHealthScore}',
                    style: TextStyle(
                      color: _healthColor(briefing.overallHealthScore),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _healthColor(int h) {
    if (h >= 70) return _kGreen;
    if (h >= 45) return _kOrange;
    return _kRed;
  }
}

class _SummaryCard extends StatelessWidget {
  final String text;
  const _SummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.ecoBriefExecutiveSummary,
              style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  color: AppColors.ink, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final List<BriefingItem> items;
  const _Section(
      {required this.title, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(AppLocalizations.of(context)!.ecoBriefNoItemsThisWeek,
                style: TextStyle(color: color.withOpacity(0.4), fontSize: 12)),
          )
        else
          ...items.map((item) => _BriefingRow(item: item, color: color)),
      ],
    );
  }
}

class _BriefingRow extends StatelessWidget {
  final BriefingItem item;
  final Color color;
  const _BriefingRow({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          if (item.detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(item.detail,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

// ── Data Origin Card ──────────────────────────────────────────────────────────
class _DataOriginCard extends StatelessWidget {
  final WeeklyBriefing briefing;
  const _DataOriginCard({required this.briefing});

  @override
  Widget build(BuildContext context) {
    final h = briefing.generatedAt.hour.toString().padLeft(2, '0');
    final m = briefing.generatedAt.minute.toString().padLeft(2, '0');
    final d = briefing.generatedAt.day.toString().padLeft(2, '0');
    final mo = briefing.generatedAt.month.toString().padLeft(2, '0');
    final y = briefing.generatedAt.year;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: _kPrimary, size: 14),
              const SizedBox(width: 6),
              Text(
                l10n.ecoBriefDataAnalyzed,
                style: const TextStyle(
                  color: _kPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                l10n.ecoBriefGeneratedAt('$d/$mo/$y', '$h:$m'),
                style: const TextStyle(color: AppColors.inkSubtle, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Contadores de origem
          Row(
            children: [
              _CountChip(
                label: l10n.ecoCountProjects,
                value: briefing.projectCount,
                color: _kCyan,
              ),
              const SizedBox(width: 8),
              _CountChip(
                label: l10n.ecoCountAnalyses,
                value: briefing.analysisCount,
                color: _kGold,
              ),
              const SizedBox(width: 8),
              _CountChip(
                label: l10n.ecoCountActions,
                value: briefing.actionsCount,
                color: _kOrange,
              ),
              const SizedBox(width: 8),
              _CountChip(
                label: l10n.ecoGateOpportunities,
                value: briefing.opportunitiesCount,
                color: _kGreen,
              ),
            ],
          ),

          // Projetos analisados
          if (briefing.analyzedProjectNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.ecoBriefIncludedProjects,
              style: const TextStyle(color: AppColors.inkSubtle, fontSize: 10),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: briefing.analyzedProjectNames
                  .map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border:
                              Border.all(color: _kPrimary.withOpacity(0.25)),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                              color: AppColors.inkMuted, fontSize: 10),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(color: AppColors.inkSubtle, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
