-- Macro-10 §8 — Codex re-verification of 20261011000000 (job
-- aef989f5a6585e695) confirmed P1 and P3 resolved, but found a NEW P2
-- interaction between that fix and the pre-existing plan-limit trigger
-- (20261004000000_strategy_limit_race_fix.sql):
--
-- strategies_enforce_plan_limit() is a BEFORE INSERT trigger that takes
-- a per-user pg_advisory_xact_lock and raises STRATEGY_LIMIT_REACHED
-- when the user is already at their plan's strategy cap -- this fires
-- (and can raise) BEFORE the unique index on (user_id, idempotency_key)
-- is ever reached. Race: two concurrent requests with the SAME
-- idempotency key both pass the RPC's own pre-check (neither sees the
-- other's row yet); the first INSERT succeeds and brings the user's
-- count to exactly their limit; the second blocks on the trigger's
-- advisory lock, then -- once it proceeds -- sees count >= limit and
-- raises STRATEGY_LIMIT_REACHED, an exception our unique_violation
-- handler never catches. A genuine retry (not an attacker) then gets a
-- confusing "limit reached" error instead of its own already-succeeded
-- result.
--
-- Fix: acquire the SAME per-user advisory lock key
-- ('strategies:' || user_id) at the START of this RPC, before the
-- idempotency pre-check, and hold it for the whole transaction. A
-- concurrent second call for the same user now blocks here until the
-- first commits; once unblocked, its pre-check SELECT runs in a fresh
-- statement snapshot (READ COMMITTED) that already sees the first
-- call's committed row, so it returns the existing result via the
-- normal pre-check path -- it never reaches the INSERT, so the
-- plan-limit trigger's own re-acquisition of the same lock is a no-op
-- (advisory xact locks are reference-counted per session) and never
-- gets a chance to fire on a request that was always going to be an
-- idempotent replay. This also makes the unique_violation handler added
-- in 20261011000000 a pure defense-in-depth backstop rather than the
-- primary path, which is the correct ordering.
--
-- Idempotent: safe to re-apply. LAB until rehearsed.

CREATE OR REPLACE FUNCTION public.strategies_create_with_version(
  p_name text,
  p_spec jsonb,
  p_spec_hash text,
  p_idempotency_key text DEFAULT NULL
) RETURNS TABLE (
  strategy_id uuid, strategy_name text, strategy_status text, strategy_current_version integer,
  strategy_created_at timestamptz, strategy_updated_at timestamptz, strategy_holdout_first_viewed_at timestamptz,
  version_id uuid, version_strategy_id uuid, version_number integer, version_spec jsonb, version_spec_hash text, version_created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_strategy_id uuid;
  v_version_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = '28000';
  END IF;
  IF NOT public.strategy_builder_access_allowed() THEN
    RAISE EXCEPTION 'MODULE_NOT_AVAILABLE' USING ERRCODE = '42501';
  END IF;

  -- Same lock key as strategies_enforce_plan_limit() -- serializes the
  -- whole pre-check + insert sequence per user, so a concurrent retry
  -- always sees a committed sibling row (if one exists) before it can
  -- ever reach the INSERT/trigger.
  PERFORM pg_advisory_xact_lock(hashtextextended('strategies:' || v_uid::text, 0));

  IF p_idempotency_key IS NOT NULL THEN
    SELECT s.id INTO v_strategy_id FROM public.strategies s
      WHERE s.user_id = v_uid AND s.idempotency_key = p_idempotency_key;
    IF FOUND THEN
      PERFORM 1 FROM public.strategy_versions v
        WHERE v.strategy_id = v_strategy_id AND v.version_number = 1 AND v.spec = p_spec;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT' USING ERRCODE = '23505';
      END IF;
      RETURN QUERY
        SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
               v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
        FROM public.strategies s
        JOIN public.strategy_versions v ON v.strategy_id = s.id AND v.version_number = 1
        WHERE s.id = v_strategy_id;
      RETURN;
    END IF;
  END IF;

  BEGIN
    INSERT INTO public.strategies (user_id, name, status, current_version, idempotency_key)
      VALUES (v_uid, p_name, 'DRAFT', 1, p_idempotency_key)
      RETURNING id INTO v_strategy_id;

    INSERT INTO public.strategy_versions (strategy_id, user_id, version_number, spec, spec_hash)
      VALUES (v_strategy_id, v_uid, 1, p_spec, p_spec_hash)
      RETURNING id INTO v_version_id;
  EXCEPTION WHEN unique_violation THEN
    -- Defense-in-depth backstop only -- the advisory lock above should
    -- make this path unreachable for a genuine idempotency-key replay,
    -- but keep it in case of a concurrent request WITHOUT this RPC's
    -- own lock (there is no other caller of this function today, but
    -- this stays cheap insurance against a future one).
    IF p_idempotency_key IS NULL THEN
      RAISE;
    END IF;
    SELECT s.id INTO v_strategy_id FROM public.strategies s
      WHERE s.user_id = v_uid AND s.idempotency_key = p_idempotency_key;
    IF NOT FOUND THEN
      RAISE;
    END IF;
    PERFORM 1 FROM public.strategy_versions v
      WHERE v.strategy_id = v_strategy_id AND v.version_number = 1 AND v.spec = p_spec;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT' USING ERRCODE = '23505';
    END IF;
    RETURN QUERY
      SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
             v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
      FROM public.strategies s
      JOIN public.strategy_versions v ON v.strategy_id = s.id AND v.version_number = 1
      WHERE s.id = v_strategy_id;
    RETURN;
  END;

  RETURN QUERY
    SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
           v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
    FROM public.strategies s JOIN public.strategy_versions v ON v.id = v_version_id
    WHERE s.id = v_strategy_id;
END $$;

REVOKE ALL ON FUNCTION public.strategies_create_with_version(text, jsonb, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.strategies_create_with_version(text, jsonb, text, text) TO authenticated;
