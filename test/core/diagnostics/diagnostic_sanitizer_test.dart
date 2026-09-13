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
}
