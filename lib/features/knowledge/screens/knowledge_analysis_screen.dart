import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/knowledge_analysis.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/persona_provider.dart';
import '../../../providers/persona_training_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../shared/widgets/translated_content_notice.dart';

// IVE-COMMERCIAL-QUOTA-HARDENING-13 (Codex Gate 2 round-2 finding) — both
// call sites below (the AppBar "Re-analisar" icon and _NoAnalysis's
// "Analisar com IA" button) fired extract-knowledge directly with no
// confirmation and no idempotency key. A round-1 fix used a short-lived
// AiExecutionController created fresh per tap, reasoning that its own
// isBusy guard didn't need widget lifecycle to work — true for a SINGLE
// button, but false here: both buttons can be visible and tappable at
// once (the AppBar icon renders whenever an item is loaded; _NoAnalysis
// renders whenever there's no analysis yet — both true simultaneously on
// first load), and two SEPARATE short-lived controllers cannot guard
// against each other. Fixed by promoting KnowledgeAnalysisScreen to a
// ConsumerStatefulWidget holding ONE persistent controller, shared by
// both buttons via _NoAnalysis's constructor — now whichever fires first
// makes the other's `isBusy` check fail synchronously, exactly like
// every other screen's single-controller-per-operation pattern.
Future<KnowledgeAnalysis?> _confirmAndAnalyze(
  BuildContext context,
  WidgetRef ref,
  KnowledgeItem item,
  AiExecutionController exec,
) {
  return exec.run<KnowledgeAnalysis?>(
    context: context,
    ref: ref,
    analysisLabel: AppLocalizations.of(context)!.knowledgeVaultAnalyzeWithAi,
    request: IveInteractionRequest(
      projectId:        item.projectId,
      sourceModule:     'knowledge_vault',
      sourceEntityType: 'knowledge_item',
      sourceEntityId:   item.id,
      operationType:    IveOperationType.analyze,
    ),
    action: (idempotencyKey) => ref
        .read(knowledgeAnalysisNotifierProvider.notifier)
        .analyze(item, idempotencyKey: idempotencyKey),
  );
}

class KnowledgeAnalysisScreen extends ConsumerStatefulWidget {
  const KnowledgeAnalysisScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<KnowledgeAnalysisScreen> createState() =>
      _KnowledgeAnalysisScreenState();
}

class _KnowledgeAnalysisScreenState
    extends ConsumerState<KnowledgeAnalysisScreen> {
  final _exec = AiExecutionController();

  @override
  void dispose() {
    _exec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n           = AppLocalizations.of(context)!;
    final itemId        = widget.itemId;
    final itemAsync     = ref.watch(knowledgeItemByIdProvider(itemId));
    final analysisAsync = ref.watch(knowledgeAnalysisProvider(itemId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: Text(
          l10n.knowledgeAnalysisTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          itemAsync.maybeWhen(
            data: (item) => item == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.rocket_launch_rounded),
                        tooltip: l10n.knowledgeStrategyGenerateButton,
                        onPressed: () => context.push(
                          AppConstants.routeKnowledgeStrategy
                              .replaceFirst(':id', item.id),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded),
                        tooltip: l10n.knowledgeAnalysisReanalyzeTooltip,
                        onPressed: () async {
                          await _confirmAndAnalyze(context, ref, item, _exec);
                          ref.invalidate(knowledgeAnalysisProvider(itemId));
                          ref.invalidate(knowledgeItemsProvider);
                        },
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(l10n.knowledgeStrategyGenericError(extractErrorMessage(e, l10n)), style: const TextStyle(color: Colors.white70)),
        ),
        data: (item) {
          if (item == null) {
            return Center(
              child: Text(l10n.knowledgeStrategyItemNotFound,
                  style: const TextStyle(color: Colors.white70)),
            );
          }
          return analysisAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _NoAnalysis(item: item, exec: _exec, error: extractErrorMessage(e, l10n)),
            data: (analysis) => analysis == null
                ? _NoAnalysis(item: item, exec: _exec)
                : _AnalysisContent(item: item, analysis: analysis),
          );
        },
      ),
    );
  }
}

