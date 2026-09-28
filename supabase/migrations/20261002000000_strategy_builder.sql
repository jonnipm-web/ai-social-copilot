-- INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 — Strategy Builder persistence (Lab only; NOT applied to production).
--
-- Minimal relational model for user-configurable strategies (§28-29):
--   strategies                one row per user-owned strategy identity
--   strategy_versions         immutable, append-only spec snapshots (§29:
--                              "Do not overwrite historical results as if
--                              produced by the new version")
--   strategy_backtest_results immutable, append-only canonical backtest
--                              results, each pinned to one strategy_version
--
-- Security model (mirrors 20260924000000_quant_watchlists.sql):
--   * RLS on all three tables; every policy is owner-only via user_id/join.
--   * Module entitlement enforced here too: module 'strategy-builder' is
--     EXPERIMENTAL (admin-only, same posture as 'ive-quant' from Macro-04)
--     via public.strategy_builder_access_allowed() -- direct PostgREST
--     access cannot bypass the Edge Function's own entitlement gate.
--   * strategy_versions and strategy_backtest_results grant NO UPDATE to
--     `authenticated` -- a version's pinned spec (and a result's pinned
--     numbers) can never be rewritten by any authenticated caller, direct
--     PostgREST or otherwise. `service_role` (the trusted backend key, used
--     the same way across this codebase's other Lab tables, e.g.
--     20260924000000_quant_watchlists.sql) still receives ALL, including
--     UPDATE -- that is a statement about what an external caller can do,
--     never a database-enforced guarantee against the server's own trusted
--     key (Codex final audit, P1: the prior wording overstated this).
--   * Only strategies.name is updatable by an authenticated owner.
--     strategies.status/current_version are intentionally NOT grantable to
--     `authenticated` (Codex final audit, P2): no Edge Function operation
--     this macro calls lifecycle.ts's canPromote before writing, so a raw
--     UPDATE grant on those columns would let an owner set VALIDATED/
--     BACKTESTED/RESEARCH with zero evidence. Both columns stay
--     service_role-only until a future mission wires status transitions
--     through an operation that actually enforces canPromote server-side.
--   * A strategy's status is NEVER SIMULATION_ELIGIBLE/PAPER_ELIGIBLE/
--     LIVE_ELIGIBLE at the database layer either -- the CHECK constraint
--     below only allows the automatic-ceiling statuses this macro's
--     lifecycle.ts actually authorizes (DRAFT/VALIDATED/BACKTESTED/
--     RESEARCH/PAUSED/RETIRED). Reaching the gated statuses requires a
--     future, explicitly authorized migration widening this constraint --
--     not an application-layer bypass.
-- Idempotent: safe to re-apply.

CREATE TABLE IF NOT EXISTS public.strategies (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE CASCADE,
  project_id       uuid NULL REFERENCES public.projects (id) ON DELETE SET NULL,
  name             text NOT NULL,
  status           text NOT NULL DEFAULT 'DRAFT',
  current_version  integer NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT strategies_name_chk CHECK (char_length(btrim(name)) BETWEEN 1 AND 200 AND name = btrim(name)),
  -- Automatic-ceiling statuses only (lifecycle.ts's GATED_TRANSITIONS
  -- target statuses are deliberately absent from this list).
  CONSTRAINT strategies_status_chk CHECK (status IN ('DRAFT', 'VALIDATED', 'BACKTESTED', 'RESEARCH', 'PAUSED', 'RETIRED')),
  CONSTRAINT strategies_current_version_chk CHECK (current_version >= 0)
);

CREATE TABLE IF NOT EXISTS public.strategy_versions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_id     uuid NOT NULL REFERENCES public.strategies (id) ON DELETE CASCADE,
  user_id         uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE CASCADE,
  version_number  integer NOT NULL,
  spec            jsonb NOT NULL,
  spec_hash       text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT strategy_versions_version_chk CHECK (version_number >= 1),
  CONSTRAINT strategy_versions_hash_chk CHECK (spec_hash ~ '^[0-9a-f]{16,64}$'),
  CONSTRAINT strategy_versions_unique UNIQUE (strategy_id, version_number)
);

CREATE TABLE IF NOT EXISTS public.strategy_backtest_results (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_version_id uuid NOT NULL REFERENCES public.strategy_versions (id) ON DELETE CASCADE,
  user_id             uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE CASCADE,
  dataset_id          text NOT NULL,
  dataset_hash        text NOT NULL,
  methodology_status  text NOT NULL,
  net_pnl             numeric NOT NULL,
  trade_count         integer NOT NULL,
  result_hash         text NOT NULL,
  canonical_result    jsonb NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT strategy_backtest_results_methodology_chk CHECK (methodology_status IN ('ZERO_COST_RESEARCH', 'COST_ADJUSTED')),
  CONSTRAINT strategy_backtest_results_trade_count_chk CHECK (trade_count >= 0),
  CONSTRAINT strategy_backtest_results_hash_chk CHECK (result_hash ~ '^[0-9a-f]{16,64}$')
);

CREATE INDEX IF NOT EXISTS strategy_versions_strategy_id_idx ON public.strategy_versions (strategy_id);
CREATE INDEX IF NOT EXISTS strategy_backtest_results_version_id_idx ON public.strategy_backtest_results (strategy_version_id);

-- ── owner-only touch trigger (updated_at) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.strategies_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS strategies_before_update ON public.strategies;
CREATE TRIGGER strategies_before_update BEFORE UPDATE ON public.strategies
  FOR EACH ROW EXECUTE FUNCTION public.strategies_touch_updated_at();

