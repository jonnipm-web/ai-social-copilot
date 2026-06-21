import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    // Mostra loading imediatamente
    runApp(const _LoadingApp());

    // Pequena pausa para o Flutter pintar a tela antes de inicializar
    await Future.delayed(const Duration(milliseconds: 200));

    await Supabase.initialize(
      url: 'https://nzngvbajrnruknpzzjbf.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56bmd2YmFqcm5ydWtucHp6amJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5NDUzODYsImV4cCI6MjA5NDUyMTM4Nn0'
          '.mOvtGzA0ZNKmVY1FAT0-v7pICmz68VrFaFKEbKE8WvI',
    );

    runApp(const ProviderScope(child: App()));
  }, (error, stack) {
    // Captura qualquer erro async que escape, inclusive de Futures internos
    runApp(_ErrorApp(error: '$error\n\n$stack'));
  });
}

class _LoadingApp extends StatelessWidget {
  const _LoadingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF6C63FF)),
              SizedBox(height: 16),
              Text('Iniciando...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Erro de inicialização:\n\n$error',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
