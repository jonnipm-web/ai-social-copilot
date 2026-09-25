// IV-QUANT-DATA-PLANE-AND-API-02 — Quant Lab: request contract, response
// parsing, error mapping, admin gate, no-execution surface, PT/EN, text
// scaling and responsive layout.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;

import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/features/quant_lab/quant_lab_models.dart';
import 'package:ai_social_copilot/features/quant_lab/quant_lab_screen.dart';
import 'package:ai_social_copilot/features/quant_lab/quant_lab_service.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_exclusion_region.dart';

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
        {
          'id': 'SMA_LAST',
          'value': 101.97,
          'unit': 'PRICE',
          'formulaId': 'SMA_V1',
          'observations': 3,
          'parameters': {'window': 3}
        },
      ],
      'signals': <dynamic>[],
      'risk': {
        'coverage': 'FOUNDATION_PARTIAL',
        'notImplemented': ['VAR', 'CVAR', 'BETA']
      },
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

  // ---- READINESS-03 watchlists (in-memory, server-shaped)
  final lists = <QuantWatchlistView>[];
  final actions = <Map<String, dynamic>>[];
  String? lastAnalyzedWatchlist;
  List<String>? lastItemIds;
  QuantMultiOutcome nextMulti = QuantMultiOutcome.success(QuantMultiView.fromJson(sampleMulti()));
  int _n = 0;

  @override
  Future<QuantWatchlistsOutcome> listWatchlists() async => QuantWatchlistsOutcome.success(List.of(lists));

  @override
  Future<QuantActionOutcome> watchlistAction(Map<String, dynamic> action) async {
    actions.add(action);
    switch (action['action']) {
      case 'create':
        lists.add(QuantWatchlistView(id: 'w${++_n}', name: action['name'] as String, items: const []));
      case 'add_item':
        final i = lists.indexWhere((w) => w.id == action['watchlist_id']);
        final inst = action['instrument'] as Map;
        lists[i] = QuantWatchlistView(id: lists[i].id, name: lists[i].name, items: [
          ...lists[i].items,
          QuantWatchlistItemView(id: 'i${++_n}', label: '${inst['symbol']} · ${inst['exchange_mic']} · ${inst['currency']}'),
        ]);
      case 'delete':
        lists.removeWhere((w) => w.id == action['watchlist_id']);
      case 'remove_item':
        final i = lists.indexWhere((w) => w.id == action['watchlist_id']);
        lists[i] = QuantWatchlistView(id: lists[i].id, name: lists[i].name, items: [
          for (final it in lists[i].items)
            if (it.id != action['item_id']) it,
        ]);
    }
    return const QuantActionOutcome(null);
  }

  @override
  Future<QuantMultiOutcome> analyzeWatchlist(String watchlistId, List<String> itemIds) async {
    lastAnalyzedWatchlist = watchlistId;
    lastItemIds = itemIds;
    return nextMulti;
  }
}

class _ThrowingPickApi extends FakeQuantLabApi {
  _ThrowingPickApi(this.fail);
  String? fail;
  @override
  Future<String?> pickCsv() async {
    final f = fail;
    if (f != null) throw QuantLabFileException(f);
    return kQuantLabSampleCsv;
  }
}

