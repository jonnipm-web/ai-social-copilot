import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

// IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — last-resort diagnostic net.
// The confirmed root cause of the physical Drive "Null check operator used
// on a null value" crash is fixed at the source in drive_service.dart
// (hasUsableSession() — see its comment for the full trail through the
// google_sign_in_web changelog). This global handler is defense in depth,
// not a substitute for that fix: any *other* error that escapes a plugin's
// JS interop boundary rather than a normal awaited Dart Future (a class of
// bug ordinary try/catch cannot intercept, documented elsewhere in
// google_sign_in_web and not unique to the one root cause found here) is
// stopped from silently killing the whole app, and gets a diagnostic log
// line to work from. Never logs tokens, file content, or Drive metadata —
// only the error's own (already-redacted, per DriveStageException) message
// and type.
void _logUncaughtError(Object error, StackTrace stack) {
  debugPrint('[uncaught] ${error.runtimeType}: $error');
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _logUncaughtError(details.exception, details.stack ?? StackTrace.empty);
    };

    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    runApp(const ProviderScope(child: App()));
  }, _logUncaughtError);
}
