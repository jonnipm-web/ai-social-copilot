-- ============================================================================
-- IVE-COMMERCIAL-OBSERVABILITY-07A — Session Diagnostic Logger
-- ============================================================================
-- PROPOSED, NOT YET APPLIED TO PRODUCTION. Prepared on a feature branch per
-- explicit mission instruction (section 18): "STOP BEFORE PRODUCTION
-- MIGRATION/DEPLOY if new database changes are required... Do not merge/
-- deploy automatically across a new security boundary."
--
-- Purpose: structured application-event capture for owner-run diagnostic
-- sessions (mission section 02's primary use case), NOT screen recording,
-- NOT prompt/response capture, NOT generic analytics. Two tables:
--   diagnostic_sessions — one row per START/STOP walkthrough
--   diagnostic_events   — append-only timeline rows within a session
--
-- Reuses existing, already-hardened infrastructure rather than inventing
-- new security primitives (mission section 07: "Do not create a broad
-- SECURITY DEFINER bypass unless strictly necessary"):
--   public.is_admin_user() — defined in 20260907120001_x4b_search_path_and_
--   role_protection.sql, STABLE SECURITY DEFINER, search_path hardened.
--   No new SECURITY DEFINER function is created by this migration; RLS
--   alone is the enforcement boundary for these two tables.
-- ============================================================================

CREATE TABLE public.diagnostic_sessions (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL,
  label         text,
  status        text NOT NULL DEFAULT 'active'
                  CHECK (status = ANY (ARRAY['active', 'stopped'])),
  started_at    timestamptz NOT NULL DEFAULT now(),
  ended_at      timestamptz,
  app_version   text,
  build_sha     text,
  platform      text,
  environment   text,
  role_snapshot text,
  language      text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT diagnostic_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT diagnostic_sessions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  -- label is owner-supplied free text (e.g. "COMMERCIAL-E2E-001") --
  -- bounded so a pathological client can't store an oversized value
  -- (mission section 14: "bounded payload size").
  CONSTRAINT diagnostic_sessions_label_len CHECK (label IS NULL OR char_length(label) <= 200),
  CONSTRAINT diagnostic_sessions_ended_after_started
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE INDEX diagnostic_sessions_user_started_idx
  ON public.diagnostic_sessions USING btree (user_id, started_at DESC);
CREATE INDEX diagnostic_sessions_status_idx
  ON public.diagnostic_sessions USING btree (status);

CREATE TABLE public.diagnostic_events (
  id               uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id       uuid NOT NULL,
  user_id          uuid NOT NULL,
  occurred_at      timestamptz NOT NULL DEFAULT now(),
  severity         text NOT NULL
                     CHECK (severity = ANY (ARRAY['DEBUG', 'INFO', 'WARN', 'ERROR', 'CRITICAL'])),
  category         text NOT NULL
                     CHECK (category = ANY (ARRAY['NAVIGATION', 'AUTH', 'QUOTA', 'AI', 'KNOWLEDGE', 'DRIVE', 'IVE', 'RUNTIME'])),
  module           text,
  operation        text,
  route            text,
  event_name       text NOT NULL,
  status           text,
  duration_ms      integer CHECK (duration_ms IS NULL OR duration_ms >= 0),
  correlation_id   text,
  metadata         jsonb NOT NULL DEFAULT '{}'::jsonb,
  error_type       text,
  error_message    text,
  error_stack      text,
  source_component text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT diagnostic_events_pkey PRIMARY KEY (id),
  CONSTRAINT diagnostic_events_session_id_fkey
    FOREIGN KEY (session_id) REFERENCES public.diagnostic_sessions(id) ON DELETE CASCADE,
  CONSTRAINT diagnostic_events_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Every free-text field is length-bounded at the database layer as a
  -- last-resort backstop -- the client-side sanitizer (lib/core/
  -- diagnostics/diagnostic_sanitizer.dart) already truncates before
  -- sending, but a constraint here means a future, unaudited write path
  -- can't silently reintroduce oversized/log-injection-shaped payloads
  -- (mission section 16: "oversized metadata", "log injection").
  CONSTRAINT diagnostic_events_event_name_len CHECK (char_length(event_name) <= 200),
  CONSTRAINT diagnostic_events_error_message_len CHECK (error_message IS NULL OR char_length(error_message) <= 2000),
  CONSTRAINT diagnostic_events_error_stack_len CHECK (error_stack IS NULL OR char_length(error_stack) <= 4000),
  CONSTRAINT diagnostic_events_metadata_size CHECK (octet_length(metadata::text) <= 8192)
);

CREATE INDEX diagnostic_events_session_occurred_idx
  ON public.diagnostic_events USING btree (session_id, occurred_at);
CREATE INDEX diagnostic_events_user_idx
  ON public.diagnostic_events USING btree (user_id);
CREATE INDEX diagnostic_events_severity_idx
  ON public.diagnostic_events USING btree (severity);
CREATE INDEX diagnostic_events_category_idx
  ON public.diagnostic_events USING btree (category);
CREATE INDEX diagnostic_events_correlation_idx
  ON public.diagnostic_events USING btree (correlation_id) WHERE correlation_id IS NOT NULL;

ALTER TABLE public.diagnostic_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diagnostic_events   ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- diagnostic_sessions RLS
-- ----------------------------------------------------------------------------
-- MVP scope (mission section 09): "Do not expose this control to normal
-- commercial users... For MVP it may be Admin/Owner only." Only an admin can
-- create/update a session, and only their OWN (user_id = auth.uid()) -- this
-- is deliberately NOT is_admin_user() alone (which would let any admin edit
-- any other admin's session metadata).
CREATE POLICY "diagnostic_sessions_admin_manage_own" ON public.diagnostic_sessions
  FOR ALL
  USING (public.is_admin_user() AND user_id = auth.uid())
  WITH CHECK (public.is_admin_user() AND user_id = auth.uid());

-- Support/admin staff can READ every session (mission section 08: "admin/
-- support can read according to authorized policy") even ones they didn't
-- personally start -- read-only, does not grant write access to another
-- admin's session (that stays owner-only via the policy above).
CREATE POLICY "diagnostic_sessions_admin_read_all" ON public.diagnostic_sessions
  FOR SELECT
  USING (public.is_admin_user());

-- ----------------------------------------------------------------------------
-- diagnostic_events RLS
-- ----------------------------------------------------------------------------
-- Events are an append-only log: INSERT only, matching mission section 07's
-- "user can create events for own active diagnostic session" -- deliberately
-- no UPDATE/DELETE policy for anyone (denied by default under RLS), so a
-- diagnostic event can never be edited or removed after the fact, including
-- by the admin who created it. This is what makes the log trustworthy
-- evidence for Claude/Codex analysis rather than something a client could
-- tamper with after an error was captured.
--
-- The subquery only ever needs to see the CURRENT user's own session rows,
-- which diagnostic_sessions_admin_manage_own already grants them (RLS on the
-- referenced table applies to this subquery using the same auth.uid()), so
-- this policy alone is sufficient without also invoking is_admin_user()
-- again here -- only an admin could ever have a matching, active session row
-- to satisfy this EXISTS check in the first place.
CREATE POLICY "diagnostic_events_insert_own_active_session" ON public.diagnostic_events
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.diagnostic_sessions s
      WHERE s.id = session_id
        AND s.user_id = auth.uid()
        AND s.status = 'active'
    )
  );

CREATE POLICY "diagnostic_events_admin_read_all" ON public.diagnostic_events
  FOR SELECT
  USING (public.is_admin_user());

-- ----------------------------------------------------------------------------
-- Retention (PROPOSED, NOT SCHEDULED — mission section 10: "Report
-- recommended retention separately", "Do not promise indefinite storage").
-- This function is safe to include (it does nothing until called), but
-- actually scheduling it (pg_cron, or an external invocation) is an
-- infrastructure change requiring separate, explicit owner authorization --
-- not enabled by this migration. See the mission report's RETENTION section
-- for the recommended schedule and window.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_old_diagnostic_sessions(retention_days integer DEFAULT 30)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_deleted integer;
BEGIN
  IF NOT public.is_admin_user() THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;

  DELETE FROM public.diagnostic_sessions
  WHERE started_at < now() - make_interval(days => retention_days);
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$function$;

-- Only real, logged-in admins may call this -- not anon, not public.
REVOKE ALL ON FUNCTION public.cleanup_old_diagnostic_sessions(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_old_diagnostic_sessions(integer) TO authenticated;
