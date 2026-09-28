import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/features/strategy_lab/data/strategy_builder_api.dart';
import 'package:ai_social_copilot/features/strategy_lab/strategy_lab_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';

Profile _profile({bool admin = true}) => Profile(
      id: 'aaaaaaaa-0000-4000-8000-00000000000a',
      email: 'admin@example.test',
      role: admin ? 'admin' : 'user',
      monthlyLimit: 10,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

class FakeStrategyBuilderApi implements StrategyBuilderApi {
  List<Map<String, dynamic>> strategies = [];
  final calls = <String>[];

  @override
  Future<StrategyBuilderResult> list() async {
    calls.add('list');
    return StrategyBuilderResult(200, {'strategies': strategies});
  }

  @override
  Future<StrategyBuilderResult> cloneReference(String reference, {String? idempotencyKey}) async {
    calls.add('clone_reference:$reference');
    final strategy = {'id': 'new-id-${strategies.length}', 'name': 'Cloned $reference', 'status': 'DRAFT', 'currentVersion': 1};
    strategies = [...strategies, strategy];
    return StrategyBuilderResult(200, {'strategy': strategy, 'version': {'id': 'v-1'}});
  }

  @override
  Future<StrategyBuilderResult> validate(Map<String, dynamic> spec) async => const StrategyBuilderResult(200, {'valid': true});
  @override
  Future<StrategyBuilderResult> draftFromText(String text) async => const StrategyBuilderResult(200, {'draft': {}});
  /// Set by a test that wants to simulate a failed first attempt (so the
  /// screen stays open and a second Save tap is a real retry, not a
  /// no-op after the screen already popped).
  bool failNextCreate = false;
  @override
  Future<StrategyBuilderResult> create(Map<String, dynamic> spec, {String? idempotencyKey}) async {
    calls.add('create:$idempotencyKey');
    if (failNextCreate) {
      failNextCreate = false;
      return const StrategyBuilderResult(500, {'error': 'INTERNAL_ERROR'});
    }
    return StrategyBuilderResult(200, {'strategy': {'id': 'sid', 'name': spec['name']}, 'version': {'id': 'vid', 'versionNumber': 1}});
  }
  @override
  Future<StrategyBuilderResult> get(String strategyId) async => const StrategyBuilderResult(404, {'error': 'NOT_FOUND'});
  @override
  Future<StrategyBuilderResult> createVersion(String strategyId, Map<String, dynamic> spec) async =>
      const StrategyBuilderResult(200, {'version': {'id': 'v2', 'versionNumber': 2}});
  @override
  Future<StrategyBuilderResult> listVersions(String strategyId) async => const StrategyBuilderResult(200, {'versions': []});
  @override
  Future<StrategyBuilderResult> runBacktest(String strategyVersionId, String datasetId, String engineId, {Map<String, dynamic>? costConfig}) async =>
      const StrategyBuilderResult(200, {'job': {'status': 'SUCCEEDED'}, 'result': {}});
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
  @override
  Future<StrategyBuilderResult> proposeVariants(String strategyVersionId, String datasetId) async =>
      const StrategyBuilderResult(200, {'fitEvidence': {'items': [], 'sufficientData': false}, 'proposals': []});
  @override
  Future<StrategyBuilderResult> runResearchLoop(String strategyVersionId, String datasetId) async =>
      const StrategyBuilderResult(200, {'fitEvidence': {'items': [], 'sufficientData': false}, 'proposals': [], 'candidates': []});
  @override
  Future<StrategyBuilderResult> runSimulation(String strategyVersionId, String datasetId) async =>
      const StrategyBuilderResult(200, {'result': {'tradeCount': 0, 'netPnl': 0}, 'experiment': {'category': 'SIMULATION'}, 'label': 'SIMULATION'});
  @override
  Future<StrategyBuilderResult> listExperiments(String strategyId) async => const StrategyBuilderResult(200, {'experiments': []});
  @override
  Future<StrategyBuilderResult> recordExperiment({
    required String strategyVersionId,
    required String category,
    required String datasetId,
    required String segment,
    required String reason,
    String? resultId,
    required String source,
  }) async =>
      StrategyBuilderResult(200, {'experiment': {'id': 'exp-${strategies.length}', 'category': category}});
  @override
  Future<StrategyBuilderResult> analyzeBacktestResult(String strategyVersionId) async => const StrategyBuilderResult(200, {'claims': []});
}

Future<FakeStrategyBuilderApi> _pump(WidgetTester tester, {bool admin = true, Locale locale = const Locale('en'), List<Map<String, dynamic>>? strategies}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = FakeStrategyBuilderApi()..strategies = strategies ?? [];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) => Future.value(_profile(admin: admin))),
        strategyBuilderApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StrategyLabScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('SL-01 admin sees the V10 reference strategy with its real reproduction numbers', (tester) async {
    await _pump(tester);
    expect(find.text('Strategy #001 — Paulo Trend Fibonacci V10 (Bidirectional Stepped)'), findsOneWidget);
    expect(find.textContaining('75 trades'), findsNWidgets(2));
    expect(find.textContaining('c19661f4dfc61193'), findsOneWidget);
    expect(find.textContaining('e79067f77120956d'), findsOneWidget);
  });

  testWidgets('SL-02 the RESEARCH-only / not-live disclaimer is always shown', (tester) async {
    await _pump(tester);
    expect(find.textContaining('NOT a proven profitable strategy'), findsOneWidget);
  });

  testWidgets('SL-03 a non-admin sees access-denied, never the strategy content', (tester) async {
    await _pump(tester, admin: false);
    expect(find.textContaining('do not have permission'), findsOneWidget);
    expect(find.text('Strategy #001 — Paulo Trend Fibonacci V10 (Bidirectional Stepped)'), findsNothing);
  });

  testWidgets('SL-04 PT locale renders the PT disclaimer, same underlying numbers', (tester) async {
    await _pump(tester, locale: const Locale('pt'));
    expect(find.textContaining('NÃO é uma estratégia com lucro comprovado'), findsOneWidget);
    expect(find.textContaining('c19661f4dfc61193'), findsOneWidget);
  });

  testWidgets('SL-05 the screen scrolls on a narrow (phone-width) viewport without overflow', (tester) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('strategyLabScroll')), findsOneWidget);
  });

  testWidgets('SL-06 the hub calls list() on load and shows an empty-state message with no strategies', (tester) async {
    final api = await _pump(tester);
    expect(api.calls, contains('list'));
    expect(find.text('No strategies yet.'), findsOneWidget);
  });

  testWidgets('SL-07 a real strategy from the server renders in the My Strategies list', (tester) async {
    await _pump(tester, strategies: [
      {'id': 's1', 'name': 'My First Strategy', 'status': 'DRAFT', 'currentVersion': 1},
    ]);
    expect(find.text('My First Strategy'), findsOneWidget);
    expect(find.textContaining('DRAFT'), findsOneWidget);
  });

  testWidgets('SL-08 tapping Clone Strategy #001 calls clone_reference(V10) and refreshes the list', (tester) async {
    final api = await _pump(tester);
    await tester.tap(find.byKey(const Key('strategyLabCloneV10')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('clone_reference:V10'));
    expect(find.text('Cloned V10'), findsOneWidget);
  });

  testWidgets('SL-09 the New strategy button opens the structured builder form, not a read-only view', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('strategyLabNewButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('strategyBuilderSaveButton')), findsOneWidget);
    expect(find.byKey(const Key('strategyBuilderNameField')), findsOneWidget);
  });
}
