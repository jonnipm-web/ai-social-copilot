// IV-MOBILE-ECOSYSTEM-FOUNDATION-01 — InsightValues Quant entry point.
//
// Build command (debug APK):
//   flutter build apk --debug --flavor quant -t lib/main_quant.dart
//
// Android package: com.insightvalues.quant
// iOS bundle:      com.insightvalues.quant (target: InsightValuesQuant)
// Deep link:       insightvalues://quant/*

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/diagnostics/diagnostic_container.dart';
import 'core/diagnostics/diagnostic_models.dart';
import 'core/diagnostics/ive_forensic_snapshot.dart';
import 'data/services/drive_stage.dart' show redactForLog;
import 'mobile/config/product_flavor.dart';
import 'shared/widgets/ive_overlay.dart' show iveRouteNotifier;

void _logUncaughtError(Object error, StackTrace stack) {
  debugPrint('[quant:uncaught] ${error.runtimeType}: ${redactForLog(error)}');
  try {
    final capturedRoute = IveForensicSnapshot.currentRoute.isNotEmpty
        ? IveForensicSnapshot.currentRoute
        : (iveRouteNotifier.value.isEmpty ? null : iveRouteNotifier.value);
    diagnosticLogger.logEvent(
      category: DiagnosticCategory.runtime,
      eventName: 'uncaught_error',
      severity: DiagnosticSeverity.critical,
      status: 'failure',
      route: capturedRoute,
      metadata: IveForensicSnapshot.toMetadata(),
      error: error,
      stackTrace: stack,
    );
  } catch (_) {}
}

void main() {
  FlavorRegistry.init(ProductFlavor.quant);
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _logUncaughtError(details.exception, details.stack ?? StackTrace.empty);
    };
    await dotenv.load(fileName: 'flutter_env.cfg');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    runApp(UncontrolledProviderScope(
        container: globalProviderContainer, child: const App()));
  }, _logUncaughtError);
}
