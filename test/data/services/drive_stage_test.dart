// IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — regression coverage for the
// Drive failure boundary. Pure Dart logic, no google_sign_in/network
// mocking needed: this is exactly the "smallest useful testable
// abstraction" the mission asked for after Remediation 04 shipped without
// any regression test and the physical crash survived it.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/services/drive_stage.dart';

void main() {
  group('runDriveStage', () {
    test('returns the action result on success', () async {
      final result = await runDriveStage('signin', () async => 'ok');
      expect(result, 'ok');
    });

    test('wraps a thrown error with the stage tag, never losing the message', () async {
      await expectLater(
        () => runDriveStage('token', () async => throw StateError('boom')),
        throwsA(
          isA<DriveStageException>()
              .having((e) => e.stage, 'stage', 'token')
              .having((e) => e.message, 'message', contains('boom')),
        ),
      );
    });

    test('never double-wraps a DriveStageException raised deeper in the chain', () async {
      const inner = DriveStageException('download', 'original');
      await expectLater(
        () => runDriveStage('extract', () async => throw inner),
        throwsA(same(inner)),
      );
    });

    test('surfaces a stage-tagged timeout instead of hanging forever', () async {
      await expectLater(
        () => runDriveStage(
          'signin',
          () => Future<void>.delayed(const Duration(seconds: 5)),
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(
          isA<DriveStageException>()
              .having((e) => e.stage, 'stage', 'signin')
              .having((e) => e.message, 'message', contains('Tempo esgotado')),
        ),
      );
    });

    test('toString() includes the stage tag for diagnostics without exposing secrets', () {
      const e = DriveStageException('list', 'Drive API erro 401');
      expect(e.toString(), '[drive:list] Drive API erro 401');
      expect(e.toString(), isNot(contains('Bearer')));
    });
  });
}
