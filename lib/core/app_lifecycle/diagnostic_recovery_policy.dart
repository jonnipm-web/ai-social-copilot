/// IVE-COMMERCIAL-STABILITY-09O-R — canonical diagnostic-session recovery
/// gate, extracted for testability the same way
/// profile_resume_policy.dart's [shouldRefreshProfileOnResume] already is.
///
/// Closes the exact gap STABILITY-09O's own post-deploy smoke test found:
/// DiagnosticLoggerService.recover() was previously only ever called from
/// the Admin diagnostics tab's initState, so a crash anywhere else in the
/// app went uncaptured even with a genuinely ACTIVE diagnostic_sessions
/// row, unless that runtime had separately visited that one screen. See
/// lib/app.dart's `_AppState._maybeRecoverDiagnosticSession` for how this
/// drives the actual `ref.read(diagnosticSessionProvider.notifier)
/// .recover()` call — never a local session write; recover() itself only
/// ever READS, so this function deciding "true" can never create or
/// duplicate a session, only ask the server whether one already exists.
///
/// [shouldAttemptDiagnosticRecovery] is the pure decision:
///   - `isAdmin`: false (or role not yet resolved — callers pass false for
///     "unknown", e.g. `profile?.isAdmin ?? false`) -> false, always. A
///     normal FREE/PRO user must never trigger recovery merely because
///     bootstrap ran (mission section 06), and an unresolved role must
///     never be treated as "safe to skip because probably not admin" —
///     both collapse to the same fail-closed `false` here.
///
/// Deliberately does NOT also decide "already attempted for this user" —
/// IVE-COMMERCIAL-STABILITY-09O-R Codex Gate (P1 ACCEPTED, 2nd pass) found
/// that living here (as a value the CALLER had to thread through and
/// compare) let a stale async recovery from a just-signed-out user
/// overwrite a different user's state, and separately let the SAME user's
/// re-login stay permanently suppressed, because the guard and the
/// session state it guards could go out of sync. That guard now lives
/// INSIDE DiagnosticSessionNotifier.recover()/reset() instead, atomically
/// with the state it protects — this function's only job is the
/// role/authorization gate, which has no such statefulness concern.
bool shouldAttemptDiagnosticRecovery({required bool isAdmin}) {
  return isAdmin;
}
