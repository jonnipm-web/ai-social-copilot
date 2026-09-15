-- IVE-COMMERCIAL-QUOTA-HARDENING-13 — server-authoritative idempotency for
-- AI quota reservation.
--
-- NOT APPLIED IN THIS MISSION — per mission Section 30 ("Do not apply
-- production migration in this mission"). Prepared for Codex Gate 1/Gate 2
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
-- REVISION HISTORY WITHIN THIS (never-applied) MIGRATION:
--   Round 1 (Codex Gate 1, FAIL): scoped uniqueness to (user_id,
--   idempotency_key) alone. Found bypass: replaying a key against a
--   DIFFERENT operation or in a LATER month was mistaken for an
--   already-successful reservation, granting free (uncharged) access.
--   Fixed by scoping to (user_id, idempotency_key, operation_type,
--   period_start), with operation_type a literal each Edge Function
--   hardcodes for itself — never client-supplied.
--
--   Round 2 (Codex Gate 2, FAIL): the round-1 fix, on retrying a
--   REFUNDED reservation, DELETEd the old row and INSERTed a new one
--   under the same tuple so the retry could get a genuine new charge.
--   Found bypass: refund_ai_quota looked up "the row for this tuple with
--   status='reserved'" rather than one specific row — so a DELAYED
--   DUPLICATE refund call (e.g. a retried refund request) arriving AFTER
--   a legitimate retry had already replaced the row could match and
--   refund the NEW (successful, real) reservation instead of the OLD
--   (already-refunded) one it actually belonged to, silently undoing a
--   real charge for a real, successful AI call.
--
--   Round 3 (this version): refund_ai_quota now targets a reservation by
--   its own immutable primary key (p_reservation_id), never by
--   re-deriving "the current row for this tuple." try_reserve_ai_quota
--   returns that id in its result specifically so the caller can pass it
--   back later. A delayed duplicate refund naming an OLD reservation id
--   can only ever match that exact row — if it's already 'refunded'
--   (ROW_COUNT=0) or gone, it is correctly a no-op, and it can never
--   accidentally match a DIFFERENT (newer) row, because ids are globally
--   unique (gen_random_uuid()) and never reused. This also lets every
--   attempt keep its own permanent ledger row (audit trail preserved) —
--   a PARTIAL unique index (WHERE status = 'reserved') is the
--   concurrency guard now, not a table-wide UNIQUE constraint, so a
--   retry after a refund is a plain INSERT of a NEW row rather than a
--   DELETE-then-INSERT of the old one.
--
-- DESIGN:
--   - Race safety: a partial unique index on (user_id, idempotency_key,
--     operation_type, period_start) WHERE status = 'reserved' means at
--     most one ACTIVE reservation can ever exist for one operation's key
--     in one period — the INSERT ... ON CONFLICT (...) WHERE status =
--     'reserved' DO NOTHING is the guard, exactly like the original
--     table-wide-constraint design, just scoped to the active rows only.
--     A 'refunded' row from an earlier failed attempt under the same key
--     does NOT count toward that index, so a retry's INSERT succeeds
--     immediately as a brand new ledger row — no deletion, full history.
--   - Refund safety: refund_ai_quota(p_reservation_id) is idempotent by
--     the reservation's own primary key + a conditional
--     status='reserved' -> 'refunded' transition (ROW_COUNT gate) — the
--     same "conditional UPDATE is the guard" pattern as before, just
--     keyed by an immutable id instead of a mutable, reusable tuple.
--   - operation_type is NOT NULL (no default) specifically because
--     Postgres treats NULLs as mutually DISTINCT in a unique index — a
--     nullable column would silently defeat the partial index's
--     uniqueness guarantee for any caller that omitted it. Supplying a
--     key without one is rejected outright (see 'invalid_request') by
--     try_reserve_ai_quota.
--   - Ownership derived from auth.uid() only (SECURITY DEFINER function
--     identity), never from a client-supplied user id — same rule the
--     existing quota functions already follow. refund_ai_quota's lookup
--     is additionally scoped to `user_id = auth.uid()`, so even a leaked
--     reservation_id from a different user's row can never be refunded
--     by someone else.
--   - BACKWARD COMPATIBLE: every new parameter defaults to NULL. A
--     legacy call (no key, no operation type, no reservation id) behaves
--     EXACTLY as before this migration — unconditional reserve/refund.
--     This is a deliberate, temporary compatibility path (mission
--     Section 10) — the actual removal point is a future mission once
--     every one of the 16 quota-consuming Edge Functions has been
--     confirmed to always send a key from an updated client.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.refund_ai_quota(uuid);
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
  refunded_at     timestamptz
);

