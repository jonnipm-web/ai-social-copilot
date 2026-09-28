// INSIGHTVALUES-FINANCIAL-PRODUCT-MACRO-08 continuation §10, §28 —
// Robustness UX.
//
// Purely presentational over analyze_backtest_result's already-computed,
// deterministic, traceable claims (ive_strategy_analyst.ts) -- no new
// analysis logic, no LLM call, every statement is a direct function of
// the caller's own persisted backtest result. Progressive disclosure
// (§36 precedent from Macro-07): a score is shown with its components,
// never collapsed into a single "quality" label a user could mistake
// for a guarantee.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../data/strategy_builder_api.dart';

class RobustnessEvidenceSection extends ConsumerStatefulWidget {
  const RobustnessEvidenceSection({super.key, required this.strategyVersionId});
  final String strategyVersionId;

  @override
  ConsumerState<RobustnessEvidenceSection> createState() => _RobustnessEvidenceSectionState();
}

class _RobustnessEvidenceSectionState extends ConsumerState<RobustnessEvidenceSection> {
  bool _busy = false;
  List<dynamic>? _claims;
  String? _error;

  Future<void> _analyze() async {
    setState(() => _busy = true);
    final result = await ref.read(strategyBuilderApiProvider).analyzeBacktestResult(widget.strategyVersionId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _claims = (result.data?['claims'] as List?);
      _error = _claims == null ? (result.errorCode ?? 'UNKNOWN') : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final claims = _claims;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const Key('strategyDetailAnalyzeRobustness'),
          onPressed: _busy ? null : _analyze,
          icon: _busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_outlined),
          label: Text(l.strategyDetailAnalyzeRobustness),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.strategyDetailRecordExperimentError(_error!), style: const TextStyle(fontSize: 12))),
        if (claims != null) ...[
          const SizedBox(height: 8),
          Text(l.strategyDetailRobustnessEvidenceTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (claims.isEmpty) Text(l.strategyDetailNoRobustnessClaims, key: const Key('strategyDetailRobustnessEmpty')),
          for (final raw in claims)
            Builder(builder: (context) {
              final c = raw as Map<String, dynamic>;
              final status = c['status'] as String? ?? 'UNKNOWN';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• [$status] ${c['statement']}', style: const TextStyle(fontSize: 12)),
              );
            }),
        ],
      ],
    );
  }
}