// ── No analysis yet ──────────────────────────────────────────

class _NoAnalysis extends ConsumerWidget {
  const _NoAnalysis({required this.item, required this.exec, this.error});

  final KnowledgeItem item;
  final AiExecutionController exec;
  final String?       error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = ref.watch(knowledgeAnalysisNotifierProvider) is AsyncLoading || exec.isBusy;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined,
                size: 64, color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            if (error != null) ...[
              Text(
                l10n.knowledgeStrategyGenericError(error!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFF44336), fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              isLoading
                  ? l10n.knowledgeAnalysisLoadingLabel
                  : l10n.knowledgeAnalysisNotYetLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            if (!isLoading)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(l10n.knowledgeVaultAnalyzeWithAi),
                onPressed: () async {
                  await _confirmAndAnalyze(context, ref, item, exec);
                  ref.invalidate(knowledgeAnalysisProvider(item.id));
                  ref.invalidate(knowledgeItemsProvider);
                },
              )
            else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ── Full analysis view ───────────────────────────────────────

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.item, required this.analysis});

  final KnowledgeItem     item;
  final KnowledgeAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        _ItemHeader(item: item),
        const SizedBox(height: 12),
        TranslatedContentNotice(localizedFrom: analysis.localizedFrom),

        // Botões de ação
        _ActionButtons(item: item, analysis: analysis),
        const SizedBox(height: 16),

        // Opportunity Score
        if (analysis.scoreOpportunity > 0) ...[
          _OpportunityScoreCard(score: analysis.scoreOpportunity),
          const SizedBox(height: 16),
        ],

        if (analysis.summary != null) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionSummary),
          _SummaryCard(analysis.summary!),
          const SizedBox(height: 16),
        ],

        _SectionTitle(l10n.knowledgeAnalysisSectionChannelScores),
        const SizedBox(height: 8),
        _ScoreGrid(analysis: analysis),
        const SizedBox(height: 16),

        _SectionTitle(l10n.knowledgeAnalysisSectionKeywords),
        const SizedBox(height: 8),
        if (analysis.keywordsPrimary.isNotEmpty)
          _ChipSection(l10n.knowledgeAnalysisKeywordsPrimary, analysis.keywordsPrimary,
              const Color(0xFF6C63FF)),
        if (analysis.keywordsSecondary.isNotEmpty)
          _ChipSection(l10n.knowledgeAnalysisKeywordsSecondary, analysis.keywordsSecondary,
              const Color(0xFF00BCD4)),
        if (analysis.keywordsLongtail.isNotEmpty)
          _ChipSection(l10n.knowledgeAnalysisKeywordsLongtail, analysis.keywordsLongtail,
              const Color(0xFF4CAF50)),
        const SizedBox(height: 8),

        if (analysis.audiencePainPoints.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionAudiencePainPoints),
          _ListCards(analysis.audiencePainPoints,
              Icons.sentiment_dissatisfied_rounded, const Color(0xFFF44336)),
          const SizedBox(height: 12),
        ],
        if (analysis.audienceDesires.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionAudienceDesires),
          _ListCards(analysis.audienceDesires, Icons.favorite_rounded,
              const Color(0xFFE91E63)),
          const SizedBox(height: 12),
        ],

        if (analysis.contentPillars.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionContentPillars),
          _ChipSection('', analysis.contentPillars, const Color(0xFFFF9800)),
          const SizedBox(height: 8),
        ],
        if (analysis.topics.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionTopics),
          _ChipSection('', analysis.topics, const Color(0xFF9C27B0)),
          const SizedBox(height: 8),
        ],

        if (analysis.postIdeas.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionPostIdeas),
          _ListCards(analysis.postIdeas, Icons.chat_bubble_outline_rounded,
              const Color(0xFF00BCD4)),
          const SizedBox(height: 12),
        ],
        if (analysis.campaignIdeas.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionCampaignIdeas),
          _ListCards(analysis.campaignIdeas, Icons.campaign_rounded,
              const Color(0xFFFF9800)),
          const SizedBox(height: 12),
        ],
        if (analysis.articleIdeas.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionArticleIdeas),
          _ListCards(analysis.articleIdeas, Icons.article_rounded,
              const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
        ],

        if (analysis.commercialAngles.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionCommercialAngles),
          _ListCards(analysis.commercialAngles, Icons.monetization_on_rounded,
              const Color(0xFFFFD700)),
          const SizedBox(height: 12),
        ],
        if (analysis.ctas.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionCtas),
          _ChipSection('', analysis.ctas, const Color(0xFFFFD700)),
          const SizedBox(height: 8),
        ],

        if (analysis.seoOpportunities.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionSeoOpportunities),
          _ListCards(analysis.seoOpportunities, Icons.search_rounded,
              const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
        ],
        if (analysis.adsenseOpportunities.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionAdsenseOpportunities),
          _ListCards(analysis.adsenseOpportunities, Icons.attach_money_rounded,
              const Color(0xFF8BC34A)),
          const SizedBox(height: 12),
        ],
        if (analysis.amazonKdpOpportunities.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionAmazonKdpOpportunities),
          _ListCards(analysis.amazonKdpOpportunities, Icons.book_rounded,
              const Color(0xFFFF5722)),
          const SizedBox(height: 12),
        ],

        // Hotmart
        if (analysis.scoreHotmart > 0 || analysis.hotmartData.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionHotmartEngine),
          _HotmartCard(
              score: analysis.scoreHotmart, data: analysis.hotmartData),
          const SizedBox(height: 12),
        ],

        // Shopify
        if (analysis.scoreShopify > 0 || analysis.shopifyData.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionShopifyEngine),
          _ShopifyCard(
              score: analysis.scoreShopify, data: analysis.shopifyData),
          const SizedBox(height: 12),
        ],

        if (analysis.scoreDetails.isNotEmpty) ...[
          _SectionTitle(l10n.knowledgeAnalysisSectionChannelDetails),
          _ScoreDetailsSection(analysis.scoreDetails),
        ],
      ],
    );
  }
}

