-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Migration 00012
-- Codex CLASS D R6 P1 fix: localize-content daily cap bypassable via concurrent requests.
--
-- PROBLEM (supabase/functions/localize-content/index.ts, lines 122-152):
--   The Edge Function reads the translation count once per request:
--     const fresh = DAILY_FRESH_TRANSLATION_CAP - await d.countFreshToday(userId);
--   Two concurrent requests both read the same count before either writes to
--   content_localizations, so both compute the same freshBudget and both
--   proceed to call the translation provider — effectively doubling (or N×)
--   the per-user quota for that second window. With a 300/day cap, a burst
--   of N concurrent requests each with 25 rows could generate N×25 LLM calls
--   instead of a total of at most 25 (or however many were available).
--
-- FIX:
--   Add a separate quota-ledger table (localization_quota) and an atomic
--   reservation function (try_reserve_localization_quota) that uses a
--   pg_advisory_xact_lock to serialize concurrent calls even when no row
--   exists yet (FOR UPDATE cannot lock a non-existent row).
--
--   The Edge Function calls the RPC once per request to reserve exactly
--   as many slots as there are candidate rows (≤ 25). Concurrent requests
--   for the same user serialize at the DB lock, so the second caller sees
--   the updated used count. Over-reservation (cache hits + same-language
--   rows don't consume reserved slots) is intentional — it is conservative
--   and bounded to at most MAX_IDS_PER_REQUEST (25) per request.
--
-- IDEMPOTENT: safe to re-run (CREATE TABLE IF NOT EXISTS + CREATE OR REPLACE).
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

SET search_path = public, pg_catalog, pg_temp;

-- ── Quota ledger ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.localization_quota (
  user_id  uuid  NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day      date  NOT NULL DEFAULT CURRENT_DATE,
  used     int   NOT NULL DEFAULT 0 CHECK (used >= 0),
  PRIMARY KEY (user_id, day)
);

ALTER TABLE public.localization_quota ENABLE ROW LEVEL SECURITY;

-- Clients cannot read or write this table directly (same model as content_localizations).
REVOKE ALL ON public.localization_quota FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.localization_quota TO service_role;

-- ── Atomic reservation function ───────────────────────────────────────────────
-- Reserves up to p_requested translation slots for p_user_id on CURRENT_DATE.
-- Returns the actual number reserved (0 when quota is already exhausted).
--
-- Serialization: pg_advisory_xact_lock(hashtext(user_id), hashtext(CURRENT_DATE))
-- ensures that even the very first INSERT for a (user, day) pair is atomic —
-- FOR UPDATE alone cannot lock a non-existent row, which would allow two
-- concurrent first-call transactions to both see used=0 and both insert.
-- The advisory lock is transaction-scoped (released on commit/rollback) and
-- safe with PgBouncer in transaction pooling mode.
--
-- p_cap: pass DAILY_FRESH_TRANSLATION_CAP from the Edge Function so the
-- cap can be changed in code without a new migration.
CREATE OR REPLACE FUNCTION public.try_reserve_localization_quota(
  p_user_id   uuid,
  p_requested int,
  p_cap       int DEFAULT 300
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_used      int;
  v_available int;
  v_reserve   int;
BEGIN
  IF p_requested <= 0 THEN
    RETURN 0;
  END IF;

  -- Acquire a per-(user, day) advisory lock before reading the counter.
  -- hashtext returns int4; pg_advisory_xact_lock accepts two int4 arguments
  -- (the two-argument form), which is safe and avoids any cast overflow.
  PERFORM pg_advisory_xact_lock(
    hashtext(p_user_id::text),
    hashtext(CURRENT_DATE::text)
  );

  SELECT COALESCE(used, 0) INTO v_used
  FROM   public.localization_quota
  WHERE  user_id = p_user_id AND day = CURRENT_DATE;

  IF v_used IS NULL THEN
    v_used := 0;
  END IF;

  v_available := GREATEST(0, p_cap - v_used);
  v_reserve   := LEAST(p_requested, v_available);

  IF v_reserve > 0 THEN
    INSERT INTO public.localization_quota (user_id, day, used)
    VALUES (p_user_id, CURRENT_DATE, v_reserve)
    ON CONFLICT (user_id, day) DO UPDATE
      SET used = public.localization_quota.used + v_reserve;
  END IF;

  RETURN v_reserve;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.try_reserve_localization_quota(uuid, int, int)
  FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.try_reserve_localization_quota(uuid, int, int)
  TO service_role;
