import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env').catchError((_) {});

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ??
        'https://nzngvbajrnruknpzzjbf.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ??
        'sb_publishable_fZboVtE9PeokahlYmhc_vg_t6JHOmFh',
  );

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
