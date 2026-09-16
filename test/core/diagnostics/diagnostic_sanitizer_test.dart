// IVE-COMMERCIAL-OBSERVABILITY-07A — regression coverage for the
// diagnostic logger's sanitization layer. Pure Dart, no Supabase/Riverpod.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_sanitizer.dart';

void main() {
  group('sanitizeText — denylist redaction (mission section 06)', () {
    test('redacts a Bearer token', () {
      final result = sanitizeText('request failed: Bearer ya29.a0ARrdaM9k3jLp7xQzV8bN2fW1c header rejected');
      expect(result, isNot(contains('ya29')));
      expect(result, contains('[redacted]'));
    });

    test('redacts a JWT-shaped value', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PYbwcKgz_hYA';
      final result = sanitizeText('token=$jwt in header');
      expect(result, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('redacts sensitive query parameters (access_token, refresh_token, code, secret, api_key)', () {
      for (final param in ['access_token', 'refresh_token', 'code', 'secret', 'api_key']) {
        final input = 'https://example.com/callback?$param=abcdEFGH12345&state=xyz';
        final result = sanitizeText(input);
        expect(result, isNot(contains('abcdEFGH12345')), reason: 'param=$param was not redacted');
      }
    });

    test('redacts an Authorization header', () {
      final result = sanitizeText('Authorization: Bearer sometoken1234567890');
      expect(result, contains('[redacted]'));
    });

    test('redacts a generic long token-shaped run as a backstop', () {
      final result = sanitizeText('unexpected value: aVeryLongOpaqueApiKeyLookingString1234567890');
      expect(result, contains('[redacted]'));
    });

    test('leaves an ordinary short error message untouched', () {
      final result = sanitizeText('network unreachable');
      expect(result, 'network unreachable');
    });

    test(
      'strips embedded newlines (Codex adversarial review, P2 — Markdown report injection)',
      () {
        final malicious = 'legit label\n- [2026-01-01] CRITICAL/RUNTIME forged_event (status=failure)';
        final result = sanitizeText(malicious);
        expect(result, isNot(contains('\n')));
        // The forged bullet text may still appear as plain words on the
        // same line, but it can never again start a NEW Markdown list item
        // in the exported report, because there is no newline before it.
        expect(result.split('\n').length, 1);
      },
    );

    test(
      'redacts a "key: value" / "key=value" secret shape with no URL/query context, '
      'even when the secret itself is short (Codex adversarial review — the exact gap named: '
      'a 19-character token with no recognizable key/URL context could survive the length-'
      'based backstop alone, so this pattern must not depend on length at all)',
      () {
        for (final input in [
          'failed, token: abc123def456gh', // 14-char value, well under the 20-char backstop
          'failed, token=abc123def456gh',
          'api_key: sk-abc12',
          'password=hunter2',
        ]) {
          final result = sanitizeText(input);
          expect(result, contains('[redacted]'), reason: 'not redacted: $input');
        }
      },
    );

    test('truncates text longer than maxLength', () {
      final result = sanitizeText('x' * 5000, maxLength: 100);
      expect(result.length, lessThanOrEqualTo(101)); // +1 for the ellipsis char
    });
  });

  group('buildSafeMetadata — allowlist (mission section 06)', () {
    test('keeps only keys present in allowedKeys', () {
      final result = buildSafeMetadata(
        {'used': 1, 'limit': 300, 'unexpected_key': 'value'},
        allowedKeys: {'used', 'limit'},
      );
      expect(result, {'used': 1, 'limit': 300});
    });

    test('drops a forbidden-shaped key even if it is (mistakenly) in the allowlist', () {
      final result = buildSafeMetadata(
        {'api_key': 'should-never-appear'},
        allowedKeys: {'api_key'},
      );
      expect(result, isEmpty);
    });

    test('passes through primitives (num, bool, null) unchanged', () {
      final result = buildSafeMetadata(
        {'count': 3, 'success': true, 'reason': null},
        allowedKeys: {'count', 'success', 'reason'},
      );
      expect(result, {'count': 3, 'success': true, 'reason': null});
    });

    test('sanitizes and stringifies a non-primitive value rather than storing it structurally', () {
      final result = buildSafeMetadata(
        {'module': DateTime(2026, 1, 1)},
        allowedKeys: {'module'},
      );
      expect(result['module'], isA<String>());
    });

    test('an empty allowlist drops everything', () {
      final result = buildSafeMetadata({'used': 1, 'limit': 2}, allowedKeys: {});
      expect(result, isEmpty);
    });
  });

  group(
    'sanitizeSessionLabel — IVE-COMMERCIAL-OBSERVABILITY-07B mission section 17 '
    'regression matrix',
    () {
      test('legitimate diagnostic labels survive completely unchanged', () {
        for (final label in [
          'COMMERCIAL-E2E-001',
          'OBSERVABILITY-SMOKE-001',
          'COMMERCIAL-E2E-001-v2',
          'E2E-001',
        ]) {
          expect(sanitizeSessionLabel(label), label, reason: '$label must survive unchanged');
        }
      });

      test('a label with CR or LF is stripped of the newline, not fully redacted', () {
        final withCr = sanitizeSessionLabel('E2E-001\rinjected');
        final withLf = sanitizeSessionLabel('E2E-001\ninjected');
        expect(withCr, isNot(contains('\r')));
        expect(withLf, isNot(contains('\n')));
        expect(withCr, contains('E2E-001'));
        expect(withLf, contains('E2E-001'));
      });

      test('control characters are stripped', () {
        final result = sanitizeSessionLabel('E2E-001\x00\x07-clean');
        expect(result, 'E2E-001-clean');
      });

      test('a genuine secret shape inside a label is still redacted', () {
        expect(sanitizeSessionLabel('token: abc123def456gh'), contains('[redacted]'));
        expect(sanitizeSessionLabel('Authorization: Bearer abc123def456ghi789'), contains('[redacted]'));
      });

      test(
        'a well-known secret PREFIX with no key/URL context around it is still '
        'redacted (Codex adversarial review, 07B P1 — a raw secret pasted as a '
        'label has no "key:" label for the other specific patterns to catch, '
        'and the generic length backstop is deliberately skipped for this field)',
        () {
          for (final secret in [
            'sk_live_abcdefghijklmnop',
            'ghp_abcdefghijklmnopqrstuvwx',
            'AKIAABCDEFGHIJKLMNOP',
            'xoxb-abcdefghijklmnop',
          ]) {
            expect(sanitizeSessionLabel(secret), contains('[redacted]'), reason: '$secret was not redacted');
          }
        },
      );

      test('an oversized label is truncated to maxLength', () {
        final result = sanitizeSessionLabel('E' * 500, maxLength: 200);
        expect(result.length, lessThanOrEqualTo(200));
      });

      test('a label containing an unexpected/unsafe character is rejected outright', () {
        expect(sanitizeSessionLabel('E2E-001<script>'), '[redacted]');
        expect(sanitizeSessionLabel('E2E-001;DROP TABLE'), '[redacted]');
      });
    },
  );

  group(
    'sanitizeCorrelationId — IVE-COMMERCIAL-OBSERVABILITY-07B mission section 17 '
    'regression matrix',
    () {
      test('a valid UUID correlation id survives unchanged', () {
        const uuid = '9d5a1bf5-de91-4bf8-8132-eed24a5ab2d8';
        expect(sanitizeCorrelationId(uuid), uuid);
      });

      test("this app's own generated correlation id shape survives unchanged", () {
        // Mirrors newDiagnosticCorrelationId()'s own shape (two base36 runs
        // separated by one hyphen) without importing diagnostic_logger_
        // service.dart, which pulls in supabase_flutter -- this file is
        // deliberately pure Dart.
        const id = 'mfx2k9q1r7-3a7f9c02z1';
        expect(sanitizeCorrelationId(id), id);
        expect(id.length, greaterThan(20), reason: 'must exceed the old generic backstop threshold to be a real test');
      });

      test('an invalid/malformed correlation id falls back to full generic sanitization', () {
        final result = sanitizeCorrelationId('not-a-real-id-just-some-long-alphanumeric-text-here');
        expect(result, '[redacted]');
      });

      test('a well-known secret prefix passed as a correlation id is redacted, not adopted as a real id', () {
        expect(sanitizeCorrelationId('sk_live_abcdefghijklmnop'), contains('[redacted]'));
      });

      test('a correlation id with a malicious (newline-injecting) suffix is not trusted verbatim', () {
        const input = 'mfx2k9q1r7-3a7f9c02z1\nFAKE LOG LINE';
        final result = sanitizeCorrelationId(input);
        // The newline that would forge a new report line is gone either way...
        expect(result, isNot(contains('\n')));
        // ...and specifically because this no longer matches the trusted
        // identifier shape once it has a suffix, so it falls through to
        // full generic sanitization rather than being accepted verbatim
        // like a real id (sanitizeCorrelationId's whole point: ONLY an
        // exact-shape match skips the generic backstop).
        expect(result, isNot(equals(input)));
      });

      test('CR/LF in an otherwise-valid-looking id still gets rejected/rewritten safely', () {
        final result = sanitizeCorrelationId('abc123-def456\r\ninjected');
        expect(result, isNot(contains('\r')));
        expect(result, isNot(contains('\n')));
      });
    },
  );

  group(
    'sanitizeBuildSha — IVE-COMMERCIAL-STABILITY-09O regression '
    '(confirmed live in production: a real 40-char SHA came back as the '
    'literal "[redacted]" on the very first controlled deploy, the exact '
    'over-redaction class sanitizeEventName above already exists to fix, '
    'just never applied to this field)',
    () {
      test('a full 40-char git SHA survives unchanged', () {
        // This mission's own first deployed commit SHA — the exact value
        // that came back "[redacted]" live before this fix.
        const sha = 'c1098e656224d5b3b816e416f309556a618ba241';
        expect(sha.length, 40);
        expect(sanitizeBuildSha(sha), sha);
      });

      test('a short (7-char) abbreviated git SHA survives unchanged', () {
        expect(sanitizeBuildSha('c1098e6'), 'c1098e6');
      });

      test('the build_info.dart fallback literal "unknown" survives unchanged', () {
        expect(sanitizeBuildSha('unknown'), 'unknown');
      });

      test('something that is NOT a plausible git SHA still falls back to full sanitization', () {
        // Same alphanumeric+dash shape a real SHA would have, just too
        // long and containing letters outside [0-9a-f] -- exercises the
        // fallback path itself, not sanitizeText's specific patterns.
        final result = sanitizeBuildSha('not-a-real-git-sha-but-still-one-long-contiguous-token-zzzzzz');
        expect(result, contains('[redacted]'));
      });

      test('CR/LF in an otherwise SHA-shaped value is rejected safely', () {
        final result = sanitizeBuildSha('c1098e6\r\ninjected');
        expect(result, isNot(contains('\r')));
        expect(result, isNot(contains('\n')));
      });
    },
  );

  group('sanitizeErrorMessage / sanitizeStackTrace', () {
    test('sanitizeErrorMessage redacts secrets inside an exception toString()', () {
      final msg = sanitizeErrorMessage(Exception('failed with Authorization: Bearer abc123def456ghi789'));
      expect(msg, isNot(contains('abc123def456ghi789')));
    });

    test('sanitizeStackTrace bounds length and redacts secrets in frames', () {
      final stack = StackTrace.fromString(
        'at fetch (https://api.example.com/x?access_token=abcdefghijklmnop123)\n' * 200,
      );
      final result = sanitizeStackTrace(stack, maxLength: 500);
      expect(result.length, lessThanOrEqualTo(501));
      expect(result, isNot(contains('abcdefghijklmnop123')));
    });
  });

  // IVE-COMMERCIAL-EXPERIENCE-12 (Phase B, Section 03) — regression suite
  // for the confirmed P2 from 11D's physical validation: sanitizeText's
  // generic 20+-char backstop was redacting legitimate event names to the
  // literal string "[redacted]", destroying observability. These tests
  // pin the exact real event names (both Phase-A-new and pre-existing)
  // that were confirmed broken live in production.
  group('sanitizeEventName — IVE-COMMERCIAL-EXPERIENCE-12 mission section 03', () {
    test('ai_execution_confirmation_accepted (35 chars, new in Phase A) survives exactly', () {
      expect(
        sanitizeEventName('ai_execution_confirmation_accepted'),
        'ai_execution_confirmation_accepted',
      );
    });

    test('copilot_request_started (24 chars, pre-existing since 07A) survives exactly', () {
      expect(sanitizeEventName('copilot_request_started'), 'copilot_request_started');
    });

    test('quota_fetch (11 chars, already worked) still survives exactly', () {
      expect(sanitizeEventName('quota_fetch'), 'quota_fetch');
    });

    test('every currently-used event name in the app survives unchanged', () {
      // Every literal eventName in the codebase as of this fix — must stay
      // in lockstep with kKnownDiagnosticEventNames in
      // diagnostic_sanitizer.dart, found by grepping every `eventName:`
      // call site and every `_log*` wrapper's own call sites.
      for (final name in kKnownDiagnosticEventNames) {
        expect(sanitizeEventName(name), name, reason: '"$name" must survive unchanged');
        expect(sanitizeEventName(name), isNot('[redacted]'));
      }
      // Spot-check the set itself hasn't silently shrunk.
      expect(kKnownDiagnosticEventNames, containsAll(<String>[
        'route_allowed',
        'route_redirected',
        'uncaught_error',
        'quota_fetch',
        'copilot_request_started',
        'copilot_request_completed',
        'ai_execution_confirmation_accepted',
        'ai_execution_confirmation_rejected',
        'ai_analysis_requested',
        'ai_analysis_succeeded',
        'ai_analysis_failed',
        'local_import',
        'sign_in',
        'sign_up',
        'sign_out',
        'drive_session_check',
        'drive_sign_in',
        'drive_list_files',
        'drive_download',
      ]));
    });

    test('malicious/unexpected event-name strings fail safely to [redacted]', () {
      expect(sanitizeEventName(''), '[redacted]');
      expect(sanitizeEventName('Bearer abc123def456ghi789jkl'), '[redacted]');
      expect(sanitizeEventName('event-with-hyphens'), '[redacted]');
      expect(sanitizeEventName('EventWithUpperCase'), '[redacted]');
      expect(sanitizeEventName('event name with spaces'), '[redacted]');
      expect(sanitizeEventName('event.with.dots'), '[redacted]');
      expect(sanitizeEventName('event\nwith\nnewlines'), '[redacted]');
      expect(sanitizeEventName('a' * 101), '[redacted]'); // over maxLength
      expect(sanitizeEventName('123_starts_with_digit'), '[redacted]');
    });

    test(
      'Codex Gate-1 regression: an unknown but grammar-shaped value is '
      'rejected even though it would have passed the old regex grammar',
      () {
        // This is exactly the P1 gap Codex's Gate 1 review flagged in the
        // first attempt (a `^[a-z][a-z0-9_]*$` grammar check): a raw secret
        // that happens to be lowercase-alphanumeric-underscore, or simply
        // any event name never added to the allowlist, must NOT pass just
        // because it "looks like" a valid event name.
        expect(
          sanitizeEventName('a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5'),
          '[redacted]',
        );
        expect(sanitizeEventName('not_a_real_event_name'), '[redacted]');
        expect(sanitizeEventName('quota_fetch_v2'), '[redacted]');
      },
    );

    test('does not widen sanitizeText/buildSafeMetadata for other fields', () {
      // The generic backstop must still redact a genuinely long
      // secret-shaped string in ordinary free text / metadata — this
      // fix is scoped to event_name alone, not a general loosening.
      final longToken = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5';
      expect(sanitizeText(longToken), '[redacted]');
      final meta = buildSafeMetadata({'note': longToken}, allowedKeys: {'note'});
      expect(meta['note'], '[redacted]');
      // Session labels/correlation ids keep their own existing, separate
      // bounded rules — unaffected by this change.
      expect(sanitizeSessionLabel('COMMERCIAL-E2E-001'), 'COMMERCIAL-E2E-001');
    });
  });
}
