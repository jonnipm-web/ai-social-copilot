import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'build_info.dart';
import 'diagnostic_models.dart';
import 'diagnostic_sanitizer.dart';

/// IVE-COMMERCIAL-OBSERVABILITY-07A — the diagnostic logger itself.
///
/// Deliberately NOT a generic analytics SDK: every write goes through
/// [buildSafeMetadata]'s allowlist and [sanitizeText]'s denylist backstop,
/// there is no batching/queueing complexity (mission section 14: "use...
/// reasonable batching where appropriate" — for this MVP's event volume, a
/// single-row insert per event is already well within Supabase's normal
/// request budget, so batching would be premature complexity), and a
/// logging failure can NEVER throw back into the caller (mission section
/// 14: "A logging failure must NOT crash the commercial operation") or
/// re-trigger itself (section 14: "Do not create recursive logging").
class DiagnosticLoggerService {
  DiagnosticLoggerService(this._client);

  final SupabaseClient _client;

  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

  /// IVE-COMMERCIAL-STABILITY-09O-R (Codex Gate, P1 ACCEPTED) — lets
  /// [DiagnosticSessionNotifier.recover] re-check, AFTER an async gap,
  /// whether the authenticated user is still who it was when the call
  /// started. A live read of the Supabase client's own current user, never
  /// cached, so it reflects a sign-out/sign-in that happened mid-await.
  String? get currentUserId => _client.auth.currentUser?.id;

  static final RegExp _uuidShape = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Name of the mission 07B partial unique index
  /// (diagnostic_one_active_session.sql) enforcing at most one ACTIVE
  /// session per user — used to disambiguate exactly THAT unique-
  /// violation from any other 23505 (e.g. a theoretical primary-key
  /// collision on `id`, which is DB-generated and never client-supplied
  /// today, but Codex read-only audit flagged the bare error CODE alone
  /// as too broad a signal to act on).
  static const _oneActiveSessionConstraint = 'diagnostic_sessions_one_active_per_user';

  /// IVE-COMMERCIAL-OBSERVABILITY-07B — lets a recovered/adopted session
  /// (see [findMyActiveSession]) become the local active session without
  /// going through [startSession]'s own INSERT. Never accepts a caller-
  /// supplied user id: the row itself was already fetched scoped to
  /// auth.uid() via RLS, so there's nothing to re-check here. A real
  /// exploit path was never possible even before this check (any misuse
  /// still hits diagnostic_events_insert_own_active_session's own RLS at
  /// write time, which requires the SESSION's owner to match auth.uid()),
  /// but Codex read-only audit flagged this as an easy-to-misuse public
  /// API with no shape validation of its own — this rejects anything that
  /// isn't a real session id (a UUID) outright as a cheap, free defense-
  /// in-depth floor, independent of the RLS backstop.
  void adoptActiveSession(String sessionId) {
    if (!_uuidShape.hasMatch(sessionId)) return;
    _activeSessionId = sessionId;
  }

  /// IVE-COMMERCIAL-STABILITY-09O-R (mission section 10 — "logout clears
  /// runtime session state") — a pure in-memory detach, no network call
  /// (unlike [stopSession], which marks the row 'stopped' server-side and
  /// is only appropriate when the OWNER explicitly ends the walkthrough).
  /// Called on sign-out so this tab's logger cannot keep attaching events
  /// to a session that belonged to whichever user was just signed out —
  /// [logEvent] would already fail closed via
  /// diagnostic_events_insert_own_active_session's RLS (session.user_id
  /// would no longer match the new auth.uid()), but clearing this
  /// eagerly avoids depending on that as the only backstop, and leaves a
  /// clean slate for the next [recover]/[startSession] call (by the same
  /// user logging back in, or a different one).
  void forgetActiveSession() {
    _activeSessionId = null;
  }

