// INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 — Strategy Builder transport.
//
// Calls the server-side `strategy-builder` Edge Function (JWT attached from
// the current session). The server (strategy_spec.ts's
// createStrategySpecification) is the ONLY validation authority -- this
// file never re-validates a spec client-side, it only shapes form state
// into the JSON contract and reports back whatever the server said.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw transport result: HTTP-ish status + decoded body, or a network
/// failure represented as status 0.
class StrategyBuilderResult {
  const StrategyBuilderResult(this.status, this.data);
  final int status;
  final Map<String, dynamic>? data;

  bool get ok => status == 200 && data?['valid'] != false;
  String? get errorCode => data?['error'] is Map ? (data!['error']['code'] as String?) : data?['error'] as String?;

  /// Only meaningful when [errorCode] is `PLAN_UPGRADE_REQUIRED` -- the
  /// server's own structured denial (strategy-builder/index.ts's
  /// errorResponse extra fields), never re-derived client-side (§13).
  bool get isPlanUpgradeRequired => errorCode == 'PLAN_UPGRADE_REQUIRED';
  String? get requiredPlan => data?['requiredPlan'] as String?;
  String? get currentPlan => data?['currentPlan'] as String?;
}

abstract class StrategyBuilderApi {
  Future<StrategyBuilderResult> validate(Map<String, dynamic> spec);
  Future<StrategyBuilderResult> draftFromText(String text);
  Future<StrategyBuilderResult> create(Map<String, dynamic> spec, {String? idempotencyKey});
  Future<StrategyBuilderResult> list();
  Future<StrategyBuilderResult> get(String strategyId);
  Future<StrategyBuilderResult> createVersion(String strategyId, Map<String, dynamic> spec);
  Future<StrategyBuilderResult> listVersions(String strategyId);
  Future<StrategyBuilderResult> runBacktest(String strategyVersionId, String datasetId, String engineId, {Map<String, dynamic>? costConfig});
  Future<StrategyBuilderResult> compareVersions(String versionAId, String versionBId, {String? objective});
  Future<StrategyBuilderResult> cloneReference(String reference, {String? idempotencyKey});
  Future<StrategyBuilderResult> engineStatus();
  Future<StrategyBuilderResult> proposeVariants(String strategyVersionId, String datasetId);
  Future<StrategyBuilderResult> runResearchLoop(String strategyVersionId, String datasetId);
  Future<StrategyBuilderResult> runSimulation(String strategyVersionId, String datasetId);
  Future<StrategyBuilderResult> listExperiments(String strategyId);
  Future<StrategyBuilderResult> recordExperiment({
    required String strategyVersionId,
    required String category,
    required String datasetId,
    required String segment,
    required String reason,
    String? resultId,
    required String source,
  });
}

class SupabaseStrategyBuilderApi implements StrategyBuilderApi {
  SupabaseStrategyBuilderApi(this._client);
  final SupabaseClient _client;

