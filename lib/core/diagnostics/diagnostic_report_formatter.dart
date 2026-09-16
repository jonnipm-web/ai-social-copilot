/// IVE-COMMERCIAL-OBSERVABILITY-07A — pure Markdown formatter for the
/// "COPY/EXPORT DIAGNOSTIC REPORT" feature (mission section 08). Every
/// field passed in already went through buildSafeMetadata/sanitizeText
/// before it was ever written to the database (see
/// DiagnosticLoggerService._writeEvent) — this function does not sanitize
/// anything itself, it only re-serializes already-safe stored data into a
/// format suitable for pasting into a Claude/Codex analysis session.
///
/// In particular (Codex adversarial review, P2): this function renders one
/// `- [timestamp] ...` Markdown bullet per event with no escaping of its
/// own, which would let an embedded newline in any field forge a
/// convincing extra timeline entry. That's fixed upstream, once, at the
/// shared sanitizeText() choke point (every stored free-text field strips
/// `\r`/`\n` before it can ever reach the database) rather than here —
/// this function can stay a plain, dependency-free formatter as long as
/// that invariant holds for everything it's given.
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
    // IVE-COMMERCIAL-STABILITY-09O-SHA (mission section 08) — explicitly
    // labeled "session-start" to prevent exactly the confusion this
    // mission exists to close: this reflects the build running when the
    // session was CREATED, which can be stale by the time any individual
    // event below actually fired (a session may survive many deploys).
    // Each event line has its OWN, authoritative build_sha for that
    // reason — always prefer the event's own value for symbolication.
    ..writeln('Session build_sha (session-start, may be stale for later events): ${session['build_sha'] ?? '—'}')
    ..writeln()
    ..writeln('## Timeline (${events.length} events)')
    ..writeln();
  for (final e in events) {
    buffer.writeln(
      '- [${e['occurred_at']}] ${e['severity']}/${e['category']} '
      '${e['event_name']} (route=${e['route'] ?? '—'}, status=${e['status'] ?? '—'}'
      '${e['duration_ms'] != null ? ', ${e['duration_ms']}ms' : ''}'
      ', event_build_sha=${e['build_sha'] ?? '—'})',
    );
    if (e['error_message'] != null) {
      buffer.writeln('  error: ${e['error_type'] ?? ''} ${e['error_message']}');
    }
  }
  return buffer.toString();
}