  // Bounded, in-memory only (mission section 15: "Maintain only a bounded
  // in-memory buffer if simple and justified... Do not build a complex
  // offline telemetry subsystem") — a small window of the most recent
  // failed writes, purely for local debugging if persistence is down. Never
  // retried automatically (that would risk exactly the recursive-failure
  // loop section 14 warns against), never persisted, never shown to normal
  // users.
  static const _maxFailedEventBuffer = 50;
  final List<String> _failedEventDebugBuffer = [];
  List<String> get failedEventDebugBuffer => List.unmodifiable(_failedEventDebugBuffer);

  /// Starts a new diagnostic session as the CURRENT authenticated user.
  /// Returns null (and logs nothing) if there is no session or the insert
  /// is rejected — RLS restricts this to admins (mission section 09: "For
  /// MVP it may be Admin/Owner only"), so a non-admin calling this simply
  /// gets null back, exactly as if the feature didn't exist for them.
  Future<String?> startSession({
    String? label,
    String? roleSnapshot,
    String? appVersion,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('diagnostic_sessions')
          .insert({
            'user_id': userId,
            'label': label != null ? sanitizeSessionLabel(label, maxLength: 200) : null,
            'status': 'active',
            // IVE-COMMERCIAL-OBSERVABILITY-07A (Codex adversarial review,
            // P2, 2nd pass) — role_snapshot is app-controlled today
            // (Profile.roleLabel is one of a fixed handful of literal
            // strings), but the diagnostic_report_formatter.dart export
            // renders it raw, and nothing here structurally stopped a
            // future caller from passing arbitrary text (e.g. an embedded
            // newline forging a fake extra report entry, the same class
            // this mission already closed for every diagnostic_events
            // field). Every session-level free-text field now goes
            // through sanitizeText too, for the same reason.
            'app_version': appVersion != null ? sanitizeText(appVersion, maxLength: 50) : null,
            // IVE-COMMERCIAL-STABILITY-09O (discovered live in production;
            // Codex Gate 2nd pass, P2 ACCEPTED) — build_sha is intentionally
            // NOT a parameter of this method: it is always kBuildSha itself
            // (the compile-time constant from build_info.dart), never a
            // caller-supplied value. This closes two issues at once: (1) a
            // plain sanitizeText() was destroying every real 40-char git SHA
            // via the generic 20+-char backstop pattern (build_sha came back
            // "[redacted]" on every session); (2) even after adding a typed
            // sanitizeBuildSha() to fix that, accepting it as a free
            // parameter would trust ANY 7-40 hex-shaped caller input,
            // including a future hex-shaped secret from a different call
            // site — removing the parameter removes that surface entirely
            // rather than relying on callers to behave.
            'build_sha': sanitizeBuildSha(kBuildSha, maxLength: 100),
            'platform': kIsWeb ? 'web' : 'native',
            'role_snapshot': roleSnapshot != null ? sanitizeText(roleSnapshot, maxLength: 50) : null,
          })
          .select('id')
          .single();
      _activeSessionId = row['id'] as String?;
      return _activeSessionId;
    } on PostgrestException catch (e) {
      // IVE-COMMERCIAL-OBSERVABILITY-07B (mission section 05) — a unique-
      // violation here means the one-active-session-per-user DB invariant
      // rejected this insert because one already exists (most plausibly
      // this same client racing itself: a double-tap, or another tab
      // already active). Recover and adopt the existing row rather than
      // surfacing a raw failure — mission section 05: "no crash; detect/
      // recover gracefully; show the existing ACTIVE session".
      //
      // Checks the specific CONSTRAINT NAME, not just the bare 23505 code
      // (Codex adversarial review) — this insert never supplies its own
      // `id` (the column is DB-generated), so a primary-key collision on
      // `id` isn't reachable today, but matching the constraint by name
      // removes the ambiguity entirely rather than relying on that being
      // permanently true.
      if (e.code == '23505' && (e.message.contains(_oneActiveSessionConstraint))) {
        final existing = await findMyActiveSession();
        if (existing != null) {
          _activeSessionId = existing['id'] as String?;
          return _activeSessionId;
        }
      }
      debugPrint('[diagnostics] falha ao iniciar sessão: ${sanitizeErrorMessage(e)}');
      return null;
    } catch (e) {
      debugPrint('[diagnostics] falha ao iniciar sessão: ${sanitizeErrorMessage(e)}');
      return null;
    }
  }

