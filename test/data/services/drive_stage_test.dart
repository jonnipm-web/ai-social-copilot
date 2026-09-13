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

  group('redactForLog', () {
    test('strips a token-shaped run from the message', () {
      final msg = redactForLog(Exception(
        'signIn failed, token=ya29.a0ARrdaM9k3jLp7xQzV8bN2fW1cH6dY4eR0tU3iO5pA7sD9fG2hJ4kL6mN8oP0q',
      ));
      expect(msg, isNot(contains('ya29')));
      expect(msg, contains('[redacted]'));
    });

    test('truncates very long messages', () {
      final msg = redactForLog(Exception('x' * 1000));
      expect(msg.length, lessThan(400));
    });

    test('leaves an ordinary short error message untouched', () {
      final msg = redactForLog(Exception('network unreachable'));
      expect(msg, contains('network unreachable'));
    });
  });

  group('resolveUsableAccount', () {
    // IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — regression test for the P1
    // Codex's adversarial review found in this mission: the original
    // signIn() reused any non-null silently-resolved account without
    // checking it actually had a usable Drive token, so a session stuck in
    // the documented "authenticated but not authorized" GIS state made the
    // "Entrar com Google" button do nothing (never reaching the
    // interactive consent screen that grants drive.readonly again).

    test('reuses the silent account when its token is usable, without going interactive', () async {
      var interactiveCalls = 0;
      final result = await resolveUsableAccount<String>(
        silentSignIn: () async => 'silent-account',
        tokenFor: (account) async => 'a-real-token',
        interactiveSignIn: () async {
          interactiveCalls++;
          return 'interactive-account';
        },
      );
      expect(result, 'silent-account');
      expect(interactiveCalls, 0);
    });

    test('falls through to interactive sign-in when there is no silent account', () async {
      final result = await resolveUsableAccount<String>(
        silentSignIn: () async => null,
        tokenFor: (account) async => 'a-real-token',
        interactiveSignIn: () async => 'interactive-account',
      );
      expect(result, 'interactive-account');
    });

    test(
      'falls through to interactive sign-in when the silent account exists but has no usable token '
      '(the "authenticated but not authorized" GIS state)',
      () async {
        final result = await resolveUsableAccount<String>(
          silentSignIn: () async => 'silent-account-without-drive-scope',
          tokenFor: (account) async => null,
          interactiveSignIn: () async => 'interactive-account',
        );
        expect(result, 'interactive-account');
      },
    );

    test('falls through to interactive sign-in when checking the silent account\'s token throws', () async {
      final result = await resolveUsableAccount<String>(
        silentSignIn: () async => 'silent-account',
        tokenFor: (account) async => throw StateError('boom'),
        interactiveSignIn: () async => 'interactive-account',
      );
      expect(result, 'interactive-account');
    });
  });
}
