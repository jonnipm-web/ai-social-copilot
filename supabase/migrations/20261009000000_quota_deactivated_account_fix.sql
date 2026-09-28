-- Macro-10 §14 revalidation (R-SEC-05) — public.profiles.is_active has
-- existed since the production baseline (20260907120000) but was never
-- read by try_reserve_ai_quota: an admin setting is_active = false on a
-- profile (lib/data/services/profile_service.dart's only write site for
-- this column) had zero server-side enforcement effect. A deactivated
-- account could still reserve and consume AI quota indefinitely. The
-- companion Edge Function fix (supabase/functions/_shared/entitlement.ts,
-- same mission) closes the parallel gap in module/access decisions;
-- this migration closes the DB-layer quota gap so both enforcement
-- points agree. LAB until rehearsed — see migration_manifest.tsv.
CREATE OR REPLACE FUNCTION public.try_reserve_ai_quota(
  p_idempotency_key uuid DEFAULT NULL,
  p_operation_type  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_user_id        uuid := auth.uid();
  v_role           text;
  v_limit          int;
  v_is_active      boolean;
  v_period         date := date_trunc('month', now())::date;
  v_count          int;
  v_reservation_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  IF p_idempotency_key IS NOT NULL AND
     (p_operation_type IS NULL OR btrim(p_operation_type) = '') THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_request');
  END IF;

  SELECT role, monthly_limit, is_active INTO v_role, v_limit, v_is_active
  FROM public.profiles WHERE id = v_user_id;

  IF v_role IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'no_profile');
  END IF;

  IF v_is_active IS FALSE THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'account_deactivated');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    INSERT INTO public.ai_quota_reservations
      (user_id, idempotency_key, operation_type, period_start, status)
    VALUES (v_user_id, p_idempotency_key, p_operation_type, v_period, 'reserved')
    ON CONFLICT (user_id, idempotency_key, operation_type, period_start)
      WHERE status = 'reserved'
      DO NOTHING
    RETURNING id INTO v_reservation_id;

    IF v_reservation_id IS NULL THEN
      SELECT id INTO v_reservation_id
      FROM public.ai_quota_reservations
      WHERE user_id = v_user_id
        AND idempotency_key = p_idempotency_key
        AND operation_type = p_operation_type
        AND period_start = v_period
        AND status = 'reserved';

      SELECT request_count INTO v_count
      FROM public.ai_usage WHERE user_id = v_user_id AND period_start = v_period;
      RETURN jsonb_build_object(
        'allowed', true, 'idempotent_replay', true,
        'reservation_id', v_reservation_id,
        'used', COALESCE(v_count, 0), 'limit', v_limit, 'role', v_role
      );
    END IF;
  END IF;

  INSERT INTO public.ai_usage (user_id, period_start, request_count)
  VALUES (v_user_id, v_period, 0)
  ON CONFLICT (user_id, period_start) DO NOTHING;

  UPDATE public.ai_usage
  SET request_count = request_count + 1, updated_at = now()
  WHERE user_id = v_user_id AND period_start = v_period AND request_count < v_limit
  RETURNING request_count INTO v_count;

  IF v_count IS NULL THEN
    IF v_reservation_id IS NOT NULL THEN
      DELETE FROM public.ai_quota_reservations WHERE id = v_reservation_id;
    END IF;
    SELECT request_count INTO v_count
    FROM public.ai_usage WHERE user_id = v_user_id AND period_start = v_period;
    RETURN jsonb_build_object(
      'allowed', false, 'reason', 'quota_exceeded',
      'used', v_count, 'limit', v_limit, 'role', v_role
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed', true, 'idempotent_replay', false,
    'reservation_id', v_reservation_id,
    'used', v_count, 'limit', v_limit, 'role', v_role
  );
END;
$function$;
