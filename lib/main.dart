import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var supabaseUrl = 'https://nzngvbajrnruknpzzjbf.supabase.co';
  var supabaseKey = 'sb_publishable_fZboVtE9PeokahlYmhc_vg_t6JHOmFh';

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
