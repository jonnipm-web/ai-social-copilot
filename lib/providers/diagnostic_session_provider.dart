import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/diagnostics/diagnostic_logger_service.dart';
import '../core/diagnostics/diagnostic_models.dart';
import 'profile_provider.dart';

final diagnosticLoggerProvider = Provider<DiagnosticLoggerService>((ref) {
  return DiagnosticLoggerService(Supabase.instance.client);
});

class DiagnosticSessionState {
  const DiagnosticSessionState({this.sessionId, this.label, this.startedAt});

  final String? sessionId;
  final String? label;
  final DateTime? startedAt;

  bool get isActive => sessionId != null;
}

/// IVE-COMMERCIAL-OBSERVABILITY-07A — owner-facing diagnostic session
/// control (mission section 09). Deliberately thin: the actual read/write
/// authorization boundary is the database's RLS policy, not this class —
/// see supabase/migrations/20260913200000_diagnostic_logger.sql's comment
/// on diagnostic_sessions_admin_manage_own ("Do not reuse client-side route
/// guard as security boundary", mission section 07). A non-admin calling
/// [start] simply gets `false` back (the insert is rejected server-side),
/// exactly as if the control didn't exist for them.
class DiagnosticSessionNotifier extends StateNotifier<DiagnosticSessionState> {
  DiagnosticSessionNotifier(this._logger, this._ref) : super(const DiagnosticSessionState());

  final DiagnosticLoggerService _logger;
  final Ref _ref;

  Future<bool> start({String? label, String? roleSnapshot}) async {
    final effectiveRole = roleSnapshot ?? _ref.read(currentProfileProvider).valueOrNull?.roleLabel;
    final id = await _logger.startSession(label: label, roleSnapshot: effectiveRole);
    if (id == null) return false;
    state = DiagnosticSessionState(sessionId: id, label: label, startedAt: DateTime.now());
    return true;
  }

  Future<void> stop() async {
    await _logger.stopSession();
    state = const DiagnosticSessionState();
  }

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
    _logger.logEvent(
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
    );
  }
}

final diagnosticSessionProvider =
    StateNotifierProvider<DiagnosticSessionNotifier, DiagnosticSessionState>((ref) {
  return DiagnosticSessionNotifier(ref.watch(diagnosticLoggerProvider), ref);
});

// ── Support Log Viewer (mission section 08) ──────────────────────────────
// autoDispose: the viewer always reflects the current server state on open
// rather than a stale cache from a previous visit (same reasoning as
// currentProfileProvider/currentQuotaProvider).
final diagnosticSessionsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(diagnosticLoggerProvider).fetchAllSessions();
});

final diagnosticEventsForSessionProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, sessionId) {
  return ref.watch(diagnosticLoggerProvider).fetchEventsForSession(sessionId);
});
