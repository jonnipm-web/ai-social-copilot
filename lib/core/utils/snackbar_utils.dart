import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Extrai uma mensagem legível de qualquer tipo de exceção.
/// Evita expor prefixos técnicos como "Exception: " ou dumps do Supabase.
String extractErrorMessage(dynamic e) {
  if (e is AuthException) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    if (msg.contains('user already registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (msg.contains('rate limit') || msg.contains('over_email')) {
      return 'Muitas tentativas. Aguarde alguns segundos.';
    }
    if (msg.contains('weak password')) {
      return 'Senha muito fraca. Use pelo menos 6 caracteres.';
    }
    return e.message;
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
    return 'Você atingiu o limite mensal de análises de IA do seu plano. Faça upgrade para o Pro para continuar.';
  }

  // MODULE-FOUNDATION-AND-ENTITLEMENT-02 — contrato de erro da autoridade de
  // entitlement do servidor (supabase/functions/_shared/entitlement.ts):
  // `error` é um CÓDIGO estável, traduzido só aqui. Checado antes dos
  // padrões genéricos de 401/503 abaixo.
  final entitlementCode = entitlementErrorCode(e);
  if (entitlementCode != null) {
    return switch (entitlementCode) {
      'PLAN_REQUIRED' => 'Este recurso faz parte de um plano superior. Faça upgrade para continuar.',
      'MODULE_NOT_AVAILABLE' => 'Este recurso ainda não está disponível para a sua conta.',
      'MODULE_DISABLED' => 'Este recurso foi desativado.',
      'ENTITLEMENT_UNAVAILABLE' => 'Não foi possível verificar o seu acesso agora. Tente novamente.',
      _ => 'Sua sessão expirou. Faça login novamente.',
    };
  }

  if (str.contains('SocketException') ||
      str.contains('ClientException') ||
      str.contains('NetworkException') ||
      str.contains('Failed host lookup')) {
    return 'Não foi possível conectar. Verifique sua internet.';
  }
  if (str.contains('401') || str.contains('Unauthorized') || str.contains('jwt expired')) {
    return 'Sua sessão expirou. Faça login novamente.';
  }
  if (str.contains('TimeoutException') || str.contains('timed out')) {
    return 'A conexão demorou muito. Tente novamente.';
  }
  if (str.contains('502') || str.contains('503')) {
    return 'Serviço temporariamente indisponível. Tente novamente.';
  }
  if (str.startsWith('Exception: ')) return str.substring(11);
  return str;
}

/// Verdadeiro quando o erro é especificamente cota de IA esgotada —
/// telas que chamam as 16 funções de IA podem usar isto para oferecer o
/// botão "Fazer upgrade" além da mensagem padrão.
bool isQuotaExceededError(dynamic e) {
  return e.toString().contains('QUOTA_EXCEEDED');
}

/// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — códigos públicos de negação de
/// entitlement do servidor. A ordem importa só para strings que contenham
/// mais de um código (não esperado).
const kEntitlementErrorCodes = [
  'PLAN_REQUIRED',
  'MODULE_NOT_AVAILABLE',
  'MODULE_DISABLED',
  'ENTITLEMENT_UNAVAILABLE',
  'AUTH_REQUIRED',
];

/// O código de entitlement presente no erro, ou null. Só para UX (mensagem
/// e botão de upgrade) — a decisão já foi tomada pelo servidor.
String? entitlementErrorCode(dynamic e) {
  final str = e.toString();
  for (final c in kEntitlementErrorCodes) {
    if (str.contains(c)) return c;
  }
  return null;
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
