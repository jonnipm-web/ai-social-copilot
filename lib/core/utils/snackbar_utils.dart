import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Extrai uma mensagem legível de qualquer tipo de exceção.
/// Evita expor prefixos técnicos como "Exception: " ou dumps do Supabase.
String extractErrorMessage(dynamic e) {
  if (e is AuthException) return e.message;
  final str = e.toString();
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
