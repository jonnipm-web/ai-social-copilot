import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'diagnostic_models.dart';
import 'diagnostic_sanitizer.dart';

/// IVE-COMMERCIAL-OBSERVABILITY-07A — the diagnostic logger itself.
///
/// Deliberately NOT a generic analytics SDK: every write goes through
/// [buildSafeMetadata]'s allowlist and [sanitizeText]'s denylist backstop,
/// there is no batching/queueing complexity (mission section 14: "use...
/// reasonable batching where appropriate" — for this MVP's event volume, a
/// single-row insert per event is already well within Supabase's normal
/// request budget, so batching would be premature complexity), and a
/// logging failure can NEVER throw back into the caller (mission section
/// 14: "A logging failure must NOT crash the commercial operation") or
/// re-trigger itself (section 14: "Do not create recursive logging").
class DiagnosticLoggerService {
  DiagnosticLoggerService(this._client);

  final SupabaseClient _client;

  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

  // Bounded, in-memory only (mission section 15: "Maintain only a bounded
  // in-memory buffer if simple and justified... Do not build a complex
  // offline telemetry subsystem") — a small window of the most recent
  // failed writes, purely for local debugging if persistence is down. Never
  // retried automatically (that would risk exactly the recursive-failure
  // loop section 14 warns against), never persisted, never shown to normal
  // users.
  static const _maxFailedEventBuffer = 50;
  final List<String> _failedEventDebugBuffer = [];
  List<String> get failedEventDebugBuffer => List.unmodifiable(_failedEventDebugBuffer);

  /// Starts a new diagnostic session as the CURRENT authenticated user.
  /// Returns null (and logs nothing) if there is no session or the insert
  /// is rejected — RLS restricts this to admins (mission section 09: "For
  /// MVP it may be Admin/Owner only"), so a non-admin calling this simply
  /// gets null back, exactly as if the feature didn't exist for them.
  Future<String?> startSession({
    String? label,
    String? roleSnapshot,
    String? appVersion,
    String? buildSha,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('diagnostic_sessions')
          .insert({
            'user_id': userId,
            'label': label != null ? sanitizeText(label, maxLength: 200) : null,
            'status': 'active',
            'app_version': appVersion,
            'build_sha': buildSha,
            'platform': kIsWeb ? 'web' : 'native',
            'role_snapshot': roleSnapshot,
          })
          .select('id')
          .single();
      _activeSessionId = row['id'] as String?;
      return _activeSessionId;
    } catch (e) {
      debugPrint('[diagnostics] falha ao iniciar sessão: ${sanitizeErrorMessage(e)}');
      return null;
    }
  }

  /// Admin/support session list (mission section 08). Relies entirely on
  /// diagnostic_sessions_admin_read_all's RLS policy for authorization — a
  /// non-admin caller simply gets an empty list back (Postgrest RLS filters
  /// rows silently, it does not error), never someone else's data. See the
  /// migration's own comment: "Do not reuse client-side route guard as
  /// security boundary" — this method enforces nothing itself by design.
  Future<List<Map<String, dynamic>>> fetchAllSessions({int limit = 100}) async {
    final rows = await _client
        .from('diagnostic_sessions')
        .select()
        .order('started_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchEventsForSession(String sessionId) async {
    final rows = await _client
        .from('diagnostic_events')
        .select()
        .eq('session_id', sessionId)
        .order('occurred_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> stopSession() async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    _activeSessionId = null;
    try {
      await _client.from('diagnostic_sessions').update({
        'status': 'stopped',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('[diagnostics] falha ao encerrar sessão: ${sanitizeErrorMessage(e)}');
    }
  }

  /// Fire-and-forget: callers never await this, and it never throws. A
  /// no-op when there is no active session — events are only ever recorded
  /// during an explicit owner-started diagnostic session (mission section
  /// 02), never ambiently for every user.
  void logEvent({
    required DiagnosticCategory category,
    required String eventName,
    DiagnosticSeverity severity = DiagnosticSeverity.info,
    String? module,
    String? operation,
    String? route,
    String? status,
    int? durationMs,
    String? correlationId,
    Map<String, Object?> metadata = const {},
    Object? error,
    StackTrace? stackTrace,
    String? sourceComponent,
  }) {
    final sessionId = _activeSessionId;
    final userId = _client.auth.currentUser?.id;
    if (sessionId == null || userId == null) return;

    unawaited(_writeEvent(
      sessionId: sessionId,
      userId: userId,
      category: category,
      eventName: eventName,
      severity: severity,
      module: module,
      operation: operation,
      route: route,
      status: status,
      durationMs: durationMs,
      correlationId: correlationId,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
      sourceComponent: sourceComponent,
    ));
  }

  Future<void> _writeEvent({
    required String sessionId,
    required String userId,
    required DiagnosticCategory category,
    required String eventName,
    required DiagnosticSeverity severity,
    String? module,
    String? operation,
    String? route,
    String? status,
    int? durationMs,
    String? correlationId,
    Map<String, Object?> metadata = const {},
    Object? error,
    StackTrace? stackTrace,
    String? sourceComponent,
  }) async {
    try {
      await _client.from('diagnostic_events').insert({
        'session_id': sessionId,
        'user_id': userId,
        'severity': severity.value,
        'category': category.value,
        'module': module,
        'operation': operation,
        'route': route,
        'event_name': sanitizeText(eventName, maxLength: 200),
        'status': status,
        'duration_ms': durationMs,
        'correlation_id': correlationId,
        'metadata': buildSafeMetadata(metadata, allowedKeys: kDiagnosticMetadataKeys),
        'error_type': error?.runtimeType.toString(),
        'error_message': error != null ? sanitizeErrorMessage(error) : null,
        'error_stack': stackTrace != null ? sanitizeStackTrace(stackTrace) : null,
        'source_component': sourceComponent,
      });
    } catch (e) {
      // Never rethrow, never log-the-logger's-own-failure through this same
      // path (that would be the recursive loop mission section 14 forbids)
      // -- a plain debugPrint plus a bounded local buffer is the ceiling.
      if (_failedEventDebugBuffer.length >= _maxFailedEventBuffer) {
        _failedEventDebugBuffer.removeAt(0);
      }
      _failedEventDebugBuffer.add('$eventName: ${sanitizeErrorMessage(e)}');
      debugPrint('[diagnostics] falha ao gravar evento "$eventName": ${sanitizeErrorMessage(e)}');
    }
  }
}

/// Public helper so instrumentation call sites can generate a correlation id
/// without needing a logger instance in scope (e.g. to hand the same id to
/// both a "started" and a later "success"/"failure" event across an await
/// gap or a different widget).
String newDiagnosticCorrelationId() {
  final rand = Random();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '-${rand.nextInt(1 << 32).toRadixString(36)}';
}
