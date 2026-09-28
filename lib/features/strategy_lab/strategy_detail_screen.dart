// INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §8-9, §12, §30 — Strategy detail.
//
// Shows the canonical spec summary (§8, same shape the server persisted --
// no client-side re-derivation of what the strategy does), lets the owner
// run a real backtest (§12: dispatches to the generic engine or the V10
// Python bridge depending on the spec's own entry rule -- this screen
// never picks an engine the spec doesn't support), and compares the two
// most recent versions once both have a result (§30).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ive_exclusion_region.dart';
import 'data/strategy_builder_api.dart';
import 'strategy_builder_form_screen.dart';
import 'widgets/plan_upgrade_banner.dart';

class StrategyDetailScreen extends ConsumerStatefulWidget {
  const StrategyDetailScreen({super.key, required this.strategyId});
  final String strategyId;

  @override
  ConsumerState<StrategyDetailScreen> createState() => _StrategyDetailScreenState();
}

class _StrategyDetailScreenState extends ConsumerState<StrategyDetailScreen> {
  Map<String, dynamic>? _strategy;
  Map<String, dynamic>? _version;
  List<dynamic> _versions = const [];
  bool _loading = true;
  bool _backtestBusy = false;
  String? _backtestStatus;
  Map<String, dynamic>? _compareResult;

