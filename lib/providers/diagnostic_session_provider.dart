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

  // IVE-COMMERCIAL-STABILITY-09O-R (Codex Gate, 2 P1s ACCEPTED) — lives
  // HERE, not in the caller (lib/app.dart's _AppState originally kept its
  // own copy), so [reset] can clear it atomically with the session state
  // it guards. The two defects that caused: (1) a stale in-flight
  // recover() from a just-signed-out user could overwrite the new user's
  // notifier state after an await gap, and (2) the SAME user signing out
  // and back in inherited a guard that never got cleared, permanently
  // suppressing their own re-recovery for the rest of the runtime.
  String? _recoveryAttemptedForUserId;

  Future<bool> start({String? label, String? roleSnapshot}) async {
    final effectiveRole = roleSnapshot ?? _ref.read(currentProfileProvider).valueOrNull?.roleLabel;
    // IVE-COMMERCIAL-STABILITY-09O (Codex Gate 2nd pass, P2 ACCEPTED) —
    // build_sha is no longer passed in here at all: DiagnosticLoggerService
    // .startSession() always writes kBuildSha internally, so there is no
    // parameter through which a caller (this one or any future one) could
    // supply a different value. See startSession's own comment.
    final id = await _logger.startSession(
      label: label,
      roleSnapshot: effectiveRole,
    );
    if (id == null) return false;
    // IVE-COMMERCIAL-OBSERVABILITY-07B — `id` may belong to a session this
    // call just created, OR one it recovered after a unique-violation
    // (mission section 05: another ACTIVE session already existed, most
    // plausibly this same client racing itself). Re-fetch the authoritative
    // row rather than trusting the label/timestamp this specific call
    // happened to be invoked with, so a recovered session shows its REAL
    // label, not whatever text happened to be in the input field this time.
    await _adoptFromServer(id);
    return true;
  }

  /// IVE-COMMERCIAL-OBSERVABILITY-07B (mission section 04) — deterministic
  /// recovery of an existing ACTIVE session after a reload/new tab/new
  /// provider container. A no-op if this notifier already tracks an active
  /// session (never overwrites live in-memory state with a server round
  /// trip it doesn't need), if there's no authenticated user, or if
  /// recovery was already attempted for the CURRENT user this runtime
  /// (cleared by [reset], so a later sign-out/sign-in — same user or a
  /// different one — always gets a fresh attempt).
  ///
  /// IVE-COMMERCIAL-STABILITY-09O-R (Codex Gate, P1 ACCEPTED) — the user
  /// id is captured BEFORE the `await` below and re-checked AFTER it, so a
  /// sign-out (-> [reset]) or a sign-in as someone else that happens
  /// mid-flight can never have this call's STALE result overwrite the
  /// notifier with the wrong (no-longer-current) user's session. try/catch
  /// wraps the query itself so a malformed row or a network failure
  /// surfaces as a caught, logged no-op rather than an unhandled async
  /// error during app bootstrap (Codex Gate, P2 ACCEPTED).
  Future<void> recover() async {
    if (state.isActive) return;
    final userId = _logger.currentUserId;
    if (userId == null) return;
    if (_recoveryAttemptedForUserId == userId) return;
    _recoveryAttemptedForUserId = userId;
    try {
      final row = await _logger.findMyActiveSession();
      if (userId != _logger.currentUserId) return; // stale — discard.
      if (row == null) return;
      _logger.adoptActiveSession(row['id'] as String);
      state = _stateFromRow(row);
    } catch (_) {
      // Diagnostics must never throw back into app bootstrap. A failed
      // attempt stays "attempted" for this user this runtime (no retry
      // storm against a persistently failing server) until the next
      // sign-out/sign-in cycle clears the guard via reset().
    }
  }

  /// IVE-COMMERCIAL-OBSERVABILITY-07B (Codex production-check review) —
  /// [sessionId] already originates from a server-validated source
  /// ([DiagnosticLoggerService.startSession]'s own INSERT result, or its
  /// internal RLS-scoped recovery on a unique-violation) — never client
  /// input. Even so, this re-confirms it against a fresh, independent
  /// [findMyActiveSession] read (retried once for an immediate-read-after-
  /// write race) rather than ever trusting [sessionId] on its own: if the
  /// server-side row can't be re-confirmed to actually be ACTIVE for the
  /// current user after that retry, this fails CLOSED to "no active
  /// session" rather than optimistically displaying one that isn't
  /// independently confirmed.
  Future<void> _adoptFromServer(String sessionId) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final row = await _logger.findMyActiveSession();
      if (row != null && row['id'] == sessionId) {
        state = _stateFromRow(row);
        return;
      }
      if (attempt == 0) await Future.delayed(const Duration(milliseconds: 250));
    }
    state = const DiagnosticSessionState();
  }

  DiagnosticSessionState _stateFromRow(Map<String, dynamic> row) {
    return DiagnosticSessionState(
      sessionId: row['id'] as String,
      label: row['label'] as String?,
      startedAt: DateTime.tryParse(row['started_at'] as String? ?? ''),
    );
  }

  Future<void> stop() async {
    await _logger.stopSession();
    state = const DiagnosticSessionState();
  }

  /// IVE-COMMERCIAL-STABILITY-09O-R (mission section 10) — local-only
  /// detach, no server call (unlike [stop], which marks the session row
  /// 'stopped' server-side). Called on sign-out: the outgoing user's
  /// session should remain 'active' server-side (so they can [recover] it
  /// again on their next login), but THIS tab's in-memory state must not
  /// keep pointing at it once they're no longer the authenticated user.
  void reset() {
    _logger.forgetActiveSession();
    // IVE-COMMERCIAL-STABILITY-09O-R (Codex Gate, P1 ACCEPTED) — clearing
    // this alongside the session state is what lets the SAME user signing
    // out and back in get a fresh recover() attempt, not just a different
    // user (see recover()'s own comment).
    _recoveryAttemptedForUserId = null;
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
