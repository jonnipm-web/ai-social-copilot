import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chave anon JWT pública (seguro hardcodar — Supabase usa RLS para segurança)
  await Supabase.initialize(
    url: 'https://nzngvbajrnruknpzzjbf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
        '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56bmd2YmFqcm5ydWtucHp6amJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5NDUzODYsImV4cCI6MjA5NDUyMTM4Nn0'
        '.mOvtGzA0ZNKmVY1FAT0-v7pICmz68VrFaFKEbKE8WvI',
  );

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