-- The concurrency guard: at most one ACTIVE ('reserved') row per
-- (user, key, operation, period). Deliberately a PARTIAL index, not a
-- table-wide UNIQUE constraint — see "Round 3" comment above for why a
-- refunded row must NOT block a later genuine retry from getting its own
-- new ledger row.
CREATE UNIQUE INDEX IF NOT EXISTS ai_quota_reservations_active_unique
  ON public.ai_quota_reservations (user_id, idempotency_key, operation_type, period_start)
  WHERE status = 'reserved';

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
-- try_reserve_ai_quota exists at any time.
DROP FUNCTION IF EXISTS public.try_reserve_ai_quota();
DROP FUNCTION IF EXISTS public.try_reserve_ai_quota(uuid);
--
-- Race-safety proof: the reservation INSERT ... ON CONFLICT (...) WHERE
-- status = 'reserved' DO NOTHING happens BEFORE the usage increment, and
-- its result (whether a row was actually inserted) gates whether the
-- increment runs at all. Two concurrent transactions with the same
-- (user_id, idempotency_key, operation_type, period_start) racing while
-- an active reservation exists (or is being created) can both attempt the
-- INSERT; the partial unique index guarantees only one commits, the
-- other observes the conflict and gets NULL back from RETURNING — so only
-- the winner ever reaches the usage increment. This is the standard
-- Postgres upsert-based idempotency pattern, not a SELECT-then-INSERT
-- race.
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
    -- A prior REFUNDED row for this same tuple (an earlier failed
    -- attempt under this key) does not block this INSERT — the partial
    -- index only constrains 'reserved' rows — so a retry always gets its
    -- own fresh ledger row and its own fresh id. If an ACTIVE reservation
    -- already exists for this tuple (a genuine retry of a
    -- currently-successful reservation, or a concurrent duplicate), the
    -- INSERT conflicts and this becomes an idempotent replay instead.
    INSERT INTO public.ai_quota_reservations
      (user_id, idempotency_key, operation_type, period_start, status)
    VALUES (v_user_id, p_idempotency_key, p_operation_type, v_period, 'reserved')
    ON CONFLICT (user_id, idempotency_key, operation_type, period_start)
      WHERE status = 'reserved'
      DO NOTHING
    RETURNING id INTO v_reservation_id;

    IF v_reservation_id IS NULL THEN
      -- Already actively reserved — do NOT reserve again. Fetch that
      -- existing reservation's id too, so a caller who only has the key
      -- (e.g. inspecting an old response) can still learn which ledger
      -- row is authoritative right now.
      SELECT id INTO v_reservation_id
      FROM public.ai_quota_reservations
      WHERE user_id = v_user_id
        AND idempotency_key = p_idempotency_key
        AND operation_type = p_operation_type
        AND period_start = v_period
        AND status = 'reserved';

      SELECT request_count INTO v_count
      FROM public.ai_usage WHERE user_id = v_user_id AND period_start = v_period;
      RETURN jsonb_build_object(
        'allowed', true, 'idempotent_replay', true,
        'reservation_id', v_reservation_id,
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
    -- attempt, delete it — a denied attempt must not permanently occupy
    -- the active slot for this key (mission Section 07: "Quota exceeded:
    -- return QUOTA_EXCEEDED", not a silently-poisoned key a legitimate
    -- retry after upgrading plan could never reuse). This DELETE is safe
    -- against the refund-race this migration exists to close: nothing
    -- has told the client a reservation_id for a denied attempt (it was
    -- never returned — this response path doesn't include one), so
    -- nothing could have captured this id to refund later.
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
    'reservation_id', v_reservation_id,
    'used', v_count, 'limit', v_limit, 'role', v_role
  );
END;
$function$;

-- ── refund_ai_quota(p_reservation_id) ───────────────────────────────────────
-- Codex Gate 2 P1 fix — refund now targets ONE SPECIFIC reservation by its
-- own immutable primary key, never by re-deriving "the current active row
-- for this (key, operation, period) tuple." That re-derivation was the
-- bug: after a refunded reservation was retried (getting a NEW row with a
-- NEW id), a DELAYED DUPLICATE refund call for the OLD attempt would
-- still match "the row for this tuple with status='reserved'" — which by
-- then was the NEW, successful, genuinely-charged reservation — and
-- incorrectly refund it, silently un-charging a real, successful AI call.
--
-- Scoping by p_reservation_id closes this completely: a delayed duplicate
-- refund names a SPECIFIC id. If that id's row is already 'refunded'
-- (ROW_COUNT=0) it is correctly a no-op; it can never match a DIFFERENT,
-- newer row, because ids are globally unique and a retry always gets its
-- own new one. The conditional UPDATE (... AND status = 'reserved') is
-- still the concurrency guard for two concurrent/duplicate refunds of the
-- SAME id — only one can ever flip it.
--
-- ownership: additionally scoped to user_id = auth.uid(), so a
-- reservation_id belonging to a different user's row (however it might
-- have leaked) can never be refunded by this caller.
DROP FUNCTION IF EXISTS public.refund_ai_quota();
DROP FUNCTION IF EXISTS public.refund_ai_quota(uuid);
DROP FUNCTION IF EXISTS public.refund_ai_quota(uuid, text);
CREATE OR REPLACE FUNCTION public.refund_ai_quota(
  p_reservation_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id           uuid := auth.uid();
  v_updated           int;
  v_reservation_period date;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  IF p_reservation_id IS NOT NULL THEN
    -- Codex round-3 review, P1-3 — this used to decrement
    -- date_trunc('month', now())::date regardless of which period the
    -- reservation actually belonged to. A refund delayed across a month
    -- boundary (reserved Aug 31, refunded Sep 1) would then decrement
    -- THIS month's usage instead of the month the charge actually
    -- happened in, permanently leaving one period over-counted and the
    -- other under-counted. RETURNING the row's own period_start and
    -- decrementing THAT period fixes it.
    UPDATE public.ai_quota_reservations
    SET status = 'refunded', refunded_at = now()
    WHERE id = p_reservation_id
      AND user_id = v_user_id
      AND status = 'reserved'
    RETURNING period_start INTO v_reservation_period;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 0 THEN
      -- No such reservation belonging to this user (never existed, or
      -- belongs to someone else), or it was already refunded once (a
      -- retried/duplicate refund of the SAME attempt) — either way, do
      -- not decrement usage again.
      RETURN;
    END IF;

    UPDATE public.ai_usage
    SET request_count = GREATEST(request_count - 1, 0), updated_at = now()
    WHERE user_id = v_user_id AND period_start = v_reservation_period;
    RETURN;
  END IF;

  -- Legacy path (no reservation id at all) — reproduces the exact pre-13
  -- behavior: unconditional decrement of the CURRENT period. Safe only
  -- because a legacy caller's reserve-then-refund always happens
  -- synchronously within one request, never spanning a period boundary.
  UPDATE public.ai_usage
  SET request_count = GREATEST(request_count - 1, 0), updated_at = now()
  WHERE user_id = v_user_id AND period_start = date_trunc('month', now())::date;
END;
$function$;

-- Same authorization posture as the functions being extended — real
-- logged-in users only, never anon/public.
REVOKE ALL ON FUNCTION public.try_reserve_ai_quota(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.refund_ai_quota(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.try_reserve_ai_quota(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_quota(uuid) TO authenticated;

-- BACKWARD COMPATIBILITY (mission Section 10): exactly one function of
-- each name now exists (old signatures were dropped above), with every
-- new parameter defaulting to NULL. An Edge Function deployed before this
-- migration and calling .rpc('try_reserve_ai_quota')/.rpc('refund_ai_quota')
-- with an empty body keeps working identically — same unconditional
-- reserve/refund behavior as before, just routed through the new function
-- bodies. The REMOVAL POINT for this compatibility default is a future
-- mission, once every one of the 16 quota-consuming Edge Functions is
-- confirmed to always send a real idempotency key + operation type (for
-- reserve) and reservation id (for refund): at that point these
-- parameters should become required, so a client that skips them can no
-- longer silently bypass idempotency forever.