  /// IVE-COMMERCIAL-OBSERVABILITY-07B (mission section 04) — deterministic
  /// recovery of the CURRENT authenticated user's own ACTIVE session, if
  /// any survives a page reload/new tab. Server-authoritative by
  /// construction: scoped to `auth.uid()` (never a client-supplied user
  /// id) and further narrowed by diagnostic_sessions_admin_manage_own's
  /// own RLS, so a non-admin/forged caller simply gets null, same as every
  /// other method here. `order by started_at desc limit 1` is defensive
  /// only (mission section 05 makes at most one ACTIVE row possible going
  /// forward); it does not itself enforce the invariant.
  Future<Map<String, dynamic>?> findMyActiveSession() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final rows = await _client
          .from('diagnostic_sessions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('started_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      return list.isEmpty ? null : list.first;
    } catch (e) {
      debugPrint('[diagnostics] falha ao recuperar sessão ativa: ${sanitizeErrorMessage(e)}');
      return null;
    }
  }

  /// Admin/support session list (mission section 08). Relies entirely on
  /// diagnostic_sessions_admin_read_all's RLS policy for authorization — a
  /// non-admin caller simply gets an empty list back (Postgrest RLS filters
  /// rows silently, it does not error), never someone else's data. See the
  /// migration's own comment: "Do not reuse client-side route guard as
  /// security boundary" — this method enforces nothing itself by design.
  Future<List<Map<String, dynamic>>> fetchAllSessions({int limit = 100}) async {
    final rows = await _client
        .from('diagnostic_sessions')
        .select()
        .order('started_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchEventsForSession(String sessionId) async {
    final rows = await _client
        .from('diagnostic_events')
        .select()
        .eq('session_id', sessionId)
        .order('occurred_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> stopSession() async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    _activeSessionId = null;
    try {
      await _client.from('diagnostic_sessions').update({
        'status': 'stopped',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('[diagnostics] falha ao encerrar sessão: ${sanitizeErrorMessage(e)}');
    }
  }

  /// Fire-and-forget: callers never await this, and it never throws. A
  /// no-op when there is no active session — events are only ever recorded
  /// during an explicit owner-started diagnostic session (mission section
  /// 02), never ambiently for every user.
  void logEvent({
    required DiagnosticCategory category,
    required String eventName,
    DiagnosticSeverity severity = DiagnosticSeverity.info,
    String? module,
    String? operation,
    String? route,
    String? status,
    int? durationMs,
    String? correlationId,
    Map<String, Object?> metadata = const {},
    Object? error,
    StackTrace? stackTrace,
    String? sourceComponent,
  }) {
    final sessionId = _activeSessionId;
    final userId = _client.auth.currentUser?.id;
    if (sessionId == null || userId == null) return;

    unawaited(_writeEvent(
      sessionId: sessionId,
      userId: userId,
      category: category,
      eventName: eventName,
      severity: severity,
      module: module,
      operation: operation,
      route: route,
      status: status,
      durationMs: durationMs,
      correlationId: correlationId,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
      sourceComponent: sourceComponent,
    ));
  }

  Future<void> _writeEvent({
    required String sessionId,
    required String userId,
    required DiagnosticCategory category,
    required String eventName,
    required DiagnosticSeverity severity,
    String? module,
    String? operation,
    String? route,
    String? status,
    int? durationMs,
    String? correlationId,
    Map<String, Object?> metadata = const {},
    Object? error,
    StackTrace? stackTrace,
    String? sourceComponent,
  }) async {
    // IVE-COMMERCIAL-OBSERVABILITY-07A (Codex adversarial review, P3) —
    // every current call site only ever passes app-controlled constants
    // here (route paths, hardcoded status strings), never raw user input,
    // so this was benign in practice — but nothing structurally guaranteed
    // that for a future call site. Every free-text field now goes through
    // sanitizeText (bounded, newline-stripped, secret-redacted) rather than
    // only event_name.
    //
    // IVE-COMMERCIAL-EXPERIENCE-12 (Phase B, Section 03) — `event_name` is
    // the one exception: it now goes through the dedicated
    // sanitizeEventName (strict lowercase-snake_case grammar), not the
    // generic sanitizeText, because sanitizeText's generic 20+-char
    // backstop was redacting legitimate event names like
    // `ai_execution_confirmation_accepted` to the literal string
    // "[redacted]" — confirmed live in production during
    // IVE-COMMERCIAL-FOUNDATION-11D's physical validation. See
    // sanitizeEventName's own doc comment in diagnostic_sanitizer.dart.
    try {
      await _client.from('diagnostic_events').insert({
        'session_id': sessionId,
        'user_id': userId,
        'severity': severity.value,
        'category': category.value,
        'module': module != null ? sanitizeText(module, maxLength: 100) : null,
        'operation': operation != null ? sanitizeText(operation, maxLength: 100) : null,
        'route': route != null ? sanitizeText(route, maxLength: 200) : null,
        'event_name': sanitizeEventName(eventName, maxLength: 200),
        'status': status != null ? sanitizeText(status, maxLength: 50) : null,
        'duration_ms': durationMs,
        'correlation_id': correlationId != null ? sanitizeCorrelationId(correlationId, maxLength: 100) : null,
        'metadata': buildSafeMetadata(metadata, allowedKeys: kDiagnosticMetadataKeys),
        'error_type': error != null ? sanitizeText(error.runtimeType.toString(), maxLength: 100) : null,
        'error_message': error != null ? sanitizeErrorMessage(error) : null,
        'error_stack': stackTrace != null ? sanitizeStackTrace(stackTrace) : null,
        'source_component': sourceComponent != null ? sanitizeText(sourceComponent, maxLength: 100) : null,
      });
    } catch (e) {
      // Never rethrow, never log-the-logger's-own-failure through this same
      // path (that would be the recursive loop mission section 14 forbids)
      // -- a plain debugPrint plus a bounded local buffer is the ceiling.
      if (_failedEventDebugBuffer.length >= _maxFailedEventBuffer) {
        _failedEventDebugBuffer.removeAt(0);
      }
      _failedEventDebugBuffer.add('$eventName: ${sanitizeErrorMessage(e)}');
      debugPrint('[diagnostics] falha ao gravar evento "$eventName": ${sanitizeErrorMessage(e)}');
    }
  }
}

/// Public helper so instrumentation call sites can generate a correlation id
/// without needing a logger instance in scope (e.g. to hand the same id to
/// both a "started" and a later "success"/"failure" event across an await
/// gap or a different widget).
String newDiagnosticCorrelationId() {
  // IVE-COMMERCIAL-STABILITY-08 — STRONGEST KNOWN CANDIDATE (Codex
  // adversarial review: SUPPORTED by exact signature match, not
  // confirmed by a live dart2js reproduction -- this repo has no local
  // Flutter SDK to build/run one) for the RangeError cluster in
  // COMMERCIAL-E2E-001 ("max must be in range 0 < max ≤ 2^32, was 0").
  // `1 << 32` is a documented dart2js web-compilation trap
  // (dart-lang/sdk#37569): its own repro is `Random.nextInt(1 << 32)`,
  // producing this EXACT error message, closed by the reporter switching
  // to the exact same `1 << 31` fix applied here. Independently confirmed
  // `1 << 32` evaluates to `1` (not 2^32) under real JavaScript semantics
  // (`node -e "console.log(1<<32)"`) -- JS's `<<` takes the shift amount
  // mod 32, so a shift by exactly 32 does not produce 2^32 the way it
  // does on the Dart VM. Regardless of whether this was the exact cause,
  // `1 << 31` is strictly safer (a shift of 31 cannot wrap) while still
  // giving 2^31 (~2.1 billion) possible values, stacked with a
  // microsecond timestamp prefix -- no meaningful loss of uniqueness for
  // a same-session correlation id.
  final rand = Random();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '-${rand.nextInt(1 << 31).toRadixString(36)}';
}
