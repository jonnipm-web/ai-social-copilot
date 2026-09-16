-- ============================================================================
-- IVE-COMMERCIAL-STABILITY-09O-SHA — Event-Level Build Identity
-- ============================================================================
-- Purpose (mission section 01): diagnostic_sessions.build_sha represents
-- SESSION CREATION time only. A diagnostic session can survive multiple
-- production deploys (confirmed live during STABILITY-09O-R's own post-
-- deploy proof: a session created during one deploy captured a genuine
-- STABILITY-09 crash several deploys later, and the session's build_sha no
-- longer matched the build that actually produced that event). This
-- migration adds the event-level column so the symbolication chain
-- (diagnostic_event -> exact build_sha -> matching encrypted source-map
-- artifact) is authoritative per-event, not per-session.
--
-- Smallest additive change (mission section 06): one nullable text column,
-- matching diagnostic_sessions.build_sha's own existing CHECK-constraint
-- shape exactly (bounded length, no CR/LF — same reasoning as that
-- column's own comment: report-injection defense-in-depth at the database
-- layer, independent of the client-side sanitizer). No historical row is
-- rewritten; existing diagnostic_events rows simply have build_sha = NULL,
-- honestly reflecting that their true originating build was never
-- recorded. No RLS change: diagnostic_events' existing policies
-- (diagnostic_events_insert_own_active_session, diagnostic_events_admin_
-- read_all) already govern the whole row, including this new column, with
-- no need for a per-column policy. No new SECURITY DEFINER function, no
-- broad grants.
-- ============================================================================

-- IVE-COMMERCIAL-STABILITY-09O-SHA (Codex Gate, P2 ACCEPTED) — ADD COLUMN
-- with no DEFAULT is already effectively instant (no table rewrite,
-- Postgres 11+), but a plain `ADD CONSTRAINT ... CHECK (...)` scans and
-- validates every EXISTING row before committing, taking a lock strong
-- enough to block concurrent writes for the duration of that scan. Added
-- NOT VALID first (near-instant: only new/updated rows are checked from
-- this point on) and validated in a separate statement, which takes the
-- much weaker SHARE UPDATE EXCLUSIVE lock — concurrent INSERTs (i.e. the
-- app's own normal diagnostic writes) are not blocked while existing rows
-- are scanned.
ALTER TABLE public.diagnostic_events
  ADD COLUMN build_sha text;

ALTER TABLE public.diagnostic_events
  ADD CONSTRAINT diagnostic_events_build_sha_len
    CHECK (build_sha IS NULL OR char_length(build_sha) <= 100) NOT VALID;

ALTER TABLE public.diagnostic_events
  ADD CONSTRAINT diagnostic_events_build_sha_no_newline
    CHECK (build_sha IS NULL OR build_sha !~ '[\r\n]') NOT VALID;

ALTER TABLE public.diagnostic_events
  VALIDATE CONSTRAINT diagnostic_events_build_sha_len;

ALTER TABLE public.diagnostic_events
  VALIDATE CONSTRAINT diagnostic_events_build_sha_no_newline;
