import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/language_utils.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/gap_analysis.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';

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
      final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      await _exec.run<void>(
        context: context,
        ref: ref,
        analysisLabel: 'Gap Analysis',
        request: IveInteractionRequest(
          projectId:        analysis.projectId,
          sourceModule:     'market_intelligence',
          sourceEntityType: 'gap_analysis',
          sourceEntityId:   widget.analysisId,
          operationType:    IveOperationType.analyze,
        ),
        action: (idempotencyKey) => ref
            .read(marketAnalysisServiceProvider)
            .runGapAnalysis(
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
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncGap = ref.watch(gapAnalysisByAnalysisProvider(widget.analysisId));

    // AnimatedBuilder over `_exec` so both "Analisar" buttons below react
    // live to AiExecutionState transitions (awaiting confirmation →
    // reserving/thinking → success/error), not just a binary running flag.
    return AnimatedBuilder(
      animation: _exec,
      builder: (context, _) => _buildScaffold(context, asyncGap),
    );
  }

  Widget _buildScaffold(BuildContext context, AsyncValue<GapAnalysis?> asyncGap) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Gap Analysis', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', widget.analysisId),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const AiThinkingIndicator(color: Color(0xFFFFD93D))
                : const Icon(Icons.find_in_page_rounded, color: Color(0xFFFFD93D)),
            label: Text(
              _running ? 'Analisando...' : 'Analisar',
              style: const TextStyle(color: Color(0xFFFFD93D)),
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          Expanded(
            child: asyncGap.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD93D))),
              error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (gap) => gap == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.find_in_page_outlined, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text('Nenhuma análise de gaps ainda', style: TextStyle(color: Colors.white38)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _running ? null : _run,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD93D),
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Analisar Gaps'),
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
                            color: const Color(0xFFFF6B6B),
                            title: 'Gaps de Conteúdo',
                            items: gap.contentGaps,
                          ),
                          _GapSection(
                            icon: Icons.search_rounded,
                            color: const Color(0xFF4D96FF),
                            title: 'Gaps de SEO',
                            items: gap.seoGaps,
                          ),
                          _GapSection(
                            icon: Icons.shield_rounded,
                            color: const Color(0xFF6BCB77),
                            title: 'Gaps de Autoridade',
                            items: gap.authorityGaps,
                          ),
                          _GapSection(
                            icon: Icons.attach_money_rounded,
                            color: const Color(0xFFFFD93D),
                            title: 'Gaps de Monetização',
                            items: gap.monetizationGaps,
                          ),
                          _GapSection(
                            icon: Icons.inventory_2_rounded,
                            color: const Color(0xFFAB83FF),
                            title: 'Gaps de Produto',
                            items: gap.productGaps,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF333355)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.summarize_rounded, color: Color(0xFFFFD93D), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: ${gap.totalGaps} gaps identificados',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD93D),
                                    fontWeight: FontWeight.bold,
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
      ),
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
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${items.length}',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF333355), height: 1),
          ...items.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
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
