/// R16 — GLOBAL LANGUAGE CONSISTENCY.
///
/// Client-side failures that reach the UI must be shown in the user's
/// presentation language. Services have no BuildContext, so instead of
/// throwing `Exception('<Portuguese sentence>')` they throw one of these
/// text-free exceptions; `extractErrorMessage(e, l10n)`
/// (core/utils/snackbar_utils.dart) turns them into a localized message.

/// No signed-in user.
class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException();
  @override
  String toString() => 'NotAuthenticatedException';
}

enum AppErrorCode {
  /// A backend call returned no/invalid data.
  emptyResponse,
  /// The requested record does not exist (or is not visible).
  notFound,
  /// A local/remote file exceeds the import limit (~6 MB).
  fileTooLarge,
  /// A picked file could not be read.
  fileUnreadable,
  /// Picking/reading a file timed out.
  fileTimeout,
  /// Server-side text extraction timed out.
  extractionTimeout,
  /// Extracted text was too short to be useful.
  extractedTextTooShort,
  /// Stripe checkout session could not be started.
  checkoutFailed,
  /// Google sign-in is not configured in this environment.
  googleSignInNotConfigured,
  /// Google credentials could not be obtained.
  googleCredentialsUnavailable,
  /// E-mail sign-up failed without a more specific reason.
  signUpFailed,
}

class AppException implements Exception {
  const AppException(this.code);
  final AppErrorCode code;
  @override
  String toString() => 'AppException(${code.name})';
}
