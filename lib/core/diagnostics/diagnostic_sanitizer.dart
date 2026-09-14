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
  // IVE-COMMERCIAL-OBSERVABILITY-07A (Codex adversarial review) — the
  // query-param pattern above only fires inside a URL's own `?`/`&`
  // syntax. A secret can just as easily show up in free text as
  // "token: abc123" or "api_key=abc123" with no surrounding URL at all
  // (a very real shape for a caught exception's own message) — this
  // catches that "key: value" / "key=value" form anywhere in the string,
  // not just inside a query string.
  RegExp(
    r'(password|token|secret|api[_-]?key|authorization)\s*[:=]\s*\S+',
    caseSensitive: false,
  ),
  // IVE-COMMERCIAL-OBSERVABILITY-07B (Codex adversarial review) — the
  // patterns above only recognize a secret by its surrounding KEY (a
  // "token:"/"api_key=" label). A well-known secret FORMAT with no such
  // label at all — a raw Stripe/GitHub/AWS/Slack/Google key pasted as-is
  // — has no key/URL context to catch it, and is exactly the shape
  // sanitizeSessionLabel/sanitizeCorrelationId's own bounded identifier
  // allowlist (letters/digits/underscore/hyphen) can no longer catch via
  // the generic length backstop, since that backstop is deliberately
  // skipped for those two fields. Matching these well-known prefixes
  // specifically closes that gap without reintroducing the original
  // false-positive problem (no real diagnostic label starts with
  // "sk_live_", "ghp_", "AKIA", etc.).
  RegExp(
    r'\b(?:sk_live_|sk_test_|rk_live_|pk_live_|ghp_|gho_|ghu_|ghs_|ghr_|github_pat_|xox[baprs]-|AIza)[A-Za-z0-9_-]{10,}',
  ),
  RegExp(r'\bAKIA[0-9A-Z]{16}\b'),
  // Generic long contiguous token-shaped run (OAuth access tokens, JWTs
  // caught elsewhere, generic API keys): 20+ chars of the base64url/JWT
  // alphabet. Deliberately last so the more specific patterns above get a
  // chance to redact with a clearer label first. Documented limitation
  // (Codex adversarial review): a shorter, e.g. 19-character, secret with
  // no recognizable key/URL context around it can still survive — this is
  // an inherent limit of length-based heuristic detection with an
  // acceptable false-positive rate, not something a slightly different
  // threshold would meaningfully fix, hence still "best-effort, not a
  // cryptographic guarantee" (see this function's own doc comment).
  RegExp(r'[A-Za-z0-9_\-\.]{20,}'),
];

