import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://nzngvbajrnruknpzzjbf.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56bmd2YmFqcm5ydWtucHp6amJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5NDUzODYsImV4cCI6MjA5NDUyMTM4Nn0'
          '.mOvtGzA0ZNKmVY1FAT0-v7pICmz68VrFaFKEbKE8WvI',
    );
  } catch (e, st) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Erro de inicialização:\n\n$e\n\n$st',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
