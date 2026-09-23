// IV-QUANT-DATA-PLANE-AND-API-02 — Quant Lab: request contract, response
// parsing, error mapping, admin gate, no-execution surface, PT/EN, text
// scaling and responsive layout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/features/quant_lab/quant_lab_models.dart';
import 'package:ai_social_copilot/features/quant_lab/quant_lab_screen.dart';
import 'package:ai_social_copilot/features/quant_lab/quant_lab_service.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';

/// Shape of a real `quant-analyze` 200 body (values from the Foundation golden G1).
Map<String, dynamic> sampleAnalysis() => {
      'schemaVersion': 1,
      'analysisId': 'qa_0123456789abcdef0123456789abcdef',
      'engineVersion': 'quant-foundation-0.2.0',
      'computedBy': 'DETERMINISTIC_ENGINE',
      'subject': {'kind': 'INSTRUMENT_SERIES', 'instrumentKey': 'EQUITY:XNAS:TSTA:USD'},
      'instruments': [
        {'assetClass': 'EQUITY', 'symbol': 'TSTA', 'exchangeMic': 'XNAS', 'currency': 'USD'},
      ],
      'period': {'start': '2026-01-05T00:00:00.000Z', 'end': '2026-01-09T00:00:00.000Z', 'bars': 5, 'frequency': 'DAILY'},
      'dataSnapshot': {
        'provenance': {
          'providerId': 'user-csv',
          'providerKind': 'USER_UPLOAD',
          'trust': 'USER_SUPPLIED',
          'retrievedAt': '2026-01-12T12:00:00.000Z',
          'frequency': 'DAILY',
          'currency': 'USD',
          'adjustment': 'UNKNOWN',
        },
        'contentHash': 'a' * 64,
        'freshness': {'state': 'FRESH', 'ageMs': 1, 'asOf': '2026-01-09T00:00:00.000Z', 'evaluatedAt': '2026-01-12T12:00:00.000Z'},
        'calendar': {
          'basis': 'MARKET_CALENDAR',
          'calendar': 'XNAS',
          'calendarStatus': 'SUPPORTED',
          'timezone': 'America/New_York',
          'marketState': 'CLOSED',
          'lastCompletedSession': '2026-01-09',
          'sessionsBehind': 0,
          'missingSessions': 0,
          'nonSessionBars': 0,
          'partialSessionBar': false,
        },
        'evidenceStrength': 'WEAK',
      },
      'metrics': [
        {'id': 'CUMULATIVE_RETURN', 'value': -0.0199, 'unit': 'RATIO', 'formulaId': 'CUMULATIVE_RETURN_V1', 'observations': 5},
        {'id': 'VOLATILITY_PER_PERIOD', 'value': 0.11547005383792515, 'unit': 'RATIO', 'formulaId': 'VOLATILITY_SAMPLE_V1', 'observations': 4},
        {'id': 'MAX_DRAWDOWN', 'value': -0.109, 'unit': 'RATIO', 'formulaId': 'MAX_DRAWDOWN_V1', 'observations': 5},
        {'id': 'SMA_LAST', 'value': 101.97, 'unit': 'PRICE', 'formulaId': 'SMA_V1', 'observations': 3, 'parameters': {'window': 3}},
      ],
      'signals': <dynamic>[],
      'risk': {'coverage': 'FOUNDATION_PARTIAL', 'notImplemented': ['VAR', 'CVAR', 'BETA']},
      'assumptions': [
        {'code': 'PRICE_BASIS', 'value': 'close'},
        {'code': 'MARKET_CALENDAR', 'value': 'XNAS'},
      ],
      'warnings': [
        {'code': 'PROVENANCE_WEAK', 'message': 'provenance does not support strong evidence'},
      ],
      'generatedAt': '2026-01-12T12:00:00.000Z',
    };

class FakeQuantLabApi implements QuantLabApi {
  QuantAnalyzeInput? lastInput;
  QuantAnalyzeOutcome next = QuantAnalyzeOutcome.success(QuantAnalysisView.fromJson(sampleAnalysis()));
  @override
  Future<QuantAnalyzeOutcome> analyze(QuantAnalyzeInput input) async {
    lastInput = input;
    return next;
  }