  bool _fitBusy = false;
  Map<String, dynamic>? _fitEvidence;
  List<dynamic> _proposals = const [];
  StrategyBuilderResult? _fitUpgrade;
  bool _simulationBusy = false;
  Map<String, dynamic>? _simulationResult;
  StrategyBuilderResult? _simulationUpgrade;
  bool _researchLoopBusy = false;
  List<dynamic>? _researchCandidates;
  StrategyBuilderResult? _researchLoopUpgrade;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(strategyBuilderApiProvider);
    final got = await api.get(widget.strategyId);
    final versions = await api.listVersions(widget.strategyId);
    if (!mounted) return;
    setState(() {
      _strategy = got.data?['strategy'] as Map<String, dynamic>?;
      _version = got.data?['version'] as Map<String, dynamic>?;
      _versions = (versions.data?['versions'] as List?) ?? const [];
      _loading = false;
    });
  }

  Future<void> _runBacktest(AppLocalizations l) async {
    final version = _version;
    if (version == null) return;
    final spec = version['spec'] as Map<String, dynamic>;
    final useV10 = spec['entry']?['ruleId'] == 'ENTRY.PULLBACK_IN_TREND';
    final target = datasetAndEngineFor(useV10Entry: useV10);
    setState(() {
      _backtestBusy = true;
      _backtestStatus = l.strategyBuilderBacktestRunning;
    });
    final result = await ref.read(strategyBuilderApiProvider).runBacktest(version['id'] as String, target.datasetId, target.engineId);
    if (!mounted) return;
    final job = result.data?['job'] as Map<String, dynamic>?;
    final succeeded = job?['status'] == 'SUCCEEDED';
    setState(() {
      _backtestBusy = false;
      _backtestStatus = succeeded ? l.strategyBuilderBacktestSucceeded : l.strategyBuilderBacktestFailed(job?['failureReason']?.toString() ?? 'UNKNOWN');
    });
  }

  /// MACRO-07 §36: these research tools are only meaningful (and only
  /// server-accepted) for the in-process generic engine's own dataset --
  /// the V10/WIN1! path has no in-process rows to compute market
  /// statistics from.
  ({String datasetId, String engineId})? _intelligenceTarget() {
    final version = _version;
    if (version == null) return null;
    final spec = version['spec'] as Map<String, dynamic>;
    final useV10 = spec['entry']?['ruleId'] == 'ENTRY.PULLBACK_IN_TREND';
    if (useV10) return null;
    return datasetAndEngineFor(useV10Entry: false);
  }

  Future<void> _analyzeFit() async {
    final version = _version;
    final target = _intelligenceTarget();
    if (version == null || target == null) return;
    setState(() => _fitBusy = true);
    final result = await ref.read(strategyBuilderApiProvider).proposeVariants(version['id'] as String, target.datasetId);
    if (!mounted) return;
    setState(() {
      _fitBusy = false;
      _fitEvidence = result.data?['fitEvidence'] as Map<String, dynamic>?;
      _proposals = (result.data?['proposals'] as List?) ?? const [];
      _fitUpgrade = result.isPlanUpgradeRequired ? result : null;
    });
  }

  Future<void> _runSimulation() async {
    final version = _version;
    final target = _intelligenceTarget();
    if (version == null || target == null) return;
    setState(() => _simulationBusy = true);
    final result = await ref.read(strategyBuilderApiProvider).runSimulation(version['id'] as String, target.datasetId);
    if (!mounted) return;
    setState(() {
      _simulationBusy = false;
      _simulationResult = result.data?['result'] as Map<String, dynamic>?;
      _simulationUpgrade = result.isPlanUpgradeRequired ? result : null;
    });
  }

  Future<void> _runResearchLoop() async {
    final version = _version;
    final target = _intelligenceTarget();
    if (version == null || target == null) return;
    setState(() => _researchLoopBusy = true);
    final result = await ref.read(strategyBuilderApiProvider).runResearchLoop(version['id'] as String, target.datasetId);
    if (!mounted) return;
    setState(() {
      _researchLoopBusy = false;
      _researchLoopUpgrade = result.isPlanUpgradeRequired ? result : null;
      _researchCandidates = result.isPlanUpgradeRequired ? null : (result.data?['candidates'] as List?) ?? const [];
    });
    // A candidate is a real, persisted new strategy version (§20) -- the
    // version list must reflect it, never left stale in this screen.
    if ((_researchCandidates?.isNotEmpty ?? false)) await _load();
  }

  Future<void> _compareLastTwo() async {
    if (_versions.length < 2) return;
    final a = _versions[_versions.length - 2] as Map<String, dynamic>;
    final b = _versions[_versions.length - 1] as Map<String, dynamic>;
    final result = await ref.read(strategyBuilderApiProvider).compareVersions(a['id'] as String, b['id'] as String);
    if (!mounted) return;
    setState(() => _compareResult = result.data?['comparison'] as Map<String, dynamic>?);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final strategy = _strategy;
    final version = _version;
    if (strategy == null || version == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.strategyLabAccessDenied)));
    }
    final spec = version['spec'] as Map<String, dynamic>;
    final t = Theme.of(context).textTheme;
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(TextSpan(children: [TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: v)])),
        );

    return Scaffold(
      appBar: AppBar(title: Text(strategy['name'] as String)),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('strategyDetailScroll'),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.strategyBuilderVersion(version['versionNumber'] as int), style: t.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(header: true, child: Text(l.strategyBuilderSummaryTitle, style: t.titleSmall)),
                  const SizedBox(height: 8),
                  kv(l.strategyBuilderSummaryInstrument, spec['marketProfile']?['instrument']?['symbol']?.toString() ?? '-'),
                  kv(l.strategyBuilderDirection, ((spec['allowedDirections'] as List?)?.join(' + ')) ?? '-'),
                  kv(l.strategyBuilderStopDistance, '${spec['stop']?['distance']}'),
                  kv(l.strategyBuilderTargetDistance, '${spec['target']?['distance']}'),
                  kv(l.strategyLabSession, '${spec['session']?['startTime']}–${spec['session']?['endTime']}'),
                  kv(l.strategyBuilderSummaryPosition, '${spec['positionSize']?['quantity']}'),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            IveExclusionRegion(
              child: FilledButton.icon(
                key: const Key('strategyDetailRunBacktest'),
                onPressed: _backtestBusy ? null : () => _runBacktest(l),
                icon: _backtestBusy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                label: Text(l.strategyBuilderRunBacktest),
              ),
            ),
            if (_backtestStatus != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_backtestStatus!, key: const Key('strategyDetailBacktestStatus'))),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('strategyDetailNewVersion'),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => StrategyBuilderFormScreen(existingStrategyId: strategy['id'] as String, initialSpec: spec)),
                );
                if (saved == true) _load();
              },
              child: Text(l.strategyBuilderNewVersionButton),
            ),
            const SizedBox(height: 16),
            for (final v in _versions) Text(l.strategyBuilderVersion(v['versionNumber'] as int)),
            if (_versions.length >= 2) ...[
              const SizedBox(height: 8),
              OutlinedButton(key: const Key('strategyDetailCompare'), onPressed: _compareLastTwo, child: Text(l.strategyBuilderCompare)),
              if (_compareResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _compareResult!['comparable'] == true
                        ? 'Δ ${l.strategyBuilderNetPnl} = ${_compareResult!['deltas']?['netPnlDelta']}'
                        : l.strategyBuilderNotComparable((_compareResult!['incomparabilityReasons'] as List?)?.join(', ') ?? ''),
                    key: const Key('strategyDetailCompareResult'),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _buildIntelligenceSection(l),
          ]),
        ),
      ),
    );
  }

  /// MACRO-07 §36: progressive disclosure -- collapsed by default (an
  /// ExpansionTile, not always-visible controls), so a normal user is not
  /// confronted with fit evidence, bounded proposals, a simulation runner
  /// and a research-loop runner just to look at a strategy's summary.
  Widget _buildIntelligenceSection(AppLocalizations l) {
    final target = _intelligenceTarget();
    return Card(
      key: const Key('strategyDetailIntelligenceSection'),
      child: ExpansionTile(
        title: Text(l.strategyDetailIntelligenceTitle),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: target == null
                ? Text(l.strategyDetailUnavailableForV10)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    IveExclusionRegion(
                      child: OutlinedButton.icon(
                        key: const Key('strategyDetailAnalyzeFit'),
                        onPressed: _fitBusy ? null : _analyzeFit,
                        icon: _fitBusy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.insights),
                        label: Text(l.strategyDetailAnalyzeFit),
                      ),
                    ),
                    if (_fitUpgrade != null) Padding(padding: const EdgeInsets.only(top: 8), child: PlanUpgradeBanner.fromResult(_fitUpgrade!)),
                    if (_fitEvidence != null) ...[
                      const SizedBox(height: 8),
                      Text(l.strategyDetailFitEvidenceTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                      for (final item in ((_fitEvidence!['items'] as List?) ?? const []))
                        Text('• ${(item as Map)['observation']}${item['flagged'] == true ? ' (${l.strategyDetailFitFlagged})' : ''}'),
                      const SizedBox(height: 8),
                      Text(l.strategyDetailProposalsTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (_proposals.isEmpty) Text(l.strategyDetailNoProposals) else for (final p in _proposals) Text('• ${(p as Map)['reason']}'),
                    ],
                    const SizedBox(height: 12),
                    IveExclusionRegion(
                      child: OutlinedButton.icon(
                        key: const Key('strategyDetailRunSimulation'),
                        onPressed: _simulationBusy ? null : _runSimulation,
                        icon: _simulationBusy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.science_outlined),
                        label: Text(l.strategyDetailRunSimulation),
                      ),
                    ),
                    if (_simulationResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l.strategyDetailSimulationResult('${_simulationResult!['tradeCount']}', '${_simulationResult!['netPnl']}'),
                          key: const Key('strategyDetailSimulationResultText'),
                        ),
                      ),
                    if (_simulationUpgrade != null) Padding(padding: const EdgeInsets.only(top: 8), child: PlanUpgradeBanner.fromResult(_simulationUpgrade!)),
                    const SizedBox(height: 12),
                    IveExclusionRegion(
                      child: OutlinedButton.icon(
                        key: const Key('strategyDetailRunResearchLoop'),
                        onPressed: _researchLoopBusy ? null : _runResearchLoop,
                        icon: _researchLoopBusy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_motion_outlined),
                        label: Text(l.strategyDetailRunResearchLoop),
                      ),
                    ),
                    if (_researchCandidates != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _researchCandidates!.isEmpty ? l.strategyDetailNoCandidates : l.strategyDetailResearchLoopSummary('${_researchCandidates!.length}'),
                          key: const Key('strategyDetailResearchLoopResultText'),
                        ),
                      ),
                    if (_researchLoopUpgrade != null) Padding(padding: const EdgeInsets.only(top: 8), child: PlanUpgradeBanner.fromResult(_researchLoopUpgrade!)),
                  ]),
          ),
        ],
      ),
    );
  }
}
