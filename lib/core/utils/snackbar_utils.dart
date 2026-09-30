import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import 'app_exceptions.dart';

export 'app_exceptions.dart';

/// Heuristic: does this error text look like a raw technical/provider dump
/// (Supabase/Postgrest/Stripe/Google/Edge) that must not reach the UI?
bool looksTechnicalError(String str) {
  const markers = [
    'PostgrestException', 'StorageException', 'FunctionException',
    'AuthException', 'FormatException', 'TypeError', 'NoSuchMethodError',
    'StateError', 'RangeError', 'statusCode', 'status_code', 'code:',
    'stripe', 'Stripe', 'googleapis', 'PlatformException', 'Null check',
    'http://', 'https://', 'Instance of', 'is not a subtype', '{', '}',
    '[drive:',
  ];
  return markers.any(str.contains);
}

/// Extrai uma mensagem legível de qualquer tipo de exceção.
/// Evita expor prefixos técnicos como "Exception: " ou dumps do Supabase.
///
/// R16 — pass [l10n] (the current UI language) so the message is shown in
/// the language the user picked; without it the message falls back to PT.
/// Raw technical/provider text is replaced by a generic localized message.
///
/// [fallback] replaces any remaining unmapped raw text (e.g. a provider
/// message from Stripe/Google on a commercial screen).
String extractErrorMessage(dynamic e, [AppLocalizations? l10n, String? fallback]) {
  final t = l10n ?? lookupAppLocalizations(const Locale('pt'));

  if (e is NotAuthenticatedException) return t.uxErrorNotAuthenticated;
  if (e is AppException) return appErrorMessage(e.code, t);

  if (e is AuthException) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return t.uxAuthErrorInvalidCredentials;
    }
    if (msg.contains('email not confirmed')) {
      return t.uxAuthErrorEmailNotConfirmed;
    }
    if (msg.contains('user already registered')) {
      return t.uxAuthErrorAlreadyRegistered;
    }
    if (msg.contains('rate limit') || msg.contains('over_email')) {
      return t.uxAuthErrorRateLimited;
    }
    if (msg.contains('weak password') || msg.contains('password should be')) {
      return t.uxAuthErrorWeakPassword;
    }
    return t.uxAuthErrorGeneric;
  }

  final str = e.toString();

  // IVE-COMMERCIAL-ENTITLEMENTS-01 — contrato de erro comercial das 16
  // funções de IA: 401 AUTH_REQUIRED, 429 QUOTA_EXCEEDED, 5xx erro do
  // provedor de IA. functions.invoke() nesta versão do SDK nunca lança
  // para status não-2xx -- os services existentes já leem `data['error']`
  // do corpo da resposta e relançam como Exception(data['error']), então
  // o texto do erro (não um tipo/status tipado) é o que chega até aqui.
  // Mapeado uma vez neste utilitário compartilhado em vez de em cada um
  // dos 16 services.
  if (str.contains('QUOTA_EXCEEDED')) {
    return t.uxErrorQuotaExceeded;
  }

  // MODULE-FOUNDATION-AND-ENTITLEMENT-02 — contrato de erro da autoridade de
  // entitlement do servidor (supabase/functions/_shared/entitlement.ts):
  // `error` é um CÓDIGO estável, traduzido só aqui. Checado antes dos
  // padrões genéricos de 401/503 abaixo.
  final entitlementCode = entitlementErrorCode(e);
  if (entitlementCode != null) {
    return switch (entitlementCode) {
      'PLAN_REQUIRED' => t.uxErrorPlanRequired,
      'MODULE_NOT_AVAILABLE' => t.uxErrorModuleNotAvailable,
      'MODULE_DISABLED' => t.uxErrorModuleDisabled,
      'ENTITLEMENT_UNAVAILABLE' => t.uxErrorEntitlementUnavailable,
      _ => t.uxErrorSessionExpired,
    };
  }

  if (str.contains('SocketException') ||
      str.contains('ClientException') ||
      str.contains('NetworkException') ||
      str.contains('Failed host lookup')) {
    return t.uxErrorNoConnection;
  }
  if (str.contains('401') || str.contains('Unauthorized') || str.contains('jwt expired')) {
    return t.uxErrorSessionExpired;
  }
  if (str.contains('TimeoutException') || str.contains('timed out')) {
    return t.uxErrorTimeout;
  }
  if (str.contains('502') || str.contains('503')) {
    return t.uxErrorServiceUnavailable;
  }
  if (looksTechnicalError(str)) return fallback ?? t.commonError;
  if (fallback != null) return fallback;
  if (str.startsWith('Exception: ')) return str.substring(11);
  return str;
}

