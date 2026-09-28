-- Macro-10 §14 revalidation (R-SEC-06) — apply_stripe_subscription_state
-- (migration 20260911030000) unconditionally overwrites public.profiles
-- .role with 'pro' or 'free' (the only two values
-- stripe-webhook/index.ts's entitlementForStatus ever produces) on every
-- processed Stripe event for a user's subscription. profiles.role also
-- holds three values Stripe knows nothing about and must never touch:
-- 'admin', 'beta_tester', 'premium' (CHECK constraint,
-- 20260907120000_baseline_production_pre_x4r.sql). Any admin, beta
-- tester, or manually-granted premium user who has ever gone through
-- Stripe checkout (creating a public.subscriptions row for their
-- user_id) would be silently demoted to 'pro'/'free' by the next
-- ordinary billing event (renewal, cancellation, payment-method update)
-- — an external system quietly overwriting a role it doesn't own and
-- has no business changing. This migration scopes the role/monthly_limit
-- write to only the two roles Stripe actually manages, leaving
-- admin/beta_tester/premium untouched regardless of subscription events.
-- The subscriptions-table write (status, period, etc.) is unaffected and
-- still applies for every user, since billing state itself is legitimate
-- to record even for a role Stripe doesn't control.
-- LAB until rehearsed — see migration_manifest.tsv.
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
    -- Only overwrite role/monthly_limit for the two roles Stripe itself
    -- manages. admin/beta_tester/premium are granted through other
    -- channels (admin panel, beta program, manual entitlement) and must
    -- never be silently downgraded by a billing webhook.
    UPDATE public.profiles
    SET role = p_role,
        monthly_limit = p_monthly_limit
    WHERE id = p_user_id
      AND role IN ('free', 'pro');
  END IF;

  RETURN v_applied;
END;
$function$;
