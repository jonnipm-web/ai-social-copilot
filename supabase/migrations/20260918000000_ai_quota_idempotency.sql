-- IVE-COMMERCIAL-QUOTA-HARDENING-13 — server-authoritative idempotency for
-- AI quota reservation.
--
-- NOT APPLIED IN THIS MISSION — per mission Section 30 ("Do not apply
-- production migration in this mission"). Prepared for Codex Gate 1
-- adversarial review and for a future controlled-deploy mission.
--
-- PROBLEM (mission Section 04): try_reserve_ai_quota() (20260910190000)
-- has no concept of "this is the same intentional operation retried" —
-- every call unconditionally increments public.ai_usage.request_count.
-- The only guard against a double-charge today is a CLIENT-SIDE
-- synchronous flag (AiExecutionController.isBusy), which protects a
-- single controller instance from a double-click, but does nothing
-- against: a second browser tab, a network-layer retry, a client refresh
-- after the server already reserved but before the response arrived, or
-- any other replay of the same logical request.
--
-- REVISION HISTORY WITHIN THIS (never-applied) MIGRATION: Codex Gate 1's
-- adversarial review of the FIRST version of this file (scoped only to
-- (user_id, idempotency_key)) found a real quota-bypass it introduced:
-- a client could replay the SAME key against a DIFFERENT Edge Function,
-- or in a LATER month, and the server would treat it as an
-- already-successful "idempotent replay" — allowed=true — WITHOUT ever
-- incrementing usage for that genuinely new operation. Worse, retrying a
-- key whose reservation had been REFUNDED (i.e. the original attempt
-- failed) also matched as a "replay," letting a client get an unlimited
-- number of free, uncharged AI calls by reusing one key after any
-- failure. Both are fixed below by scoping the reservation identity to
-- (user_id, idempotency_key, operation_type, period_start) — never just
-- the key alone — and by treating a 'refunded' row as "this key's
-- attempt failed, allow a genuine new attempt" rather than "already
-- handled."
--
-- DESIGN (mission Sections 04-07):
--   - ONE ROW PER (user_id, idempotency_key, operation_type,
--     period_start) — a client generates ONE key per intentional
--     operation (mission Section 05) and reuses it for every retry of
--     that SAME operation; a genuinely new analysis gets a new key.
--     operation_type identifies WHICH Edge Function/action the key was
--     issued for (e.g. 'gap-analysis', 'context-copilot') — required
--     whenever a key is supplied, precisely so one key cannot be replayed
--     against a different operation and be mistaken for that operation's
--     own already-successful reservation. period_start is part of the
--     scope too, so a key captured and replayed in a later calendar
--     month cannot be mistaken for "already reserved this month" — it
--     simply doesn't match any row for the new period and proceeds to a
--     real, correctly-charged reservation instead.
--   - The UNIQUE constraint on (user_id, idempotency_key, operation_type,
--     period_start) is the concurrency guard itself — not a
--     SELECT-before-INSERT (mission Section 06 explicitly forbids that
--     pattern). Two concurrent requests racing to claim the same tuple
--     can only have one INSERT succeed; Postgres serializes on the
--     unique index. operation_type is NOT NULL (no default) specifically
--     because Postgres treats NULLs as mutually DISTINCT in a unique
--     index — an nullable operation_type would silently defeat this
--     exact uniqueness guarantee for any caller that omitted it.
--   - Ownership derived from auth.uid() only (SECURITY DEFINER function
--     identity), never from a client-supplied user id — same rule the
--     existing quota functions already follow.
--   - BACKWARD COMPATIBLE: the idempotency key parameter on both
--     functions defaults to NULL. A legacy call (no key, no operation
--     type) behaves EXACTLY as before this migration — unconditional
--     reserve/refund. This is a deliberate, temporary compatibility path
--     (mission Section 10) — the actual removal point is a future
--     mission once every one of the 16 quota-consuming Edge Functions has
--     been confirmed to always send a key from an updated client; until
--     then an old cached client build (or a request from before this
--     mission shipped) still functions, just without idempotency
--     protection for that one call. Supplying a key WITHOUT an
--     operation_type is rejected outright (see 'invalid_request' below)
--     rather than silently degrading protection.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.refund_ai_quota(uuid, text);
--   DROP FUNCTION IF EXISTS public.try_reserve_ai_quota(uuid, text);
--   -- Recreate the pre-13 zero-arg versions from 20260910190000 if
--   -- reverting fully.
--   DROP TABLE IF EXISTS public.ai_quota_reservations;

CREATE TABLE IF NOT EXISTS public.ai_quota_reservations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  idempotency_key uuid NOT NULL,
  operation_type  text NOT NULL,
  period_start    date NOT NULL,
  status          text NOT NULL DEFAULT 'reserved'
                    CHECK (status IN ('reserved', 'refunded')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  refunded_at     timestamptz,
  CONSTRAINT ai_quota_reservations_unique_key
    UNIQUE (user_id, idempotency_key, operation_type, period_start)
);

CREATE INDEX IF NOT EXISTS idx_ai_quota_reservations_user_period
  ON public.ai_quota_reservations (user_id, period_start);

ALTER TABLE public.ai_quota_reservations ENABLE ROW LEVEL SECURITY;

-- Read-only for the row's own user (auditability — mission Section 06:
-- "where useful: refund state"). No INSERT/UPDATE/DELETE policy for
-- anyone but service_role/SECURITY DEFINER functions, same pattern as
-- public.ai_usage itself (20260910190000).
DROP POLICY IF EXISTS "users_read_own_quota_reservations" ON public.ai_quota_reservations;
CREATE POLICY "users_read_own_quota_reservations" ON public.ai_quota_reservations
  FOR SELECT USING (auth.uid() = user_id);

