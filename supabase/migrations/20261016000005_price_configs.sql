-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Stripe Price Config Table (P1-J fix)
--
-- Creates stripe_price_configs to persist price→(product,tier) mappings.
-- This allows process_pending_entitlement_events (SQL worker) to resolve
-- unknown-price events WITHOUT requiring the entitlement-reconcile Edge
-- Function to be scheduled separately.
--
-- Flow:
--   1. Operator configures STRIPE_PRICE_MAP on entitlement-reconcile Edge Function.
--   2. Edge Function runs → upserts mappings into stripe_price_configs.
--   3. pg_cron runs SQL worker → reads stripe_price_configs → resolves unknown events.
--
-- Without this table, the pg_cron SQL worker could not resolve unknown-price
-- events (P1-J: two scheduling paths had disjoint capabilities).
--
-- IDEMPOTENT: safe to re-run.
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

CREATE TABLE IF NOT EXISTS public.stripe_price_configs (
  price_id   text        PRIMARY KEY,
  product    text        NOT NULL CHECK (product IN ('core','impact','quant','suite')),
  tier       text        NOT NULL CHECK (tier IN ('free','pro','premium')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.stripe_price_configs IS
  'IV-WEB-ECOSYSTEM-UNIFICATION-01: Persisted Stripe price→(product,tier) mappings. '
  'Populated by entitlement-reconcile Edge Function when STRIPE_PRICE_MAP is configured. '
  'Read by process_pending_entitlement_events to resolve unknown-product events. '
  'PRODUCTION PROTECTION: gate required.';

-- Only service_role may write; authenticated may read (for UI display if needed)
REVOKE ALL  ON TABLE public.stripe_price_configs FROM PUBLIC;
GRANT SELECT ON TABLE public.stripe_price_configs TO authenticated;
GRANT ALL    ON TABLE public.stripe_price_configs TO service_role;
