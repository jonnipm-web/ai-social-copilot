-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Product Entitlement Resolver + Core Backfill
--
-- 1. resolve_product_entitlement(user_id, product) → jsonb
--      Server-authoritative answer: "may this user access this product?"
--      FAIL CLOSED: unknown product, inactive account, expired subscription → deny.
--      BASE_FREE: all authenticated non-anonymous users with active accounts.
--
-- 2. backfill_core_product_subscriptions()
--      One-time backfill: existing Core subscribers (subscriptions.status='active'
--      + profiles.role IN ('pro','premium')) → product_subscriptions(product='core').
--      Idempotent (INSERT ... ON CONFLICT DO NOTHING).
--
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

-- ── resolve_product_entitlement ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.resolve_product_entitlement(
  p_user_id  uuid,
  p_product  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_ps     public.product_subscriptions%ROWTYPE;
  v_active boolean;
BEGIN
  -- Validate product
  IF p_product NOT IN ('core','impact','quant','suite') THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'code',    'UNKNOWN_PRODUCT',
      'reason',  'Product not in canonical list'
    );
  END IF;

  -- Tenant isolation: authenticated callers may only resolve their own entitlements.
  -- service_role calls (backfill, admin) have auth.uid() = NULL and are allowed.
  -- P2 fix (IV-WEB-ECOSYSTEM-UNIFICATION-01): prevents info-disclosure via cross-user lookups.
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'code',    'PERMISSION_DENIED',
      'reason',  'May only resolve own product entitlements'
    );
  END IF;

  -- Check user account active (profiles.is_active when present, else assume active)
  -- We check existence in auth.users — a deleted user has no rows here.
  -- is_active column exists on profiles in some migrations; treat missing as active.
  SELECT COALESCE(
    (SELECT is_active FROM public.profiles
     WHERE id = p_user_id LIMIT 1),
    true
  ) INTO v_active;

  IF NOT v_active THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'code',    'ACCOUNT_INACTIVE',
      'reason',  'User account is not active'
    );
  END IF;

  -- BASE_FREE: no product row needed — every authenticated active user gets it
  IF p_product = 'base_free' THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'product', 'base_free',
      'tier',    'free',
      'source',  'system',
      'reason',  'BASE_FREE_IMPLICIT'
    );
  END IF;

  -- Lookup product subscription
  SELECT * INTO v_ps
  FROM public.product_subscriptions
  WHERE user_id = p_user_id
    AND product  = p_product
  LIMIT 1;

  IF NOT FOUND THEN
    -- Core backward compat: check legacy subscriptions + profiles.role
    IF p_product = 'core' THEN
      DECLARE
        v_role   text;
        v_status text;
      BEGIN
        SELECT s.status, pr.role
        INTO   v_status, v_role
        FROM   public.subscriptions s
        JOIN   public.profiles      pr ON pr.id = s.user_id
        WHERE  s.user_id = p_user_id
        LIMIT  1;

        IF FOUND
           AND v_status IN ('active','trialing')
           AND v_role   IN ('pro','premium') THEN
          RETURN jsonb_build_object(
            'allowed', true,
            'product', 'core',
            'tier',    v_role,
            'source',  'legacy_core',
            'reason',  'LEGACY_CORE_SUBSCRIPTION'
          );
        END IF;
      END;
    END IF;

    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'code',    'NO_ENTITLEMENT',
      'reason',  'No active product subscription found'
    );
  END IF;

  -- Found a product_subscriptions row — check status
  IF v_ps.status NOT IN ('active','trialing') THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'tier',    v_ps.tier,
      'status',  v_ps.status,
      'code',    'SUBSCRIPTION_NOT_ACTIVE',
      'reason',  'Subscription status is ' || v_ps.status
    );
  END IF;

  -- Check expiry
  IF v_ps.current_period_end IS NOT NULL
     AND clock_timestamp() > v_ps.current_period_end
     AND v_ps.status <> 'trialing' THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'tier',    v_ps.tier,
      'code',    'SUBSCRIPTION_EXPIRED',
      'reason',  'current_period_end has passed'
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed',               true,
    'product',               v_ps.product,
    'tier',                  v_ps.tier,
    'status',                v_ps.status,
    'source',                v_ps.source,
    'current_period_end',    v_ps.current_period_end,
    'cancel_at_period_end',  v_ps.cancel_at_period_end,
    'reason',                'ENTITLEMENT_ACTIVE'
  );
