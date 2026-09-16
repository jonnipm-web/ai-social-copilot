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
///   - `isAdmin`: false (or role not yet resolved, callers pass false for
///     "unknown") -> false, always. A normal FREE/PRO user must never
///     trigger recovery merely because bootstrap ran (mission section 06).
///     This is a courtesy pre-check, not the real security boundary — the
///     actual boundary is diagnostic_sessions_admin_manage_own's RLS
///     (`is_admin_user() AND user_id = auth.uid()`), which recover()'s
///     own findMyActiveSession() call is already subject to regardless of
///     this function's answer.
///   - `userId`: null (no authenticated user resolved yet) -> false,
///     always (mission section 06: "fail closed until role is resolved" —
///     there is no user to resolve a role FOR without one).
///   - `alreadyAttemptedForUserId == userId`: recovery was already tried
///     for this exact user in this runtime -> false. Keyed by user id
///     (not a one-shot flag) so a sign-out/sign-in as a DIFFERENT user in
///     the same tab, with no full reload, still gets its own fresh
///     attempt (mission section 10: "user switch isolation") — comparing
///     against a live id rather than a boolean naturally resets across a
///     user change without any separate sign-out hook needed for THIS
///     specific guard (a separate reset() call still clears the actual
///     in-memory *session* state on sign-out — see
///     DiagnosticSessionNotifier.reset()).
bool shouldAttemptDiagnosticRecovery({
  required bool isAdmin,
  required String? userId,
  required String? alreadyAttemptedForUserId,
}) {
  if (!isAdmin) return false;
  if (userId == null) return false;
  if (alreadyAttemptedForUserId == userId) return false;
  return true;
}
