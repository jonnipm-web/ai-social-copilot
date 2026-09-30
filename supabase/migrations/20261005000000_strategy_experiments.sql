-- INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 — Experiment provenance
-- and holdout contamination tracking (§14-15, §28-29). Lab only; NOT
-- applied to production.
--
-- strategy_experiments is a DEDICATED table with its own closed
-- category vocabulary (BACKTEST/ROBUSTNESS_EXPERIMENT/SIMULATION/
-- USER_DECISION/IVE_RECOMMENDATION) -- deliberately NOT an extension of
-- result_learning.sql's business_memory.memory_type, which that
-- module's own comments document as closed to
-- 'success'|'failure'|'decision'. Forcing five new categories into that
-- vocabulary would silently violate a different module's own stated
-- contract; a dedicated table does not.
--
-- Every row is append-only (SELECT+INSERT only for authenticated, same
-- posture as strategy_backtest_jobs/strategy_versions) -- an
-- experiment's recorded reason/result can never be silently rewritten
-- after the fact.
--
-- strategies.holdout_first_viewed_at is the single source of truth this
-- macro uses for holdout contamination (experiment_provenance.ts's
-- computeContamination): the timestamp of the FIRST HOLDOUT-segment
-- experiment ever recorded for a strategy. It is set once
-- (COALESCE-guarded, first-write-wins) by the same trigger that
-- inserts a HOLDOUT experiment row, never by the application directly,
-- so it cannot be backdated or cleared by a client.
--
-- Idempotent: safe to re-apply.

ALTER TABLE public.strategies ADD COLUMN IF NOT EXISTS holdout_first_viewed_at timestamptz NULL;

CREATE TABLE IF NOT EXISTS public.strategy_experiments (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE CASCADE,
  strategy_id          uuid NOT NULL REFERENCES public.strategies (id) ON DELETE CASCADE,
  strategy_version_id  uuid NOT NULL REFERENCES public.strategy_versions (id) ON DELETE CASCADE,
  category             text NOT NULL,
  dataset_id           text NOT NULL,
  segment              text NOT NULL,
  parameters_changed   jsonb NULL,
  reason               text NOT NULL,
  result_id            uuid NULL REFERENCES public.strategy_backtest_results (id) ON DELETE SET NULL,
  cost_assumptions     jsonb NULL,
  source               text NOT NULL,
  -- Computed by the application at insert time (experiment_provenance.ts's
  -- computeContamination) from strategies.holdout_first_viewed_at as it
  -- stood at that moment -- stored, not recomputed later, so a row's
  -- meaning never silently changes as new holdout experiments appear.
  contaminated         boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT strategy_experiments_category_chk CHECK (category IN ('BACKTEST', 'ROBUSTNESS_EXPERIMENT', 'SIMULATION', 'USER_DECISION', 'IVE_RECOMMENDATION')),
  CONSTRAINT strategy_experiments_segment_chk CHECK (segment IN ('FULL', 'RESEARCH', 'HOLDOUT')),
  CONSTRAINT strategy_experiments_source_chk CHECK (source IN ('USER', 'IVE_PROPOSAL', 'AUTOMATED_RESEARCH_LOOP')),
  CONSTRAINT strategy_experiments_reason_chk CHECK (length(btrim(reason)) > 0)
);

CREATE INDEX IF NOT EXISTS strategy_experiments_user_id_idx ON public.strategy_experiments (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS strategy_experiments_strategy_id_idx ON public.strategy_experiments (strategy_id);

-- Sets strategies.holdout_first_viewed_at exactly once, at the FIRST
-- HOLDOUT-segment experiment for that strategy -- COALESCE means a
-- later HOLDOUT experiment never overwrites the original timestamp.
--
-- SECURITY DEFINER, deliberately, unlike this schema's other trigger
-- functions: `authenticated` is granted UPDATE (name) only on
-- `strategies` (20261002000000) -- it has no privilege to write
-- holdout_first_viewed_at directly, and this migration intentionally
-- does NOT grant one, so that column can ONLY ever change through this
-- function, never via a direct client UPDATE (which could otherwise
-- clear or backdate it to defeat contamination tracking). This does
-- NOT expand privilege beyond that narrow purpose: it fires AFTER
-- INSERT on a row that only exists because
-- strategy_experiments_insert_own's WITH CHECK already proved
-- NEW.strategy_id is owned by auth.uid() -- the ownership check this
-- function would otherwise need to repeat already happened. The
-- pinned search_path prevents search-path hijacking of this elevated
-- function.
CREATE OR REPLACE FUNCTION public.strategy_experiments_mark_holdout_viewed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.segment = 'HOLDOUT' THEN
    UPDATE public.strategies
    SET holdout_first_viewed_at = COALESCE(holdout_first_viewed_at, NEW.created_at)
    WHERE id = NEW.strategy_id;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS strategy_experiments_mark_holdout_viewed ON public.strategy_experiments;
CREATE TRIGGER strategy_experiments_mark_holdout_viewed AFTER INSERT ON public.strategy_experiments
  FOR EACH ROW EXECUTE FUNCTION public.strategy_experiments_mark_holdout_viewed();

REVOKE ALL ON FUNCTION public.strategy_experiments_mark_holdout_viewed() FROM PUBLIC, anon, authenticated;

ALTER TABLE public.strategy_experiments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS strategy_experiments_select_own ON public.strategy_experiments;
CREATE POLICY strategy_experiments_select_own ON public.strategy_experiments
  FOR SELECT TO authenticated USING (user_id = auth.uid() AND public.strategy_builder_access_allowed());

DROP POLICY IF EXISTS strategy_experiments_insert_own ON public.strategy_experiments;
CREATE POLICY strategy_experiments_insert_own ON public.strategy_experiments
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid()
    AND public.strategy_builder_access_allowed()
    AND EXISTS (
      SELECT 1 FROM public.strategy_versions v
      JOIN public.strategies s ON s.id = v.strategy_id
      WHERE v.id = strategy_version_id AND s.id = strategy_id AND s.user_id = auth.uid()
    )
  );

REVOKE ALL ON public.strategy_experiments FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.strategy_experiments TO authenticated;
GRANT ALL ON public.strategy_experiments TO service_role;