/// Shape of a real `quant.analyze.watchlist.v1` 200 `multi_analysis` body.
Map<String, dynamic> sampleMulti() {
  Map<String, dynamic> series(String sym, String mic, double ret) => {
        'instrumentKey': 'EQUITY:$mic:$sym:USD', // server layout: ASSET:MIC:SYMBOL:CCY
        'instrument': {'assetClass': 'EQUITY', 'symbol': sym, 'exchangeMic': mic, 'currency': 'USD'},
        'analysis': {
          ...sampleAnalysis(),
          'dataSnapshot': {
            ...(sampleAnalysis()['dataSnapshot'] as Map),
            'provenance': {
              'providerId': 'synthetic-vendor-v1',
              'providerKind': 'FIXTURE',
              'trust': 'SYNTHETIC_FIXTURE',
              'retrievedAt': '2026-09-23T22:00:00.000Z',
              'frequency': 'DAILY',
              'currency': 'USD',
              'adjustment': 'SPLIT_AND_DIVIDEND_ADJUSTED',
            },
          },
        },
        'droppedFromAlignment': 0,
        'alignedCumulativeReturn': ret,
      };
  return {
    'schemaVersion': 1,
    'multiAnalysisId': 'qm_0123456789abcdef0123456789abcdef',
    'engineVersion': 'quant-foundation-0.2.0',
    'computedBy': 'DETERMINISTIC_ENGINE',
    'series': [series('SYNA', 'XNYS', 0.1234), series('SYNB', 'XNAS', -0.05)],
    'alignment': {
      'policy': 'INTERSECTION_OF_TIMESTAMPS',
      'start': '2025-09-23T00:00:00.000Z',
      'end': '2026-09-23T00:00:00.000Z',
      'commonBars': 250,
      'seriesCount': 2
    },
    'correlation': [
      {'a': 'EQUITY:XNYS:SYNA:USD', 'b': 'EQUITY:XNAS:SYNB:USD', 'correlation': 0.8765, 'observations': 249},
    ],
    'portfolio': null,
    'assumptions': [
      {'code': 'ALIGNMENT', 'value': 'INTERSECTION_OF_TIMESTAMPS'},
      {'code': 'RETURNS_IN_OWN_CURRENCY', 'value': null},
    ],
    'warnings': [
      {'code': 'PROVENANCE_WEAK', 'message': 'provenance does not support strong evidence'},
    ],
    'generatedAt': '2026-09-23T22:00:00.000Z',
    'dataSource': {
      'kind': 'SYNTHETIC_PROVIDER',
      'providerId': 'synthetic-vendor-v1',
      'cache': {'hits': 1, 'misses': 1, 'staleFallbacks': 0, 'uncached': 0},
    },
  };
}

