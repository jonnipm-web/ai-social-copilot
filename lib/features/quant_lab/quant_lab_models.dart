// IV-QUANT-DATA-PLANE-AND-API-02 — Quant Lab view models.
//
// Pure Dart: builds the versioned `quant.analyze.v1` request and parses the
// server's structured QuantAnalysisResult. The client NEVER computes a
// financial number — every value shown comes from the server engine; this
// file only rounds for DISPLAY (the server's raw value is kept alongside).

/// Asset classes the server can analyze today (Foundation-supported).
const kQuantLabAssetClasses = ['EQUITY', 'ETF', 'INDEX'];

/// Venues with a supported market calendar (others are analyzed calendar-naive).
const kQuantLabMics = ['XNAS', 'XNYS', 'XLON'];

const kQuantLabAdjustments = ['UNKNOWN', 'UNADJUSTED', 'SPLIT_ADJUSTED', 'SPLIT_AND_DIVIDEND_ADJUSTED'];

/// Synthetic sample (the Foundation golden series G1) — not market data.
const kQuantLabSampleCsv = 'date,open,high,low,close,volume\n'
    '2026-01-05,100,101,99,100,1000\n'
    '2026-01-06,110,111,109,110,1000\n'
    '2026-01-07,99,100,98,99,1000\n'
    '2026-01-08,108.9,109.9,107.9,108.9,1000\n'
    '2026-01-09,98.01,99.01,97.01,98.01,1000\n';

class QuantAnalyzeInput {
  const QuantAnalyzeInput({
    required this.assetClass,
    required this.symbol,
    required this.mic,
    required this.currency,
    required this.adjustment,
    required this.csv,
    required this.periodsPerYear,
    this.smaWindows = const [],
  });

  final String assetClass;
  final String symbol;
  final String? mic;
  final String currency;
  final String adjustment;
  final String csv;
  final int? periodsPerYear;
  final List<int> smaWindows;

  /// Exactly the fields of the server contract — no user id, plan or role
  /// (the server rejects unknown fields and derives identity from the JWT).
  Map<String, dynamic> toRequestBody() => {
        'contract_version': 'quant.analyze.v1',
        'instrument': {
          'asset_class': assetClass,
          'symbol': symbol.trim(),
          if (mic != null && mic!.isNotEmpty) 'exchange_mic': mic,
          'currency': currency.trim(),
        },
        'dataset': {'format': 'csv', 'frequency': 'DAILY', 'adjustment': adjustment, 'csv': csv},
        'options': {
          'periods_per_year': periodsPerYear,
          if (smaWindows.isNotEmpty) 'sma_windows': smaWindows,
        },
      };
}

/// Parses "20, 50" → [20, 50]; returns null when any token is not a positive integer.
List<int>? parseSmaWindows(String raw) {
  final parts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final out = <int>[];
  for (final p in parts) {
    final v = int.tryParse(p);
    if (v == null || v < 1) return null;
    out.add(v);
  }
  return out;
}

class QuantMetricView {
  const QuantMetricView({
    required this.id,
    required this.value,
    required this.unit,
    required this.formulaId,
    required this.observations,
    this.window,
  });

  final String id;
  final double? value;
  final String unit;
  final String formulaId;
  final int observations;
  final int? window;

  /// Display only: ratios as %, prices with 2 decimals. Raw [value] is untouched.
  String display(String currency) {
    final v = value;
    if (v == null || v.isNaN || v.isInfinite) return 'n/a';
    if (unit == 'PRICE') return '${v.toStringAsFixed(2)} $currency';
    if (id == 'SHARPE_RATIO') return v.toStringAsFixed(2);
    final pct = (v * 100).toStringAsFixed(2);
    return '${pct == '-0.00' ? '0.00' : pct}%';
  }
}

class QuantWarningView {
  const QuantWarningView(this.code, this.message);
  final String code;
  final String message;
}

class QuantAnalysisView {
  const QuantAnalysisView({
    required this.analysisId,
    required this.engineVersion,
    required this.instrumentLabel,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.bars,
    required this.frequency,
    required this.providerId,
    required this.trust,
    required this.adjustment,
    required this.retrievedAt,
    required this.evidenceStrength,
    required this.freshnessState,
    required this.freshnessAsOf,
    required this.calendarBasis,
    required this.calendarId,
    required this.marketState,
    required this.sessionsBehind,
    required this.contentHash,
    required this.metrics,
    required this.assumptions,
    required this.warnings,
    required this.riskNotImplemented,
    required this.signals,
  });