  @override
  Future<String?> pickCsv() async => null;
}

Profile profile(String role) => Profile(
      id: 'u1',
      role: role,
      monthlyLimit: 10,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Widget app(FakeQuantLabApi api, {Profile? who, Locale locale = const Locale('pt'), double textScale = 1.0}) => ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => who),
        quantLabApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const QuantLabScreen(),
      ),
    );

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // A tap that misses its target must fail the test, never pass silently.
  WidgetController.hitTestWarningShouldBeFatal = true;
  group('request contract', () {
    test('exactly the server contract fields — no user id, plan or role', () {
      final body = const QuantAnalyzeInput(
        assetClass: 'EQUITY',
        symbol: ' tsta ',
        mic: 'XNAS',
        currency: 'USD',
        adjustment: 'UNKNOWN',
        csv: kQuantLabSampleCsv,
        periodsPerYear: 252,
        smaWindows: [2, 3],
      ).toRequestBody();
      expect(body.keys.toSet(), {'contract_version', 'instrument', 'dataset', 'options'});
      expect(body['contract_version'], 'quant.analyze.v1');
      expect((body['instrument'] as Map)['symbol'], 'tsta');
      final flat = body.toString();
      for (final forbidden in ['user_id', 'plan', 'role', 'trust', 'source_as_of', 'url']) {
        expect(flat.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('periods_per_year null is sent explicitly (no silent annualization)', () {
      final body = const QuantAnalyzeInput(
        assetClass: 'ETF', symbol: 'X', mic: null, currency: 'GBP', adjustment: 'UNADJUSTED', csv: 'x', periodsPerYear: null,
      ).toRequestBody();
      expect((body['options'] as Map).containsKey('periods_per_year'), isTrue);
      expect((body['options'] as Map)['periods_per_year'], isNull);
      expect((body['instrument'] as Map).containsKey('exchange_mic'), isFalse);
    });

    test('SMA window parsing', () {
      expect(parseSmaWindows('20, 50'), [20, 50]);
      expect(parseSmaWindows(''), <int>[]);
      expect(parseSmaWindows('20, x'), isNull);
      expect(parseSmaWindows('0'), isNull);
    });
  });

  group('response parsing', () {
    test('parses the structured result; display rounding never touches the raw value', () {
      final v = QuantAnalysisView.fromJson(sampleAnalysis());
      expect(v.instrumentLabel, 'EQUITY · TSTA · XNAS · USD');
      expect(v.freshnessState, 'FRESH');
      expect(v.calendarId, 'XNAS');
      expect(v.sessionsBehind, 0);
      expect(v.periodStart, '2026-01-05');
      final vol = v.metrics.firstWhere((m) => m.id == 'VOLATILITY_PER_PERIOD');
      expect(vol.value, 0.11547005383792515);
      expect(vol.display('USD'), '11.55%');
      expect(v.metrics.firstWhere((m) => m.id == 'SMA_LAST').display('USD'), '101.97 USD');
      expect(v.metrics.firstWhere((m) => m.id == 'CUMULATIVE_RETURN').display('USD'), '-1.99%');
      expect(v.assumptions, contains('MARKET_CALENDAR = XNAS'));
      expect(v.riskNotImplemented, contains('VAR'));
    });

    test('malformed responses only ever throw FormatException (Codex CXN-05)', () {
      Map<String, dynamic> mutate(void Function(Map<String, dynamic>) f) {
        final m = sampleAnalysis();
        f(m);
        return m;
      }
      final cases = [
        mutate((m) => m['instruments'] = <dynamic>[]),
        mutate((m) => (m['period'] as Map)['start'] = '2026'),
        mutate((m) => m['metrics'] = [<String, dynamic>{'id': 'X'}]),
        mutate((m) => m['metrics'] = [42]),
        mutate((m) => m.remove('dataSnapshot')),
        mutate((m) => (m['dataSnapshot'] as Map)['calendar'] = 'nope'),
      ];
      for (final c in cases) {
        expect(() => QuantAnalysisView.fromJson(c), throwsFormatException);
      }
      expect(outcomeFromResponse(200, {'analysis': mutate((m) => m['instruments'] = <dynamic>[])}).errorCode, 'MALFORMED_RESPONSE');
    });

    test('server error codes and malformed bodies map to stable outcomes', () {
      expect(outcomeFromResponse(403, {'error': 'MODULE_NOT_AVAILABLE'}).errorCode, 'MODULE_NOT_AVAILABLE');
      final f = outcomeFromResponse(400, {'error': 'INVALID_PARAMETER', 'details': {'field': 'options.sma_windows'}});
      expect([f.errorCode, f.errorField], ['INVALID_PARAMETER', 'options.sma_windows']);
      expect(outcomeFromResponse(200, {'analysis': {'metrics': 'nope'}}).errorCode, 'MALFORMED_RESPONSE');
      expect(outcomeFromResponse(502, 'gateway down').errorCode, 'HTTP_502');
      expect(outcomeFromResponse(200, {'analysis': sampleAnalysis()}).analysis, isNotNull);
    });
  });

  group('screen', () {
    testWidgets('non-admin sees access denied and never the lab', (tester) async {
      await tester.pumpWidget(app(FakeQuantLabApi(), who: profile('premium')));
      await tester.pumpAndSettle();
      expect(find.text('Você não tem permissão para acessar o Quant Lab.'), findsOneWidget);
      expect(find.byKey(const Key('quantLabAnalyze')), findsNothing);
    });

    testWidgets('missing profile fails closed', (tester) async {
      await tester.pumpWidget(app(FakeQuantLabApi(), who: null));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quantLabAnalyze')), findsNothing);
    });

    testWidgets('admin: sample → analyze → structured result; no execution affordance anywhere', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi();
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze')));
      await tester.pumpAndSettle();
      expect(api.lastInput?.csv, kQuantLabSampleCsv);
      expect(api.lastInput?.smaWindows, [2, 3]);
      expect(find.byKey(const Key('quantLabResult')), findsOneWidget);
      expect(find.text('FRESH'), findsWidgets);
      expect(find.text('11.55%'), findsOneWidget);
      for (final word in ['Comprar', 'Vender', 'Executar', 'Buy', 'Sell', 'Execute', 'corretora conectar', 'Connect broker']) {
        expect(find.textContaining(word, findRichText: true), findsNothing, reason: word);
      }
    });

    testWidgets('server error is shown as a stable code, not a number', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi()..next = const QuantAnalyzeOutcome.failure('DATA_QUALITY_ERROR');
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze')));
      await tester.pumpAndSettle();
      expect(find.textContaining('DATA_QUALITY_ERROR'), findsOneWidget);
    });

    testWidgets('invalid local input is refused before any request', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi();
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze'))); // empty CSV
      await tester.pumpAndSettle();
      expect(api.lastInput, isNull);
      expect(find.text('Preencha símbolo, moeda, CSV e números válidos.'), findsOneWidget);
    });

    for (final locale in const [Locale('pt'), Locale('en')]) {
      testWidgets('text scale 2.0 on a 360px phone renders without overflow (${locale.languageCode})', (tester) async {
        await setSize(tester, const Size(360, 780));
        final api = FakeQuantLabApi();
        await tester.pumpWidget(app(api, who: profile('admin'), locale: locale, textScale: 2.0));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
        await tester.tap(find.byKey(const Key('quantLabAnalyze')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('quantLabResult')), findsOneWidget);
        // Touch target of the primary action.
        expect(tester.getSize(find.byKey(const Key('quantLabAnalyze'))).height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('wide (web/desktop) layout shows form and result side by side', (tester) async {
      await setSize(tester, const Size(1280, 900));
      final api = FakeQuantLabApi();
      await tester.pumpWidget(app(api, who: profile('admin'), locale: const Locale('en')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final form = tester.getTopLeft(find.byKey(const Key('quantLabAnalyze')));
      final result = tester.getTopLeft(find.byKey(const Key('quantLabResult')));
      expect(result.dx, greaterThan(form.dx + 300));
      expect(find.text('Quant Lab (internal)'), findsOneWidget);
    });
  });
}
