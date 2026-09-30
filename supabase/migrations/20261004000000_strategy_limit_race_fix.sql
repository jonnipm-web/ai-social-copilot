-- INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 — Codex final audit (P1 fix, round 1).
--
-- Codex found: STRATEGY_LIMIT_BY_PLAN in strategy-builder/index.ts is
-- enforced as list-then-insert (two separate round-trips) -- concurrent
-- create/clone_reference requests from the same user can both observe a
-- count below the limit and both succeed, exceeding the advertised cap.
--
-- Fix (mirrors 20260924000000_quant_watchlists.sql's own
-- quant_watchlists_before_write, the existing race-safe pattern in this
-- codebase): a BEFORE INSERT trigger takes a per-user advisory
-- transaction lock FIRST, serializing concurrent creates by the SAME
-- user, then counts under that lock. The app-level check in index.ts is
-- NOT removed -- it stays as a fast, friendly pre-check (a good error
-- message without needing to wait on the trigger's exception) -- but the
-- database is now the actual, race-safe authority: a caller who somehow
-- got past the app-level check (the race Codex found) still cannot
-- exceed the limit, because the trigger re-checks under the lock
-- regardless of what the application already believed.
--
-- Idempotent: safe to re-apply.

CREATE OR REPLACE FUNCTION public.strategies_enforce_plan_limit()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = public, pg_temp AS $$
DECLARE
  user_role text;
  plan_limit integer;
BEGIN
  -- Serialize concurrent creates by the SAME user so the cap cannot be
  -- raced (Codex final audit, P1) -- identical technique to
  -- quant_watchlists_before_write's own pg_advisory_xact_lock.
  PERFORM pg_advisory_xact_lock(hashtextextended('strategies:' || NEW.user_id::text, 0));

  SELECT p.role INTO user_role FROM public.profiles p WHERE p.id = NEW.user_id;
  -- Mirrors entitlement.ts's mapLegacyProfileRole: only 'pro'/'premium'
  -- raise the limit; every other value (including 'admin', 'free',
  -- 'beta_tester', unknown, or no row at all) fails closed to the free
  -- limit -- never accidentally to an unlimited one. Premium's own
  -- limit (Macro-08 §37 fix) is a high FINITE fair-use cap (mirrors
  -- strategy-builder/index.ts's STRATEGY_LIMIT_BY_PLAN.premium=200),
  -- not 2147483647 -- "unlimited" was itself the finding: unbounded
  -- storage/compute exposure from a single account. PROVISIONAL_CAP
  -- (Macro-08 continuation §20): 200 is a judgment-based safety
  -- ceiling, not derived from real usage telemetry (nothing is
  -- deployed yet) -- keep in sync with the TS constant's own comment.
  plan_limit := CASE user_role
    WHEN 'pro' THEN 20
    WHEN 'premium' THEN 200
    ELSE 3
  END;

  IF (SELECT count(*) FROM public.strategies s WHERE s.user_id = NEW.user_id) >= plan_limit THEN
    RAISE EXCEPTION 'STRATEGY_LIMIT_REACHED' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS strategies_enforce_plan_limit ON public.strategies;
CREATE TRIGGER strategies_enforce_plan_limit BEFORE INSERT ON public.strategies
  FOR EACH ROW EXECUTE FUNCTION public.strategies_enforce_plan_limit();

REVOKE ALL ON FUNCTION public.strategies_enforce_plan_limit() FROM PUBLIC, anon, authenticated;
