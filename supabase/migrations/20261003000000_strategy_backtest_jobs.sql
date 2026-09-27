-- INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 — Backtest Job persistence (Lab only; NOT applied to production).
--
-- §19: "A user-triggered backtest must become a bounded auditable job."
-- This macro's execution model is SYNCHRONOUS (the Edge Function runs the
-- engine and resolves the job in the same request, §12/§13's bounded-
-- execution requirement) -- there is no background worker yet. A row is
-- therefore always inserted ALREADY in its terminal state (SUCCEEDED or
-- FAILED), computed before the INSERT. QUEUED/RUNNING remain valid CHECK
-- values so a future real async worker can use this same table without a
-- schema change, but nothing in THIS macro's code ever inserts one.
--
-- Because every row is append-only from the moment it exists, the same
-- "no UPDATE for authenticated" posture as strategy_versions/
-- strategy_backtest_results applies here too -- a job's recorded outcome
-- can never be silently rewritten after the fact.
--
-- Idempotent: safe to re-apply.

CREATE TABLE IF NOT EXISTS public.strategy_backtest_jobs (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE CASCADE,
  strategy_version_id  uuid NOT NULL REFERENCES public.strategy_versions (id) ON DELETE CASCADE,
  dataset_id           text NOT NULL,
  engine_id            text NOT NULL,
  status               text NOT NULL,
  started_at           timestamptz NOT NULL,
  completed_at         timestamptz NULL,
  failure_reason       text NULL,
  result_id            uuid NULL REFERENCES public.strategy_backtest_results (id) ON DELETE SET NULL,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT strategy_backtest_jobs_status_chk CHECK (status IN ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED')),
  CONSTRAINT strategy_backtest_jobs_engine_chk CHECK (engine_id IN ('GENERIC_RULE_ENGINE', 'PAULO_TREND_FIBONACCI_V10')),
  -- Every row this macro's code ever inserts is already terminal.
  CONSTRAINT strategy_backtest_jobs_terminal_chk CHECK (
    (status = 'SUCCEEDED' AND result_id IS NOT NULL AND failure_reason IS NULL AND completed_at IS NOT NULL)
    OR (status = 'FAILED' AND result_id IS NULL AND failure_reason IS NOT NULL AND completed_at IS NOT NULL)
    OR (status IN ('QUEUED', 'RUNNING') AND completed_at IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS strategy_backtest_jobs_user_id_idx ON public.strategy_backtest_jobs (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS strategy_backtest_jobs_version_id_idx ON public.strategy_backtest_jobs (strategy_version_id);

ALTER TABLE public.strategy_backtest_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS strategy_backtest_jobs_select_own ON public.strategy_backtest_jobs;
CREATE POLICY strategy_backtest_jobs_select_own ON public.strategy_backtest_jobs
  FOR SELECT TO authenticated USING (user_id = auth.uid() AND public.strategy_builder_access_allowed());

DROP POLICY IF EXISTS strategy_backtest_jobs_insert_own ON public.strategy_backtest_jobs;
CREATE POLICY strategy_backtest_jobs_insert_own ON public.strategy_backtest_jobs
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid()
    AND public.strategy_builder_access_allowed()
    AND EXISTS (
      SELECT 1 FROM public.strategy_versions v
      JOIN public.strategies s ON s.id = v.strategy_id
      WHERE v.id = strategy_version_id AND s.user_id = auth.uid()
    )
  );

REVOKE ALL ON public.strategy_backtest_jobs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.strategy_backtest_jobs TO authenticated;
GRANT ALL ON public.strategy_backtest_jobs TO service_role;
