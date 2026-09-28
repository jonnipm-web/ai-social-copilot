-- INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 — Codex final audit
-- re-verification, P1-02 remaining gap. Lab only; NOT applied to
-- production.
--
-- The re-verification pass on 20261006000000's fixes found that
-- result_kind ('BACKTEST'|'SIMULATION') was made authoritative at the
-- APPLICATION layer (every insertBacktestResult call site, the
-- compare_versions/analyze_backtest_result filters, and
-- record_experiment's cross-check), but `authenticated` still had a
-- direct, ownership-only-checked INSERT path onto
-- strategy_backtest_results via strategy_backtest_results_insert_own
-- (20261002000000) -- the exact same class of gap P1-01 already fixed
-- for strategy_experiments. A caller going straight through PostgREST,
-- bypassing the Edge Function (and its buildCanonicalBacktestResult
-- computation) entirely, could insert a fabricated canonical_result
-- and simply choose (or omit, taking the default) result_kind =
-- 'BACKTEST', making the discriminator meaningless against a
-- determined direct-DB caller.
--
-- Fixed identically to strategy_experiments_insert (20261006000000):
-- revoke the direct INSERT grant/policy, replace it with a SECURITY
-- DEFINER RPC that re-validates ownership (strategy_version_id belongs
-- to a strategy owned by auth.uid()) before inserting. This closes the
-- "bypass the app entirely" vector; it does not (and structurally
-- cannot) prove a canonical_result's NUMBERS are the genuine output of
-- the real engine -- no database-side check can attest to off-database
-- computation authenticity. That limitation already existed equally
-- for the pre-existing Edge-Function-only path and is unchanged by
-- this migration; what this migration removes is the STRICTLY WORSE
-- alternate path that skipped even the Edge Function's own structural
-- checks.
--
-- Idempotent: safe to re-apply.

DROP POLICY IF EXISTS strategy_backtest_results_insert_own ON public.strategy_backtest_results;
REVOKE INSERT ON public.strategy_backtest_results FROM authenticated;

CREATE OR REPLACE FUNCTION public.strategy_backtest_results_insert(
  p_strategy_version_id uuid,
  p_dataset_id text,
  p_dataset_hash text,
  p_methodology_status text,
  p_net_pnl numeric,
  p_trade_count integer,
  p_result_hash text,
  p_canonical_result jsonb,
  p_result_kind text
) RETURNS public.strategy_backtest_results
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.strategy_backtest_results;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = '28000';
  END IF;
  IF NOT public.strategy_builder_access_allowed() THEN
    RAISE EXCEPTION 'MODULE_NOT_AVAILABLE' USING ERRCODE = '42501';
  END IF;

  PERFORM 1 FROM public.strategy_versions v
    JOIN public.strategies s ON s.id = v.strategy_id
    WHERE v.id = p_strategy_version_id AND s.user_id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.strategy_backtest_results (
    strategy_version_id, user_id, dataset_id, dataset_hash, methodology_status,
    net_pnl, trade_count, result_hash, canonical_result, result_kind
  ) VALUES (
    p_strategy_version_id, v_uid, p_dataset_id, p_dataset_hash, p_methodology_status,
    p_net_pnl, p_trade_count, p_result_hash, p_canonical_result, p_result_kind
  ) RETURNING * INTO v_row;

  RETURN v_row;
END $$;

REVOKE ALL ON FUNCTION public.strategy_backtest_results_insert(uuid, text, text, text, numeric, integer, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.strategy_backtest_results_insert(uuid, text, text, text, numeric, integer, text, jsonb, text) TO authenticated;
