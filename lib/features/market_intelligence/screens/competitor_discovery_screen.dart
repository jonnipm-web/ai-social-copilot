import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/language_utils.dart';
import '../../../data/models/competitor.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../competitor_type_labels.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class CompetitorDiscoveryScreen extends ConsumerStatefulWidget {
  const CompetitorDiscoveryScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<CompetitorDiscoveryScreen> createState() =>
      _CompetitorDiscoveryScreenState();
}

// IVE-COMMERCIAL-QUOTA-HARDENING-13 (Codex Gate 2 finding) — this screen
// fired competitor-discovery directly with no confirmation and no
// idempotency key; only gap_analysis_screen.dart's representative call
// site was migrated by Foundation-11. Same pattern as that screen.
class _CompetitorDiscoveryScreenState
    extends ConsumerState<CompetitorDiscoveryScreen> {
  final _exec = AiExecutionController();
  String? _error;

  @override
  void dispose() {
    _exec.dispose();
    super.dispose();
  }

  bool get _running => _exec.isBusy;

  Future<void> _discover() async {
    setState(() => _error = null);
    try {
      final analysis =
          await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      if (!mounted) return;
      await _exec.run<List<Competitor>>(
        context: context,
        ref: ref,
        analysisLabel: AppLocalizations.of(context)!.miCompetitorTitle,
        request: IveInteractionRequest(
          projectId: analysis.projectId,
          sourceModule: 'market_intelligence',
          sourceEntityType: 'competitor_discovery',
          sourceEntityId: widget.analysisId,
          operationType: IveOperationType.analyze,
        ),
        action: (idempotencyKey) =>
            ref.read(marketAnalysisServiceProvider).discoverCompetitors(
                  widget.analysisId,
                  analysis.input,
                  language: backendLanguageCode(context),
                  idempotencyKey: idempotencyKey,
                ),
      );
      if (_exec.state != AiExecutionState.success) return;
      ref.invalidate(competitorsByAnalysisProvider(widget.analysisId));
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
    final asyncList =
        ref.watch(competitorsByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        backgroundColor: AppColors.ground,
        title: Text(l10n.miCompetitorTitle,
            style: const TextStyle(color: AppColors.ink)),
        iconTheme: const IconThemeData(color: AppColors.ink),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub
                .replaceFirst(':id', widget.analysisId),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _discover,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: AppColors.negative, strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded, color: AppColors.negative),
            label: Text(
              _running
                  ? l10n.miCompetitorSearching
                  : l10n.miCompetitorDiscoverButton,
              style: const TextStyle(color: AppColors.negative),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.negative.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.negative.withOpacity(0.3)),
              ),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppColors.negative, fontSize: 13)),
            ),
          Expanded(
            child: asyncList.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.negative)),
              error: (e, _) => Center(
                  child: Text(
                      l10n.miSubErrorPrefix(extractErrorMessage(e, l10n)),
                      style: const TextStyle(color: AppColors.negative))),
              data: (competitors) => competitors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_alt_outlined,
                              color: AppColors.inkSubtle, size: 64),
                          const SizedBox(height: 16),
                          Text(l10n.miCompetitorEmptyTitle,
                              style: const TextStyle(color: AppColors.inkSubtle)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(l10n.miCompetitorEmptyBody,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.inkSubtle,
                                    fontSize: 12,
                                    height: 1.4)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _running ? null : _discover,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.negative,
                              foregroundColor: AppColors.ground,
                            ),
                            child: Text(l10n.miCompetitorEmptyButton),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: competitors.length,
                      itemBuilder: (_, i) =>
                          _CompetitorCard(competitor: competitors[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetitorCard extends StatelessWidget {
  const _CompetitorCard({required this.competitor});
  final Competitor competitor;

  Color get _typeColor {
    switch (competitor.type) {
      case 'direct':
        return AppColors.negative;
      case 'indirect':
        return AppColors.warning;
      default:
        return AppColors.positive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _typeColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(competitor.name,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(competitor.url,
                        style: const TextStyle(
                            color: AppColors.inkMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _typeColor.withOpacity(0.4)),
                ),
                child: Text(
                  competitorTypeLabel(competitor.type, l10n).toUpperCase(),
                  style: TextStyle(
                      color: _typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ScoreItem(
                  label: l10n.miCompetitorScoreSimilarity,
                  value: competitor.similarityScore,
                  color: AppColors.info),
              const SizedBox(width: 12),
              _ScoreItem(
                  label: l10n.miCompetitorScoreAuthority,
                  value: competitor.authorityScore,
                  color: AppColors.warning),
              const SizedBox(width: 12),
              _ScoreItem(
                  label: l10n.miCompetitorScoreRelevance,
                  value: competitor.relevanceScore,
                  color: AppColors.positive),
              const SizedBox(width: 12),
              _ScoreItem(
                  label: l10n.miCompetitorScoreOverall,
                  value: competitor.overallScore,
                  color: AppColors.negative),
            ],
          ),
          if (competitor.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(competitor.description,
                style: const TextStyle(
                    color: AppColors.inkMuted, fontSize: 12, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          if (competitor.strengths.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.miCompetitorStrengthsLabel,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 11)),
            const SizedBox(height: 4),
            ...competitor.strengths.take(3).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.positive, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    color: AppColors.inkMuted, fontSize: 12))),
                      ],
                    ),
                  ),
                ),
          ],
          // COMMERCIAL-V1-UX-RECONCILIATION (R2/R5) — Competitor.weaknesses
          // already existed on the model (populated by the same AI response
          // as strengths, see market_analysis_service.dart's insert) but was
          // never rendered — a Free/Pro user only ever saw half of what the
          // analysis actually found. Rendered symmetrically to "Pontos
          // fortes" above.
          if (competitor.weaknesses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.miCompetitorWeaknessesLabel,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 11)),
            const SizedBox(height: 4),
            ...competitor.weaknesses.take(3).map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_rounded,
                            color: AppColors.negative, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(w,
                                style: const TextStyle(
                                    color: AppColors.inkMuted, fontSize: 12))),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  const _ScoreItem(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: const TextStyle(color: AppColors.inkSubtle, fontSize: 10)),
      ],
    );
  }
}
