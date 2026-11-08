import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/language_utils.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/gap_analysis.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

// IVE-COMMERCIAL-FOUNDATION-11 — this screen is the representative
// quota-consuming call site migrated in Phase A (mission Section 11).
// Before this mission, "Analisar" fired immediately on tap with no
// confirmation, guarded only by the `bool _running` this replaces. The
// other 7 screens in the same situation (opportunity_discovery_screen.
// dart, revenue_planner_screen.dart, niche_discovery_screen.dart,
// content_cluster_screen.dart, competitor_discovery_screen.dart,
// persona_form_screen.dart, action_engine_screen.dart) are intentionally
// NOT migrated here — see docs/commercial/IMPLEMENTATION_ROADMAP.md
// Phase C/D — this migration is mechanical once the pattern below is
// copied, not architecturally different.
class GapAnalysisScreen extends ConsumerStatefulWidget {
  const GapAnalysisScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<GapAnalysisScreen> createState() => _GapAnalysisScreenState();
}

class _GapAnalysisScreenState extends ConsumerState<GapAnalysisScreen> {
  final _exec = AiExecutionController();
  String? _error;

  @override
  void dispose() {
    _exec.dispose();
    super.dispose();
  }

  bool get _running => _exec.isBusy;

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final analysis =
          await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await _exec.run<void>(
        context: context,
        ref: ref,
        analysisLabel: l10n.miGapTitle,
        request: IveInteractionRequest(
          projectId: analysis.projectId,
          sourceModule: 'market_intelligence',
          sourceEntityType: 'gap_analysis',
          sourceEntityId: widget.analysisId,
          operationType: IveOperationType.analyze,
        ),
        action: (idempotencyKey) =>
            ref.read(marketAnalysisServiceProvider).runGapAnalysis(
                  widget.analysisId,
                  analysis.input,
                  language: backendLanguageCode(context),
                  idempotencyKey: idempotencyKey,
                ),
      );
      // `run` returns null both when the user cancelled AND when a
      // `Future<void>` action succeeds (void has no distinct non-null
      // value) — check the controller's own terminal state instead of
      // the return value to know whether to invalidate.
      if (_exec.state != AiExecutionState.success) return;
      ref.invalidate(gapAnalysisByAnalysisProvider(widget.analysisId));
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _error = extractErrorMessage(e, AppLocalizations.of(context)!));
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncGap =
        ref.watch(gapAnalysisByAnalysisProvider(widget.analysisId));

    // AnimatedBuilder over `_exec` so both "Analisar" buttons below react
    // live to AiExecutionState transitions (awaiting confirmation →
    // reserving/thinking → success/error), not just a binary running flag.
    return AnimatedBuilder(
      animation: _exec,
      builder: (context, _) => _buildScaffold(context, asyncGap),
    );
  }

  Widget _buildScaffold(
      BuildContext context, AsyncValue<GapAnalysis?> asyncGap) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title:
            Text(l10n.miGapTitle, style: const TextStyle(color: AppColors.ink)),
        iconTheme: const IconThemeData(color: AppColors.ink),
        leading: IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, 
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub
                .replaceFirst(':id', widget.analysisId),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const AiThinkingIndicator(color: AppColors.warning)
                : const Icon(Icons.find_in_page_rounded,
                    color: AppColors.warning),
            label: Text(
              _running ? l10n.miGapAnalyzing : l10n.miGapAnalyzeButton,
              style: const TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
      body: IvBody(child: Column(
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.negative.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.negative.withOpacity(0.3)),
              ),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppColors.negative, fontSize: 13)),
            ),
          Expanded(
            child: asyncGap.when(
              loading: () => const IvLoadingSkeleton(),
              error: (e, _) => Center(
                  child: Text(
                      l10n.miSubErrorPrefix(extractErrorMessage(e, l10n)),
                      style: const TextStyle(color: AppColors.negative))),
              data: (gap) => gap == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.find_in_page_outlined,
                              color: AppColors.inkSubtle, size: 64),
                          const SizedBox(height: 16),
                          Text(l10n.miGapEmptyTitle,
                              style: const TextStyle(color: AppColors.inkSubtle)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(l10n.miGapEmptyBody,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.inkSubtle,
                                    fontSize: 12,
                                    height: 1.4)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _running ? null : _run,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.black,
                            ),
                            child: Text(l10n.miGapEmptyButton),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GapSection(
                            icon: Icons.article_rounded,
                            color: AppColors.negative,
                            title: l10n.miGapSectionContent,
                            items: gap.contentGaps,
                          ),
                          _GapSection(
                            icon: Icons.search_rounded,
                            color: AppColors.info,
                            title: l10n.miGapSectionSeo,
                            items: gap.seoGaps,
                          ),
                          _GapSection(
                            icon: Icons.shield_rounded,
                            color: AppColors.positive,
                            title: l10n.miGapSectionAuthority,
                            items: gap.authorityGaps,
                          ),
                          _GapSection(
                            icon: Icons.attach_money_rounded,
                            color: AppColors.warning,
                            title: l10n.miGapSectionMonetization,
                            items: gap.monetizationGaps,
                          ),
                          _GapSection(
                            icon: Icons.inventory_2_rounded,
                            color: AppColors.accent,
                            title: l10n.miGapSectionProduct,
                            items: gap.productGaps,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface, gradient: kIvSurfaceGradient,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border:
                                  Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.summarize_rounded,
                                    color: AppColors.warning, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.miGapTotalIdentified(gap.totalGaps),
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      )),
    );
  }
}

class _GapSection extends StatelessWidget {
  const _GapSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text('${items.length}',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.line, height: 1),
          ...items.asMap().entries.map(
                (e) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${e.key + 1}',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value,
                            style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 13,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
