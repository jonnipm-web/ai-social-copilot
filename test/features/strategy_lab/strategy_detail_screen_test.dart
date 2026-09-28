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
  Future<StrategyBuilderResult> compareVersions(String versionAId, String versionBId) async =>
      const StrategyBuilderResult(200, {'comparison': {'comparable': true, 'deltas': {'netPnlDelta': 0}}});
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
}
