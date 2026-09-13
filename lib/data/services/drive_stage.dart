/// IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — small, pure, unit-testable
/// boundary for the Google Drive import flow.
///
/// The physical "Null check operator used on a null value" crash survived
/// Remediation 04's fix (which already wraps `signInSilently()`/
/// `isSignedIn()` in try/catch — verified still present). Confirmed root
/// cause (see drive_service.dart for the full trail): `google_sign_in_web
/// ^0.12.0` (forced transitively by `google_sign_in: ^6.2.1`) migrated to
/// Google Identity Services and, per its own changelog, made
/// `signInSilently`/`isSignedIn` report a user as authenticated even when
/// that user never authorized (or lost authorization for) the
/// `drive.readonly` scope — package version 6.x has no API to explicitly
/// re-request that scope, and the internal reconciliation between the old
/// unified authentication/authorization model and the new split one is
/// exactly where the documented null-check exception fires.
/// hasUsableSession() (drive_service.dart) closes that gap by verifying a
/// real token, not just identity — but the underlying package call can
/// still throw in ways a synchronous try/catch around the call site alone
/// wouldn't reliably surface as a clean, diagnosable error.
///
/// [runDriveStage] gives every stage of the flow two things the mission
/// specifically asked for:
///   1. A stage-tagged diagnostic (never the token/content itself) so a
///      future crash report says exactly which step failed.
///   2. A timeout, so a call whose underlying plugin Future never completes
///      (a real possibility when the failure happens outside Dart's tracked
///      completion machinery) surfaces as a clear, recoverable error instead
///      of an indefinitely stuck spinner.
library drive_stage;

/// IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — Codex adversarial review flagged
/// that logging a caught error's raw `toString()` asserts, but does not
/// enforce, that no token/secret ever reaches a log line: an exception
/// thrown by a third-party plugin could in principle embed request/response
/// internals we don't control. This is a defensive, best-effort filter, not
/// a cryptographic guarantee — it truncates and strips any long contiguous
/// token-shaped run (the general shape of OAuth access tokens, JWTs and
/// API keys: 20+ chars of base64url/JWT alphabet) before a message is ever
/// handed to debugPrint.
final _tokenShaped = RegExp(r'[A-Za-z0-9_\-\.]{20,}');

String redactForLog(Object error) {
  final raw = error.toString();
  final truncated = raw.length > 300 ? '${raw.substring(0, 300)}…' : raw;
  return truncated.replaceAll(_tokenShaped, '[redacted]');
}

/// Raised by [runDriveStage]. `stage` identifies exactly where in the Drive
/// flow the failure happened (session check, sign-in, token, list,
/// download, extraction) without ever carrying the OAuth token, file
/// content, or Drive metadata that caused it.
class DriveStageException implements Exception {
  const DriveStageException(this.stage, this.message);

  final String stage;
  final String message;

  @override
  String toString() => '[drive:$stage] $message';
}

/// IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — Codex adversarial review (this
/// mission) found the P1 this closes: the original `signIn()` treated any
/// non-null silently-resolved account as good enough, so a Drive session
/// stuck in the documented "authenticated but not authorized" GIS state
/// (see drive_service.dart) was returned as-is on every "Entrar com
/// Google" click — the button did nothing, and the user could never reach
/// the interactive consent screen that would actually grant drive.readonly.
///
/// Generic (no google_sign_in import here, kept pure/testable without any
/// plugin mocking) two-step resolution: reuse the silent account only if a
/// real token for it checks out; otherwise always fall through to
/// interactive sign-in, which re-prompts for scope consent.
Future<T?> resolveUsableAccount<T>({
  required Future<T?> Function() silentSignIn,
  required Future<Object?> Function(T account) tokenFor,
  required Future<T?> Function() interactiveSignIn,
}) async {
  final silent = await silentSignIn();
  if (silent != null) {
    Object? token;
    try {
      token = await tokenFor(silent);
    } catch (_) {
      token = null;
    }
    if (token != null) return silent;
  }
  return interactiveSignIn();
}

/// Runs [action], tagging any failure with [stage] and enforcing [timeout]
/// so a hung underlying call surfaces as a diagnosable error rather than an
/// indefinite wait. Rethrows [DriveStageException] as-is so stage tags never
/// get double-wrapped when stages call into one another.
Future<T> runDriveStage<T>(
  String stage,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  try {
    return await action().timeout(
      timeout,
      onTimeout: () => throw DriveStageException(
        stage,
        'Tempo esgotado aguardando resposta do Google. Tente novamente.',
      ),
    );
  } on DriveStageException {
    rethrow;
  } catch (e) {
    throw DriveStageException(stage, e.toString());
  }
}
