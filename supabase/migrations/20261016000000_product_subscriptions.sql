-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Product Entitlement System (Opção A+)
--
-- DESIGN: Additive per-product subscription table.
--
--   profiles.role          — still the PLAN source for Core backward compat
--   public.subscriptions   — still Stripe single-product state for Core
--   public.subject_roles   — roles (admin/beta_tester), unchanged
--   NEW: product_subscriptions — one row per (user_id, product) for
--         multi-product ownership. Source-agnostic: Stripe, legacy_core
--         backfill, admin grant, or trial.
--
-- Products: 'core' | 'impact' | 'quant' | 'suite'
-- Tiers:    'free' | 'pro' | 'premium'
-- Source:   'stripe' | 'legacy_core' | 'admin_grant' | 'trial'
-- Status:   Stripe-aligned subset + 'active' (for non-Stripe sources)
--
-- FAIL CLOSED: any failure to resolve → deny. Unknown product → deny.
-- BASE_FREE is not a product row — it is the default for all authenticated
-- users (enforced in resolve_product_entitlement, not in this table).
--
-- Security:
--   RLS enabled. SELECT-only for own user_id (app can read own entitlements).
--   No INSERT/UPDATE/DELETE policy for any client role — only service_role
--   (webhook, admin) writes here. Clients can never grant themselves a product.
--
-- IDEMPOTENT: safe to re-run.
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

-- ── preconditions ────────────────────────────────────────────────────────────
DO $$
DECLARE v_missing text[] := ARRAY[]::text[];
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles'
      AND column_name='id' AND data_type='uuid') THEN
    v_missing := v_missing || 'public.profiles.id uuid';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='subscriptions') THEN
    v_missing := v_missing || 'public.subscriptions';
  END IF;
  IF (SELECT count(*) FROM pg_roles
      WHERE rolname IN ('anon','authenticated','service_role')) <> 3 THEN
    v_missing := v_missing || 'roles anon/authenticated/service_role';
  END IF;
  IF array_length(v_missing,1) > 0 THEN
    RAISE EXCEPTION 'UNIFICATION_PRECONDITION (20261016000000): missing: %',
      array_to_string(v_missing,', ') USING ERRCODE='AE010';
  END IF;
END $$;

-- ── product_subscriptions ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.product_subscriptions (
  id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id                 uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product                 text        NOT NULL,
  tier                    text        NOT NULL DEFAULT 'free',
  status                  text        NOT NULL DEFAULT 'active',
  source                  text        NOT NULL,
  stripe_subscription_id  text        NULL,
  stripe_price_id         text        NULL,
  current_period_end      timestamptz NULL,
  cancel_at_period_end          boolean     NOT NULL DEFAULT false,
  last_stripe_event_created     timestamptz NULL,
  granted_by                    uuid        NULL,
  metadata                      jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at                    timestamptz NOT NULL DEFAULT now(),
  updated_at                    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT product_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT product_subscriptions_user_product_key UNIQUE (user_id, product),

  CONSTRAINT product_subscriptions_product_check CHECK (
    product IN ('core','impact','quant','suite')
  ),
  CONSTRAINT product_subscriptions_tier_check CHECK (
    tier IN ('free','pro','premium')
  ),
  CONSTRAINT product_subscriptions_status_check CHECK (
    status IN (
      'active','trialing','past_due','canceled','unpaid','paused',
      'incomplete','incomplete_expired','none'
    )
  ),
  CONSTRAINT product_subscriptions_source_check CHECK (
    source IN ('stripe','legacy_core','admin_grant','trial')
  )
);

ALTER TABLE public.product_subscriptions ENABLE ROW LEVEL SECURITY;

-- SELECT: user reads own entitlements (app can show product status)
CREATE POLICY "ps_users_read_own"
  ON public.product_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at_product_subscriptions()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_product_subscriptions_updated_at ON public.product_subscriptions;
CREATE TRIGGER trg_product_subscriptions_updated_at
  BEFORE UPDATE ON public.product_subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_product_subscriptions();

-- grants
REVOKE ALL ON TABLE public.product_subscriptions FROM PUBLIC;
REVOKE ALL ON TABLE public.product_subscriptions FROM anon, authenticated;
GRANT SELECT ON TABLE public.product_subscriptions TO authenticated;
-- service_role accesses via RLS bypass (Supabase design); no explicit GRANT needed

-- ── product_entitlement_events ───────────────────────────────────────────────
-- Immutable audit log for every product entitlement change. Never updated
-- or deleted. Provides replay capability for billing reconciliation.
CREATE TABLE IF NOT EXISTS public.product_entitlement_events (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product      text        NOT NULL,
  event_type   text        NOT NULL,
  from_status  text        NULL,
  to_status    text        NULL,
  from_tier    text        NULL,
  to_tier      text        NULL,
  source       text        NOT NULL,
  stripe_event_id text     NULL,
  metadata     jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pee_pkey PRIMARY KEY (id),
  CONSTRAINT pee_product_check CHECK (
    product IN ('core','impact','quant','suite','unknown')
  ),
  CONSTRAINT pee_event_type_check CHECK (
    event_type IN (
      'created','activated','upgraded','downgraded',
      'canceled','expired','reinstated','admin_grant','trial_started',
      'pending_retry'
    )
  )
);

ALTER TABLE public.product_entitlement_events ENABLE ROW LEVEL SECURITY;

-- SELECT: user reads own events only
CREATE POLICY "pee_users_read_own"
  ON public.product_entitlement_events FOR SELECT
  USING (auth.uid() = user_id);

REVOKE ALL ON TABLE public.product_entitlement_events FROM PUBLIC;
REVOKE ALL ON TABLE public.product_entitlement_events FROM anon, authenticated;
GRANT SELECT ON TABLE public.product_entitlement_events TO authenticated;

-- IDEMPOTENT constraint update: if table already existed with the old
-- pee_product_check (without 'unknown'), replace it. This handles LAB
-- environments that ran the original migration before this fix.
ALTER TABLE IF EXISTS public.product_entitlement_events
  DROP CONSTRAINT IF EXISTS pee_product_check;
ALTER TABLE IF EXISTS public.product_entitlement_events
  ADD CONSTRAINT pee_product_check CHECK (
    product IN ('core','impact','quant','suite','unknown')
  );

COMMENT ON TABLE public.product_subscriptions IS
  'IV-WEB-ECOSYSTEM-UNIFICATION-01: per-product subscription state. '
  'Source-agnostic (Stripe, legacy_core backfill, admin grant, trial). '
  'PRODUCTION PROTECTION: not applied without AM+Paulo gate.';

COMMENT ON TABLE public.product_entitlement_events IS
  'IV-WEB-ECOSYSTEM-UNIFICATION-01: immutable audit log for product '
  'entitlement transitions. Never updated/deleted. Supports billing replay.';
