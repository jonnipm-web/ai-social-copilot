/// IVE-COMMERCIAL-OBSERVABILITY-07A — pure Markdown formatter for the
/// "COPY/EXPORT DIAGNOSTIC REPORT" feature (mission section 08). Every
/// field passed in already went through buildSafeMetadata/sanitizeText
/// before it was ever written to the database (see
/// DiagnosticLoggerService._writeEvent) — this function does not sanitize
/// anything itself, it only re-serializes already-safe stored data into a
/// format suitable for pasting into a Claude/Codex analysis session.
library diagnostic_report_formatter;

String formatDiagnosticReport({
  required Map<String, dynamic> session,
  required List<Map<String, dynamic>> events,
}) {
  final buffer = StringBuffer()
    ..writeln('# Diagnostic Session Report')
    ..writeln()
    ..writeln('Session ID: ${session['id']}')
    ..writeln('Label: ${session['label'] ?? '—'}')
    ..writeln('Started: ${session['started_at']}')
    ..writeln('Ended: ${session['ended_at'] ?? '(active)'}')
    ..writeln('Role snapshot: ${session['role_snapshot'] ?? '—'}')
    ..writeln()
    ..writeln('## Timeline (${events.length} events)')
    ..writeln();
  for (final e in events) {
    buffer.writeln(
      '- [${e['occurred_at']}] ${e['severity']}/${e['category']} '
      '${e['event_name']} (route=${e['route'] ?? '—'}, status=${e['status'] ?? '—'}'
      '${e['duration_ms'] != null ? ', ${e['duration_ms']}ms' : ''})',
    );
    if (e['error_message'] != null) {
      buffer.writeln('  error: ${e['error_type'] ?? ''} ${e['error_message']}');
    }
  }
  return buffer.toString();
}
