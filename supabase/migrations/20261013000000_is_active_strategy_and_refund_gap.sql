-- Macro-10 §52 — final Codex audit of the whole diff (job
-- ab236568dc84c9b7b) found two remaining is_active gaps that the
-- earlier fix (20261009000000, entitlement.ts) did not cover:
--
-- P1: strategy_builder_access_allowed() (20261002000000) -- the
-- predicate backing every strategy_* RLS policy and used directly by
-- strategies_create_with_version -- checks only profiles.role /
-- subject_roles, never is_active. A deactivated user with a
-- still-qualifying role could read/write strategy data directly via
-- PostgREST or call the creation RPC, bypassing the Edge Function's
-- entitlement.ts check entirely (the same class of app-vs-DB-boundary
-- gap this whole session's is_active work has been closing).
--
-- P2: refund_ai_quota(uuid) (20260918000000, APPLIED_PRODUCTION) also
-- never checks is_active, and stays granted to authenticated. Lower
-- severity -- it can only refund a reservation the same user already
-- created (never grants fresh capacity, try_reserve_ai_quota already
-- blocks that) -- but fixed for the same defense-in-depth reason: a
-- deactivated account should not be able to mutate its own quota
-- ledger at all.
--
-- Idempotent: safe to re-apply. LAB until rehearsed.

CREATE OR REPLACE FUNCTION public.strategy_builder_access_allowed()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = public, pg_temp AS $$
DECLARE
  uid uuid := auth.uid();
  allowed boolean := false;
BEGIN
  IF uid IS NULL THEN
    RETURN false;
  END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = uid AND p.role IN ('free', 'pro', 'premium', 'beta_tester', 'admin') AND p.is_active
  ) INTO allowed;
  IF NOT allowed AND to_regclass('public.subject_roles') IS NOT NULL THEN
    EXECUTE 'SELECT EXISTS (
      SELECT 1 FROM public.subject_roles r
      JOIN public.profiles p ON p.id = r.subject_id
      WHERE r.subject_type = ''user'' AND r.subject_id = $1 AND r.role = ''admin'' AND p.is_active
    )'
      INTO allowed USING uid;
  END IF;
  RETURN coalesce(allowed, false);
END $$;

CREATE OR REPLACE FUNCTION public.refund_ai_quota(
  p_reservation_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id           uuid := auth.uid();
  v_is_active         boolean;
  v_updated           int;
  v_reservation_period date;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT is_active INTO v_is_active FROM public.profiles WHERE id = v_user_id;
  IF v_is_active IS FALSE THEN
    RETURN false;
  END IF;

  IF p_reservation_id IS NOT NULL THEN
    UPDATE public.ai_quota_reservations
    SET status = 'refunded', refunded_at = now()
    WHERE id = p_reservation_id
      AND user_id = v_user_id
      AND status = 'reserved'
    RETURNING period_start INTO v_reservation_period;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 0 THEN
      RETURN false;
    END IF;

    UPDATE public.ai_usage
    SET request_count = GREATEST(request_count - 1, 0), updated_at = now()
    WHERE user_id = v_user_id AND period_start = v_reservation_period;
    RETURN true;
  END IF;

  UPDATE public.ai_usage
  SET request_count = GREATEST(request_count - 1, 0), updated_at = now()
  WHERE user_id = v_user_id AND period_start = date_trunc('month', now())::date;
  RETURN true;
END;
$function$;
