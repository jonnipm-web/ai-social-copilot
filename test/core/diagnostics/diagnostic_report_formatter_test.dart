// IVE-COMMERCIAL-OBSERVABILITY-07A — regression coverage for the
// "COPY/EXPORT DIAGNOSTIC REPORT" formatter (mission section 08).

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_report_formatter.dart';

void main() {
  test('includes session metadata and every event in the timeline', () {
    final report = formatDiagnosticReport(
      session: {
        'id': 'abc-123',
        'label': 'COMMERCIAL-E2E-001',
        'started_at': '2026-09-14T10:00:00Z',
        'ended_at': '2026-09-14T10:20:00Z',
        'role_snapshot': 'Pro',
      },
      events: [
        {
          'occurred_at': '2026-09-14T10:01:00Z',
          'severity': 'INFO',
          'category': 'NAVIGATION',
          'event_name': 'route_allowed',
          'route': '/dashboard',
          'status': 'allowed',
          'duration_ms': null,
        },
        {
          'occurred_at': '2026-09-14T10:05:00Z',
          'severity': 'CRITICAL',
          'category': 'RUNTIME',
          'event_name': 'uncaught_error',
          'route': null,
          'status': 'failure',
          'duration_ms': null,
          'error_type': 'NoSuchMethodError',
          'error_message': "Cannot read properties of null (reading 'a')",
        },
      ],
    );

    expect(report, contains('abc-123'));
    expect(report, contains('COMMERCIAL-E2E-001'));
    expect(report, contains('Timeline (2 events)'));
    expect(report, contains('route_allowed'));
    expect(report, contains('/dashboard'));
    expect(report, contains('uncaught_error'));
    expect(report, contains('NoSuchMethodError'));
    expect(report, contains("Cannot read properties of null (reading 'a')"));
  });

  test('handles an active session (no ended_at) and events with no error', () {
    final report = formatDiagnosticReport(
      session: {'id': 'x', 'started_at': '2026-09-14T10:00:00Z', 'ended_at': null},
      events: [],
    );
    expect(report, contains('(active)'));
    expect(report, contains('Timeline (0 events)'));
  });
}
