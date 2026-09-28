import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/features/strategy_lab/data/strategy_builder_api.dart';
import 'package:ai_social_copilot/features/strategy_lab/strategy_detail_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

class FakeDetailApi implements StrategyBuilderApi {
  final Map<String, dynamic> spec;
  final calls = <String>[];
  Map<String, dynamic> backtestJob = {'status': 'SUCCEEDED'};

  FakeDetailApi(this.spec);

  @override
  Future<StrategyBuilderResult> get(String strategyId) async {
    calls.add('get');
    return StrategyBuilderResult(200, {
      'strategy': {'id': strategyId, 'name': spec['name'], 'status': 'DRAFT', 'currentVersion': 1},
      'version': {'id': 'v1', 'versionNumber': 1, 'spec': spec, 'specHash': 'h1'},
    });
  }

  @override
  Future<StrategyBuilderResult> listVersions(String strategyId) async {
    calls.add('list_versions');
    return const StrategyBuilderResult(200, {'versions': []});
  }

  @override
  Future<StrategyBuilderResult> runBacktest(String strategyVersionId, String datasetId, String engineId, {Map<String, dynamic>? costConfig}) async {
    calls.add('run_backtest:$datasetId:$engineId');
    return StrategyBuilderResult(200, {'job': backtestJob, 'result': backtestJob['status'] == 'SUCCEEDED' ? {} : null});
  }

  @override
  Future<StrategyBuilderResult> validate(Map<String, dynamic> spec) async => const StrategyBuilderResult(200, {'valid': true});
  @override
  Future<StrategyBuilderResult> draftFromText(String text) async => const StrategyBuilderResult(200, {'draft': {}});
  @override
  Future<StrategyBuilderResult> create(Map<String, dynamic> spec) async => const StrategyBuilderResult(200, {});
  @override
  Future<StrategyBuilderResult> createVersion(String strategyId, Map<String, dynamic> spec) async => const StrategyBuilderResult(200, {});
  @override
  Future<StrategyBuilderResult> list() async => const StrategyBuilderResult(200, {'strategies': []});
  @override
  Future<StrategyBuilderResult> cloneReference(String reference) async => const StrategyBuilderResult(200, {});
  @override
  Future<StrategyBuilderResult> compareVersions(String versionAId, String versionBId, {String? objective}) async => const StrategyBuilderResult(200, {
        'comparison': {'comparable': true, 'deltas': {'netPnlDelta': 0}},
        'robustnessA': {'sampleSize': {'sufficient': false}},
        'robustnessB': {'sampleSize': {'sufficient': false}},
        'scoreA': {'overall': 0, 'language': 'REQUIRES_MORE_EVIDENCE', 'components': []},
        'scoreB': {'overall': 0, 'language': 'REQUIRES_MORE_EVIDENCE', 'components': []},
      });
  @override
  Future<StrategyBuilderResult> engineStatus() async =>
      const StrategyBuilderResult(200, {'engines': [{'engineId': 'GENERIC_RULE_ENGINE', 'available': true, 'reason': null}]});
  Map<String, dynamic> proposeVariantsResult = {
    'fitEvidence': {'items': [], 'sufficientData': false},
    'proposals': [],
  };
  StrategyBuilderResult? proposeVariantsForcedResult;
  @override
  Future<StrategyBuilderResult> proposeVariants(String strategyVersionId, String datasetId) async {
    calls.add('propose_variants:$datasetId');
    return proposeVariantsForcedResult ?? StrategyBuilderResult(200, proposeVariantsResult);
  }

  Map<String, dynamic> runResearchLoopResult = {
    'fitEvidence': {'items': [], 'sufficientData': false},
    'proposals': [],
    'candidates': [],
  };
  StrategyBuilderResult? runResearchLoopForcedResult;
  @override
  Future<StrategyBuilderResult> runResearchLoop(String strategyVersionId, String datasetId) async {
    calls.add('run_research_loop:$datasetId');
    return runResearchLoopForcedResult ?? StrategyBuilderResult(200, runResearchLoopResult);
  }

