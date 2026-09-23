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

  /// Parses `response.analysis`. Throws [FormatException] on any shape mismatch,
  /// so a malformed response can never render as partial numbers.
  factory QuantAnalysisView.fromJson(Map<String, dynamic> json) {
    T req<T>(Map<String, dynamic> m, String k) {
      final v = m[k];
      if (v is! T) throw FormatException('quant-analyze: unexpected field $k');
      return v;
    }

    Map<String, dynamic> obj(Map<String, dynamic> m, String k) => Map<String, dynamic>.from(req<Map>(m, k));
    final instrument = Map<String, dynamic>.from((req<List>(json, 'instruments')).first as Map);
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
      periodStart: req<String>(period, 'start').substring(0, 10),
      periodEnd: req<String>(period, 'end').substring(0, 10),
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
        for (final a in req<List>(json, 'assumptions'))
          '${(a as Map)['code']}${a['value'] != null ? ' = ${a['value']}' : ''}',
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
  const QuantAnalyzeOutcome.success(QuantAnalysisView this.analysis) : errorCode = null, errorField = null;
  const QuantAnalyzeOutcome.failure(String this.errorCode, {this.errorField}) : analysis = null;

  final QuantAnalysisView? analysis;
  final String? errorCode;
  final String? errorField;
}
