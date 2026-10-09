-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Migration 00012 (revised after Codex R7)
-- Codex CLASS D R6 P1 fix: localize-content daily cap bypassable via concurrent requests.
--
-- PROBLEM (supabase/functions/localize-content/index.ts, lines 122-152):
--   1. count-then-decrement race: two concurrent requests both read the same stale count
--      before either writes, consuming 2× (or N×) the intended cap.
--   2. First version of this migration used CURRENT_DATE (calendar day) while the
--      countFreshToday fallback uses a rolling 24-hour window — a bypass near midnight.
--   3. First version reserved rows.length upfront, before cache hits are resolved,
--      making each request consume up to 25 slots even if all rows are already cached
--      (user-visible self-DoS that prevents future uncached translations).
--
-- FIX:
--   Append-only quota log keyed by (user_id, reserved_at timestamptz). Each LLM call
--   reserves exactly one slot atomically with try_reserve_localization_slot(), which
--   uses pg_advisory_xact_lock to serialize concurrent callers per user even before
--   the first row exists. The rolling 24-hour window matches countFreshToday exactly.
--   The Edge Function calls this RPC once per LLM attempt (not upfront per request),
--   so cache hits and same-language rows never consume quota.
--
-- REPLACES earlier version of this migration (never APPLIED_PRODUCTION; LAB only).
-- The old names (localization_quota table, try_reserve_localization_quota function)
-- are dropped if they exist, so re-running is safe.
--
-- IDEMPOTENT: safe to re-run (CREATE TABLE IF NOT EXISTS + CREATE OR REPLACE).
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

SET search_path = public, pg_catalog, pg_temp;

-- Drop old names from the first version of this migration (LAB only, never applied).
DROP FUNCTION IF EXISTS public.try_reserve_localization_quota(uuid, int, int);
DROP TABLE IF EXISTS public.localization_quota;

-- ── Append-only quota log ─────────────────────────────────────────────────────
-- One row per reserved translation slot. The rolling 24-hour window is computed
-- at query time so no daily reset job is needed. Old rows (> 24h) are inert and
-- can be purged by a maintenance job later without affecting correctness.
CREATE TABLE IF NOT EXISTS public.localization_quota_log (
  id          bigserial   PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reserved_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_localization_quota_log_user_time
  ON public.localization_quota_log (user_id, reserved_at);

ALTER TABLE public.localization_quota_log ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.localization_quota_log FROM anon, authenticated;
GRANT  SELECT, INSERT ON public.localization_quota_log TO service_role;
GRANT  USAGE, SELECT ON SEQUENCE public.localization_quota_log_id_seq TO service_role;

-- ── Per-slot atomic reservation function ─────────────────────────────────────
-- Reserves exactly one translation slot for p_user_id in a rolling 24-hour
-- window. Returns TRUE when the slot was granted, FALSE when quota is exhausted.
--
-- Called once per LLM attempt (not upfront per request) so cache hits and
-- same-language rows never consume quota.
--
-- Serialization: pg_advisory_xact_lock(hashtext(user_id), 16) acquires a
-- transaction-scoped lock per user+namespace before the COUNT query. Two
-- concurrent first-time calls for the same user cannot both see count=0 and
-- both insert — the second waits for the first to commit. The lock is
-- transaction-scoped (released on commit/rollback) and safe with PgBouncer in
-- transaction-pooling mode.
--
-- Namespace constant 16 namespaces the lock key to avoid collision with other
-- per-user advisory locks in this project.
CREATE OR REPLACE FUNCTION public.try_reserve_localization_slot(
  p_user_id uuid,
  p_cap     int DEFAULT 300
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_used int;
BEGIN
  -- Per-user advisory lock (two-int4 form; namespace 16 = localization quota).
  PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text), 16);

  SELECT COUNT(*) INTO v_used
  FROM   public.localization_quota_log
  WHERE  user_id     = p_user_id
    AND  reserved_at >= now() - interval '24 hours';

  IF v_used >= p_cap THEN
    RETURN false;
  END IF;

  INSERT INTO public.localization_quota_log (user_id) VALUES (p_user_id);
  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.try_reserve_localization_slot(uuid, int)
  FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.try_reserve_localization_slot(uuid, int)
  TO service_role;
