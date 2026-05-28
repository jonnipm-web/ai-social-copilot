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