// ── Common widgets ───────────────────────────────────────────

// ── Action buttons ───────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.item, required this.analysis});

  final KnowledgeItem     item;
  final KnowledgeAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personas = ref.watch(personasProvider).valueOrNull ?? [];
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          icon:  Icons.rocket_launch_rounded,
          label: l10n.uxKnowledgeActionGenerateStrategy,
          color: const Color(0xFF6C63FF),
          onTap: () => context.push(
            AppConstants.routeKnowledgeStrategy.replaceFirst(':id', item.id),
          ),
        ),
        _ActionChip(
          icon:  Icons.campaign_rounded,
          label: l10n.uxKnowledgeActionCreateCampaign,
          color: const Color(0xFF00BCD4),
          onTap: () => context.push(
            AppConstants.routeCampaignNew,
            extra: item.id,
          ),
        ),
        _ActionChip(
          icon:  Icons.person_pin_rounded,
          label: l10n.uxKnowledgeActionTrainPersona,
          color: const Color(0xFFFF9800),
          onTap: () => _trainPersona(context, ref, personas),
        ),
      ],
    );
  }

  Future<void> _trainPersona(BuildContext context, WidgetRef ref, List personas) async {
    final l10n = AppLocalizations.of(context)!;
    if (personas.isEmpty) {
      showErrorSnack(context, l10n.uxKnowledgeNoPersonas);
      return;
    }
    String? selectedPersonaId;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(l10n.uxKnowledgeActionTrainPersona, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: personas.map((p) => RadioListTile<String>(
              title: Text(p.name, style: const TextStyle(color: Colors.white70)),
              value: p.id as String,
              groupValue: selectedPersonaId,
              onChanged: (v) => setState(() => selectedPersonaId = v),
              activeColor: const Color(0xFF6C63FF),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: selectedPersonaId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await ref
                            .read(personaTrainingNotifierProvider.notifier)
                            .train(
                              personaId: selectedPersonaId!,
                              item: item,
                              analysis: analysis,
                            );
                        if (context.mounted) {
                          showSuccessSnack(context, l10n.uxKnowledgePersonaTrained);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showErrorSnack(context, extractErrorMessage(e, l10n));
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF)),
              child: Text(l10n.uxKnowledgeTrain),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Opportunity Score ────────────────────────────────────────

class _OpportunityScoreCard extends StatelessWidget {
  const _OpportunityScoreCard({required this.score});
  final int score;

  Color get _color {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _label(AppLocalizations l10n) {
    if (score >= 80) return l10n.uxKnowledgeOppHigh;
    if (score >= 60) return l10n.uxKnowledgeOppGood;
    if (score >= 40) return l10n.uxKnowledgeOppModerate;
    return l10n.uxKnowledgeOppLow;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.2), _color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withOpacity(0.15),
              border: Border.all(color: _color, width: 2),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                    color: _color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opportunity Score',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(_label(AppLocalizations.of(context)!),
                    style: TextStyle(color: _color, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(_color),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hotmart Card ─────────────────────────────────────────────

class _HotmartCard extends StatelessWidget {
  const _HotmartCard({required this.score, required this.data});
  final int                  score;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6C63FF);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              const Text('Hotmart',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (score > 0) _ScoreBadge(score, color),
            ],
          ),
          if (data.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            ...{
              AppLocalizations.of(context)!.uxKnowledgeFieldProduct:  data['product_name'],
              AppLocalizations.of(context)!.uxKnowledgeFieldPromise:  data['promise'],
              AppLocalizations.of(context)!.uxKnowledgeFieldFormat:   data['format'],
              AppLocalizations.of(context)!.uxKnowledgeFieldPrice:    data['price_range'],
              'Upsell':     data['upsell'],
            }.entries
                .where((e) => e.value != null && e.value.toString().isNotEmpty)
                .map((e) => _DataRow(e.key, e.value.toString())),
          ],
        ],
      ),
    );
  }
}

