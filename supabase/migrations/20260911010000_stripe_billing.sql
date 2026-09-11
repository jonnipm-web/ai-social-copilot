-- IVE-COMMERCIAL-BILLING-01 (Fast Track IV) — minimum additive schema for
-- Stripe-backed subscriptions, TEST MODE ONLY at this stage.
--
-- Design choice: profiles.role/monthly_limit (already tamper-proof since
-- migration 20260907120001) REMAIN the fast entitlement source that
-- try_reserve_ai_quota() reads -- zero changes needed there. This
-- migration only adds where Stripe/webhook state is durably recorded and
-- how it flows into those two columns.
--
-- Both new tables are written ONLY by the stripe-webhook Edge Function,
-- which authenticates to Postgres as service_role (bypasses RLS by
-- Supabase's own design) after independently verifying a Stripe
-- signature -- never by an authenticated user's own session, and never
-- via a new SECURITY DEFINER RPC (unlike the quota system, there is no
-- "the calling user's own auth.uid()" concept for a Stripe webhook; the
-- trust boundary is the signature, not a JWT). RLS on both tables has
-- SELECT-only (or no) policies for authenticated -- no INSERT/UPDATE/
-- DELETE policy exists for any client role, so a direct PostgREST call
-- from the app can never write to either table, only read the row RLS
-- lets it see. This does not touch or weaken the existing X4B
-- self-promotion trigger on profiles at all -- service_role already
-- satisfies that trigger's own carve-out (`auth.role() = 'service_role'`).
--
-- ADDITIVE ONLY. No existing table, column, policy, trigger, or function
-- is altered or dropped.
--
-- ROLLBACK:
--   DROP TABLE IF EXISTS public.processed_webhook_events;
--   DROP TABLE IF EXISTS public.subscriptions;

CREATE TABLE public.subscriptions (
  user_id                 uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_customer_id      text NOT NULL,
  stripe_subscription_id  text,
  stripe_price_id         text,
  status                  text NOT NULL DEFAULT 'none',
  current_period_end      timestamptz,
  cancel_at_period_end    boolean NOT NULL DEFAULT false,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT subscriptions_stripe_customer_id_key UNIQUE (stripe_customer_id),
  CONSTRAINT subscriptions_status_check CHECK (status IN (
    'none', 'incomplete', 'incomplete_expired', 'trialing', 'active',
    'past_due', 'canceled', 'unpaid', 'paused'
  ))
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Read-only for the row's own user (so the app can show subscription
-- status/renewal date if it wants to). No write policy for any client
-- role -- only service_role (the webhook) can ever write here.
CREATE POLICY "users_read_own_subscription" ON public.subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.set_updated_at_subscriptions()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at_subscriptions();

-- Durable webhook idempotency. INSERT ... ON CONFLICT DO NOTHING
-- RETURNING is the atomic "is this new?" check the webhook handler uses
-- before acting on any event -- a duplicate delivery (Stripe explicitly
-- does not guarantee exactly-once delivery) inserts nothing and the
-- handler skips processing but still returns 200.
CREATE TABLE public.processed_webhook_events (
  event_id     text PRIMARY KEY,
  event_type   text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.processed_webhook_events ENABLE ROW LEVEL SECURITY;
-- No policies at all: not even SELECT for authenticated/anon. Purely
-- internal bookkeeping for the webhook handler (service_role), never
-- meant to be read by the app.
