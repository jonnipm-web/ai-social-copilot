import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/aef_runtime.dart';

/// IV-IVE-AEF-RUNTIME-INTEGRATION-01 — LAB client of the `aef-runtime`
/// function. Sends only {op, intent|gate|operationId}; the server derives
/// the subject from the session JWT. Every failure becomes a denied result
/// (never a guessed state); nothing is retried automatically.
abstract class AefRuntimeApi {
  Future<AefRuntimeResult> propose(Map<String, dynamic> proposal);
  Future<AefRuntimeResult> execute(Map<String, dynamic> proposal);
  Future<AefRuntimeResult> decide(AefGate gate, {required bool approve});
  Future<AefRuntimeResult> status(String operationId);
}

class AefRuntimeService implements AefRuntimeApi {
  static const functionName = 'aef-runtime';
  SupabaseClient get _client => Supabase.instance.client;

  Future<AefRuntimeResult> _call(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final data = res.data;
      if (data is Map && data['result'] != null) return AefRuntimeResult.fromMap(data['result']);
      return AefRuntimeResult.unreadable;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['result'] != null) return AefRuntimeResult.fromMap(details['result']);
      final code = details is Map && details['error'] is String ? details['error'] as String : 'UNAVAILABLE';
      return AefRuntimeResult.denied(code);
    } catch (_) {
      return AefRuntimeResult.denied('NETWORK_INTERRUPTED');
    }
  }

  @override
  Future<AefRuntimeResult> propose(Map<String, dynamic> proposal) => _call({'op': 'propose', 'intent': proposal});

  @override
  Future<AefRuntimeResult> execute(Map<String, dynamic> proposal) => _call({'op': 'execute', 'intent': proposal});

  @override
  Future<AefRuntimeResult> decide(AefGate gate, {required bool approve}) => _call({
        'op': 'decide',
        'gate': {'gateId': gate.gateId, 'decision': approve ? 'APPROVE' : 'REJECT', 'bindingHash': gate.bindingHash},
      });

  @override
  Future<AefRuntimeResult> status(String operationId) => _call({'op': 'status', 'operationId': operationId});
}

/// Overridable in tests; the LAB card reads it only when [kAefRuntimeLabEnabled].
final aefRuntimeApiProvider = Provider<AefRuntimeApi>((ref) => AefRuntimeService());
