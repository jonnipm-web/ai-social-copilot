// IVE-COMMERCIAL-OBSERVABILITY-07A — locks the Dart enum values to exactly
// what supabase/migrations/20260913200000_diagnostic_logger.sql's CHECK
// constraints accept, so a future enum addition here that forgets to also
// update the migration (or vice versa) fails a test instead of failing a
// live insert with a cryptic Postgres constraint-violation error.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_models.dart';

void main() {
  test('DiagnosticSeverity values match the diagnostic_events.severity CHECK constraint', () {
    final values = DiagnosticSeverity.values.map((s) => s.value).toSet();
    expect(values, {'DEBUG', 'INFO', 'WARN', 'ERROR', 'CRITICAL'});
  });

  test('DiagnosticCategory values match the diagnostic_events.category CHECK constraint', () {
    final values = DiagnosticCategory.values.map((c) => c.value).toSet();
    expect(values, {
      'NAVIGATION', 'AUTH', 'QUOTA', 'AI', 'KNOWLEDGE', 'DRIVE', 'IVE', 'RUNTIME',
    });
  });

  test('kDiagnosticMetadataKeys contains no forbidden-shaped key name', () {
    const forbiddenFragments = ['password', 'token', 'secret', 'authorization', 'cookie', 'api_key', 'apikey'];
    for (final key in kDiagnosticMetadataKeys) {
      final lower = key.toLowerCase();
      for (final fragment in forbiddenFragments) {
        expect(
          lower.contains(fragment),
          isFalse,
          reason: 'kDiagnosticMetadataKeys contains "$key", which looks like a secret field name',
        );
      }
    }
  });
}