  Future<StrategyBuilderResult> _call(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('strategy-builder', body: body);
      return StrategyBuilderResult(res.status, _asMap(res.data));
    } on FunctionException catch (e) {
      return StrategyBuilderResult(e.status, _asMap(e.details));
    } catch (_) {
      return const StrategyBuilderResult(0, {'error': 'NETWORK_ERROR'});
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  Future<StrategyBuilderResult> validate(Map<String, dynamic> spec) => _call({'op': 'validate', 'spec': spec});
  @override
  Future<StrategyBuilderResult> draftFromText(String text) => _call({'op': 'draft_from_text', 'text': text});
  @override
  Future<StrategyBuilderResult> create(Map<String, dynamic> spec, {String? idempotencyKey}) =>
      _call({'op': 'create', 'spec': spec, if (idempotencyKey != null) 'idempotencyKey': idempotencyKey});
  @override
  Future<StrategyBuilderResult> list() => _call({'op': 'list'});
  @override
  Future<StrategyBuilderResult> get(String strategyId) => _call({'op': 'get', 'strategyId': strategyId});
  @override
  Future<StrategyBuilderResult> createVersion(String strategyId, Map<String, dynamic> spec) =>
      _call({'op': 'create_version', 'strategyId': strategyId, 'spec': spec});
  @override
  Future<StrategyBuilderResult> listVersions(String strategyId) => _call({'op': 'list_versions', 'strategyId': strategyId});
  @override
  Future<StrategyBuilderResult> runBacktest(String strategyVersionId, String datasetId, String engineId, {Map<String, dynamic>? costConfig}) => _call({
        'op': 'run_backtest', 'strategyVersionId': strategyVersionId, 'datasetId': datasetId, 'engineId': engineId,
        'costConfig': costConfig,
      });
  @override
  Future<StrategyBuilderResult> compareVersions(String versionAId, String versionBId, {String? objective}) =>
      _call({'op': 'compare_versions', 'versionAId': versionAId, 'versionBId': versionBId, if (objective != null) 'objective': objective});
  @override
  Future<StrategyBuilderResult> cloneReference(String reference, {String? idempotencyKey}) =>
      _call({'op': 'clone_reference', 'reference': reference, if (idempotencyKey != null) 'idempotencyKey': idempotencyKey});
  @override
  Future<StrategyBuilderResult> engineStatus() => _call({'op': 'engine_status'});
  @override
  Future<StrategyBuilderResult> proposeVariants(String strategyVersionId, String datasetId) =>
      _call({'op': 'propose_variants', 'strategyVersionId': strategyVersionId, 'datasetId': datasetId});
  @override
  Future<StrategyBuilderResult> runResearchLoop(String strategyVersionId, String datasetId) =>
      _call({'op': 'run_research_loop', 'strategyVersionId': strategyVersionId, 'datasetId': datasetId});
  @override
  Future<StrategyBuilderResult> runSimulation(String strategyVersionId, String datasetId) =>
      _call({'op': 'run_simulation', 'strategyVersionId': strategyVersionId, 'datasetId': datasetId});
  @override
  Future<StrategyBuilderResult> listExperiments(String strategyId) => _call({'op': 'list_experiments', 'strategyId': strategyId});
  @override
  Future<StrategyBuilderResult> recordExperiment({
    required String strategyVersionId,
    required String category,
    required String datasetId,
    required String segment,
    required String reason,
    String? resultId,
    required String source,
  }) =>
      _call({
        'op': 'record_experiment', 'strategyVersionId': strategyVersionId, 'category': category, 'datasetId': datasetId,
        'segment': segment, 'parametersChanged': null, 'reason': reason, 'resultId': resultId, 'source': source,
      });
}

final strategyBuilderApiProvider = Provider<StrategyBuilderApi>((ref) => SupabaseStrategyBuilderApi(Supabase.instance.client));

/// Builds the exact JSON contract strategy_spec.ts's
/// StrategySpecificationInput expects, from structured form state. This is
/// the ONE place form state becomes a spec -- the summary widget and the
/// save action both go through it, so there is no second source of truth
/// (§8: "The summary must be generated from the canonical Strategy
/// Specification. No second source of truth.").
Map<String, dynamic> buildStrategySpecInput({
  required String name,
  required String description,
  required bool useV10Entry,
  required List<String> allowedDirections,
  required double stopDistance,
  required double targetDistance,
  required bool breakEvenEnabled,
  required double breakEvenTrigger,
  required double breakEvenInitial,
  required double breakEvenStep,
  required String sessionStart,
  required String sessionEnd,
  required String forcedExitTime,
  required int quantity,
}) {
  final marketProfile = useV10Entry
      ? {
          'instrument': {'assetClass': 'FUTURE', 'symbol': 'WIN1!', 'currency': 'BRL', 'exchangeTimezone': 'America/Sao_Paulo'},
          'tickSize': 5.0, 'tickValue': 1.0, 'contractMultiplier': 0.20,
          'timezone': 'America/Sao_Paulo', 'sessionCalendarId': 'b3-win-2026', 'availableTimeframes': ['5min'],
        }
      : {
          'instrument': {'assetClass': 'INDEX', 'symbol': 'SYNTH1', 'currency': 'USD', 'exchangeTimezone': 'UTC'},
          'tickSize': 1.0, 'tickValue': 1.0, 'contractMultiplier': 1.0,
          'timezone': 'UTC', 'sessionCalendarId': 'synthetic-fixture', 'availableTimeframes': ['5min'],
        };
  return {
    'name': name,
    'description': description,
    'marketProfile': marketProfile,
    'signalTimeframe': '5min',
    'executionTimeframe': null,
    'allowedDirections': allowedDirections,
    'allowReversals': false,
    'entry': {'ruleId': useV10Entry ? 'ENTRY.PULLBACK_IN_TREND' : 'ENTRY.SESSION_OPEN'},
    'stop': {'ruleId': 'STOP.FIXED_DISTANCE', 'distance': stopDistance},
    'target': {'ruleId': 'TARGET.FIXED_DISTANCE', 'distance': targetDistance},
    'breakEven': breakEvenEnabled
        ? {
            'ruleId': 'BREAK_EVEN.STEPPED',
            'triggerDistance': breakEvenTrigger,
            'initialProtectedDistance': breakEvenInitial,
            'stepDistance': breakEvenStep,
          }
        : null,
    'trailing': null,
    'session': {'ruleId': 'SESSION.WINDOW', 'startTime': sessionStart, 'endTime': sessionEnd, 'allowedWeekdays': [1, 2, 3, 4, 5]},
    'forcedExit': {'ruleId': 'EXIT.FORCED_TIME', 'time': forcedExitTime},
    'positionSize': {'ruleId': 'POSITION_SIZE.FIXED_CONTRACTS', 'quantity': quantity},
    'riskLimits': null,
  };
}

/// The dataset/engine pair a given entry-rule mode must run against
/// (mirrors engine_registry.ts's allowlist -- kept in lockstep by
/// strategy_builder_contract_test.dart, not re-derived here).
({String datasetId, String engineId}) datasetAndEngineFor({required bool useV10Entry}) => useV10Entry
    ? (datasetId: 'win1-5min-qt01c3', engineId: 'PAULO_TREND_FIBONACCI_V10')
    : (datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE');