  final String analysisId;
  final String engineVersion;
  final String instrumentLabel;
  final String currency;
  final String periodStart;
  final String periodEnd;
  final int bars;
  final String frequency;
  final String providerId;
  final String trust;
  final String adjustment;
  final String retrievedAt;
  final String evidenceStrength;
  final String freshnessState;
  final String? freshnessAsOf;
  final String calendarBasis;
  final String? calendarId;
  final String? marketState;
  final int? sessionsBehind;
  final String contentHash;
  final List<QuantMetricView> metrics;
  final List<String> assumptions;
  final List<QuantWarningView> warnings;
  final List<String> riskNotImplemented;
  final List<String> signals;

  /// Parses `response.analysis`. Throws [FormatException] — and only
  /// FormatException — on any shape mismatch (Codex CXN-05), so a malformed
  /// response can never render as partial numbers or crash the screen.
  factory QuantAnalysisView.fromJson(Map<String, dynamic> json) {
    try {
      return QuantAnalysisView._parse(json);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('quant-analyze: malformed response (${e.runtimeType})');
    }
  }

  static final _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}');

  static String _day(String iso) {
    if (!_isoDay.hasMatch(iso)) throw FormatException('quant-analyze: bad date $iso');
    return iso.substring(0, 10);
  }

  static QuantAnalysisView _parse(Map<String, dynamic> json) {
    T req<T>(Map<String, dynamic> m, String k) {
      final v = m[k];
      if (v is! T) throw FormatException('quant-analyze: unexpected field $k');
      return v;
    }

    Map<String, dynamic> obj(Map<String, dynamic> m, String k) => Map<String, dynamic>.from(req<Map>(m, k));
    final instruments = req<List>(json, 'instruments');
    if (instruments.isEmpty) throw const FormatException('quant-analyze: no instrument');
    final instrument = Map<String, dynamic>.from(instruments.first as Map);
    final period = obj(json, 'period');
    final snap = obj(json, 'dataSnapshot');
    final prov = obj(snap, 'provenance');
    final fresh = obj(snap, 'freshness');
    final cal = obj(snap, 'calendar');
    final risk = json['risk'] is Map ? Map<String, dynamic>.from(json['risk'] as Map) : null;
    final mic = instrument['exchangeMic'] as String?;
    final currency = req<String>(instrument, 'currency');
    return QuantAnalysisView(
      analysisId: req<String>(json, 'analysisId'),
      engineVersion: req<String>(json, 'engineVersion'),
      instrumentLabel: '${req<String>(instrument, 'assetClass')} · ${req<String>(instrument, 'symbol')}'
          '${mic != null ? ' · $mic' : ''} · $currency',
      currency: currency,
      periodStart: _day(req<String>(period, 'start')),
      periodEnd: _day(req<String>(period, 'end')),
      bars: req<int>(period, 'bars'),
      frequency: req<String>(period, 'frequency'),
      providerId: req<String>(prov, 'providerId'),
      trust: req<String>(prov, 'trust'),
      adjustment: req<String>(prov, 'adjustment'),
      retrievedAt: req<String>(prov, 'retrievedAt'),
      evidenceStrength: req<String>(snap, 'evidenceStrength'),
      freshnessState: req<String>(fresh, 'state'),
      freshnessAsOf: fresh['asOf'] as String?,
      calendarBasis: req<String>(cal, 'basis'),
      calendarId: cal['calendar'] as String?,
      marketState: cal['marketState'] as String?,
      sessionsBehind: cal['sessionsBehind'] as int?,
      contentHash: req<String>(snap, 'contentHash'),
      metrics: [
        for (final m in req<List>(json, 'metrics'))
          QuantMetricView(
            id: (m as Map)['id'] as String,
            value: (m['value'] as num?)?.toDouble(),
            unit: m['unit'] as String,
            formulaId: m['formulaId'] as String,
            observations: (m['observations'] as num).toInt(),
            window: ((m['parameters'] as Map?)?['window'] as num?)?.toInt(),
          ),
      ],
      assumptions: [
        for (final a in req<List>(json, 'assumptions')) '${(a as Map)['code']}${a['value'] != null ? ' = ${a['value']}' : ''}',
      ],
      warnings: [
        for (final w in req<List>(json, 'warnings')) QuantWarningView((w as Map)['code'] as String, w['message'] as String? ?? ''),
      ],
      riskNotImplemented: [for (final r in (risk?['notImplemented'] as List? ?? const [])) r as String],
      signals: [for (final s in req<List>(json, 'signals')) (s as Map)['description'] as String],
    );
  }
}