Profile profile(String role) => Profile(
      id: 'u1',
      role: role,
      monthlyLimit: 10,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Widget app(FakeQuantLabApi api, {Profile? who, Locale locale = const Locale('pt'), double textScale = 1.0, StreamController<AuthState>? auth}) => ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => who),
        authStateProvider.overrideWith((ref) => auth?.stream ?? const Stream<AuthState>.empty()),
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
        assetClass: 'ETF',
        symbol: 'X',
        mic: null,
        currency: 'GBP',
        adjustment: 'UNADJUSTED',
        csv: 'x',
        periodsPerYear: null,
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
        mutate((m) => m['metrics'] = [
              <String, dynamic>{'id': 'X'}
            ]),
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
      final f = outcomeFromResponse(400, {
        'error': 'INVALID_PARAMETER',
        'details': {'field': 'options.sma_windows'}
      });
      expect([f.errorCode, f.errorField], ['INVALID_PARAMETER', 'options.sma_windows']);
      expect(
          outcomeFromResponse(200, {
            'analysis': {'metrics': 'nope'}
          }).errorCode,
          'MALFORMED_RESPONSE');
      expect(outcomeFromResponse(502, 'gateway down').errorCode, 'HTTP_502');
      expect(outcomeFromResponse(200, {'analysis': sampleAnalysis()}).analysis, isNotNull);
    });
  });

  group('READINESS-03 transport + file policy', () {
    test('dev base URL is honored only in debug and only for loopback http', () {
      expect(quantDevBaseUrl(define: 'http://127.0.0.1:54321/', debug: true), 'http://127.0.0.1:54321');
      expect(quantDevBaseUrl(define: 'http://localhost:54321', debug: true), 'http://localhost:54321');
      expect(quantDevBaseUrl(define: 'http://127.0.0.1:54321', debug: false), isNull, reason: 'release/profile ignore the override');
      expect(quantDevBaseUrl(define: 'https://evil.example.com', debug: true), isNull);
      expect(quantDevBaseUrl(define: 'http://10.0.2.2:54321', debug: true), isNull);
      expect(quantDevBaseUrl(define: '', debug: true), isNull);
    });

    Uint8List b(List<int> v) => Uint8List.fromList(v);
    Uint8List t(String v) => Uint8List.fromList(utf8.encode(v));
    String codeOf(String? name, Uint8List bytes) {
      try {
        decodeQuantFile(name, bytes);
        return 'SUPPORTED';
      } on QuantLabFileException catch (e) {
        return e.code;
      }
    }

    test('file-type matrix: CSV/TXT supported; spreadsheets/JSON not implemented; PDF/images/other rejected', () {
      expect(codeOf('prices.csv', t(kQuantLabSampleCsv)), 'SUPPORTED');
      expect(codeOf('prices.CSV', t('\uFEFF$kQuantLabSampleCsv')), 'SUPPORTED');
      expect(codeOf('prices.txt', t(kQuantLabSampleCsv)), 'SUPPORTED');
      expect(codeOf('prices', t(kQuantLabSampleCsv)), 'SUPPORTED', reason: 'SAF providers may omit the extension');
      expect(codeOf('prices.xlsx', b([0x50, 0x4B, 0x03, 0x04, 1, 2])), 'FILE_TYPE_NOT_IMPLEMENTED');
      expect(codeOf('prices.ods', b([0x50, 0x4B, 0x03, 0x04, 1, 2])), 'FILE_TYPE_NOT_IMPLEMENTED');
      expect(codeOf('prices.xls', b([0xD0, 0xCF, 0x11, 0xE0, 1, 2])), 'FILE_TYPE_NOT_IMPLEMENTED');
      expect(codeOf('prices.json', t('{"a":1}')), 'FILE_TYPE_NOT_IMPLEMENTED');
      expect(codeOf('prices.csv', t('[{"date":"2026-01-05"}]')), 'FILE_TYPE_NOT_IMPLEMENTED', reason: 'JSON content under a .csv name');
      expect(codeOf('report.pdf', t('%PDF-1.7')), 'FILE_TYPE_NOT_SUPPORTED');
      expect(codeOf('renamed.csv', t('%PDF-1.7 ...')), 'FILE_TYPE_NOT_SUPPORTED', reason: 'a renamed PDF is still refused');
      expect(codeOf('chart.png', b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])), 'FILE_TYPE_NOT_SUPPORTED');
      expect(codeOf('photo.jpg', b([0xFF, 0xD8, 0xFF, 0xE0])), 'FILE_TYPE_NOT_SUPPORTED');
      expect(codeOf('x.csv', b([0x50, 0x4B, 0x03, 0x04])), 'FILE_TYPE_NOT_IMPLEMENTED', reason: 'a renamed XLSX is still detected');
      expect(codeOf('notes.docx', t('hello')), 'FILE_TYPE_NOT_SUPPORTED');
      // Physical finding S25: a real .docx is a ZIP — it must not be reported as a spreadsheet.
      expect(codeOf('notes.docx', b([0x50, 0x4B, 0x03, 0x04, 1, 2])), 'FILE_TYPE_NOT_SUPPORTED');
      expect(codeOf('archive.zip', b([0x50, 0x4B, 0x03, 0x04, 1, 2])), 'FILE_TYPE_NOT_SUPPORTED');
      expect(codeOf('legacy.doc', b([0xD0, 0xCF, 0x11, 0xE0, 1, 2])), 'FILE_TYPE_NOT_SUPPORTED');
      expect(codeOf('prices', b([0x50, 0x4B, 0x03, 0x04, 1, 2])), 'FILE_TYPE_NOT_IMPLEMENTED', reason: 'nameless container → likely spreadsheet');
      expect(codeOf('bin.csv', b([0x64, 0x00, 0x61])), 'FILE_TYPE_NOT_SUPPORTED');
      expect(codeOf('latin1.csv', b([0x64, 0xE9, 0x0A])), 'FILE_UNREADABLE');
      expect(codeOf('big.csv', Uint8List(kQuantLabMaxCsvBytes + 1)), 'FILE_TOO_LARGE');
    });

    test('bounded file read: declared size refused before reading; unknown size cut at the cap (Codex Gate 3 P1)', () async {
      var chunksRead = 0;
      Stream<Uint8List> chunks(int n, int size) async* {
        for (var i = 0; i < n; i++) {
          chunksRead++;
          yield Uint8List(size);
        }
      }

      await expectLater(readBoundedBytes(() async => 10 * 1024 * 1024 * 1024, () => chunks(1, 1), kQuantLabMaxCsvBytes),
          throwsA(isA<QuantLabFileException>().having((e) => e.code, 'code', 'FILE_TOO_LARGE')));
      expect(chunksRead, 0, reason: 'declared size must be refused before opening the stream');
      chunksRead = 0;
      await expectLater(readBoundedBytes(() async => null, () => chunks(1 << 20, 1024 * 1024), kQuantLabMaxCsvBytes),
          throwsA(isA<QuantLabFileException>().having((e) => e.code, 'code', 'FILE_TOO_LARGE')));
      expect(chunksRead, lessThanOrEqualTo(6), reason: 'the stream must be cut right after passing the cap');
      final ok = await readBoundedBytes(() async => kQuantLabMaxCsvBytes, () => chunks(5, 1024 * 1024), kQuantLabMaxCsvBytes);
      expect(ok.length, kQuantLabMaxCsvBytes);
      await expectLater(readBoundedBytes(() async => null, () => Stream<Uint8List>.error(StateError('io')), kQuantLabMaxCsvBytes),
          throwsA(isA<QuantLabFileException>().having((e) => e.code, 'code', 'FILE_UNREADABLE')));
    });

    test('multi response integrity: short hash, duplicate series key, unknown correlation reference → FormatException (Codex Gate 3)', () {
      final shortHash = Map<String, dynamic>.from(sampleAnalysis());
      shortHash['dataSnapshot'] = {...(sampleAnalysis()['dataSnapshot'] as Map), 'contentHash': 'abc'};
      expect(() => QuantAnalysisView.fromJson(shortHash), throwsFormatException);
      final dup = sampleMulti();
      (dup['series'] as List)[1] = <String, dynamic>{
        ...Map<String, dynamic>.from((dup['series'] as List)[1] as Map),
        'instrumentKey': ((dup['series'] as List)[0] as Map)['instrumentKey'],
      };
      expect(() => QuantMultiView.fromJson(dup), throwsFormatException);
      final unknown = sampleMulti();
      unknown['correlation'] = [
        {'a': 'EQUITY:XNYS:SYNA:USD', 'b': 'EQUITY:XNYS:NOPE:USD', 'correlation': 0.1, 'observations': 3},
      ];
      expect(() => QuantMultiView.fromJson(unknown), throwsFormatException);
      expect(multiOutcomeFromResponse(200, {'multi_analysis': unknown}).errorCode, 'MALFORMED_RESPONSE');
    });

    test('watchlist analysis request carries ids only — never instruments, prices or a URL', () {
      final body = watchlistAnalysisBody('w1', ['i1', 'i2']);
      expect(body.keys.toSet(), {'contract_version', 'watchlist_id', 'item_ids', 'data_source', 'options'});
      expect(body['contract_version'], 'quant.analyze.watchlist.v1');
      expect(body['data_source'], 'SYNTHETIC_PROVIDER');
      expect(watchlistAnalysisBody('w1', const []).containsKey('item_ids'), isFalse);
      for (final forbidden in ['instrument', 'symbol', 'url', 'csv', 'user_id', 'role']) {
        expect(body.toString().contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('multi response parses; malformed shape is a FormatException, never partial numbers', () {
      final v = QuantMultiView.fromJson(sampleMulti());
      expect(v.series.length, 2);
      expect(v.correlation.single.a, 'SYNA');
      expect(v.correlation.single.b, 'SYNB');
      // Physical finding S25: two symbols on the SAME venue must not collapse to the venue name.
      final sameVenue = sampleMulti();
      (sameVenue['series'] as List)[1] = <String, dynamic>{
        ...Map<String, dynamic>.from((sameVenue['series'] as List)[1] as Map),
        'instrumentKey': 'EQUITY:XNYS:SYNB:USD',
        'instrument': {'assetClass': 'EQUITY', 'symbol': 'SYNB', 'exchangeMic': 'XNYS', 'currency': 'USD'},
      };
      sameVenue['correlation'] = [
        {'a': 'EQUITY:XNYS:SYNA:USD', 'b': 'EQUITY:XNYS:SYNB:USD', 'correlation': 0.5, 'observations': 10},
      ];
      final sv = QuantMultiView.fromJson(sameVenue);
      expect([sv.correlation.single.a, sv.correlation.single.b], ['SYNA', 'SYNB']);
      // Same symbol on two venues → disambiguated with the venue.
      final dup = sampleMulti();
      (dup['series'] as List)[1] = <String, dynamic>{
        ...Map<String, dynamic>.from((dup['series'] as List)[1] as Map),
        'instrumentKey': 'EQUITY:XLON:SYNA:GBP',
        'instrument': {'assetClass': 'EQUITY', 'symbol': 'SYNA', 'exchangeMic': 'XLON', 'currency': 'GBP'},
      };
      dup['correlation'] = [
        {'a': 'EQUITY:XNYS:SYNA:USD', 'b': 'EQUITY:XLON:SYNA:GBP', 'correlation': 0.1, 'observations': 10},
      ];
      final dv = QuantMultiView.fromJson(dup);
      expect([dv.correlation.single.a, dv.correlation.single.b], ['SYNA (XNYS)', 'SYNA (XLON)']);
      expect(quantCorr(v.correlation.single.value), '0.88');
      expect(quantPct(v.series.first.alignedReturn), '12.34%');
      expect(v.cacheHits, 1);
      final bad = sampleMulti()..remove('alignment');
      expect(() => QuantMultiView.fromJson(bad), throwsFormatException);
      expect(multiOutcomeFromResponse(200, {'multi_analysis': bad}).errorCode, 'MALFORMED_RESPONSE');
      expect(multiOutcomeFromResponse(429, {'error': 'RATE_LIMITED'}).errorCode, 'RATE_LIMITED');
      expect(watchlistsOutcomeFromResponse(403, {'error': 'MODULE_NOT_AVAILABLE'}).errorCode, 'MODULE_NOT_AVAILABLE');
      expect(
          actionOutcomeFromResponse(400, {
            'error': 'INVALID_PARAMETER',
            'details': {'reason': 'DUPLICATE_INSTRUMENT'}
          }).reason,
          'DUPLICATE_INSTRUMENT');
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

    Future<void> openWatchlistTab(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('quantLabTabWatchlist')));
      await tester.pumpAndSettle();
    }

    testWidgets('watchlist tab: create → add → analyze sends ids only and renders the synthetic result', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi();
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      await openWatchlistTab(tester);
      expect(find.text('Nenhuma watchlist ainda.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('quantWatchlistName')), 'Tech');
      await tester.tap(find.byKey(const Key('quantWatchlistCreate')));
      await tester.pumpAndSettle();
      for (final sym in ['SYNA', 'SYNB']) {
        await tester.ensureVisible(find.byKey(const Key('quantWatchlistSymbol')));
        await tester.enterText(find.byKey(const Key('quantWatchlistSymbol')), sym);
        await tester.ensureVisible(find.byKey(const Key('quantWatchlistAdd')));
        await tester.tap(find.byKey(const Key('quantWatchlistAdd')));
        await tester.pumpAndSettle();
      }
      expect(api.actions.map((a) => a['action']), ['create', 'add_item', 'add_item']);
      expect(api.actions.every((a) => !a.containsKey('user_id')), isTrue);
      await tester.ensureVisible(find.byKey(const Key('quantWatchlistAnalyze')));
      await tester.tap(find.byKey(const Key('quantWatchlistAnalyze')));
      await tester.pumpAndSettle();
      expect(api.lastAnalyzedWatchlist, 'w1');
      expect(api.lastItemIds, isEmpty, reason: 'nothing checked → whole list (≤ 10) is analyzed server-side');
      expect(find.byKey(const Key('quantMultiResult')), findsOneWidget);
      expect(find.textContaining('SYNTHETIC_PROVIDER', findRichText: true), findsOneWidget);
      expect(find.textContaining('0.88', findRichText: true), findsOneWidget);
      for (final word in ['Comprar', 'Vender', 'Executar', 'Buy', 'Sell', 'Execute', 'Connect broker']) {
        expect(find.textContaining(word, findRichText: true), findsNothing, reason: word);
      }
    });

    testWidgets('watchlist with > 10 items requires a selection of ≤ 10 before analysis', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi()
        ..lists.add(QuantWatchlistView(id: 'big', name: 'Big', items: [
          for (var i = 0; i < 11; i++) QuantWatchlistItemView(id: 'i$i', label: 'S$i · XNYS · USD'),
        ]));
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      await openWatchlistTab(tester);
      await tester.ensureVisible(find.byKey(const Key('quantWatchlistAnalyze')));
      expect(tester.widget<FilledButton>(find.byKey(const Key('quantWatchlistAnalyze'))).onPressed, isNull);
      await tester.ensureVisible(find.byKey(const Key('quantWatchlistItem_i0')));
      await tester.tap(find.byKey(const Key('quantWatchlistItem_i0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantWatchlistAnalyze')));
      await tester.tap(find.byKey(const Key('quantWatchlistAnalyze')));
      await tester.pumpAndSettle();
      expect(api.lastItemIds, ['i0']);
    });

    for (final locale in const [Locale('pt'), Locale('en')]) {
      testWidgets('watchlist tab at text scale 2.0 on 360px renders without overflow (${locale.languageCode})', (tester) async {
        await setSize(tester, const Size(360, 780));
        final api = FakeQuantLabApi()
          ..lists.add(const QuantWatchlistView(id: 'w', name: 'Carteira de observação longa', items: [
            QuantWatchlistItemView(id: 'a', label: 'SYNA · XNYS · USD'),
            QuantWatchlistItemView(id: 'b', label: 'SYNB · XNAS · USD'),
          ]));
        await tester.pumpWidget(app(api, who: profile('admin'), locale: locale, textScale: 2.0));
        await tester.pumpAndSettle();
        await openWatchlistTab(tester);
        await tester.ensureVisible(find.byKey(const Key('quantWatchlistAnalyze')));
        await tester.tap(find.byKey(const Key('quantWatchlistAnalyze')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('quantMultiResult')), findsOneWidget);
        expect(tester.getSize(find.byKey(const Key('quantWatchlistAnalyze'))).height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('profile refresh on app resume keeps the lab mounted (form, result, error state)', (tester) async {
      // Physical finding S25: returning from the Android file picker re-fetches
      // the profile (profile_resume_policy); the lab used to unmount into a spinner.
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi();
      var fetches = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          // First fetch immediate; refreshes take network time, like on the device.
          authStateProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
          currentProfileProvider.overrideWith((ref) async {
            if (fetches++ > 0) await Future<void>.delayed(const Duration(seconds: 1));
            return profile('admin');
          }),
          quantLabApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const QuantLabScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(QuantLabScreen)));
      container.invalidate(currentProfileProvider);
      await tester.pump(const Duration(milliseconds: 100)); // refresh in flight
      expect(fetches, 2);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('quantLabResult')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2)); // refresh completes
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quantLabResult')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('quantLabCsv'))).controller!.text, kQuantLabSampleCsv);
    });

    testWidgets('a refresh that returns a non-admin profile still denies (fail closed)', (tester) async {
      Profile? who = profile('admin');
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => who),
          authStateProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
          quantLabApiProvider.overrideWithValue(FakeQuantLabApi()),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const QuantLabScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quantLabAnalyze')), findsOneWidget);
      who = profile('premium');
      ProviderScope.containerOf(tester.element(find.byType(QuantLabScreen))).invalidate(currentProfileProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quantLabAnalyze')), findsNothing);
      expect(find.text('Você não tem permissão para acessar o Quant Lab.'), findsOneWidget);
    });

    testWidgets('loading the sample clears a previous file error', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = _ThrowingPickApi('FILE_TYPE_NOT_IMPLEMENTED');
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabPick')));
      await tester.tap(find.byKey(const Key('quantLabPick')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Planilhas'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Planilhas'), findsNothing);
      api.fail = null; // next pick succeeds
      await tester.ensureVisible(find.byKey(const Key('quantLabPick')));
      await tester.tap(find.byKey(const Key('quantLabPick')));
      await tester.pumpAndSettle();
      api.fail = 'FILE_TYPE_NOT_SUPPORTED';
      await tester.tap(find.byKey(const Key('quantLabPick')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tipo de arquivo não suportado'), findsOneWidget);
      api.fail = null;
      await tester.tap(find.byKey(const Key('quantLabPick')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tipo de arquivo não suportado'), findsNothing, reason: 'a successful import clears the old error');
    });

    testWidgets('essential actions and key metrics are IVE exclusion regions (S25: avatar covered them)', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi()
        ..lists.add(const QuantWatchlistView(id: 'w', name: 'W', items: [QuantWatchlistItemView(id: 'a', label: 'SYNA · XNYS · USD')]));
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      Finder protectedBy(Finder f) => find.ancestor(of: f, matching: find.byType(IveExclusionRegion));
      expect(protectedBy(find.byKey(const Key('quantLabAnalyze'))), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze')));
      await tester.pumpAndSettle();
      expect(protectedBy(find.text('11.55%')), findsOneWidget, reason: 'metric value');
      await tester.tap(find.byKey(const Key('quantLabTabWatchlist')));
      await tester.pumpAndSettle();
      expect(protectedBy(find.byTooltip('Excluir watchlist')), findsOneWidget);
      expect(protectedBy(find.byTooltip('Remover')), findsOneWidget);
      expect(protectedBy(find.byKey(const Key('quantWatchlistAnalyze'))), findsOneWidget);
    });

    testWidgets('explicit sign-out closes the lab immediately and discards the shown result (Codex Gate 3 P1)', (tester) async {
      await setSize(tester, const Size(420, 900));
      final auth = StreamController<AuthState>();
      addTearDown(auth.close);
      final api = FakeQuantLabApi();
      await tester.pumpWidget(app(api, who: profile('admin'), auth: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quantLabResult')), findsOneWidget);
      auth.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quantLabAnalyze')), findsNothing);
      expect(find.byKey(const Key('quantLabResult')), findsNothing);
      expect(find.text('Você não tem permissão para acessar o Quant Lab.'), findsOneWidget);
    });

    testWidgets('watchlist mutation or selection change clears the previous analysis (Codex Gate 3)', (tester) async {
      await setSize(tester, const Size(420, 900));
      final api = FakeQuantLabApi()
        ..lists.add(const QuantWatchlistView(id: 'w', name: 'W', items: [
          QuantWatchlistItemView(id: 'a', label: 'SYNA · XNYS · USD'),
          QuantWatchlistItemView(id: 'b', label: 'SYNB · XNAS · USD'),
        ]));
      await tester.pumpWidget(app(api, who: profile('admin')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quantLabTabWatchlist')));
      await tester.pumpAndSettle();
      Future<void> analyze() async {
        await tester.ensureVisible(find.byKey(const Key('quantWatchlistAnalyze')));
        await tester.tap(find.byKey(const Key('quantWatchlistAnalyze')));
        await tester.pumpAndSettle();
      }

      await analyze();
      expect(find.byKey(const Key('quantMultiResult')), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remover').first);
      await tester.tap(find.byTooltip('Remover').first);
      await tester.pumpAndSettle();
      expect(api.actions.last['action'], 'remove_item');
      expect(find.byKey(const Key('quantMultiResult')), findsNothing);
      await analyze();
      expect(find.byKey(const Key('quantMultiResult')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('quantWatchlistItem_b')));
      await tester.tap(find.byKey(const Key('quantWatchlistItem_b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quantMultiResult')), findsNothing);
    });

    testWidgets('PT result shows localized technical labels (Codex Gate 3)', (tester) async {
      await setSize(tester, const Size(420, 900));
      await tester.pumpWidget(app(FakeQuantLabApi(), who: profile('admin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabSample')));
      await tester.tap(find.byKey(const Key('quantLabSample')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quantLabAnalyze')));
      await tester.tap(find.byKey(const Key('quantLabAnalyze')));
      await tester.pumpAndSettle();
      for (final pt in ['Fornecedor: ', 'Nível de confiança: ', 'Hash do conteúdo: ', 'Motor: ', 'Referente a: ']) {
        expect(find.textContaining(pt, findRichText: true), findsWidgets, reason: pt);
      }
      for (final en in ['provider: ', 'trust: ', 'contentHash: ', 'engine: ', 'as of: ']) {
        expect(find.textContaining(en, findRichText: true), findsNothing, reason: en);
      }
    });

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
