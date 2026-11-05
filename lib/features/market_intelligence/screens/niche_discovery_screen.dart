import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/language_utils.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/niche_ranking.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class NicheDiscoveryScreen extends ConsumerStatefulWidget {
  const NicheDiscoveryScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<NicheDiscoveryScreen> createState() =>
      _NicheDiscoveryScreenState();
}

// IVE-COMMERCIAL-QUOTA-HARDENING-13 (Codex Gate 2 finding) — see
// competitor_discovery_screen.dart's identical note.
class _NicheDiscoveryScreenState extends ConsumerState<NicheDiscoveryScreen> {
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
      await _exec.run<List<NicheRanking>>(
        context: context,
        ref: ref,
        analysisLabel: AppLocalizations.of(context)!.miNicheTitle,
        request: IveInteractionRequest(
          projectId: analysis.projectId,
          sourceModule: 'market_intelligence',
          sourceEntityType: 'niche_discovery',
          sourceEntityId: widget.analysisId,
          operationType: IveOperationType.analyze,
        ),
        action: (idempotencyKey) =>
            ref.read(marketAnalysisServiceProvider).discoverNiches(
                  widget.analysisId,
                  analysis.input,
                  language: backendLanguageCode(context),
                  idempotencyKey: idempotencyKey,
                ),
      );
      if (_exec.state != AiExecutionState.success) return;
      ref.invalidate(nichesByAnalysisProvider(widget.analysisId));
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
    final asyncList = ref.watch(nichesByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.miNicheTitle,
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
                        color: AppColors.info, strokeWidth: 2),
                  )
                : const Icon(Icons.hub_rounded, color: AppColors.info),
            label: Text(
              _running ? l10n.miNicheDiscovering : l10n.miNicheDiscoverButton,
              style: const TextStyle(color: AppColors.info),
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
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.negative.withOpacity(0.3)),
              ),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppColors.negative, fontSize: 13)),
            ),
          Expanded(
            child: asyncList.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.info)),
              error: (e, _) => Center(
                  child: Text(
                      l10n.miSubErrorPrefix(extractErrorMessage(e, l10n)),
                      style: const TextStyle(color: AppColors.negative))),
              data: (niches) => niches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hub_outlined,
                              color: AppColors.inkSubtle, size: 64),
                          const SizedBox(height: 16),
                          Text(l10n.miNicheEmptyTitle,
                              style: const TextStyle(color: AppColors.inkSubtle)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(l10n.miNicheEmptyBody,
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
                              backgroundColor: AppColors.info,
                              foregroundColor: AppColors.ground,
                            ),
                            child: Text(l10n.miNicheEmptyButton),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: niches.length,
                      itemBuilder: (_, i) =>
                          _NicheCard(niche: niches[i], rank: i + 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NicheCard extends StatelessWidget {
  const _NicheCard({required this.niche, required this.rank});
  final NicheRanking niche;
  final int rank;

  Color get _levelColor {
    switch (niche.level) {
      case 'niche':
        return AppColors.info;
      case 'sub_niche':
        return AppColors.accent;
      default:
        return AppColors.info;
    }
  }

  String _levelLabel(AppLocalizations l10n) {
    switch (niche.level) {
      case 'niche':
        return l10n.miNicheLevelNiche;
      case 'sub_niche':
        return l10n.miNicheLevelSubNiche;
      default:
        return l10n.miNicheLevelMicroNiche;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _levelColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _levelColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _levelColor),
                ),
                child: Center(
                  child: Text('#$rank',
                      style: TextStyle(
                          color: _levelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(niche.name,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(_levelLabel(l10n),
                        style: TextStyle(color: _levelColor, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${niche.overallScore}',
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  Text(l10n.miNicheScoreLabel,
                      style:
                          const TextStyle(color: AppColors.inkSubtle, fontSize: 10)),
                ],
              ),
            ],
          ),
          if (niche.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(niche.description,
                style: const TextStyle(
                    color: AppColors.inkMuted, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          // Score grid
          Row(
            children: [
              _MiniBar(
                  label: l10n.miNicheScorePotential,
                  value: niche.potentialScore,
                  color: AppColors.positive),
              const SizedBox(width: 8),
              _MiniBar(
                  label: l10n.miNicheScoreGrowth,
                  value: niche.growthScore,
                  color: AppColors.info),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _MiniBar(
                  label: l10n.miNicheScoreMonetization,
                  value: niche.monetizationScore,
                  color: AppColors.warning),
              const SizedBox(width: 8),
              _MiniBar(
                  label: l10n.miNicheScoreTrend,
                  value: niche.trendScore,
                  color: AppColors.accent),
            ],
          ),
          if (niche.keywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: niche.keywords
                  .take(5)
                  .map(
                    (k) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _levelColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: _levelColor.withOpacity(0.3)),
                      ),
                      child: Text(k,
                          style: TextStyle(color: _levelColor, fontSize: 11)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 10)),
              Text('$value',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
