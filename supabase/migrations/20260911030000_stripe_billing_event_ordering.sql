-- IVE-COMMERCIAL-BILLING-01 — Codex re-verification of the previous fix
-- (task-mtw7wtog-py3laq, second pass) found the earlier atomic-RPC fix
-- closed torn writes but not a narrower, still-real race: two DIFFERENT
-- webhook events for the same subscription (e.g. an update and a later
-- cancellation) can each independently call Stripe's GET at slightly
-- different times and get different snapshots; if their two (individually
-- atomic) RPC calls then commit in an order that doesn't match the true
-- Stripe event order, the chronologically OLDER event's snapshot can
-- overwrite the newer one's, even though each single write is internally
-- consistent.
--
-- Fix: every Stripe event carries its own `created` field -- the Unix
-- timestamp Stripe itself assigned when the event was generated. Unlike
-- delivery order, this value is stable and comparable across events for
-- the same subscription. Storing a high-water mark and only applying an
-- update when its event is not older than the last one actually applied
-- makes the write itself order-safe, independent of GET-timing races or
-- delivery-order races: whichever event is chronologically newest always
-- wins, regardless of which HTTP request happens to finish last.
--
-- ADDITIVE ONLY.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.apply_stripe_subscription_state(uuid, timestamptz, text, text, text, timestamptz, boolean, text, integer);
--   ALTER TABLE public.subscriptions DROP COLUMN IF EXISTS last_event_created;
--   (then re-apply migration 20260911020000's CREATE OR REPLACE FUNCTION to restore the previous signature, if ever needed)

ALTER TABLE public.subscriptions ADD COLUMN last_event_created timestamptz;

-- Return type changes (void -> boolean), so the old signature must be
-- dropped explicitly -- CREATE OR REPLACE cannot change a function's
-- return type.
DROP FUNCTION IF EXISTS public.apply_stripe_subscription_state(uuid, text, text, text, timestamptz, boolean, text, integer);

CREATE OR REPLACE FUNCTION public.apply_stripe_subscription_state(
  p_user_id                uuid,
  p_event_created          timestamptz,
  p_stripe_subscription_id text,
  p_stripe_price_id        text,
  p_status                 text,
  p_current_period_end     timestamptz,
  p_cancel_at_period_end   boolean,
  p_role                   text,
  p_monthly_limit          integer
)
RETURNS boolean -- true if applied, false if skipped as stale (a newer event already won)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_row_count integer;
  v_applied   boolean;
BEGIN
  UPDATE public.subscriptions
  SET stripe_subscription_id = p_stripe_subscription_id,
      stripe_price_id        = p_stripe_price_id,
      status                 = p_status,
      current_period_end     = p_current_period_end,
      cancel_at_period_end   = p_cancel_at_period_end,
      last_event_created     = p_event_created
  WHERE user_id = p_user_id
    AND (last_event_created IS NULL OR p_event_created >= last_event_created);

  GET DIAGNOSTICS v_row_count = ROW_COUNT;
  v_applied := v_row_count > 0;

  IF v_applied THEN
    UPDATE public.profiles
    SET role = p_role,
        monthly_limit = p_monthly_limit
    WHERE id = p_user_id;
  END IF;

  RETURN v_applied;
END;
$function$;

REVOKE ALL ON FUNCTION public.apply_stripe_subscription_state(uuid, timestamptz, text, text, text, timestamptz, boolean, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_stripe_subscription_state(uuid, timestamptz, text, text, text, timestamptz, boolean, text, integer) FROM anon;
REVOKE ALL ON FUNCTION public.apply_stripe_subscription_state(uuid, timestamptz, text, text, text, timestamptz, boolean, text, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.apply_stripe_subscription_state(uuid, timestamptz, text, text, text, timestamptz, boolean, text, integer) TO service_role;