  Map<String, dynamic> runSimulationResult = {
    'result': {'tradeCount': 2, 'netPnl': 5},
    'experiment': {'category': 'SIMULATION'},
    'label': 'SIMULATION',
  };
  StrategyBuilderResult? runSimulationForcedResult;
  @override
  Future<StrategyBuilderResult> runSimulation(String strategyVersionId, String datasetId) async {
    calls.add('run_simulation:$datasetId');
    return runSimulationForcedResult ?? StrategyBuilderResult(200, runSimulationResult);
  }

  @override
  Future<StrategyBuilderResult> listExperiments(String strategyId) async => const StrategyBuilderResult(200, {'experiments': []});
}

const _genericSpec = {
  'name': 'Detail Test Strategy',
  'entry': {'ruleId': 'ENTRY.SESSION_OPEN'},
  'allowedDirections': ['LONG'],
  'marketProfile': {'instrument': {'symbol': 'SYNTH1'}},
  'stop': {'distance': 5}, 'target': {'distance': 10},
  'session': {'startTime': '13:00', 'endTime': '14:00'}, 'forcedExit': {'time': '14:00'},
  'positionSize': {'quantity': 1},
};

const _v10Spec = {
  'name': 'V10 Clone',
  'entry': {'ruleId': 'ENTRY.PULLBACK_IN_TREND'},
  'allowedDirections': ['LONG', 'SHORT'],
  'marketProfile': {'instrument': {'symbol': 'WIN1!'}},
  'stop': {'distance': 100}, 'target': {'distance': 250},
  'session': {'startTime': '10:00', 'endTime': '16:00'}, 'forcedExit': {'time': '16:00'},
  'positionSize': {'quantity': 1},
};

