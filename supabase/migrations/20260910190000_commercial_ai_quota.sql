-- IVE-COMMERCIAL-ENTITLEMENTS-01 — minimum server-side AI usage quota.
--
-- Reuses existing, already-hardened schema instead of inventing a new
-- entitlement model: public.profiles.role ('free'/'pro'/'premium'/
-- 'beta_tester'/'admin') and public.profiles.monthly_limit are already the
-- plan/quota-limit source of truth, and migration 20260907120001 (X4B)
-- already made both tamper-proof (a client can never self-promote role or
-- raise their own monthly_limit -- verified live on production before
-- writing this file: trg_prevent_self_privilege_escalation exists and is
-- enabled).
--
-- What's missing is a USAGE COUNTER. This migration adds exactly that, as
-- a new table rather than new columns on profiles, so it never has to
-- touch that already-audited trigger/policy at all.
--
-- ADDITIVE ONLY: one new table, two new SECURITY DEFINER functions. No
-- existing table, column, policy, or trigger is altered or dropped.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.refund_ai_quota();
--   DROP FUNCTION IF EXISTS public.try_reserve_ai_quota();
--   DROP TABLE IF EXISTS public.ai_usage;

CREATE TABLE public.ai_usage (
  user_id       uuid NOT NULL,
  period_start  date NOT NULL,
  request_count integer NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ai_usage_pkey PRIMARY KEY (user_id, period_start),
  CONSTRAINT ai_usage_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT ai_usage_request_count_nonneg CHECK (request_count >= 0)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

-- Read-only for the row's own user (so the app can show "X of Y used this
-- month"). No INSERT/UPDATE/DELETE policy for anyone but service_role --
-- the only writers are the SECURITY DEFINER functions below, which bypass
-- RLS by design (that's the whole point of SECURITY DEFINER) while still
-- deriving identity from auth.uid(), never from a client-supplied value.
CREATE POLICY "users_read_own_ai_usage" ON public.ai_usage
  FOR SELECT USING (auth.uid() = user_id);

-- try_reserve_ai_quota(): the ONLY way a client-side call can increment
-- usage. Atomic (single conditional UPDATE, relies on Postgres row-level
-- locking -- concurrent calls serialize on the same (user_id, period_start)
-- row, so this cannot overshoot monthly_limit or go negative under
-- concurrency). Reserves BEFORE the caller does any AI work: if the AI
-- call then fails, the caller must call refund_ai_quota() to give the unit
-- back (see supabase/functions/_shared/quota.ts for the paired usage).
--
-- Never trusts a client-supplied user id, plan, or limit -- auth.uid() and
-- profiles.role/monthly_limit (already tamper-proof) are the only inputs.
CREATE OR REPLACE FUNCTION public.try_reserve_ai_quota()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text;
  v_limit int;
  v_period date := date_trunc('month', now())::date;
  v_count int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  SELECT role, monthly_limit INTO v_role, v_limit
  FROM public.profiles WHERE id = v_user_id;

  IF v_role IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'no_profile');
  END IF;

  INSERT INTO public.ai_usage (user_id, period_start, request_count)
  VALUES (v_user_id, v_period, 0)
  ON CONFLICT (user_id, period_start) DO NOTHING;

  UPDATE public.ai_usage
  SET request_count = request_count + 1, updated_at = now()
  WHERE user_id = v_user_id AND period_start = v_period AND request_count < v_limit
  RETURNING request_count INTO v_count;

  IF v_count IS NULL THEN
    SELECT request_count INTO v_count
    FROM public.ai_usage WHERE user_id = v_user_id AND period_start = v_period;
    RETURN jsonb_build_object(
      'allowed', false, 'reason', 'quota_exceeded',
      'used', v_count, 'limit', v_limit, 'role', v_role
    );
  END IF;

  RETURN jsonb_build_object('allowed', true, 'used', v_count, 'limit', v_limit, 'role', v_role);
END;
$function$;

-- refund_ai_quota(): compensating decrement for AI-provider failures, so a
-- Groq outage/error doesn't permanently cost the user a unit of their
-- monthly allowance. Floors at 0 (CHECK constraint backs this up too).
-- Same identity rule as above: auth.uid() only, never a parameter.
CREATE OR REPLACE FUNCTION public.refund_ai_quota()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_period date := date_trunc('month', now())::date;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.ai_usage
  SET request_count = GREATEST(request_count - 1, 0), updated_at = now()
  WHERE user_id = v_user_id AND period_start = v_period;
END;
$function$;

-- Only real, logged-in users may call these -- not anon, not public.
REVOKE ALL ON FUNCTION public.try_reserve_ai_quota() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.refund_ai_quota() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.try_reserve_ai_quota() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_quota() TO authenticated;
