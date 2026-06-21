import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var supabaseUrl = 'https://nzngvbajrnruknpzzjbf.supabase.co';
  var supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56bmd2YmFqcm5ydWtucHp6amJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5NDUzODYsImV4cCI6MjA5NDUyMTM4Nn0.mOvtGzA0ZNKmVY1FAT0-v7pICmz68VrFaFKEbKE8WvI';

  try {
    await dotenv.load(fileName: '.env');
    final envUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final envKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (envUrl.isNotEmpty) supabaseUrl = envUrl;
    if (envKey.isNotEmpty) supabaseKey = envKey;
  } catch (_) {}

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
