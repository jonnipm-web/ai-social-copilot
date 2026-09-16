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
import 'shared/widgets/ive_overlay.dart' show iveRouteNotifier;

// IVE-COMMERCIAL-OBSERVABILITY-07A — a manually-created ProviderContainer
// (rather than plain `ProviderScope(child: App())`) is the standard
// Riverpod pattern for reaching a provider from OUTSIDE the widget tree —
// exactly what's needed here: FlutterError.onError and runZonedGuarded's
// error handler run with no BuildContext at all, so they cannot use
// ProviderScope.containerOf(context) the way app.dart's redirect does.
// UncontrolledProviderScope wires this same container into the normal
// widget tree, so every provider (including diagnosticLoggerProvider) is
// still the exact same singleton instance app widgets see. Defined once in
// diagnostic_container.dart (as `globalProviderContainer`) rather than
// here, so plain (non-Riverpod) service classes like DriveService can also
// reach the logger without a BuildContext or a `ref`.

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
//
// IVE-COMMERCIAL-OBSERVABILITY-07A — this is also the single choke point
// for RUNTIME category events (mission section 04: "CRITICAL for the
// current Cannot read properties of null... defects"), since EVERY
// uncaught Flutter framework error and every uncaught async error in the
// whole app funnels through here already. Same fail-safe rules as the rest
// of the logger: never throws, no-ops when there's no active diagnostic
// session.
void _logUncaughtError(Object error, StackTrace stack) {
  debugPrint('[uncaught] ${error.runtimeType}: ${redactForLog(error)}');
  try {
    // IVE-COMMERCIAL-STABILITY-08 (Phase 3/4) — COMMERCIAL-E2E-001 captured
    // 25 uncaught_error events with route always null. STABILITY-09O root-
    // caused why: iveRouteNotifier only updates via a NavigatorObserver's
    // didPush/didPop/didReplace, keyed off `route.settings.name` — but no
    // GoRoute in app.dart sets `name:`, so that name is empty for ordinary
    // GoRouter navigation and the notifier rarely actually changes.
    // IveForensicSnapshot.currentRoute is populated instead from the
    // GoRouter `redirect` callback (app.dart), which already runs on every
    // navigation ATTEMPT and already computes an accurate path — that is
    // now the primary source, with iveRouteNotifier kept only as a
    // zero-cost fallback for any navigation that somehow bypasses it.
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
  } catch (_) {
    // Diagnostics must never compound an already-uncaught error.
  }
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

    runApp(UncontrolledProviderScope(container: globalProviderContainer, child: const App()));
  }, _logUncaughtError);
}