// ── Shopify Card ─────────────────────────────────────────────

class _ShopifyCard extends StatelessWidget {
  const _ShopifyCard({required this.score, required this.data});
  final int                  score;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF00BCD4);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              const Text('Shopify',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (score > 0) _ScoreBadge(score, color),
            ],
          ),
          if (data.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            ...{
              AppLocalizations.of(context)!.uxKnowledgeFieldProduct:     data['product_name'],
              AppLocalizations.of(context)!.uxKnowledgeFieldDescription: data['short_description'],
              AppLocalizations.of(context)!.uxKnowledgeFieldPrice:       data['price_range'],
            }.entries
                .where((e) => e.value != null && e.value.toString().isNotEmpty)
                .map((e) => _DataRow(e.key, e.value.toString())),
            if (data['categories'] is List) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (data['categories'] as List)
                    .map((c) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: color.withOpacity(0.3)),
                          ),
                          child: Text(c.toString(),
                              style: TextStyle(
                                  color: color, fontSize: 11)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge(this.score, this.color);
  final int   score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$score/100',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 65,
            child: Text('$label:',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Item header ──────────────────────────────────────────────

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.item});

  final KnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.3),
            const Color(0xFF6C63FF).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_rounded,
              color: Color(0xFF6C63FF), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.niche != null)
                  Text(item.niche!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.summary);

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(summary,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, height: 1.5)),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.analysis});

  final KnowledgeAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final scores = [
      _ScoreData('SEO', analysis.scoreSeo, const Color(0xFF4CAF50),
          Icons.search_rounded),
      _ScoreData('AdSense', analysis.scoreAdsense, const Color(0xFF8BC34A),
          Icons.attach_money_rounded),
      _ScoreData('Amazon KDP', analysis.scoreAmazonKdp,
          const Color(0xFFFF5722), Icons.book_rounded),
      _ScoreData('LinkedIn', analysis.scoreLinkedin, const Color(0xFF0077B5),
          Icons.business_rounded),
      _ScoreData('Social', analysis.scoreSocial, const Color(0xFFE91E63),
          Icons.people_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scores.map((s) => _ScoreCard(data: s)).toList(),
    );
  }
}

