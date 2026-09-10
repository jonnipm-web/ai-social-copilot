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

void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
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
