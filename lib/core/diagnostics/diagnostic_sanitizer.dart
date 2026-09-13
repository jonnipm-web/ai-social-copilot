/// IVE-COMMERCIAL-OBSERVABILITY-07A — centralized sanitization for the
/// diagnostic logger. Pure functions, no Supabase/Riverpod dependency, so
/// every redaction rule is independently unit-testable.
///
/// Two complementary strategies, per mission section 06 ("Use allowlisted
/// metadata where practical rather than relying only on denylist
/// redaction"):
///   1. Allowlist: [buildSafeMetadata] only ever keeps keys the CALLER
///      explicitly listed as safe for that event — an unknown/typo'd key is
///      dropped, never passed through by accident.
///   2. Denylist: [sanitizeText] additionally scrubs the surviving string
///      VALUES (and any free-text field like an error message) for
///      token/secret-shaped substrings, as a backstop for values that are
///      legitimately free text (e.g. an exception's own message) and can't
///      be allowlisted by key alone.
library diagnostic_sanitizer;

/// Field names that must never appear as metadata keys even if a caller
/// mistakenly includes them in a passed map alongside safe ones — checked
/// case-insensitively. Mission section 06's explicit "NEVER LOG" list.
const Set<String> kForbiddenMetadataKeyFragments = {
  'password',
  'token',
  'secret',
  'authorization',
  'cookie',
  'api_key',
  'apikey',
  'service_role',
  'credit_card',
  'card_number',
  'cvv',
};

bool _isForbiddenKey(String key) {
  final lower = key.toLowerCase();
  return kForbiddenMetadataKeyFragments.any(lower.contains);
}

/// Only keeps entries whose key is BOTH in [allowedKeys] and not itself a
/// forbidden-shaped key name (defense in depth against an allowlist that
/// accidentally includes something it shouldn't). Values are restricted to
/// primitives — a nested Map/List/other object is stringified and then run
/// through [sanitizeText] rather than logged structurally, keeping the
/// stored shape predictable and bounded.
Map<String, Object?> buildSafeMetadata(
  Map<String, Object?> raw, {
  required Set<String> allowedKeys,
}) {
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    if (!allowedKeys.contains(entry.key)) continue;
    if (_isForbiddenKey(entry.key)) continue;
    final value = entry.value;
    if (value == null || value is num || value is bool) {
      result[entry.key] = value;
    } else if (value is String) {
      result[entry.key] = sanitizeText(value, maxLength: 300);
    } else {
      result[entry.key] = sanitizeText(value.toString(), maxLength: 300);
    }
  }
  return result;
}

/// Token/secret-shaped substrings this app might otherwise accidentally
/// log verbatim inside a caught exception's own message or stack trace —
/// mission section 06's explicit examples (Bearer, JWT-shaped, OAuth/API-
/// key-shaped, sensitive query params).
final List<RegExp> _secretPatterns = [
  RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
  // JWT: three base64url segments separated by dots.
  RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
  // Sensitive query-string parameters: token=..., access_token=...,
  // refresh_token=..., code=..., secret=..., api_key=... up to the next
  // '&', '#', whitespace, or end of string.
  RegExp(
    r'(?<=[?&])(access_token|refresh_token|token|code|secret|api_key|apikey|password)=[^&#\s]+',
    caseSensitive: false,
  ),
  RegExp(r'Authorization:\s*\S+', caseSensitive: false),
  // Generic long contiguous token-shaped run (OAuth access tokens, JWTs
  // caught elsewhere, generic API keys): 20+ chars of the base64url/JWT
  // alphabet. Deliberately last so the more specific patterns above get a
  // chance to redact with a clearer label first.
  RegExp(r'[A-Za-z0-9_\-\.]{20,}'),
];

/// Best-effort, not a cryptographic guarantee (documented consistently with
/// drive_stage.dart's redactForLog, which this generalizes) — truncates and
/// strips every recognized secret-shaped pattern before a string is ever
/// considered for storage.
String sanitizeText(String input, {int maxLength = 2000}) {
  var text = input;
  for (final pattern in _secretPatterns) {
    text = text.replaceAll(pattern, '[redacted]');
  }
  if (text.length > maxLength) {
    text = '${text.substring(0, maxLength)}…';
  }
  return text;
}

/// Convenience wrapper for an error's own message — same rules as
/// [sanitizeText], just a distinct name so call sites read clearly.
String sanitizeErrorMessage(Object error, {int maxLength = 500}) {
  return sanitizeText(error.toString(), maxLength: maxLength);
}

/// Stack traces are noisier and longer than a message, so given more room,
/// but still bounded and scrubbed the same way — a stack frame can
/// occasionally embed a request URL with a query string.
String sanitizeStackTrace(StackTrace stack, {int maxLength = 1500}) {
  return sanitizeText(stack.toString(), maxLength: maxLength);
}
