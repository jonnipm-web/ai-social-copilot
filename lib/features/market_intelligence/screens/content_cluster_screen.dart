import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/language_utils.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class ContentClusterScreen extends ConsumerStatefulWidget {
  const ContentClusterScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<ContentClusterScreen> createState() =>
      _ContentClusterScreenState();
}

// IVE-COMMERCIAL-QUOTA-HARDENING-13 (Codex Gate 2 finding) — see
// competitor_discovery_screen.dart's identical note.
class _ContentClusterScreenState extends ConsumerState<ContentClusterScreen> {
  final _exec = AiExecutionController();
  String? _error;
  final _keywordCtrl = TextEditingController();

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _exec.dispose();
    super.dispose();
  }

  bool get _running => _exec.isBusy;

  Future<void> _build() async {
    final kw = _keywordCtrl.text.trim();
    if (kw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.miClusterKeywordRequired),
            backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _error = null);
    try {
      final analysis =
          await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      if (!mounted) return;
      await _exec.run<void>(
        context: context,
        ref: ref,
        analysisLabel: AppLocalizations.of(context)!.miClusterTitle,
        request: IveInteractionRequest(
          projectId: analysis.projectId,
          sourceModule: 'market_intelligence',
          sourceEntityType: 'content_cluster',
          sourceEntityId: widget.analysisId,
          operationType: IveOperationType.analyze,
        ),
        action: (idempotencyKey) =>
            ref.read(marketAnalysisServiceProvider).buildContentCluster(
                  widget.analysisId,
                  analysis.input,
                  kw,
                  language: backendLanguageCode(context),
                  idempotencyKey: idempotencyKey,
                ),
      );
      if (_exec.state != AiExecutionState.success) return;
      ref.invalidate(contentClusterByAnalysisProvider(widget.analysisId));
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
    return AnimatedBuilder(
      animation: _exec,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncCluster =
        ref.watch(contentClusterByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.miClusterTitle,
            style: const TextStyle(color: AppColors.ink)),
        iconTheme: const IconThemeData(color: AppColors.ink),
        leading: IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, 
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub
                .replaceFirst(':id', widget.analysisId),
          ),
        ),
      ),
      body: IvBody(child: asyncCluster.when(
        loading: () => const IvLoadingSkeleton(),
        error: (e, _) => Center(
            child: Text(l10n.miSubErrorPrefix(extractErrorMessage(e, l10n)),
                style: const TextStyle(color: AppColors.negative))),
        data: (cluster) => cluster == null
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.account_tree_outlined,
                        color: AppColors.inkSubtle, size: 64),
                    const SizedBox(height: 16),
                    Text(l10n.miClusterEmptyTitle,
                        style: const TextStyle(color: AppColors.inkSubtle)),
                    const SizedBox(height: 8),
                    Text(l10n.miClusterEmptyBody,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.inkSubtle, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _keywordCtrl,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: InputDecoration(
                        labelText: l10n.miClusterKeywordFieldLabel,
                        labelStyle: const TextStyle(color: AppColors.inkMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide:
                              const BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide:
                              const BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.negative, fontSize: 13)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _running ? null : _build,
                        icon: _running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: AppColors.ink, strokeWidth: 2))
                            : const Icon(Icons.account_tree_rounded),
                        label: Text(_running
                            ? l10n.miClusterGenerating
                            : l10n.miClusterGenerateButton),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface, gradient: kIvSurfaceGradient,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key_rounded,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                              l10n.miClusterKeywordDisplay(cluster.mainKeyword),
                              style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClusterSection(
                        title: l10n.miClusterSectionClusters,
                        color: AppColors.accent,
                        items: cluster.clusters,
                        labelKey: 'name',
                        descKey: 'description'),
                    _ClusterSection(
                        title: l10n.miClusterSectionSilos,
                        color: AppColors.info,
                        items: cluster.silos,
                        labelKey: 'name',
                        descKey: 'description'),
                    _ArticleSection(articles: cluster.articles),
                    _RoadmapSection(roadmap: cluster.editorialRoadmap),
                  ],
                ),
              ),
      )),
    );
  }
}

class _ClusterSection extends StatelessWidget {
  const _ClusterSection({
    required this.title,
    required this.color,
    required this.items,
    required this.labelKey,
    required this.descKey,
  });

  final String title;
  final Color color;
  final List<Map<String, dynamic>> items;
  final String labelKey;
  final String descKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface, gradient: kIvSurfaceGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item[labelKey]?.toString() ?? '',
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if ((item[descKey]?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item[descKey].toString(),
                      style:
                          const TextStyle(color: AppColors.inkMuted, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ArticleSection extends StatelessWidget {
  const _ArticleSection({required this.articles});
  final List<Map<String, dynamic>> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.miClusterSectionArticles,
            style: const TextStyle(
                color: AppColors.positive,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...articles.asMap().entries.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface, gradient: kIvSurfaceGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.positive.withOpacity(0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.positive.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: const TextStyle(
                                color: AppColors.positive,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value['title']?.toString() ?? '',
                              style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          if (e.value['keyword'] != null)
                            Text(
                                l10n.miClusterArticleKeyword(
                                    '${e.value['keyword']}'),
                                style: const TextStyle(
                                    color: AppColors.inkSubtle, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RoadmapSection extends StatelessWidget {
  const _RoadmapSection({required this.roadmap});
  final List<Map<String, dynamic>> roadmap;

  @override
  Widget build(BuildContext context) {
    if (roadmap.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.miClusterSectionRoadmap,
            style: const TextStyle(
                color: AppColors.warning,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...roadmap.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface, gradient: kIvSurfaceGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border:
                  Border.all(color: AppColors.warning.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['month'] != null)
                  Text(l10n.miClusterRoadmapMonth('${item['month']}'),
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                if (item['focus'] != null)
                  Text(item['focus'].toString(),
                      style:
                          const TextStyle(color: AppColors.ink, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