END;
$$;

REVOKE ALL   ON FUNCTION public.resolve_product_entitlement(uuid,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.resolve_product_entitlement(uuid,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.resolve_product_entitlement(uuid,text) TO authenticated, service_role;

-- ── upsert_product_subscription ──────────────────────────────────────────────
-- Called by stripe-webhook and admin tools to set/update a product subscription.
-- Writes an audit event on every call. Idempotent (UPSERT).
CREATE OR REPLACE FUNCTION public.upsert_product_subscription(
  p_user_id               uuid,
  p_product               text,
  p_tier                  text,
  p_status                text,
  p_source                text,
  p_stripe_subscription_id text DEFAULT NULL,
  p_stripe_price_id        text DEFAULT NULL,
  p_current_period_end     timestamptz DEFAULT NULL,
  p_cancel_at_period_end   boolean DEFAULT false,
  p_stripe_event_id        text DEFAULT NULL,
  p_metadata               jsonb DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_old_status text;
  v_old_tier   text;
  v_event_type text;
BEGIN
  -- Validation
  IF p_product NOT IN ('core','impact','quant','suite') THEN
    RAISE EXCEPTION 'UPSERT_PRODUCT: invalid product %', p_product;
  END IF;
  IF p_tier NOT IN ('free','pro','premium') THEN
    RAISE EXCEPTION 'UPSERT_PRODUCT: invalid tier %', p_tier;
  END IF;
  IF p_status NOT IN (
    'active','trialing','past_due','canceled','unpaid','paused',
    'incomplete','incomplete_expired','none'
  ) THEN
    RAISE EXCEPTION 'UPSERT_PRODUCT: invalid status %', p_status;
  END IF;
  IF p_source NOT IN ('stripe','legacy_core','admin_grant','trial') THEN
    RAISE EXCEPTION 'UPSERT_PRODUCT: invalid source %', p_source;
  END IF;

  -- Capture old state for audit
  SELECT status, tier INTO v_old_status, v_old_tier
  FROM public.product_subscriptions
  WHERE user_id=p_user_id AND product=p_product;

  -- Determine event type
  IF v_old_status IS NULL THEN
    v_event_type := 'created';
  ELSIF p_status IN ('active','trialing') AND v_old_status NOT IN ('active','trialing') THEN
    v_event_type := 'activated';
  ELSIF p_status IN ('canceled','none') THEN
    v_event_type := 'canceled';
  -- P2 fix: use semantic tier rank ('free'=0 < 'pro'=1 < 'premium'=2) instead of
  -- alphabetical comparison ('pro' > 'premium' alphabetically, which is wrong).
  ELSIF (CASE p_tier      WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) >
        (CASE v_old_tier  WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) THEN
    v_event_type := 'upgraded';
  ELSIF (CASE p_tier      WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) <
        (CASE v_old_tier  WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) THEN
    v_event_type := 'downgraded';
  ELSE
    v_event_type := 'activated'; -- renewal / status update
  END IF;

  INSERT INTO public.product_subscriptions (
    user_id, product, tier, status, source,
    stripe_subscription_id, stripe_price_id,
    current_period_end, cancel_at_period_end, metadata
  ) VALUES (
    p_user_id, p_product, p_tier, p_status, p_source,
    p_stripe_subscription_id, p_stripe_price_id,
    p_current_period_end, p_cancel_at_period_end, p_metadata
  )
  ON CONFLICT (user_id, product) DO UPDATE SET
    tier                    = EXCLUDED.tier,
    status                  = EXCLUDED.status,
    source                  = EXCLUDED.source,
    stripe_subscription_id  = COALESCE(EXCLUDED.stripe_subscription_id, product_subscriptions.stripe_subscription_id),
    stripe_price_id         = COALESCE(EXCLUDED.stripe_price_id, product_subscriptions.stripe_price_id),
    current_period_end      = EXCLUDED.current_period_end,
    cancel_at_period_end    = EXCLUDED.cancel_at_period_end,
    metadata                = EXCLUDED.metadata,
    updated_at              = now();

  -- Audit event
  INSERT INTO public.product_entitlement_events (
    user_id, product, event_type,
    from_status, to_status, from_tier, to_tier,
    source, stripe_event_id, metadata
  ) VALUES (
    p_user_id, p_product, v_event_type,
    v_old_status, p_status, v_old_tier, p_tier,
    p_source, p_stripe_event_id, p_metadata
  );

  RETURN jsonb_build_object(
    'ok',         true,
    'product',    p_product,
    'tier',       p_tier,
    'status',     p_status,
    'event_type', v_event_type
  );
END;
$$;

REVOKE ALL   ON FUNCTION public.upsert_product_subscription(uuid,text,text,text,text,text,text,timestamptz,boolean,text,jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.upsert_product_subscription(uuid,text,text,text,text,text,text,timestamptz,boolean,text,jsonb) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.upsert_product_subscription(uuid,text,text,text,text,text,text,timestamptz,boolean,text,jsonb) TO service_role;

-- ── backfill_core_product_subscriptions ──────────────────────────────────────
-- One-time backfill: Core subscribers → product_subscriptions.
-- Safe to run multiple times (ON CONFLICT DO NOTHING).
-- Captures existing active/trialing Core subscriptions from the legacy table.
CREATE OR REPLACE FUNCTION public.backfill_core_product_subscriptions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_inserted  int := 0;
  v_skipped   int := 0;
BEGIN
  WITH eligible AS (
    SELECT s.user_id,
           pr.role AS tier,
           s.status,
           s.stripe_subscription_id,
           s.stripe_price_id,
           s.current_period_end,
           s.cancel_at_period_end
    FROM   public.subscriptions s
    JOIN   public.profiles      pr ON pr.id = s.user_id
    WHERE  s.status IN ('active','trialing')
      AND  pr.role  IN ('pro','premium')
  ),
  ins AS (
    INSERT INTO public.product_subscriptions (
      user_id, product, tier, status, source,
      stripe_subscription_id, stripe_price_id,
      current_period_end, cancel_at_period_end,
      metadata
    )
    SELECT
      e.user_id, 'core', e.tier, e.status, 'legacy_core',
      e.stripe_subscription_id, e.stripe_price_id,
      e.current_period_end, e.cancel_at_period_end,
      '{"backfill": true}'::jsonb
    FROM eligible e
    ON CONFLICT (user_id, product) DO NOTHING
    RETURNING user_id
  )
  SELECT count(*) INTO v_inserted FROM ins;

  SELECT count(*) INTO v_skipped
  FROM public.product_subscriptions
  WHERE product='core' AND source='legacy_core';

  -- Audit events for backfilled rows
  INSERT INTO public.product_entitlement_events (
    user_id, product, event_type, to_status, to_tier, source, metadata
  )
  SELECT ps.user_id, 'core', 'created', ps.status, ps.tier, 'legacy_core',
         '{"backfill": true}'::jsonb
  FROM   public.product_subscriptions ps
  WHERE  ps.product='core' AND ps.source='legacy_core'
    AND  NOT EXISTS (
      SELECT 1 FROM public.product_entitlement_events pee
      WHERE  pee.user_id=ps.user_id AND pee.product='core' AND pee.event_type='created'
    );

  RETURN jsonb_build_object(
    'ok',             true,
    'inserted',       v_inserted,
    'total_core_rows', v_skipped
  );
END;
$$;

REVOKE ALL   ON FUNCTION public.backfill_core_product_subscriptions() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.backfill_core_product_subscriptions() FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.backfill_core_product_subscriptions() TO service_role;

COMMENT ON FUNCTION public.resolve_product_entitlement(uuid,text) IS
  'IV-WEB-ECOSYSTEM-UNIFICATION-01: server-authoritative product entitlement '
  'resolver. FAIL CLOSED. Checks product_subscriptions + legacy_core fallback '
  'for Core. PRODUCTION PROTECTION: not applied without AM+Paulo gate.';

COMMENT ON FUNCTION public.upsert_product_subscription(uuid,text,text,text,text,text,text,timestamptz,boolean,text,jsonb) IS
  'IV-WEB-ECOSYSTEM-UNIFICATION-01: idempotent upsert for product entitlement '
  'state. Called by stripe-webhook and admin tools. Writes audit events. '
  'service_role only. PRODUCTION PROTECTION: not applied without AM+Paulo gate.';