class _ScoreData {
  _ScoreData(this.label, this.score, this.color, this.icon);
  final String   label;
  final int      score;
  final Color    color;
  final IconData icon;
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.data});

  final _ScoreData data;

  Color get _barColor {
    if (data.score >= 70) return const Color(0xFF4CAF50);
    if (data.score >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: data.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(data.icon, color: data.color, size: 20),
          const SizedBox(height: 6),
          Text(
            '${data.score}',
            style: TextStyle(
              color: _barColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(data.label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: data.score / 100,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection(this.label, this.items, this.color);

  final String       label;
  final List<String> items;
  final Color        color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (kw) => GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: kw));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.knowledgeAnalysisCopiedKeyword(kw)),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF1A1A2E),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Text(kw,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _ListCards extends StatelessWidget {
  const _ListCards(this.items, this.icon, this.color);

  final List<String> items;
  final IconData     icon;
  final Color        color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.knowledgeAnalysisCopied),
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF1A1A2E),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded,
                        color: Colors.white24, size: 15),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ScoreDetailsSection extends StatelessWidget {
  const _ScoreDetailsSection(this.details);

  final Map<String, dynamic> details;

  static const _channelLabels = {
    'seo':        'SEO',
    'adsense':    'AdSense',
    'amazon_kdp': 'Amazon KDP',
    'linkedin':   'LinkedIn',
    'social':     'Social Media',
  };

  @override
  Widget build(BuildContext context) {
    final channels = _channelLabels.entries
        .where((e) => details.containsKey(e.key))
        .toList();

    return Column(
      children: channels.map((e) {
        final ch = details[e.key] as Map<String, dynamic>? ?? {};
        return _ChannelDetail(label: e.value, data: ch);
      }).toList(),
    );
  }
}

class _ChannelDetail extends StatefulWidget {
  const _ChannelDetail({required this.label, required this.data});

  final String               label;
  final Map<String, dynamic> data;

  @override
  State<_ChannelDetail> createState() => _ChannelDetailState();
}

class _ChannelDetailState extends State<_ChannelDetail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final strengths    = _list(widget.data['strengths']);
    final weaknesses   = _list(widget.data['weaknesses']);
    final improvements = _list(widget.data['improvements']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            trailing: Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: Colors.white38,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (strengths.isNotEmpty) ...[
                    _SubLabel(AppLocalizations.of(context)!.uxKnowledgeStrengths, const Color(0xFF4CAF50)),
                    ...strengths.map((s) => _DetailItem(s, const Color(0xFF4CAF50))),
                    const SizedBox(height: 6),
                  ],
                  if (weaknesses.isNotEmpty) ...[
                    _SubLabel(AppLocalizations.of(context)!.uxKnowledgeWeaknesses, const Color(0xFFF44336)),
                    ...weaknesses.map((s) => _DetailItem(s, const Color(0xFFF44336))),
                    const SizedBox(height: 6),
                  ],
                  if (improvements.isNotEmpty) ...[
                    _SubLabel(AppLocalizations.of(context)!.uxKnowledgeImprovements, const Color(0xFF6C63FF)),
                    ...improvements.map((s) => _DetailItem(s, const Color(0xFF6C63FF))),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text, this.color);

  final String text;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem(this.text, this.color);

  final String text;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 6, color: color.withOpacity(0.7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
