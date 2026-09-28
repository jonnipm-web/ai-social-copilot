-- INSIGHTVALUES-FINANCIAL-PRODUCT-MACRO-08 -- Codex adversarial review
-- re-verification (diff vs 15d4177), [high] finding: "Create is not
-- idempotent under timeout or client retry".
--
-- SupabaseStrategyStore.create() inserted `strategies` and its version 1
-- row as two separate, non-transactional PostgREST requests. A
-- version-insert failure left an orphan `strategies` row behind -- no
-- usable version, but still counted by strategies_enforce_plan_limit's
-- trigger, permanently burning a slot out of the caller's (now real,
-- paying) plan limit. A best-effort compensating delete (this session's
-- first fix pass) only covers the case where the CLIENT OBSERVES the
-- version-insert error; it does nothing for a network timeout after
-- either insert actually committed server-side, or a genuine retry after
-- an apparent failure.
--
-- Fix: strategies_create_with_version(), a SECURITY DEFINER RPC that
-- performs both inserts inside ONE function call -- Postgres functions
-- are atomic, so ANY failure (not just a PostgREST-visible error) rolls
-- back both inserts together; there is no code path left that can leave
-- an orphan. An optional idempotency key lets a genuine retry (not just
-- a same-request timeout) return the ORIGINAL strategy/version instead
-- of creating a duplicate. Mirrors the exact SECURITY DEFINER RPC
-- pattern already established for strategy_experiments_insert
-- (20261006000000) and strategy_backtest_results_insert (20261007000000)
-- -- including revoking the direct-insert path on `strategies` it
-- replaces, for the same reason those migrations did: a caller bypassing
-- the Edge Function entirely via raw PostgREST must not be able to
-- recreate the exact non-atomic race this migration closes.
--
-- `strategy_versions` keeps its existing direct-insert grant: it is also
-- used by the unrelated, legitimate create_version op (a new version for
-- an EXISTING strategy), which this migration does not touch.
--
-- Idempotent: safe to re-apply.

ALTER TABLE public.strategies
  ADD COLUMN IF NOT EXISTS idempotency_key text NULL;

ALTER TABLE public.strategies
  DROP CONSTRAINT IF EXISTS strategies_idempotency_key_chk;
ALTER TABLE public.strategies
  ADD CONSTRAINT strategies_idempotency_key_chk CHECK (idempotency_key IS NULL OR char_length(idempotency_key) BETWEEN 1 AND 200);

CREATE UNIQUE INDEX IF NOT EXISTS strategies_user_idempotency_key_uq
  ON public.strategies (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

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

  -- A retry with the SAME idempotency key returns the ORIGINAL row
  -- instead of creating a duplicate or erroring on the unique index.
  IF p_idempotency_key IS NOT NULL THEN
    SELECT s.id INTO v_strategy_id FROM public.strategies s
      WHERE s.user_id = v_uid AND s.idempotency_key = p_idempotency_key;
    IF FOUND THEN
      RETURN QUERY
        SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
               v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
        FROM public.strategies s
        JOIN public.strategy_versions v ON v.strategy_id = s.id AND v.version_number = 1
        WHERE s.id = v_strategy_id;
      RETURN;
    END IF;
  END IF;

  -- Both inserts below run inside this single function invocation --
  -- Postgres executes a plpgsql function body as one transaction, so a
  -- failure on the SECOND insert (or the plan-limit trigger the FIRST
  -- one still fires) rolls back the first insert too. No orphan is
  -- possible from this path, by construction, not by compensation.
  INSERT INTO public.strategies (user_id, name, status, current_version, idempotency_key)
    VALUES (v_uid, p_name, 'DRAFT', 1, p_idempotency_key)
    RETURNING id INTO v_strategy_id;

  INSERT INTO public.strategy_versions (strategy_id, user_id, version_number, spec, spec_hash)
    VALUES (v_strategy_id, v_uid, 1, p_spec, p_spec_hash)
    RETURNING id INTO v_version_id;

  RETURN QUERY
    SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
           v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
    FROM public.strategies s JOIN public.strategy_versions v ON v.id = v_version_id
    WHERE s.id = v_strategy_id;
END $$;

REVOKE ALL ON FUNCTION public.strategies_create_with_version(text, jsonb, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.strategies_create_with_version(text, jsonb, text, text) TO authenticated;

-- Force all initial strategy creation through the atomic RPC above --
-- the same "no bypass via raw PostgREST" posture already applied to
-- strategy_experiments/strategy_backtest_results in 20261006000000/
-- 20261007000000. strategy_versions keeps its own direct-insert grant
-- (create_version, an unrelated legitimate op, still uses it).
DROP POLICY IF EXISTS strategies_insert_own ON public.strategies;
REVOKE INSERT ON public.strategies FROM authenticated;
