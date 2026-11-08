import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ai_enum_labels.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/knowledge_analysis.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../data/models/knowledge_strategy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/strategy_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

// IVE-COMMERCIAL-QUOTA-HARDENING-13 (Codex Gate 2 round-2 finding) — both
// call sites below (the initial "Gerar Estratégia" button and "Regenerar
// Estratégia") fired generate-strategy directly with no confirmation and
// no idempotency key. A round-1 fix used a short-lived AiExecutionController
// per tap, which is only safe when at most one button using it can ever
// be visible at once — true here (strategyAsync.when renders EITHER
// _GeneratePrompt OR _StrategyContent's regenerate button, never both),
// but a fresh controller per tap still can't guard against a rapid
// DOUBLE-tap on the SAME button, since each tap gets its own instance
// with no memory of the other. Fixed the same way as
// knowledge_analysis_screen.dart: StrategyScreen (promoted to
// ConsumerStatefulWidget) owns ONE persistent controller, passed down to
// whichever of the two mutually-exclusive widgets is actually rendered.
Future<KnowledgeStrategy?> _confirmAndGenerateStrategy(
  BuildContext context,
  WidgetRef ref,
  KnowledgeItem item,
  KnowledgeAnalysis analysis,
  AiExecutionController exec,
) {
  return exec.run<KnowledgeStrategy?>(
    context: context,
    ref: ref,
    analysisLabel:
        AppLocalizations.of(context)!.knowledgeStrategyGenerateButton,
    request: IveInteractionRequest(
      projectId: item.projectId,
      sourceModule: 'knowledge_vault',
      sourceEntityType: 'knowledge_strategy',
      sourceEntityId: item.id,
      operationType: IveOperationType.analyze,
    ),
    action: (idempotencyKey) => ref
        .read(strategyNotifierProvider.notifier)
        .generate(item, analysis, idempotencyKey: idempotencyKey),
  );
}