-- ── module entitlement predicate (Macro-08 §5-11: strategy-builder is now
-- COMMERCIAL/free, module_policy.ts -- no longer admin-only) ──────────────
-- SECURITY INVOKER: reads only the caller's OWN profile / role rows under
-- their existing RLS; grants nothing. Fails closed (NULL uid → false).
--
-- Codex adversarial review (Macro-08, diff vs 15d4177) found this predicate
-- still hardcoded to role='admin' after the Edge Function's own entitlement
-- gate (supabase/functions/_shared/module_policy.ts) was promoted to allow
-- every resolvable plan: a real free/pro/premium user would pass
-- requireModuleAccess in strategy-builder/index.ts and then get a bare RLS
-- failure on every list/create/version/backtest read or write. Fixed by
-- widening the predicate to the five profiles.role values entitlement.ts's
-- mapLegacyProfileRole() exhaustively maps to a resolvable plan (free, pro,
-- premium, beta_tester, admin) -- any other value stays denied here too,
-- matching mapLegacyProfileRole's own "anything else -> plan:null -> deny".
-- This predicate stays MODULE-level only (does this role reach the tables at
-- all); the finer PER-OPERATION plan gate (pro for propose_variants/
-- record_experiment/list_experiments/run_research_loop, premium for
-- run_simulation) is enforced separately in strategy-builder/index.ts's
-- planAllowsOp -- RLS has no visibility into which op a request is for.
CREATE OR REPLACE FUNCTION public.strategy_builder_access_allowed()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = public, pg_temp AS $$
DECLARE
  uid uuid := auth.uid();
  allowed boolean := false;
BEGIN
  IF uid IS NULL THEN
    RETURN false;
  END IF;
  SELECT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = uid AND p.role IN ('free', 'pro', 'premium', 'beta_tester', 'admin')) INTO allowed;
  IF NOT allowed AND to_regclass('public.subject_roles') IS NOT NULL THEN
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.subject_roles r WHERE r.subject_type = ''user'' AND r.subject_id = $1 AND r.role = ''admin'')'
      INTO allowed USING uid;
  END IF;
  RETURN coalesce(allowed, false);
END $$;

-- ── RLS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.strategies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strategy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strategy_backtest_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS strategies_select_own ON public.strategies;
CREATE POLICY strategies_select_own ON public.strategies
  FOR SELECT TO authenticated USING (user_id = auth.uid() AND public.strategy_builder_access_allowed());

DROP POLICY IF EXISTS strategies_insert_own ON public.strategies;
CREATE POLICY strategies_insert_own ON public.strategies
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid()
    AND public.strategy_builder_access_allowed()
    AND (project_id IS NULL OR EXISTS (
      SELECT 1 FROM public.projects p WHERE p.id = project_id AND p.user_id = auth.uid()
    ))
  );

DROP POLICY IF EXISTS strategies_update_own ON public.strategies;
CREATE POLICY strategies_update_own ON public.strategies
  FOR UPDATE TO authenticated USING (user_id = auth.uid() AND public.strategy_builder_access_allowed())
  WITH CHECK (user_id = auth.uid() AND public.strategy_builder_access_allowed());

DROP POLICY IF EXISTS strategies_delete_own ON public.strategies;
CREATE POLICY strategies_delete_own ON public.strategies
  FOR DELETE TO authenticated USING (user_id = auth.uid() AND public.strategy_builder_access_allowed());

DROP POLICY IF EXISTS strategy_versions_select_own ON public.strategy_versions;
CREATE POLICY strategy_versions_select_own ON public.strategy_versions
  FOR SELECT TO authenticated USING (user_id = auth.uid() AND public.strategy_builder_access_allowed());

DROP POLICY IF EXISTS strategy_versions_insert_own ON public.strategy_versions;
CREATE POLICY strategy_versions_insert_own ON public.strategy_versions
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid()
    AND public.strategy_builder_access_allowed()
    AND EXISTS (SELECT 1 FROM public.strategies s WHERE s.id = strategy_id AND s.user_id = auth.uid())
  );

DROP POLICY IF EXISTS strategy_backtest_results_select_own ON public.strategy_backtest_results;
CREATE POLICY strategy_backtest_results_select_own ON public.strategy_backtest_results
  FOR SELECT TO authenticated USING (user_id = auth.uid() AND public.strategy_builder_access_allowed());

DROP POLICY IF EXISTS strategy_backtest_results_insert_own ON public.strategy_backtest_results;
CREATE POLICY strategy_backtest_results_insert_own ON public.strategy_backtest_results
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid()
    AND public.strategy_builder_access_allowed()
    AND EXISTS (
      SELECT 1 FROM public.strategy_versions v
      JOIN public.strategies s ON s.id = v.strategy_id
      WHERE v.id = strategy_version_id AND s.user_id = auth.uid()
    )
  );

-- ── privileges (explicit; override Supabase default grants) ──────────────
REVOKE ALL ON public.strategies FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.strategy_versions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.strategy_backtest_results FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, DELETE ON public.strategies TO authenticated;
GRANT UPDATE (name) ON public.strategies TO authenticated;
GRANT SELECT, INSERT ON public.strategy_versions TO authenticated;
GRANT SELECT, INSERT ON public.strategy_backtest_results TO authenticated;
GRANT ALL ON public.strategies, public.strategy_versions, public.strategy_backtest_results TO service_role;

REVOKE ALL ON FUNCTION public.strategy_builder_access_allowed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.strategy_builder_access_allowed() TO authenticated;