Future<FakeDetailApi> _pump(WidgetTester tester, Map<String, dynamic> spec) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = FakeDetailApi(spec);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [strategyBuilderApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StrategyDetailScreen(strategyId: 'sid-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('SD-01 shows the canonical spec summary from the server, not a client re-derivation', (tester) async {
    await _pump(tester, _genericSpec);
    expect(find.text('Detail Test Strategy'), findsOneWidget);
    expect(find.textContaining('SYNTH1'), findsOneWidget);
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('SD-02 running a backtest on a generic-entry strategy dispatches GENERIC_RULE_ENGINE + the synthetic dataset', (tester) async {
    final api = await _pump(tester, _genericSpec);
    final button = find.byKey(const Key('strategyDetailRunBacktest'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.calls, contains('run_backtest:synthetic-fixture-5min-v1:GENERIC_RULE_ENGINE'));
    expect(find.text('Backtest complete.'), findsOneWidget);
  });

  testWidgets('SD-03 running a backtest on a V10-entry (cloned) strategy dispatches the Python bridge engine + the real WIN1! dataset id', (tester) async {
    final api = await _pump(tester, _v10Spec);
    final button = find.byKey(const Key('strategyDetailRunBacktest'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.calls, contains('run_backtest:win1-5min-qt01c3:PAULO_TREND_FIBONACCI_V10'));
  });

  testWidgets('SD-04 a failed backtest shows the failure reason, never a fabricated success', (tester) async {
    final api = FakeDetailApi(_genericSpec)..backtestJob = {'status': 'FAILED', 'failureReason': 'engine refused'};
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [strategyBuilderApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StrategyDetailScreen(strategyId: 'sid-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('strategyDetailRunBacktest'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('engine refused'), findsOneWidget);
  });

  testWidgets('SD-05 (§36) the Strategy Intelligence section is collapsed by default and shows the V10-unavailable message for a V10-entry strategy', (tester) async {
    await _pump(tester, _v10Spec);
    final tile = find.byKey(const Key('strategyDetailIntelligenceSection'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    // Collapsed by default: none of the three action buttons are reachable yet.
    expect(find.byKey(const Key('strategyDetailAnalyzeFit')), findsNothing);
    await tester.tap(find.text('Strategy Intelligence'));
    await tester.pumpAndSettle();
    expect(find.text('These research tools only work with the in-process generic engine right now.'), findsOneWidget);
    expect(find.byKey(const Key('strategyDetailAnalyzeFit')), findsNothing);
  });

  testWidgets('SD-06 (§10/§19) analyzing fit on a generic-entry strategy calls propose_variants with the real synthetic dataset id and renders the result', (tester) async {
    final api = FakeDetailApi(_genericSpec)
      ..proposeVariantsResult = {
        'fitEvidence': {
          'items': [
            {'dimension': 'STOP_VS_MOVEMENT', 'observation': 'Stop distance is tight vs typical range.', 'flagged': true},
          ],
          'sufficientData': false,
        },
        'proposals': [
          {'label': 'stop=6', 'reason': 'Current stop is tight -- testing a wider stop.'},
        ],
      };
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [strategyBuilderApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StrategyDetailScreen(strategyId: 'sid-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('strategyDetailIntelligenceSection'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strategy Intelligence'));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('strategyDetailAnalyzeFit'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.calls, contains('propose_variants:synthetic-fixture-5min-v1'));
    expect(find.textContaining('Stop distance is tight vs typical range.'), findsOneWidget);
    expect(find.textContaining('Current stop is tight -- testing a wider stop.'), findsOneWidget);
  });

  testWidgets('SD-07 (§13) a PLAN_UPGRADE_REQUIRED denial on Analyze fit renders the structured upgrade banner, never a silent no-op', (tester) async {
    final api = FakeDetailApi(_genericSpec)
      ..proposeVariantsForcedResult = const StrategyBuilderResult(403, {
        'error': 'PLAN_UPGRADE_REQUIRED', 'correlation_id': 'c1', 'requiredPlan': 'pro', 'currentPlan': 'free', 'op': 'propose_variants',
      });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [strategyBuilderApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StrategyDetailScreen(strategyId: 'sid-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strategy Intelligence'));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('strategyDetailAnalyzeFit'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planUpgradeBanner')), findsOneWidget);
    expect(find.textContaining('Pro'), findsWidgets);
    expect(find.textContaining('Free'), findsWidgets);
    expect(find.byKey(const Key('planUpgradeBannerCta')), findsOneWidget);
  });

  testWidgets('SD-08 (§13) a PLAN_UPGRADE_REQUIRED denial on Run simulation renders the structured upgrade banner requiring Premium', (tester) async {
    final api = FakeDetailApi(_genericSpec)
      ..runSimulationForcedResult = const StrategyBuilderResult(403, {
        'error': 'PLAN_UPGRADE_REQUIRED', 'correlation_id': 'c2', 'requiredPlan': 'premium', 'currentPlan': 'pro', 'op': 'run_simulation',
      });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [strategyBuilderApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StrategyDetailScreen(strategyId: 'sid-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strategy Intelligence'));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('strategyDetailRunSimulation'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planUpgradeBanner')), findsOneWidget);
    expect(find.textContaining('Premium'), findsWidgets);
    expect(find.byKey(const Key('strategyDetailSimulationResultText')), findsNothing);
  });

  testWidgets('SD-09 (§13) a PLAN_UPGRADE_REQUIRED denial on the research loop shows the banner instead of a misleading "no candidates" message', (tester) async {
    final api = FakeDetailApi(_genericSpec)
      ..runResearchLoopForcedResult = const StrategyBuilderResult(403, {
        'error': 'PLAN_UPGRADE_REQUIRED', 'correlation_id': 'c3', 'requiredPlan': 'pro', 'currentPlan': 'free', 'op': 'run_research_loop',
      });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [strategyBuilderApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StrategyDetailScreen(strategyId: 'sid-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strategy Intelligence'));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('strategyDetailRunResearchLoop'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planUpgradeBanner')), findsOneWidget);
    expect(find.byKey(const Key('strategyDetailResearchLoopResultText')), findsNothing);
    // A denied loop produced no candidates, so _load() must not re-fire a
    // second time (mirrors the "only reload on a real persisted candidate"
    // guard right after runResearchLoop's setState).
    expect(api.calls.where((c) => c == 'get').length, 1);
  });
}