-- ── try_reserve_ai_quota(p_idempotency_key, p_operation_type) ──────────────
-- Extends the existing function (does not replace its identity/plan
-- resolution logic — see 20260910190000 for that rationale) with an
-- optional idempotency key + operation type. Both NULL preserves the
-- exact pre-13 behavior.
--
-- DELIBERATELY DROPPED AND RECREATED rather than left as a second
-- overload: CREATE OR REPLACE only replaces a function with the IDENTICAL
-- parameter list, so adding parameters would otherwise create a SECOND,
-- separate zero-arg-vs-two-args-with-defaults overload. Plain SQL
-- resolves that unambiguously (exact arity wins), but PostgREST's RPC
-- dispatch (what supabase-js's .rpc() actually goes through) resolves
-- overloads by matching the JSON body's keys against each candidate's
-- parameters, and an EMPTY body can match both a genuine zero-arg
-- function and an all-defaults function — a documented PostgREST
-- ambiguity ("Could not choose the best candidate function"). Dropping
-- the old signature first guarantees exactly one function named
-- try_reserve_ai_quota exists at any time, so there is no dispatch
-- ambiguity for either an old caller (empty body -> both params default
-- to NULL, identical behavior to before this migration) or a new caller
-- (body includes both).
DROP FUNCTION IF EXISTS public.try_reserve_ai_quota();
DROP FUNCTION IF EXISTS public.try_reserve_ai_quota(uuid);
--
-- Race-safety proof: the reservation INSERT ... ON CONFLICT DO NOTHING
-- happens BEFORE the usage increment, and its result (whether a row was
-- actually inserted) gates whether the increment runs at all. Two
-- concurrent transactions with the same (user_id, idempotency_key,
-- operation_type, period_start) can both attempt the INSERT; Postgres's
-- unique index guarantees only one commits the insert, the other observes
-- the conflict and gets NULL back from RETURNING — so only the winner
-- ever reaches the usage increment. This is the standard Postgres
-- upsert-based idempotency pattern, not a SELECT-then-INSERT race.
CREATE OR REPLACE FUNCTION public.try_reserve_ai_quota(
  p_idempotency_key uuid DEFAULT NULL,
  p_operation_type  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id         uuid := auth.uid();
  v_role            text;
  v_limit           int;
  v_period          date := date_trunc('month', now())::date;
  v_count           int;
  v_reservation_id  uuid;
  v_existing_status text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  -- Codex Gate 1 P1 fix — a key with no operation type would defeat the
  -- whole point of scoping uniqueness by operation (a NULL
  -- operation_type could never collide with itself under Postgres's
  -- NULLs-are-distinct rule for unique indexes, silently disabling
  -- duplicate detection). Fail closed rather than silently degrade.
  IF p_idempotency_key IS NOT NULL AND
     (p_operation_type IS NULL OR btrim(p_operation_type) = '') THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_request');
  END IF;

  SELECT role, monthly_limit INTO v_role, v_limit
  FROM public.profiles WHERE id = v_user_id;

  IF v_role IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'no_profile');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    -- Codex Gate 1 P1 fix — a previously REFUNDED reservation under this
    -- exact (key, operation, period) means that attempt failed and cost
    -- nothing real. Treating it as "already reserved" would let a client
    -- retry indefinitely after every failure and get a free, uncharged
    -- allowed=true every time (the Edge Function would then make a real,
    -- unrewarded Groq call). Clear it out so the retry below gets a
    -- GENUINE new reservation instead.
    SELECT status INTO v_existing_status
    FROM public.ai_quota_reservations
    WHERE user_id = v_user_id
      AND idempotency_key = p_idempotency_key
      AND operation_type = p_operation_type
      AND period_start = v_period
    FOR UPDATE;

    IF v_existing_status = 'refunded' THEN
      DELETE FROM public.ai_quota_reservations
      WHERE user_id = v_user_id
        AND idempotency_key = p_idempotency_key
        AND operation_type = p_operation_type
        AND period_start = v_period;
    END IF;

    INSERT INTO public.ai_quota_reservations
      (user_id, idempotency_key, operation_type, period_start, status)
    VALUES (v_user_id, p_idempotency_key, p_operation_type, v_period, 'reserved')
    ON CONFLICT (user_id, idempotency_key, operation_type, period_start) DO NOTHING
    RETURNING id INTO v_reservation_id;

    IF v_reservation_id IS NULL THEN
      -- This exact (key, operation, period) tuple is already reserved —
      -- a genuine retry of a currently-successful reservation, or this
      -- request lost the race to a concurrent duplicate. Do NOT reserve
      -- again. Replaying the SAME key against a DIFFERENT operation_type
      -- or in a DIFFERENT period_start never reaches this branch at all —
      -- it simply doesn't match this WHERE clause, so it falls through
      -- to a real, correctly-charged reservation below instead.
      SELECT request_count INTO v_count
      FROM public.ai_usage WHERE user_id = v_user_id AND period_start = v_period;
      RETURN jsonb_build_object(
        'allowed', true, 'idempotent_replay', true,
        'used', COALESCE(v_count, 0), 'limit', v_limit, 'role', v_role
      );
    END IF;
  END IF;

  INSERT INTO public.ai_usage (user_id, period_start, request_count)
  VALUES (v_user_id, v_period, 0)
  ON CONFLICT (user_id, period_start) DO NOTHING;

  UPDATE public.ai_usage
  SET request_count = request_count + 1, updated_at = now()
  WHERE user_id = v_user_id AND period_start = v_period AND request_count < v_limit
  RETURNING request_count INTO v_count;

  IF v_count IS NULL THEN
    -- Quota exceeded. If we just claimed a reservation row above for this
    -- attempt, release it — a denied attempt must not permanently occupy
    -- the key (mission Section 07: "Quota exceeded: return
    -- QUOTA_EXCEEDED", not a silently-poisoned key a legitimate retry
    -- after upgrading plan could never reuse).
    IF v_reservation_id IS NOT NULL THEN
      DELETE FROM public.ai_quota_reservations WHERE id = v_reservation_id;
    END IF;
    SELECT request_count INTO v_count
    FROM public.ai_usage WHERE user_id = v_user_id AND period_start = v_period;
    RETURN jsonb_build_object(
      'allowed', false, 'reason', 'quota_exceeded',
      'used', v_count, 'limit', v_limit, 'role', v_role
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed', true, 'idempotent_replay', false,
    'used', v_count, 'limit', v_limit, 'role', v_role
  );
END;
$function$;

-- ── refund_ai_quota(p_idempotency_key, p_operation_type) ────────────────────
-- Idempotent refund: tied to the reservation row's own state transition
-- (reserved -> refunded), not a blind decrement, and scoped by the SAME
-- (key, operation, period) tuple as the reservation it's refunding — a
-- refund call carrying the wrong operation_type for this key must not be
-- able to refund a different operation's reservation. The conditional
-- UPDATE (... AND status = 'reserved') is itself the concurrency guard —
-- a retried or concurrently-duplicated refund call for the same tuple can
-- only ever flip that row once; ROW_COUNT tells us whether THIS call was
-- the one that did it.
--
-- Same drop-and-recreate reasoning as try_reserve_ai_quota above — avoids
-- a PostgREST overload-dispatch ambiguity between a genuine zero-arg
-- function and an all-defaults function.
DROP FUNCTION IF EXISTS public.refund_ai_quota();
DROP FUNCTION IF EXISTS public.refund_ai_quota(uuid);
CREATE OR REPLACE FUNCTION public.refund_ai_quota(
  p_idempotency_key uuid DEFAULT NULL,
  p_operation_type  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_period  date := date_trunc('month', now())::date;
  v_updated int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  -- A refund is already a best-effort failure-path cleanup step (see
  -- quota.ts's own doc comment) — a malformed/incomplete pair degrades to
  -- the legacy unconditional decrement rather than being rejected, unlike
  -- try_reserve_ai_quota's hard fail-closed on the same condition.
  IF p_idempotency_key IS NOT NULL AND
     (p_operation_type IS NULL OR btrim(p_operation_type) = '') THEN
    p_idempotency_key := NULL;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    UPDATE public.ai_quota_reservations
    SET status = 'refunded', refunded_at = now()
    WHERE user_id = v_user_id
      AND idempotency_key = p_idempotency_key
      AND operation_type = p_operation_type
      AND period_start = v_period
      AND status = 'reserved';
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 0 THEN
      -- No reservation exists for this exact tuple (nothing to refund —
      -- e.g. a refund call for a key that was never reserved, or
      -- fail-closed against refund-before-reserve), or it was already
      -- refunded once (a retried refund) — either way, do not decrement
      -- usage again.
      RETURN;
    END IF;
  END IF;

  UPDATE public.ai_usage
  SET request_count = GREATEST(request_count - 1, 0), updated_at = now()
  WHERE user_id = v_user_id AND period_start = v_period;
END;
$function$;

-- Same authorization posture as the functions being extended — real
-- logged-in users only, never anon/public.
REVOKE ALL ON FUNCTION public.try_reserve_ai_quota(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.refund_ai_quota(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.try_reserve_ai_quota(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_quota(uuid, text) TO authenticated;

-- BACKWARD COMPATIBILITY (mission Section 10): exactly one function of
-- each name now exists (the old zero-arg and one-arg signatures were
-- dropped above), with both parameters defaulting to NULL. An Edge
-- Function deployed before this migration and calling
-- .rpc('try_reserve_ai_quota') with an empty body keeps working
-- identically — same unconditional-reserve behavior as before, just
-- routed through the new function body. The REMOVAL POINT for this
-- compatibility default is a future mission, once every one of the 16
-- quota-consuming Edge Functions is confirmed to always send a real
-- idempotency key + operation type: at that point both parameters should
-- become NOT NULL / required, so a client that skips them can no longer
-- silently bypass idempotency forever.
