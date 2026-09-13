import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/diagnostic_session_provider.dart';
import 'diagnostic_logger_service.dart';

/// IVE-COMMERCIAL-OBSERVABILITY-07A — the app's single ProviderContainer,
/// created once in main.dart and passed to UncontrolledProviderScope so the
/// same instance backs both the normal widget tree (via
/// ProviderScope.containerOf) and code with no BuildContext at all (the
/// global error handler, and plain service classes like DriveService/
/// QuotaService that predate Riverpod-based dependency injection in this
/// codebase and were not restructured for this mission — "do not
/// over-engineer").
final globalProviderContainer = ProviderContainer();

/// Convenience accessor so a plain service class can log a diagnostic event
/// with one line, no `ref` required: `diagnosticLogger.logEvent(...)`.
DiagnosticLoggerService get diagnosticLogger =>
    globalProviderContainer.read(diagnosticLoggerProvider);