/// R16 — localized message for a text-free [AppErrorCode].
String appErrorMessage(AppErrorCode code, AppLocalizations t) {
  switch (code) {
    case AppErrorCode.emptyResponse:               return t.uxErrorEmptyResponse;
    case AppErrorCode.notFound:                    return t.uxErrorNotFound;
    case AppErrorCode.fileTooLarge:                return t.uxErrorFileTooLarge;
    case AppErrorCode.fileUnreadable:              return t.uxErrorFileUnreadable;
    case AppErrorCode.fileTimeout:                 return t.uxErrorFileTimeout;
    case AppErrorCode.extractionTimeout:           return t.uxErrorExtractionTimeout;
    case AppErrorCode.extractedTextTooShort:       return t.uxErrorExtractedTextTooShort;
    case AppErrorCode.checkoutFailed:              return t.checkoutOpeningError;
    case AppErrorCode.googleSignInNotConfigured:   return t.uxErrorGoogleNotConfigured;
    case AppErrorCode.googleCredentialsUnavailable:return t.uxErrorGoogleCredentials;
    case AppErrorCode.signUpFailed:                return t.uxErrorSignUpFailed;
  }
}

/// Verdadeiro quando o erro é especificamente cota de IA esgotada —
/// telas que chamam as 16 funções de IA podem usar isto para oferecer o
/// botão "Fazer upgrade" além da mensagem padrão.
bool isQuotaExceededError(dynamic e) {
  return e.toString().contains('QUOTA_EXCEEDED');
}

/// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — códigos públicos de negação de
/// entitlement do servidor (supabase/functions/_shared/entitlement.ts).
const kEntitlementErrorCodes = [
  'PLAN_REQUIRED',
  'MODULE_NOT_AVAILABLE',
  'MODULE_DISABLED',
  'ENTITLEMENT_UNAVAILABLE',
  'AUTH_REQUIRED',
];

/// O código de entitlement do erro, ou null. Só para UX (mensagem e botão de
/// upgrade) — a decisão já foi tomada pelo servidor.
///
/// Igualdade EXATA (Codex Final CXF-03): os services relançam o campo
/// `error` do servidor como `Exception(code)`, então só `code` ou
/// `Exception: code` contam. Uma mensagem qualquer que apenas CONTENHA um
/// desses textos (ex.: erro do provedor de IA) não é classificada como
/// negação de acesso.
String? entitlementErrorCode(dynamic e) {
  var str = e.toString().trim();
  if (str.startsWith('Exception: ')) str = str.substring('Exception: '.length).trim();
  return kEntitlementErrorCodes.contains(str) ? str : null;
}

/// Verdadeiro quando o servidor negou por plano insuficiente — telas podem
/// oferecer "Fazer upgrade", como já fazem para QUOTA_EXCEEDED.
bool isPlanRequiredError(dynamic e) => entitlementErrorCode(e) == 'PLAN_REQUIRED';

void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// IVE-COMMERCIAL-TARGETED-REMEDIATION-06S — feedback for a CTA whose
// module isn't commercially released yet (see
// core/modules/route_policy.dart's isModuleActionable). Neutral tone,
// deliberately not styled as an error: nothing went wrong, the feature
// just isn't available yet.
void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.white24,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