class StrategyScreen extends ConsumerStatefulWidget {
  const StrategyScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends ConsumerState<StrategyScreen> {
  final _exec = AiExecutionController();

  @override
  void dispose() {
    _exec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemId = widget.itemId;
    final itemAsync = ref.watch(knowledgeItemByIdProvider(itemId));
    final analysisAsync = ref.watch(knowledgeAnalysisProvider(itemId));
    final strategyAsync = ref.watch(knowledgeStrategyProvider(itemId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        title: Text(
          l10n.knowledgeStrategyTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: IvBody(child: itemAsync.when(
        loading: () => const IvLoadingSkeleton(),
        error: (e, _) => Center(
            child: Text(
                l10n.knowledgeStrategyGenericError(
                    extractErrorMessage(e, l10n)),
                style: const TextStyle(color: AppColors.inkMuted))),
        data: (item) {
          if (item == null) {
            return Center(
                child: Text(l10n.knowledgeStrategyItemNotFound,
                    style: const TextStyle(color: AppColors.inkMuted)));
          }
          return analysisAsync.when(
            loading: () => const IvLoadingSkeleton(),
            error: (e, _) => Center(
                child: Text(
                    l10n.knowledgeStrategyGenericError(
                        extractErrorMessage(e, l10n)),
                    style: const TextStyle(color: AppColors.inkMuted))),
            data: (analysis) {
              if (analysis == null) {
                return _NoAnalysis(item: item);
              }
              return strategyAsync.when(
                loading: () => const IvLoadingSkeleton(),
                error: (e, _) => _GeneratePrompt(
                    item: item,
                    analysis: analysis,
                    exec: _exec,
                    error: extractErrorMessage(e, l10n)),
                data: (strategy) => strategy == null
                    ? _GeneratePrompt(
                        item: item, analysis: analysis, exec: _exec)
                    : _StrategyContent(
                        item: item,
                        strategy: strategy,
                        analysis: analysis,
                        exec: _exec),
              );
            },
          );
        },
      )),
    );
  }
}

class _NoAnalysis extends StatelessWidget {
  const _NoAnalysis({required this.item});
  final KnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined,
                size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              l10n.knowledgeStrategyAnalysisRequiredTitle,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.knowledgeStrategyAnalysisRequiredBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(l10n.knowledgeStrategyBackAndAnalyze),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratePrompt extends ConsumerWidget {
  const _GeneratePrompt(
      {required this.item,
      required this.analysis,
      required this.exec,
      this.error});
  final KnowledgeItem item;
  final KnowledgeAnalysis analysis;
  final AiExecutionController exec;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifierState = ref.watch(strategyNotifierProvider);
    final isLoading = notifierState is AsyncLoading || exec.isBusy;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border:
                    Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.knowledgeStrategyGenerateTitle,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.knowledgeStrategyGenerateBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.inkMuted, fontSize: 13, height: 1.5),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.knowledgeStrategyGenericError(error!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.negative, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            if (isLoading) ...[
              const CircularProgressIndicator(color: AppColors.accent),
              const SizedBox(height: 12),
              Text(l10n.knowledgeStrategyGenerating,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ] else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text(l10n.knowledgeStrategyGenerateButton,
                    style: const TextStyle(fontSize: 15)),
                onPressed: () async {
                  final strategy = await _confirmAndGenerateStrategy(
                      context, ref, item, analysis, exec);
                  if (strategy != null) {
                    ref.invalidate(knowledgeStrategyProvider(item.id));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StrategyContent extends ConsumerWidget {
  const _StrategyContent({
    required this.item,
    required this.strategy,
    required this.analysis,
    required this.exec,
  });

  final KnowledgeItem item;
  final KnowledgeStrategy strategy;
  final KnowledgeAnalysis analysis;
  final AiExecutionController exec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final s = strategy.strategyJson;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Header
        _StratHeader(title: item.title, niche: item.niche),
        const SizedBox(height: 16),

        // Resumo estratégico
        if (strategy.strategicSummary.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionSummary,
              Icons.summarize_rounded, AppColors.accent),
          _HighlightCard(strategy.strategicSummary, AppColors.accent),
          const SizedBox(height: 16),
        ],

        // Proposta de valor
        if (strategy.valueProposition.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionValueProp,
              Icons.diamond_rounded, AppColors.gold),
          _HighlightCard(strategy.valueProposition, AppColors.gold),
          const SizedBox(height: 16),
        ],

        // Posicionamento
        if (strategy.positioning.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionPositioning, Icons.flag_rounded,
              AppColors.info),
          _HighlightCard(strategy.positioning, AppColors.info),
          const SizedBox(height: 16),
        ],

        // Público-alvo
        _buildAudience(s, l10n),

        // Canais recomendados
        if (strategy.recommendedChannels.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionChannels,
              Icons.broadcast_on_personal_rounded, AppColors.positive),
          const SizedBox(height: 8),
          ...strategy.recommendedChannels.map((ch) => _ChannelTile(ch)),
          const SizedBox(height: 16),
        ],

        // Funil
        if (strategy.funnel.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionFunnel,
              Icons.filter_alt_rounded, AppColors.warning),
          const SizedBox(height: 8),
          _FunnelCard(strategy.funnel, l10n),
          const SizedBox(height: 16),
        ],

        // Oportunidades comerciais
        if (strategy.commercialOpportunities.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionOpportunities,
              Icons.monetization_on_rounded, AppColors.gold),
          const SizedBox(height: 8),
          ...strategy.commercialOpportunities.map((op) => _OpportunityTile(op)),
          const SizedBox(height: 16),
        ],

        // Keywords prioritárias
        if (strategy.priorityKeywords.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionKeywords, Icons.key_rounded,
              AppColors.accent),
          const SizedBox(height: 8),
          _ChipRow(strategy.priorityKeywords, AppColors.accent),
          const SizedBox(height: 16),
        ],

        // Quick wins
        if (strategy.quickWins.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionQuickWins, Icons.bolt_rounded,
              AppColors.warning),
          const SizedBox(height: 8),
          ...strategy.quickWins
              .map((w) => _BulletItem(w, AppColors.warning)),
          const SizedBox(height: 16),
        ],

        // Plano de crescimento
        if (strategy.growthPlan.isNotEmpty) ...[
          _Section(l10n.knowledgeStrategySectionGrowthPlan,
              Icons.trending_up_rounded, AppColors.positive),
          const SizedBox(height: 8),
          _GrowthCard(strategy.growthPlan, l10n),
          const SizedBox(height: 16),
        ],

