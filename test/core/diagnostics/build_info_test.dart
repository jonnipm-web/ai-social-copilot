// IVE-COMMERCIAL-STABILITY-09O — build SHA propagation (mission section 04).

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/diagnostics/build_info.dart';

void main() {
  test('kBuildSha falls back to "unknown" when no --dart-define is supplied (this test run)', () {
    // `flutter test` never passes --dart-define=BUILD_SHA — proves the
    // constant fails visibly (a literal, greppable "unknown") rather than
    // silently claiming a commit it wasn't actually built from.
    expect(kBuildSha, 'unknown');
  });

  test('kBuildSha fits diagnostic_sessions.build_sha\'s CHECK constraint (<= 100 chars)', () {
    // A real full git SHA is 40 hex chars — this just guards against the
    // constant ever becoming something unexpectedly long and silently
    // failing every startSession() insert at the DB layer.
    expect(kBuildSha.length, lessThanOrEqualTo(100));
  });

  test('kBuildSha contains no newline (diagnostic_sessions.build_sha CHECK)', () {
    expect(kBuildSha, isNot(contains('\n')));
    expect(kBuildSha, isNot(contains('\r')));
  });
}
