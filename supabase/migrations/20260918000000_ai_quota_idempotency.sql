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
-- DESIGN (mission Sections 04-07):
--   - ONE ROW PER (user_id, idempotency_key) — a client generates ONE
--     key per intentional operation (mission Section 05) and reuses it
--     for every retry of that SAME operation; a genuinely new analysis
--     gets a new key.
--   - The UNIQUE constraint on (user_id, idempotency_key) is the
--     concurrency guard itself — not a SELECT-before-INSERT (mission
--     Section 06 explicitly forbids that pattern). Two concurrent
--     requests racing to claim the same key can only have one INSERT
--     succeed; Postgres serializes on the unique index.
--   - Ownership derived from auth.uid() only (SECURITY DEFINER function
--     identity), never from a client-supplied user id — same rule the
--     existing quota functions already follow.
--   - BACKWARD COMPATIBLE: the idempotency key parameter on both
--     functions defaults to NULL. A legacy call (no key) behaves
--     EXACTLY as before this migration — unconditional reserve/refund.
--     This is a deliberate, temporary compatibility path (mission
--     Section 10) — the actual removal point is a future mission once
--     every one of the 16 quota-consuming Edge Functions has been
--     confirmed to always send a key from an updated client; until then
--     an old cached client build (or a request from before this mission
--     shipped) still functions, just without idempotency protection for
--     that one call.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.refund_ai_quota(uuid);
--   DROP FUNCTION IF EXISTS public.try_reserve_ai_quota(uuid);
--   -- Recreate the pre-13 zero-arg versions from 20260910190000 if
--   -- reverting fully.
--   DROP TABLE IF EXISTS public.ai_quota_reservations;

CREATE TABLE IF NOT EXISTS public.ai_quota_reservations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  idempotency_key uuid NOT NULL,
  operation_type  text,
  period_start    date NOT NULL,
  status          text NOT NULL DEFAULT 'reserved'
                    CHECK (status IN ('reserved', 'refunded')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  refunded_at     timestamptz,
  CONSTRAINT ai_quota_reservations_unique_key UNIQUE (user_id, idempotency_key)
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

-- ── try_reserve_ai_quota(p_idempotency_key) ─────────────────────────────────
-- Extends the existing function (does not replace its identity/plan
-- resolution logic — see 20260910190000 for that rationale) with an
-- optional idempotency key. NULL preserves the exact pre-13 behavior.
--
-- DELIBERATELY DROPPED AND RECREATED rather than left as a second
-- overload: CREATE OR REPLACE only replaces a function with the IDENTICAL
-- parameter list, so adding a parameter would otherwise create a SECOND,
-- separate zero-arg-vs-one-arg-with-default overload. Plain SQL resolves
-- that unambiguously (exact arity wins), but PostgREST's RPC dispatch
-- (what supabase-js's .rpc() actually goes through) resolves overloads by
-- matching the JSON body's keys against each candidate's parameters, and
-- an EMPTY body can match both a genuine zero-arg function and a
-- one-arg-with-default function — a documented PostgREST ambiguity
-- ("Could not choose the best candidate function"). Dropping the old
-- signature first guarantees exactly one function named
-- try_reserve_ai_quota exists at any time, so there is no dispatch
-- ambiguity for either an old caller (empty body -> p_idempotency_key
-- defaults to NULL, identical behavior to before this migration) or a
-- new caller (body includes p_idempotency_key).
DROP FUNCTION IF EXISTS public.try_reserve_ai_quota();
--
-- Race-safety proof: the reservation INSERT ... ON CONFLICT DO NOTHING
-- happens BEFORE the usage increment, and its result (whether a row was
-- actually inserted) gates whether the increment runs at all. Two
-- concurrent transactions with the same (user_id, idempotency_key) can
-- both attempt the INSERT; Postgres's unique index guarantees only one
-- commits the insert, the other observes the conflict and gets NULL back
-- from RETURNING — so only the winner ever reaches the usage increment.
-- This is the standard Postgres upsert-based idempotency pattern, not a
-- SELECT-then-INSERT race.
CREATE OR REPLACE FUNCTION public.try_reserve_ai_quota(p_idempotency_key uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id        uuid := auth.uid();
  v_role           text;
  v_limit          int;
  v_period         date := date_trunc('month', now())::date;
  v_count          int;
  v_reservation_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  SELECT role, monthly_limit INTO v_role, v_limit
  FROM public.profiles WHERE id = v_user_id;

  IF v_role IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'no_profile');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    INSERT INTO public.ai_quota_reservations (user_id, idempotency_key, period_start, status)
    VALUES (v_user_id, p_idempotency_key, v_period, 'reserved')
    ON CONFLICT (user_id, idempotency_key) DO NOTHING
    RETURNING id INTO v_reservation_id;

    IF v_reservation_id IS NULL THEN
      -- This key is already claimed (a genuine retry, or this request
      -- lost the race to a concurrent duplicate) — do NOT reserve again.
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

-- ── refund_ai_quota(p_idempotency_key) ──────────────────────────────────────
-- Idempotent refund: tied to the reservation row's own state transition
-- (reserved -> refunded), not a blind decrement. The conditional UPDATE
-- (... AND status = 'reserved') is itself the concurrency guard — a
-- retried or concurrently-duplicated refund call for the same key can
-- only ever flip that row once; ROW_COUNT tells us whether THIS call was
-- the one that did it.
--
-- Same drop-and-recreate reasoning as try_reserve_ai_quota above — avoids
-- a PostgREST overload-dispatch ambiguity between a genuine zero-arg
-- function and a one-arg-with-default function.
DROP FUNCTION IF EXISTS public.refund_ai_quota();
CREATE OR REPLACE FUNCTION public.refund_ai_quota(p_idempotency_key uuid DEFAULT NULL)
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

  IF p_idempotency_key IS NOT NULL THEN
    UPDATE public.ai_quota_reservations
    SET status = 'refunded', refunded_at = now()
    WHERE user_id = v_user_id
      AND idempotency_key = p_idempotency_key
      AND status = 'reserved';
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 0 THEN
      -- No reservation exists for this key (nothing to refund — e.g. a
      -- refund call for a key that was never reserved, or fail-closed
      -- against refund-before-reserve), or it was already refunded once
      -- (a retried refund) — either way, do not decrement usage again.
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
REVOKE ALL ON FUNCTION public.try_reserve_ai_quota(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.refund_ai_quota(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.try_reserve_ai_quota(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_quota(uuid) TO authenticated;

-- BACKWARD COMPATIBILITY (mission Section 10): exactly one function of
-- each name now exists (the old zero-arg signature was dropped above),
-- with p_idempotency_key defaulting to NULL. An Edge Function deployed
-- before this migration and calling .rpc('try_reserve_ai_quota') with an
-- empty body keeps working identically — same unconditional-reserve
-- behavior as before, just routed through the new function body. The
-- REMOVAL POINT for this compatibility default is a future mission, once
-- every one of the 16 quota-consuming Edge Functions is confirmed to
-- always send a real idempotency key: at that point p_idempotency_key
-- should become NOT NULL / required, so a client that skips it can no
-- longer silently bypass idempotency forever.
