// IVE-COMMERCIAL-STABILITY-08 — regression coverage for
// newDiagnosticCorrelationId(), the pure top-level helper in
// diagnostic_logger_service.dart. Importing the file does not require a
// live Supabase client (that's only needed to construct
// DiagnosticLoggerService itself, which this test never does).

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';

void main() {
  group(
    'newDiagnosticCorrelationId — IVE-COMMERCIAL-STABILITY-08 '
    '(RangeError "max ... was 0" root cause: 1 << 32 dart2js web trap, '
    'dart-lang/sdk#37569)',
    () {
      test('never throws across many calls (regression for the proven RangeError)', () {
        for (var i = 0; i < 500; i++) {
          expect(() => newDiagnosticCorrelationId(), returnsNormally);
        }
      });

      test('matches the app-generated correlation-id shape (two base36 runs, one hyphen)', () {
        final id = newDiagnosticCorrelationId();
        expect(id, matches(RegExp(r'^[0-9a-z]+-[0-9a-z]+$')));
      });

      test('calls in quick succession are all unique', () {
        final ids = List.generate(200, (_) => newDiagnosticCorrelationId());
        expect(ids.toSet().length, ids.length);
      });
    },
  );
}
