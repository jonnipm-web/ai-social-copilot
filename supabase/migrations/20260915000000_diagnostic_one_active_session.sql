-- IVE-COMMERCIAL-OBSERVABILITY-07B — one-active-diagnostic-session-per-user
-- server invariant (mission section 05).
--
-- 07A's production smoke found that a client-side reload can orphan an
-- ACTIVE session (the app forgets it, but the row stays status='active'
-- forever) with nothing preventing a second START from creating a second
-- concurrent ACTIVE session for the same user. Client-side recovery
-- (07B section 04) reduces how often that happens, but is not itself an
-- invariant -- two tabs, or a genuine race, could still both attempt to
-- INSERT an ACTIVE row at the same moment. This migration makes the
-- database the single source of truth for "at most one ACTIVE session per
-- user", exactly per mission instruction: "Do not build a locking
-- subsystem. Do not depend on UI state for this guarantee."
--
-- A partial unique index is the smallest robust primitive for this: it
-- only constrains rows where status = 'active', so any number of 'stopped'
-- historical sessions for the same user remain unaffected, and a second
-- concurrent INSERT attempting a second ACTIVE row for that user fails
-- atomically at the database level (unique_violation, SQLSTATE 23505) --
-- application code (diagnostic_logger_service.dart's startSession) catches
-- that specific error and recovers/adopts the existing row instead of
-- surfacing a raw failure.
--
-- Pre-deploy read-only check performed 2026-09-14: zero ACTIVE sessions
-- exist in production at all (the one row from OBSERVABILITY-SMOKE-001 is
-- already 'stopped'), so this index can be created with no reconciliation
-- step and no pre-existing violation risk.
CREATE UNIQUE INDEX diagnostic_sessions_one_active_per_user
  ON public.diagnostic_sessions (user_id)
  WHERE status = 'active';