/// Outcome of one lab analysis: a parsed result OR a stable server error code.
class QuantAnalyzeOutcome {
  const QuantAnalyzeOutcome.success(QuantAnalysisView this.analysis)
      : errorCode = null,
        errorField = null;
  const QuantAnalyzeOutcome.failure(String this.errorCode, {this.errorField}) : analysis = null;

  final QuantAnalysisView? analysis;
  final String? errorCode;
  final String? errorField;
}

// ---------------------------------------------------------------- READINESS-03: watchlists + multi-series

const kWatchlistsContract = 'quant.watchlists.v1';

/// Server bound: at most 10 instruments per multi-series analysis.
const kQuantMaxSeriesPerAnalysis = 10;

/// quant.analyze.watchlist.v1 — only ids travel; the server reads the
/// instruments from the caller's own watchlist and the data from its own
/// provider (the client can supply neither).
Map<String, dynamic> watchlistAnalysisBody(String watchlistId, List<String> itemIds) => {
      'contract_version': 'quant.analyze.watchlist.v1',
      'watchlist_id': watchlistId,
      if (itemIds.isNotEmpty) 'item_ids': itemIds,
      'data_source': 'SYNTHETIC_PROVIDER',
      'options': {'periods_per_year': 252},
    };

class QuantWatchlistItemView {
  const QuantWatchlistItemView({required this.id, required this.label});
  final String id;
  final String label;
}

class QuantWatchlistView {
  const QuantWatchlistView({required this.id, required this.name, required this.items});
  final String id;
  final String name;
  final List<QuantWatchlistItemView> items;

  factory QuantWatchlistView.fromJson(Map<String, dynamic> j) {
    String s(Map m, String k) {
      final v = m[k];
      if (v is! String) throw FormatException('quant-watchlists: unexpected field $k');
      return v;
    }

    return QuantWatchlistView(
      id: s(j, 'id'),
      name: s(j, 'name'),
      items: [
        for (final it in (j['items'] as List? ?? const []))
          QuantWatchlistItemView(
            id: s(it as Map, 'id'),
            label: '${s(it, 'symbol')}${it['exchange_mic'] is String ? ' · ${it['exchange_mic']}' : ''} · ${s(it, 'currency')}',
          ),
      ],
    );
  }
}

class QuantWatchlistsOutcome {
  const QuantWatchlistsOutcome.success(List<QuantWatchlistView> this.watchlists) : errorCode = null;
  const QuantWatchlistsOutcome.failure(String this.errorCode) : watchlists = null;
  final List<QuantWatchlistView>? watchlists;
  final String? errorCode;
}

class QuantActionOutcome {
  const QuantActionOutcome(this.errorCode, {this.reason});
  final String? errorCode;
  final String? reason;
  bool get ok => errorCode == null;
}

class QuantSeriesSummaryView {
  const QuantSeriesSummaryView({
    required this.label,
    required this.alignedReturn,
    required this.dropped,
    required this.freshnessState,
    required this.trust,
    required this.providerId,
    required this.bars,
  });
  final String label;
  final double alignedReturn;
  final int dropped;
  final String freshnessState;
  final String trust;
  final String providerId;
  final int bars;
}

class QuantCorrelationView {
  const QuantCorrelationView(this.a, this.b, this.value, this.observations, this.error);
  final String a;
  final String b;
  final double? value;
  final int observations;
  final String? error;
}

class QuantMultiView {
  const QuantMultiView({
    required this.id,
    required this.series,
    required this.alignmentPolicy,
    required this.alignmentStart,
    required this.alignmentEnd,
    required this.commonBars,
    required this.correlation,
    required this.warnings,
    required this.assumptions,
    this.portfolioReturn,
    this.dataSourceKind,
    this.cacheHits,
    this.cacheMisses,
  });

  final String id;
  final List<QuantSeriesSummaryView> series;
  final String alignmentPolicy;
  final String? alignmentStart;
  final String? alignmentEnd;
  final int commonBars;
  final List<QuantCorrelationView> correlation;
  final List<QuantWarningView> warnings;
  final List<String> assumptions;
  final double? portfolioReturn;
  final String? dataSourceKind;
  final int? cacheHits;
  final int? cacheMisses;

  /// Throws [FormatException] (only) on any shape mismatch.
  factory QuantMultiView.fromJson(Map<String, dynamic> json) {
    try {
      return QuantMultiView._parse(json);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('quant-analyze: malformed multi response (${e.runtimeType})');
    }
  }

