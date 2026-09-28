-- INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 — Codex final audit fixes
-- (P1-01, P1-02, P2-02). Lab only; NOT applied to production.
--
-- P1-01 (experiment provenance is client-forgeable): `authenticated`
-- previously had direct INSERT on strategy_experiments via RLS
-- (ownership-checked, but not content-checked) -- a caller going
-- straight through PostgREST, bypassing the Edge Function's own
-- cross-checks entirely, could claim any category/segment/
-- contaminated/created_at value for a row it otherwise owned. Fixed by
-- revoking INSERT from authenticated entirely and replacing it with
-- strategy_experiments_insert(), a SECURITY DEFINER RPC that repeats
-- every cross-check the Edge Function already does (ownership,
-- resultId/dataset match) IN THE DATABASE, and computes contaminated
-- and created_at itself -- a client can no longer supply either.
--
-- P1-02 (simulation results lack an enforced type discriminator):
-- strategy_backtest_results.result_kind distinguishes a real BACKTEST
-- from a SIMULATION at the row level, set authoritatively by whichever
-- server code path actually produced it (never client-supplied).
-- record_experiment (application layer, strategy-builder/index.ts)
-- now refuses a category/result_kind mismatch; compare_versions and
-- analyze_backtest_result now exclude SIMULATION-kind results from the
-- pool they select "the" result from.
--
-- P2-02 (holdout timestamp backdating): a direct consequence of P1-01 --
-- once direct INSERT is revoked and created_at is set by the RPC
-- itself (never accepted as a parameter), a client can no longer
-- backdate the row the strategy_experiments_mark_holdout_viewed
-- trigger reads from.
--
-- Idempotent: safe to re-apply.

ALTER TABLE public.strategy_backtest_results
  ADD COLUMN IF NOT EXISTS result_kind text NOT NULL DEFAULT 'BACKTEST';

ALTER TABLE public.strategy_backtest_results
  DROP CONSTRAINT IF EXISTS strategy_backtest_results_result_kind_chk;
ALTER TABLE public.strategy_backtest_results
  ADD CONSTRAINT strategy_backtest_results_result_kind_chk CHECK (result_kind IN ('BACKTEST', 'SIMULATION'));

-- Revoke the direct-insert path P1-01 identified. SELECT is unaffected
-- (callers still read their own experiments the same way).
DROP POLICY IF EXISTS strategy_experiments_insert_own ON public.strategy_experiments;
REVOKE INSERT ON public.strategy_experiments FROM authenticated;

-- SECURITY DEFINER, deliberately: this function's whole purpose is to
-- perform checks and a computation (contamination, created_at) that
-- `authenticated` must NOT be able to skip or override by inserting
-- directly -- the same reasoning as strategy_experiments_mark_holdout_
-- viewed (20261005000000), which this function still relies on to
-- update strategies.holdout_first_viewed_at afterward. Every check
-- below mirrors strategy-builder/index.ts's own record_experiment
-- handler exactly, so the database enforces the same rules the app
-- does, not a weaker or divergent copy.
CREATE OR REPLACE FUNCTION public.strategy_experiments_insert(
  p_strategy_id uuid,
  p_strategy_version_id uuid,
  p_category text,
  p_dataset_id text,
  p_segment text,
  p_parameters_changed jsonb,
  p_reason text,
  p_result_id uuid,
  p_cost_assumptions jsonb,
  p_source text
) RETURNS public.strategy_experiments
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_holdout_first_viewed_at timestamptz;
  v_contaminated boolean;
  v_result_kind text;
  v_row public.strategy_experiments;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = '28000';
  END IF;
  IF NOT public.strategy_builder_access_allowed() THEN
    RAISE EXCEPTION 'MODULE_NOT_AVAILABLE' USING ERRCODE = '42501';
  END IF;

  PERFORM 1 FROM public.strategy_versions v
    JOIN public.strategies s ON s.id = v.strategy_id
    WHERE v.id = p_strategy_version_id AND s.id = p_strategy_id AND s.user_id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  IF p_result_id IS NOT NULL THEN
    SELECT result_kind INTO v_result_kind FROM public.strategy_backtest_results r
      WHERE r.id = p_result_id AND r.strategy_version_id = p_strategy_version_id
        AND r.user_id = v_uid AND r.dataset_id = p_dataset_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'INVALID_BODY' USING ERRCODE = '22023';
    END IF;
    -- P1-02: a client-supplied category can no longer disagree with
    -- what the result actually is.
    IF v_result_kind = 'SIMULATION' AND p_category <> 'SIMULATION' THEN
      RAISE EXCEPTION 'INVALID_BODY' USING ERRCODE = '22023';
    END IF;
    IF v_result_kind = 'BACKTEST' AND p_category = 'SIMULATION' THEN
      RAISE EXCEPTION 'INVALID_BODY' USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT holdout_first_viewed_at INTO v_holdout_first_viewed_at FROM public.strategies WHERE id = p_strategy_id;
  -- Mirrors experiment_provenance.ts's computeContamination(): the
  -- strategy's FIRST HOLDOUT experiment is never contaminated by its
  -- own first view; any candidate created at/after that moment is.
  -- `now()` here IS this row's created_at (below), computed once so
  -- both values agree exactly.
  v_contaminated := v_holdout_first_viewed_at IS NOT NULL
    AND NOT (p_segment = 'HOLDOUT' AND now() <= v_holdout_first_viewed_at);

  INSERT INTO public.strategy_experiments (
    user_id, strategy_id, strategy_version_id, category, dataset_id, segment,
    parameters_changed, reason, result_id, cost_assumptions, source, contaminated, created_at
  ) VALUES (
    v_uid, p_strategy_id, p_strategy_version_id, p_category, p_dataset_id, p_segment,
    p_parameters_changed, p_reason, p_result_id, p_cost_assumptions, p_source, v_contaminated, now()
  ) RETURNING * INTO v_row;

  RETURN v_row;
END $$;

REVOKE ALL ON FUNCTION public.strategy_experiments_insert(uuid, uuid, text, text, text, jsonb, text, uuid, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.strategy_experiments_insert(uuid, uuid, text, text, text, jsonb, text, uuid, jsonb, text) TO authenticated;
