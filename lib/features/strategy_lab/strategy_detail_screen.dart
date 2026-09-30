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
import 'widgets/experiment_history_section.dart';
import 'widgets/plan_upgrade_banner.dart';
import 'widgets/robustness_evidence_section.dart';
import 'widgets/simulation_governance_section.dart';

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
  bool _backtestSucceeded = false;
  Map<String, dynamic>? _compareResult;
  Map<String, dynamic>? _compareScoreA;
  Map<String, dynamic>? _compareScoreB;

  bool _fitBusy = false;
  Map<String, dynamic>? _fitEvidence;
  List<dynamic> _proposals = const [];
  List<dynamic> _unsupportedParameters = const [];
  StrategyBuilderResult? _fitUpgrade;
  bool _simulationBusy = false;
  Map<String, dynamic>? _simulationResult;
  StrategyBuilderResult? _simulationUpgrade;
  bool _researchLoopBusy = false;
  List<dynamic>? _researchCandidates;
  StrategyBuilderResult? _researchLoopUpgrade;

  // Macro-08 continuation §5-8/§9/§16/§27 — governed simulation approval,
  // experiment history and user decision capture.
  String? _simulationExperimentId;
  bool _recordingBacktestExperiment = false;
  String? _backtestExperimentStatus;
  final _historyKey = GlobalKey<ExperimentHistorySectionState>();
  bool _decisionBusy = false;
  String? _decisionStatus;

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
      _backtestSucceeded = succeeded;
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
      _unsupportedParameters = (result.data?['unsupportedParameters'] as List?) ?? const [];
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
      // run_simulation auto-records a SIMULATION-category experiment
      // server-side (index.ts) -- this is the id the governed AEF
      // approval step (§5-8) reviews, never a client-invented one.
      _simulationExperimentId = (result.data?['experiment'] as Map<String, dynamic>?)?['id'] as String?;
    });
    _historyKey.currentState?.refresh();
  }

  /// §9/§27: a backtest is not auto-recorded as an experiment (unlike a
  /// simulation or a research-loop candidate) -- the owner explicitly
  /// decides a given backtest is worth citing in the strategy's research
  /// history.
  Future<void> _recordBacktestExperiment(AppLocalizations l) async {
    final version = _version;
    final target = _intelligenceTarget();
    if (version == null || target == null) return;
    setState(() => _recordingBacktestExperiment = true);
    final result = await ref.read(strategyBuilderApiProvider).recordExperiment(
          strategyVersionId: version['id'] as String,
          category: 'BACKTEST',
          datasetId: target.datasetId,
          segment: 'FULL',
          reason: 'Owner-recorded backtest result',
          source: 'USER',
        );
    if (!mounted) return;
    final id = (result.data?['experiment'] as Map<String, dynamic>?)?['id'] as String?;
    setState(() {
      _recordingBacktestExperiment = false;
      _backtestExperimentStatus = id != null ? l.strategyDetailExperimentRecorded(id) : l.strategyDetailRecordExperimentError(result.errorCode ?? 'UNKNOWN');
    });
    if (id != null) _historyKey.currentState?.refresh();
  }

  /// §16: KEEP_CURRENT/PREFER_CANDIDATE/REJECT_CANDIDATE/NEEDS_MORE_EVIDENCE,
  /// recorded as a USER_DECISION experiment (research decision provenance)
  /// -- never a lifecycle mutation: lifecycle.ts's own gates are the only
  /// path to a status transition, this is purely a citable research fact.
  Future<void> _recordDecision(AppLocalizations l, String decision, String label) async {
    final version = _version;
    final target = _intelligenceTarget();
    if (version == null || target == null) return;
    setState(() => _decisionBusy = true);
    final result = await ref.read(strategyBuilderApiProvider).recordExperiment(
          strategyVersionId: version['id'] as String,
          category: 'USER_DECISION',
          datasetId: target.datasetId,
          segment: 'FULL',
          reason: 'User decision on candidate comparison: $decision',
          source: 'USER',
        );
    if (!mounted) return;
    setState(() {
      _decisionBusy = false;
      _decisionStatus = result.data?['experiment'] != null ? l.strategyDetailUserDecisionRecorded(label) : l.strategyDetailRecordExperimentError(result.errorCode ?? 'UNKNOWN');
    });
    if (result.data?['experiment'] != null) _historyKey.currentState?.refresh();
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
    setState(() {
      _compareResult = result.data?['comparison'] as Map<String, dynamic>?;
      // §10/§21: independent robustness/score for EACH side -- never a
      // single "winner" verdict (server's own comment on compare_versions).
      _compareScoreA = result.data?['scoreA'] as Map<String, dynamic>?;
      _compareScoreB = result.data?['scoreB'] as Map<String, dynamic>?;
    });
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
            if (_backtestSucceeded) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('strategyDetailRecordBacktestExperiment'),
                onPressed: _recordingBacktestExperiment ? null : () => _recordBacktestExperiment(l),
                child: Text(l.strategyDetailRecordExperiment),
              ),
              if (_backtestExperimentStatus != null)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(_backtestExperimentStatus!, key: const Key('strategyDetailBacktestExperimentStatus'), style: const TextStyle(fontSize: 12))),
              const SizedBox(height: 8),
              RobustnessEvidenceSection(key: const Key('strategyDetailRobustnessSection'), strategyVersionId: version['id'] as String),
            ],
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
              if (_compareResult != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _compareResult!['comparable'] == true
                        ? 'Δ ${l.strategyBuilderNetPnl} = ${_compareResult!['deltas']?['netPnlDelta']}'
                        : l.strategyBuilderNotComparable((_compareResult!['incomparabilityReasons'] as List?)?.join(', ') ?? ''),
                    key: const Key('strategyDetailCompareResult'),
                  ),
                ),
                if (_compareScoreA != null) _buildScoreCard(l, 'A', _compareScoreA!),
                if (_compareScoreB != null) _buildScoreCard(l, 'B', _compareScoreB!),
                const SizedBox(height: 8),
                Text(l.strategyDetailUserDecisionTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(
                    key: const Key('strategyDetailDecisionKeepCurrent'),
                    onPressed: _decisionBusy ? null : () => _recordDecision(l, 'KEEP_CURRENT', l.strategyDetailUserDecisionKeepCurrent),
                    child: Text(l.strategyDetailUserDecisionKeepCurrent),
                  ),
                  OutlinedButton(
                    key: const Key('strategyDetailDecisionPreferCandidate'),
                    onPressed: _decisionBusy ? null : () => _recordDecision(l, 'PREFER_CANDIDATE', l.strategyDetailUserDecisionPreferCandidate),
                    child: Text(l.strategyDetailUserDecisionPreferCandidate),
                  ),
                  OutlinedButton(
                    key: const Key('strategyDetailDecisionRejectCandidate'),
                    onPressed: _decisionBusy ? null : () => _recordDecision(l, 'REJECT_CANDIDATE', l.strategyDetailUserDecisionRejectCandidate),
                    child: Text(l.strategyDetailUserDecisionRejectCandidate),
                  ),
                  OutlinedButton(
                    key: const Key('strategyDetailDecisionNeedsMoreEvidence'),
                    onPressed: _decisionBusy ? null : () => _recordDecision(l, 'NEEDS_MORE_EVIDENCE', l.strategyDetailUserDecisionNeedsMoreEvidence),
                    child: Text(l.strategyDetailUserDecisionNeedsMoreEvidence),
                  ),
                ]),
                if (_decisionStatus != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(_decisionStatus!, key: const Key('strategyDetailDecisionStatus'), style: const TextStyle(fontSize: 12))),
              ],
            ],
            const SizedBox(height: 16),
            _buildIntelligenceSection(l),
            const SizedBox(height: 16),
            Card(
              key: const Key('strategyDetailExperimentHistorySection'),
              child: ExpansionTile(
                title: Text(l.strategyDetailExperimentHistoryTitle),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ExperimentHistorySection(key: _historyKey, strategyId: strategy['id'] as String),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// §10/§21: independent, transparent score for one side of a comparison
  /// -- every component's value/weight/rationale shown, never collapsed
  /// into a single number a user could read as a guarantee (§18).
  Widget _buildScoreCard(AppLocalizations l, String side, Map<String, dynamic> score) {
    final components = (score['components'] as List?) ?? const [];
    final language = score['language'] == 'MORE_ROBUST_UNDER_TESTED_ASSUMPTIONS' ? l.strategyDetailScoreLanguageMoreRobust : l.strategyDetailScoreLanguageRequiresEvidence;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        key: Key('strategyDetailScoreCard$side'),
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$side · ${l.strategyDetailScoreOverall('${score['overall']}', language)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text(l.strategyDetailScoreComponentsTitle, style: const TextStyle(fontSize: 11)),
            for (final raw in components)
              Builder(builder: (context) {
                final c = raw as Map<String, dynamic>;
                final value = (c['value'] as num).toStringAsFixed(2);
                final weight = (c['weight'] as num).toStringAsFixed(2);
                return Text('  • ${c['name']} = $value (${l.uxStrategyScoreWeight(weight)}): ${c['rationale']}', style: const TextStyle(fontSize: 11));
              }),
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
                      if (_unsupportedParameters.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        for (final u in _unsupportedParameters)
                          Text(
                            l.strategyDetailUnsupportedParameter('${(u as Map)['parameter']}'),
                            key: const Key('strategyDetailUnsupportedParameter'),
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                      ],
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
                    if (_simulationExperimentId != null)
                      SimulationGovernanceSection(
                        key: const Key('strategyDetailSimulationGovernanceSection'),
                        experimentId: _simulationExperimentId!,
                        strategyId: (_strategy?['id'] as String?) ?? '',
                      ),
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