  /// Correlation cells reference series by their canonical instrument key.
  /// The label comes from the series' OWN instrument in the same response —
  /// the key layout is a server detail and is never parsed here (physical
  /// finding S25: guessing the layout labelled pairs by exchange, "XNAS × XNYS").
  /// Symbols repeated across venues are disambiguated with the venue.
  static Map<String, String> _labelsByKey(List series) {
    final symbols = <String, int>{};
    for (final s in series) {
      final sym = ((s as Map)['instrument'] as Map?)?['symbol'];
      if (sym is String) symbols[sym] = (symbols[sym] ?? 0) + 1;
    }
    return {
      for (final s in series)
        if ((s as Map)['instrumentKey'] is String && (s['instrument'] as Map?)?['symbol'] is String)
          s['instrumentKey'] as String: () {
            final inst = s['instrument'] as Map;
            final sym = inst['symbol'] as String;
            final mic = inst['exchangeMic'];
            return symbols[sym]! > 1 && mic is String ? '$sym ($mic)' : sym;
          }(),
    };
  }

  static QuantMultiView _parse(Map<String, dynamic> json) {
    T req<T>(Map m, String k) {
      final v = m[k];
      if (v is! T) throw FormatException('quant-analyze: unexpected field $k');
      return v;
    }

    final alignment = req<Map>(json, 'alignment');
    final ds = json['dataSource'] is Map ? json['dataSource'] as Map : null;
    final cache = ds?['cache'] is Map ? ds!['cache'] as Map : null;
    final portfolio = json['portfolio'] is Map ? json['portfolio'] as Map : null;
    String? day(Object? v) => v is String && v.length >= 10 ? v.substring(0, 10) : null;
    final labels = _labelsByKey(req<List>(json, 'series'));
    String label(String key) => labels[key] ?? key;
    return QuantMultiView(
      id: req<String>(json, 'multiAnalysisId'),
      series: [
        for (final s in req<List>(json, 'series'))
          () {
            final a = req<Map>(s as Map, 'analysis');
            final snap = req<Map>(a, 'dataSnapshot');
            final prov = req<Map>(snap, 'provenance');
            final inst = req<Map>(s, 'instrument');
            return QuantSeriesSummaryView(
              label: '${req<String>(inst, 'symbol')}${inst['exchangeMic'] is String ? ' · ${inst['exchangeMic']}' : ''} · ${req<String>(inst, 'currency')}',
              alignedReturn: req<num>(s, 'alignedCumulativeReturn').toDouble(),
              dropped: req<int>(s, 'droppedFromAlignment'),
              freshnessState: req<String>(req<Map>(snap, 'freshness'), 'state'),
              trust: req<String>(prov, 'trust'),
              providerId: req<String>(prov, 'providerId'),
              bars: req<int>(req<Map>(a, 'period'), 'bars'),
            );
          }(),
      ],
      alignmentPolicy: req<String>(alignment, 'policy'),
      alignmentStart: day(alignment['start']),
      alignmentEnd: day(alignment['end']),
      commonBars: req<int>(alignment, 'commonBars'),
      correlation: [
        for (final c in req<List>(json, 'correlation'))
          QuantCorrelationView(
            label(req<String>(c as Map, 'a')),
            label(req<String>(c, 'b')),
            (c['correlation'] as num?)?.toDouble(),
            req<int>(c, 'observations'),
            c['error'] as String?,
          ),
      ],
      warnings: [
        for (final w in req<List>(json, 'warnings')) QuantWarningView((w as Map)['code'] as String, w['message'] as String? ?? ''),
      ],
      assumptions: [
        for (final a in req<List>(json, 'assumptions')) '${(a as Map)['code']}${a['value'] != null ? ' = ${a['value']}' : ''}',
      ],
      portfolioReturn: (portfolio?['buyAndHoldReturn'] as num?)?.toDouble(),
      dataSourceKind: ds?['kind'] as String?,
      cacheHits: cache?['hits'] as int?,
      cacheMisses: cache?['misses'] as int?,
    );
  }
}

class QuantMultiOutcome {
  const QuantMultiOutcome.success(QuantMultiView this.result)
      : errorCode = null,
        errorField = null;
  const QuantMultiOutcome.failure(String this.errorCode, {this.errorField}) : result = null;
  final QuantMultiView? result;
  final String? errorCode;
  final String? errorField;
}

/// Display only: ratio → "12.34%"; correlation → "0.87"; null → "n/a".
String quantPct(double? v) {
  if (v == null || v.isNaN || v.isInfinite) return 'n/a';
  final s = (v * 100).toStringAsFixed(2);
  return '${s == '-0.00' ? '0.00' : s}%';
}

String quantCorr(double? v) {
  if (v == null || v.isNaN || v.isInfinite) return 'n/a';
  final s = v.toStringAsFixed(2);
  return s == '-0.00' ? '0.00' : s;
}
