-- IVE-COMMERCIAL-BILLING-01 — Codex adversarial gate (task-mtw7wtog-py3laq)
-- found that stripe-webhook wrote public.subscriptions and public.profiles
-- as two separate PostgREST round-trips (two independent HTTP requests),
-- so a failure between them (network blip, function timeout) could leave
-- subscriptions.status updated but profiles.role/monthly_limit stale, or
-- vice versa -- an entitlement/billing-state mismatch (P1 finding).
--
-- Fix: a single Postgres function that updates both rows in one
-- transaction, called once via .rpc() instead of two .update() calls.
--
-- SECURITY: this function accepts an arbitrary p_user_id/p_role/
-- p_monthly_limit and writes profiles.role/monthly_limit directly --
-- exactly the two columns the X4B self-promotion trigger
-- (20260907120001) protects. It MUST NOT be callable by anon or
-- authenticated -- doing so would be a direct, unauthenticated
-- self-privilege-escalation hole (any signed-in user could call
-- `apply_stripe_subscription_state(auth.uid(), ..., 'admin', 999999999)`).
-- EXECUTE is revoked from PUBLIC/anon/authenticated and granted only to
-- service_role, which is the only role stripe-webhook ever authenticates
-- as -- this does not create a new privilege path, it's the same
-- service_role carve-out the X4B trigger and the existing
-- create-checkout-session/stripe-webhook service client already rely on.
--
-- ADDITIVE ONLY.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.apply_stripe_subscription_state(uuid, text, text, text, timestamptz, boolean, text, integer);

CREATE OR REPLACE FUNCTION public.apply_stripe_subscription_state(
  p_user_id                uuid,
  p_stripe_subscription_id text,
  p_stripe_price_id        text,
  p_status                 text,
  p_current_period_end     timestamptz,
  p_cancel_at_period_end   boolean,
  p_role                   text,
  p_monthly_limit          integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
BEGIN
  UPDATE public.subscriptions
  SET stripe_subscription_id = p_stripe_subscription_id,
      stripe_price_id        = p_stripe_price_id,
      status                 = p_status,
      current_period_end     = p_current_period_end,
      cancel_at_period_end   = p_cancel_at_period_end
  WHERE user_id = p_user_id;

  UPDATE public.profiles
  SET role = p_role,
      monthly_limit = p_monthly_limit
  WHERE id = p_user_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.apply_stripe_subscription_state(uuid, text, text, text, timestamptz, boolean, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_stripe_subscription_state(uuid, text, text, text, timestamptz, boolean, text, integer) FROM anon;
REVOKE ALL ON FUNCTION public.apply_stripe_subscription_state(uuid, text, text, text, timestamptz, boolean, text, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.apply_stripe_subscription_state(uuid, text, text, text, timestamptz, boolean, text, integer) TO service_role;