        // Regenerar
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkMuted,
            side: const BorderSide(color: AppColors.line),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(l10n.knowledgeStrategyRegenerateButton,
              style: const TextStyle(fontSize: 13)),
          onPressed: () async {
            await _confirmAndGenerateStrategy(
                context, ref, item, analysis, exec);
            ref.invalidate(knowledgeStrategyProvider(item.id));
          },
        ),
      ],
    );
  }

  Widget _buildAudience(Map<String, dynamic> s, AppLocalizations l10n) {
    final audience = s['target_audience'];
    if (audience == null) return const SizedBox.shrink();
    final a = audience is Map
        ? Map<String, dynamic>.from(audience)
        : <String, dynamic>{};
    if (a.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(l10n.knowledgeStrategySectionAudience, Icons.people_rounded,
            AppColors.accent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface, gradient: kIvSurfaceGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a['primary'] != null)
                _AudienceRow(l10n.knowledgeStrategyAudiencePrimary,
                    a['primary'].toString(), AppColors.accent),
              if (a['secondary'] != null)
                _AudienceRow(l10n.knowledgeStrategyAudienceSecondary,
                    a['secondary'].toString(), AppColors.inkMuted),
              if (a['age_range'] != null)
                _AudienceRow(l10n.knowledgeStrategyAudienceAgeRange,
                    a['age_range'].toString(), AppColors.inkSubtle),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StratHeader extends StatelessWidget {
  const _StratHeader({required this.title, this.niche});
  final String title;
  final String? niche;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.3),
            AppColors.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_rounded,
              color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (niche != null)
                  Text(niche!,
                      style:
                          const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.icon, this.color);
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.knowledgeStrategyCopied),
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.surface,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, color: color.withOpacity(0.4), size: 14),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile(this.data);
  final Map<String, dynamic> data;

  Color _priorityColor(String p) {
    switch (aiLevel(p)) {
      case AiLevel.high:
      case AiLevel.critical:
        return AppColors.positive;
      case AiLevel.medium:
        return AppColors.warning;
      default:
        return AppColors.inkSubtle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = data['channel'] as String? ?? '';
    final priority = data['priority'] as String? ?? '';
    final reason = data['reason'] as String? ?? '';
    final color = _priorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
                aiPriorityLabel(priority, AppLocalizations.of(context)!),
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (reason.isNotEmpty)
                  Text(reason,
                      style:
                          const TextStyle(color: AppColors.inkSubtle, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard(this.funnel, this.l10n);
  final Map<String, dynamic> funnel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final stages = [
      (
        l10n.knowledgeStrategyFunnelAwareness,
        funnel['awareness'],
        AppColors.accent
      ),
      (
        l10n.knowledgeStrategyFunnelConsideration,
        funnel['consideration'],
        AppColors.info
      ),
      (
        l10n.knowledgeStrategyFunnelConversion,
        funnel['conversion'],
        AppColors.positive
      ),
      (
        l10n.knowledgeStrategyFunnelRetention,
        funnel['retention'],
        AppColors.gold
      ),
    ];

    return Column(
      children: stages
          .where((s) => s.$2 != null && s.$2.toString().isNotEmpty)
          .map((s) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: s.$3.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: s.$3.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      child: Text(s.$1,
                          style: TextStyle(
                              color: s.$3,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(s.$2.toString(),
                          style: const TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 12,
                              height: 1.4)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _OpportunityTile extends StatelessWidget {
  const _OpportunityTile(this.data);
  final Map<String, dynamic> data;

  Color _potentialColor(String p) {
    switch (aiLevel(p)) {
      case AiLevel.high:
      case AiLevel.critical:
        return AppColors.positive;
      case AiLevel.medium:
        return AppColors.warning;
      default:
        return AppColors.inkSubtle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final potential = data['potential'] as String? ?? '';
    final color = _potentialColor(potential);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: AppColors.gold, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (description.isNotEmpty)
                  Text(description,
                      style:
                          const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              ],
            ),
          ),
          if (potential.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                  aiLevelLabel(potential, AppLocalizations.of(context)!),
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow(this.items, this.color);
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((kw) => GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: kw));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!
                          .knowledgeStrategyCopiedKeyword(kw)),
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Text(kw,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ))
          .toList(),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.bolt_rounded, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard(this.plan, this.l10n);
  final Map<String, dynamic> plan;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final months = [
      (l10n.knowledgeStrategyMonth(1), plan['month_1']),
      (l10n.knowledgeStrategyMonth(2), plan['month_2']),
      (l10n.knowledgeStrategyMonth(3), plan['month_3']),
    ];

    final kpis = plan['kpis'];
    final kpiList =
        kpis is List ? kpis.map((e) => e.toString()).toList() : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...months
            .where((m) => m.$2 != null && m.$2.toString().isNotEmpty)
            .map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface, gradient: kIvSurfaceGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 45,
                        child: Text(m.$1,
                            style: const TextStyle(
                                color: AppColors.positive,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(m.$2.toString(),
                            style: const TextStyle(
                                color: AppColors.inkMuted, fontSize: 12)),
                      ),
                    ],
                  ),
                )),
        if (kpiList.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l10n.knowledgeStrategyKpisLabel,
              style: const TextStyle(
                  color: AppColors.positive,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: kpiList
                .map((k) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.positive.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.positive.withOpacity(0.3)),
                      ),
                      child: Text(k,
                          style: const TextStyle(
                              color: AppColors.positive, fontSize: 11)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _AudienceRow extends StatelessWidget {
  const _AudienceRow(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
