// INSIGHTVALUES-FINANCIAL-PRODUCT-MACRO-08 continuation §9, §27 —
// Experiment History UI.
//
// Purely a read-only presentation of strategy_experiments rows the
// server already records (run_simulation and run_research_loop
// auto-record SIMULATION/ROBUSTNESS_EXPERIMENT; record_experiment lets
// the user record BACKTEST/USER_DECISION/IVE_RECOMMENDATION explicitly)
// -- list_experiments already scopes to the caller's own strategy
// (SB-30), so no new ownership/project-isolation surface is introduced
// here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../data/strategy_builder_api.dart';

class ExperimentHistorySection extends ConsumerStatefulWidget {
  const ExperimentHistorySection({super.key, required this.strategyId});
  final String strategyId;

  @override
  ConsumerState<ExperimentHistorySection> createState() => ExperimentHistorySectionState();
}

class ExperimentHistorySectionState extends ConsumerState<ExperimentHistorySection> {
  List<dynamic>? _experiments;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final result = await ref.read(strategyBuilderApiProvider).listExperiments(widget.strategyId);
    if (!mounted) return;
    setState(() {
      _experiments = (result.data?['experiments'] as List?) ?? const [];
      _loading = false;
    });
  }

  String _categoryLabel(AppLocalizations l, String category) => switch (category) {
        'BACKTEST' => l.strategyDetailExperimentCategoryBacktest,
        'ROBUSTNESS_EXPERIMENT' => l.strategyDetailExperimentCategoryRobustness,
        'SIMULATION' => l.strategyDetailExperimentCategorySimulation,
        'USER_DECISION' => l.strategyDetailExperimentCategoryUserDecision,
        'IVE_RECOMMENDATION' => l.strategyDetailExperimentCategoryIveRecommendation,
        _ => category,
      };

  Color _categoryColor(String category) => switch (category) {
        'BACKTEST' => Colors.blueGrey,
        'ROBUSTNESS_EXPERIMENT' => Colors.deepPurple,
        'SIMULATION' => Colors.teal,
        'USER_DECISION' => Colors.orange,
        'IVE_RECOMMENDATION' => Colors.indigo,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    final experiments = _experiments ?? const [];
    if (experiments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(l.strategyDetailExperimentHistoryEmpty, key: const Key('experimentHistoryEmpty')),
      );
    }
    // Newest first: the server returns chronological research lineage,
    // most recent activity is what a returning user wants to see.
    final sorted = [...experiments]..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    return Column(
      key: const Key('experimentHistoryList'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in sorted)
          Builder(builder: (context) {
            final e = raw as Map<String, dynamic>;
            final category = e['category'] as String? ?? '-';
            final contaminated = e['contaminated'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3, right: 8),
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: _categoryColor(category), shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_categoryLabel(l, category), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${e['reason'] ?? ''}', style: const TextStyle(fontSize: 12)),
                        Text(
                          l.strategyDetailExperimentSegment('${e['segment']}') + (contaminated ? ' · ${l.strategyDetailExperimentContaminated}' : ''),
                          style: TextStyle(fontSize: 11, color: contaminated ? Colors.orangeAccent : Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