/// Best-effort, not a cryptographic guarantee (documented consistently with
/// drive_stage.dart's redactForLog, which this generalizes) — truncates and
/// strips every recognized secret-shaped pattern before a string is ever
/// considered for storage.
///
/// IVE-COMMERCIAL-OBSERVABILITY-07A (Codex adversarial review, P2) —
/// newlines are collapsed to a single space BEFORE anything else. Every
/// stored free-text field ultimately flows through this one function (see
/// DiagnosticLoggerService._writeEvent), and
/// diagnostic_report_formatter.dart's Markdown export renders each event as
/// one `- [timestamp] ...` bullet line — an embedded "\n- [fake]
/// CRITICAL/RUNTIME forged_event" inside any field (a session label, an
/// error message, anything) would otherwise forge a convincing extra
/// timeline entry in the exported report. Stripping newlines here, at the
/// one shared choke point, closes that for every field and every future
/// call site at once, rather than only at the formatter boundary.
String sanitizeText(String input, {int maxLength = 2000}) {
  var text = input.replaceAll(RegExp(r'[\r\n]+'), ' ');
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

/// IVE-COMMERCIAL-OBSERVABILITY-07B — a diagnostic session label and a
/// correlation id are NOT arbitrary free text pulled from an exception or
/// external source (that's [sanitizeText]'s job, unchanged below): they are
/// short, structured identifiers either hand-chosen by the caller (a label
/// like "COMMERCIAL-E2E-001") or generated in a known bounded shape (see
/// [newDiagnosticCorrelationId] below). [sanitizeText]'s last-resort generic
/// backstop pattern — `[A-Za-z0-9_\-\.]{20,}` — cannot tell those apart from
/// an actual leaked token of the same shape and redacts both identically
/// (07B production smoke: "OBSERVABILITY-SMOKE-001", 23 chars, came back as
/// "[redacted]" end to end, and the app's OWN placeholder example
/// "COMMERCIAL-E2E-001" is only 1 character short of the same fate).
/// Destroying every non-trivial label/correlation id defeats the feature
/// (a label you can't read back, a correlation id that can never correlate
/// anything), so these two fields get their own bounded validation instead
/// of the generic length backstop — while still running every OTHER,
/// SPECIFIC secret pattern above (Bearer/JWT/Authorization header/query-
/// param/key-value shapes) as a defense-in-depth floor, plus the same CR/LF
/// and control-character stripping and a strict length cap. An input that
/// still doesn't look like a plain identifier after that — because it
/// contains a genuinely unexpected character, not merely because it is long
/// — is rejected outright rather than stored partially-sanitized.
final List<RegExp> _specificSecretPatterns =
    _secretPatterns.sublist(0, _secretPatterns.length - 1);

String _stripControlChars(String input) {
  return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
}

/// Letters, digits, spaces and a small set of punctuation already used by
/// real labels in this codebase/mission text (COMMERCIAL-E2E-001-v2,
/// E2E-001) — deliberately NOT the same permissive class the old generic
/// backstop watched (that class is exactly what made a real label
/// indistinguishable from a token).
final RegExp _safeIdentifierShape = RegExp(r'^[A-Za-z0-9 _.-]*$');

/// Sanitizes a user-supplied diagnostic session label (mission section 03:
/// "SESSION LABEL"). Legitimate short identifiers survive unchanged;
/// CR/LF, control characters, recognized secret shapes, and anything
/// oversized or outside the safe identifier character set are rejected.
String sanitizeSessionLabel(String input, {int maxLength = 200}) {
  var text = _stripControlChars(input.replaceAll(RegExp(r'[\r\n]+'), ' '));
  for (final pattern in _specificSecretPatterns) {
    text = text.replaceAll(pattern, '[redacted]');
  }
  if (text.length > maxLength) {
    text = text.substring(0, maxLength);
  }
  text = text.trim();
  if (text.isEmpty) return text;
  if (text.contains('[redacted]')) return text;
  if (!_safeIdentifierShape.hasMatch(text)) {
    // Something other than a specifically-recognized secret pattern still
    // doesn't look like a plain identifier (e.g. an unexpected symbol) --
    // fail closed rather than guess at partial sanitization.
    return '[redacted]';
  }
  return text;
}

/// Matches a canonical UUID (any version/variant).
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Matches this app's own generated shape (see [newDiagnosticCorrelationId]
/// in diagnostic_logger_service.dart): two lowercase base36 (0-9a-z) runs
/// separated by a single hyphen.
final RegExp _appCorrelationIdPattern = RegExp(r'^[0-9a-z]+-[0-9a-z]+$');

/// Sanitizes a correlation id (mission section 03: "CORRELATION ID").
/// A value matching a UUID or this app's own generated correlation-id
/// shape survives unchanged (after CR/LF/control-char stripping) — it is
/// exactly the kind of long alphanumeric+hyphen string the generic
/// backstop would otherwise always destroy, defeating the entire point of
/// correlating events. Anything else falls back to full [sanitizeText]
/// (generic backstop included), since an unrecognized shape here gets no
/// special trust.
String sanitizeCorrelationId(String input, {int maxLength = 100}) {
  final text = _stripControlChars(input.replaceAll(RegExp(r'[\r\n]+'), ' ')).trim();
  final bounded = text.length > maxLength ? text.substring(0, maxLength) : text;
  if (_uuidPattern.hasMatch(bounded) || _appCorrelationIdPattern.hasMatch(bounded)) {
    return bounded;
  }
  return sanitizeText(input, maxLength: maxLength);
}

/// Stack traces are noisier and longer than a message, so given more room,
/// but still bounded and scrubbed the same way — a stack frame can
/// occasionally embed a request URL with a query string.
String sanitizeStackTrace(StackTrace stack, {int maxLength = 1500}) {
  return sanitizeText(stack.toString(), maxLength: maxLength);
}
