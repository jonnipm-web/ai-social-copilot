-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Multi-subscription per product
--
-- REDESIGN: product_subscriptions now supports multiple Stripe subscriptions
-- per (user_id, product). Key change:
--   OLD: UNIQUE(user_id, product) — one row per user per product
--   NEW: UNIQUE(user_id, product, stripe_subscription_id) — one row per subscription
--
-- ENTITLEMENT AGGREGATION: resolve_product_entitlement aggregates across all
-- subscriptions: allowed = ANY is active/trialing and not expired;
-- tier = MAX tier among valid subscriptions.
--
-- RULE: cancellation of ONE subscription does NOT revoke entitlement while
-- another valid subscription for the same product/tier exists.
--
-- stripe_subscription_id is NOT NULL. Non-Stripe sources (admin_grant, trial)
-- use a synthetic ref prefixed with their source: 'admin_<uuid>' / 'trial_<uuid>'.
-- Legacy rows backfilled with 'sys_<uuid>' to preserve idempotency.
--
-- IDEMPOTENT: safe to re-run.
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

-- ── Step 1: add stripe_customer_id column (for replay lookup) ────────────────
ALTER TABLE public.product_subscriptions
  ADD COLUMN IF NOT EXISTS stripe_customer_id text NULL;

-- ── Step 2: backfill stripe_subscription_id for legacy rows ──────────────────
-- Rows already have stripe_subscription_id if they came from Stripe. Rows
-- inserted by backfill_core_product_subscriptions may have NULL if the
-- underlying legacy subscription had no stripe_subscription_id.
-- KEY MUST be deterministic — using gen_random_uuid() here would create a key
-- that cannot conflict with the backfill function's 'sys_legacy_core_<user_id>'
-- key, resulting in duplicate rows and stale access after cancellation (P1 fix).
-- One existing NULL row per (user_id, product) = one deterministic key.
UPDATE public.product_subscriptions
SET    stripe_subscription_id = 'sys_legacy_core_' || user_id::text
WHERE  stripe_subscription_id IS NULL;

-- ── Step 3: make stripe_subscription_id NOT NULL ────────────────────────────
ALTER TABLE public.product_subscriptions
  ALTER COLUMN stripe_subscription_id SET NOT NULL;

-- ── Step 4: replace UNIQUE(user_id, product) with per-subscription key ───────
ALTER TABLE public.product_subscriptions
  DROP CONSTRAINT IF EXISTS product_subscriptions_user_product_key;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'product_subscriptions'
      AND constraint_name = 'product_subscriptions_user_product_sub_key'
  ) THEN
    ALTER TABLE public.product_subscriptions
      ADD CONSTRAINT product_subscriptions_user_product_sub_key
      UNIQUE (user_id, product, stripe_subscription_id);
  END IF;
END $$;

-- ── Step 5: update resolve_product_entitlement ───────────────────────────────
-- Now aggregates across all subscriptions for (user_id, product).
-- Allowed when ANY subscription is active/trialing and not expired.
-- Tier = max tier among valid subscriptions.
-- Suite policy: suite subscription also grants access to all constituent products.
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
  v_active       boolean := false;
  v_tier_rank    int     := 0;
  v_tier         text    := 'free';
  v_has_any      boolean := false;
  v_is_active    boolean;
BEGIN
  -- R17-A/R18-A fix: Tenant isolation check FIRST — applies to ALL products including
  -- base_free. An authenticated caller may only resolve their own entitlements.
  -- service_role has auth.uid() = NULL and is always allowed.
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'code',    'PERMISSION_DENIED',
      'reason',  'May only resolve own product entitlements'
    );
  END IF;

  -- P2-A fix: BASE_FREE must be checked BEFORE product validation, otherwise the
  -- validation rejects it as UNKNOWN_PRODUCT and the allow path is never reached.
  -- R17-A fix: enforce account-active check so inactive accounts do not get
  -- allowed=true via base_free (tenant check already performed above).
  IF p_product = 'base_free' THEN
    IF NOT COALESCE((SELECT is_active FROM public.profiles WHERE id = p_user_id LIMIT 1), true) THEN
      RETURN jsonb_build_object(
        'allowed', false, 'product', 'base_free',
        'code', 'ACCOUNT_INACTIVE', 'reason', 'Account is inactive'
      );
    END IF;
    RETURN jsonb_build_object(
      'allowed', true, 'product', 'base_free', 'tier', 'free',
      'source',  'system', 'reason', 'BASE_FREE_IMPLICIT'
    );
  END IF;

  -- Validate product (FAIL CLOSED for unknown products)
  IF p_product NOT IN ('core','impact','quant','suite') THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'code',    'UNKNOWN_PRODUCT',
      'reason',  'Product not in canonical list'
    );
  END IF;

  -- Account active check
  SELECT COALESCE(
    (SELECT is_active FROM public.profiles WHERE id = p_user_id LIMIT 1),
    true
  ) INTO v_is_active;

  IF NOT v_is_active THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'product', p_product,
      'code',    'ACCOUNT_INACTIVE',
      'reason',  'User account is not active'
    );
  END IF;

  -- Suite grants access to all constituent products.
  -- If the user has an active suite subscription, grant access to any product.
  IF p_product IN ('core','impact','quant') THEN
    SELECT
      bool_or(
        ps.status IN ('active','trialing')
        AND (ps.current_period_end IS NULL OR clock_timestamp() <= ps.current_period_end)
      ),
      -- P1-F fix: same validity predicate as P1-B — only valid (active+not-expired) rows
      -- contribute to tier. An expired premium + active pro must yield pro, not premium.
      MAX(
        CASE WHEN ps.status IN ('active','trialing')
                  AND (ps.current_period_end IS NULL OR clock_timestamp() <= ps.current_period_end)
             THEN CASE ps.tier WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END
             ELSE 0
        END
      ),
      bool_or(true)
    INTO v_active, v_tier_rank, v_has_any
    FROM public.product_subscriptions ps
    WHERE ps.user_id = p_user_id AND ps.product = 'suite';
    -- P0 fix: bool_or/MAX return NULL (not false/0) when no rows match.
    -- Without COALESCE, IF NOT NULL → IF NULL → skips denial branch → incorrectly grants access.
    v_has_any   := COALESCE(v_has_any, false);
    v_active    := COALESCE(v_active, false);
    v_tier_rank := COALESCE(v_tier_rank, 0);

    IF v_has_any AND v_active THEN
      v_tier := CASE v_tier_rank WHEN 2 THEN 'premium' WHEN 1 THEN 'pro' ELSE 'free' END;
      RETURN jsonb_build_object(
        'allowed', true,
        'product', p_product,
        'tier',    v_tier,
        'source',  'suite',
        'reason',  'SUITE_GRANTS_' || upper(p_product)
      );
    END IF;
  END IF;

  -- Aggregate across all subscriptions for this product.
  -- Both allowed-flag and tier aggregation use the SAME validity predicate so
  -- a canceled/expired premium row cannot inflate the effective tier while
  -- a separate active pro row grants access (P1-B fix).
  SELECT
    bool_or(
      ps.status IN ('active','trialing')
      AND (ps.current_period_end IS NULL OR clock_timestamp() <= ps.current_period_end)
    ),
    MAX(
      CASE WHEN ps.status IN ('active','trialing')
                AND (ps.current_period_end IS NULL OR clock_timestamp() <= ps.current_period_end)
           THEN CASE ps.tier WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END
           ELSE 0
      END
    ),
    bool_or(true)
  INTO v_active, v_tier_rank, v_has_any
  FROM public.product_subscriptions ps
  WHERE ps.user_id = p_user_id AND ps.product = p_product;
  -- P0 fix: bool_or/MAX return NULL (not false/0) when no rows match.
  -- Without COALESCE, IF NOT v_has_any → IF NOT NULL → IF NULL → false → skips denial
  -- → falls through to RETURN allowed:true — authorization bypass for users with no subscription.
  v_has_any   := COALESCE(v_has_any, false);
  v_active    := COALESCE(v_active, false);
  v_tier_rank := COALESCE(v_tier_rank, 0);

  IF NOT v_has_any THEN
    -- Core backward compat: check legacy subscriptions + profiles.role
    IF p_product = 'core' THEN
      DECLARE
        v_role              text;
        v_status            text;
        v_legacy_period_end timestamptz;
      BEGIN
        SELECT s.status, pr.role, s.current_period_end
        INTO   v_status, v_role, v_legacy_period_end
        FROM   public.subscriptions s
        JOIN   public.profiles      pr ON pr.id = s.user_id
        WHERE  s.user_id = p_user_id
        LIMIT  1;

        IF FOUND
           AND v_status IN ('active','trialing')
           AND v_role   IN ('pro','premium')
           AND (v_legacy_period_end IS NULL
                OR clock_timestamp() <= v_legacy_period_end) THEN
          RETURN jsonb_build_object(
            'allowed', true,  'product', 'core',
            'tier',    v_role, 'source',  'legacy_core',
            'reason',  'LEGACY_CORE_SUBSCRIPTION'
          );
        END IF;
      END;
    END IF;

    RETURN jsonb_build_object(
      'allowed', false, 'product', p_product,
      'code',    'NO_ENTITLEMENT',
      'reason',  'No active product subscription found'
    );
  END IF;

  IF NOT v_active THEN
    RETURN jsonb_build_object(
      'allowed', false, 'product', p_product,
      'code',    'SUBSCRIPTION_NOT_ACTIVE',
      'reason',  'All subscriptions are inactive or expired'
    );
  END IF;

  v_tier := CASE v_tier_rank WHEN 2 THEN 'premium' WHEN 1 THEN 'pro' ELSE 'free' END;

  RETURN jsonb_build_object(
    'allowed', true,
    'product', p_product,
    'tier',    v_tier,
    'source',  'product_subscriptions',
    'reason',  'ENTITLEMENT_ACTIVE'
  );
END;
$$;

REVOKE ALL     ON FUNCTION public.resolve_product_entitlement(uuid,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.resolve_product_entitlement(uuid,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.resolve_product_entitlement(uuid,text) TO authenticated, service_role;

-- ── Step 6: update upsert_product_subscription with multi-sub key ────────────
-- p_stripe_subscription_id is now required for Stripe events.
-- Non-Stripe callers must pass a stable synthetic ref.
-- Drop old 12-param overload (p_stripe_subscription_id had DEFAULT NULL, no p_stripe_customer_id).
-- CREATE OR REPLACE only replaces when the signature matches exactly; a changed
-- default or new parameter creates a second overload instead.
DROP FUNCTION IF EXISTS public.upsert_product_subscription(
  uuid, text, text, text, text, text, text, timestamptz, boolean, text, timestamptz, jsonb
);
CREATE OR REPLACE FUNCTION public.upsert_product_subscription(
  p_user_id                 uuid,
  p_product                 text,
  p_tier                    text,
  p_status                  text,
  p_source                  text,
  p_stripe_subscription_id  text,
  p_stripe_price_id         text        DEFAULT NULL,
  p_stripe_customer_id      text        DEFAULT NULL,
  p_current_period_end      timestamptz DEFAULT NULL,
  p_cancel_at_period_end    boolean     DEFAULT false,
  p_stripe_event_id         text        DEFAULT NULL,
  p_stripe_event_created    timestamptz DEFAULT NULL,
  p_metadata                jsonb       DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_old_status              text;
  v_old_tier                text;
  v_last_stripe_event_created timestamptz;
  v_event_type              text;
  v_rows_applied            int;
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
  IF p_stripe_subscription_id IS NULL OR p_stripe_subscription_id = '' THEN
    RAISE EXCEPTION 'UPSERT_PRODUCT: stripe_subscription_id is required';
  END IF;

  -- Capture old state for this specific subscription
  SELECT status, tier, last_stripe_event_created
  INTO   v_old_status, v_old_tier, v_last_stripe_event_created
  FROM   public.product_subscriptions
  WHERE  user_id = p_user_id
    AND  product  = p_product
    AND  stripe_subscription_id = p_stripe_subscription_id;

  -- Optimistic stale-event skip (per-subscription ordering)
  IF p_stripe_event_created IS NOT NULL
     AND v_last_stripe_event_created IS NOT NULL
     AND p_stripe_event_created < v_last_stripe_event_created THEN
    RETURN jsonb_build_object(
      'ok', false, 'skipped', true,
      'reason', 'STALE_EVENT', 'product', p_product
    );
  END IF;

  -- Determine event type
  IF v_old_status IS NULL THEN
    v_event_type := 'created';
  ELSIF p_status IN ('active','trialing') AND v_old_status NOT IN ('active','trialing') THEN
    v_event_type := 'activated';
  ELSIF p_status IN ('canceled','none') THEN
    v_event_type := 'canceled';
  ELSIF (CASE p_tier     WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) >
        (CASE v_old_tier WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) THEN
    v_event_type := 'upgraded';
  ELSIF (CASE p_tier     WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) <
        (CASE v_old_tier WHEN 'premium' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END) THEN
    v_event_type := 'downgraded';
  ELSE
    v_event_type := 'activated';
  END IF;

  -- Atomic upsert on (user_id, product, stripe_subscription_id)
  INSERT INTO public.product_subscriptions (
    user_id, product, tier, status, source,
    stripe_subscription_id, stripe_customer_id, stripe_price_id,
    current_period_end, cancel_at_period_end,
    last_stripe_event_created, metadata
  ) VALUES (
    p_user_id, p_product, p_tier, p_status, p_source,
    p_stripe_subscription_id, p_stripe_customer_id, p_stripe_price_id,
    p_current_period_end, p_cancel_at_period_end,
    p_stripe_event_created, p_metadata
  )
  ON CONFLICT (user_id, product, stripe_subscription_id) DO UPDATE SET
    tier                      = EXCLUDED.tier,
    status                    = EXCLUDED.status,
    source                    = EXCLUDED.source,
    stripe_customer_id        = COALESCE(EXCLUDED.stripe_customer_id, product_subscriptions.stripe_customer_id),
    stripe_price_id           = COALESCE(EXCLUDED.stripe_price_id, product_subscriptions.stripe_price_id),
    current_period_end        = EXCLUDED.current_period_end,
    cancel_at_period_end      = EXCLUDED.cancel_at_period_end,
    last_stripe_event_created = COALESCE(EXCLUDED.last_stripe_event_created, product_subscriptions.last_stripe_event_created),
    metadata                  = EXCLUDED.metadata,
    updated_at                = now()
  -- P1-L fix: use strict < (not <=) to match the pre-check. Equal timestamps mean
  -- an earlier event arrived after a same-second event already applied; treat as
  -- skipped (same ordering rule as the pre-check above). Without this, two events
  -- sharing a Stripe-second timestamp could overwrite each other in arrival order,
  -- potentially resurrecting a canceled subscription.
  WHERE (
    product_subscriptions.last_stripe_event_created IS NULL
    OR EXCLUDED.last_stripe_event_created IS NULL
    OR product_subscriptions.last_stripe_event_created < EXCLUDED.last_stripe_event_created
  );

  GET DIAGNOSTICS v_rows_applied = ROW_COUNT;

  IF v_rows_applied = 0 THEN
    RETURN jsonb_build_object(
      'ok', false, 'skipped', true,
      'reason', 'STALE_EVENT', 'product', p_product
    );
  END IF;

  -- Audit event
  INSERT INTO public.product_entitlement_events (
    user_id, product, event_type,
    from_status, to_status, from_tier, to_tier,
    source, stripe_event_id, metadata
  ) VALUES (
    p_user_id, p_product, v_event_type,
    v_old_status, p_status, v_old_tier, p_tier,
    p_source, p_stripe_event_id, p_metadata
  )
  ON CONFLICT DO NOTHING;

  -- P1-G fix: when a real Stripe subscription enters any non-active status,
  -- cascade that status to any synthetic legacy row ('sys_legacy_core_') for
  -- the same (user_id, product). Using NOT IN ('active','trialing') aligns with
  -- entitlementForStatus (webhook) and resolve_product_entitlement (SQL):
  -- any status other than active/trialing means no entitlement.
  -- This prevents backfill rows from keeping paid access during past_due,
  -- paused, incomplete, or canceled states on the real subscription.
  IF p_source = 'stripe'
     AND p_status NOT IN ('active','trialing') THEN
    UPDATE public.product_subscriptions
    SET    status     = p_status,
           updated_at = now()
    WHERE  user_id   = p_user_id
      AND  product   = p_product
      AND  stripe_subscription_id LIKE 'sys_legacy_core_%'
      AND  status IN ('active','trialing');
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'product', p_product,
    'tier', p_tier, 'status', p_status, 'event_type', v_event_type
  );
END;
$$;

-- ACL for new signature (old signature was dropped above, so only new one exists)
REVOKE EXECUTE ON FUNCTION public.upsert_product_subscription(uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb) FROM anon, authenticated;

GRANT  EXECUTE ON FUNCTION public.upsert_product_subscription(uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb) TO service_role;

-- ── Step 7: update backfill to use new conflict key ─────────────────────────
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
           -- Deterministic synthetic key: stable across repeated backfill runs.
           -- Random gen_random_uuid() would create duplicate rows on re-run.
           COALESCE(s.stripe_subscription_id, 'sys_legacy_core_' || s.user_id::text) AS sub_id,
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
      e.sub_id, e.stripe_price_id,
      e.current_period_end, e.cancel_at_period_end,
      '{"backfill": true}'::jsonb
    FROM eligible e
    ON CONFLICT (user_id, product, stripe_subscription_id) DO NOTHING
    RETURNING user_id
  )
  SELECT count(*) INTO v_inserted FROM ins;

  SELECT count(*) INTO v_skipped
  FROM public.product_subscriptions
  WHERE product='core' AND source='legacy_core';

  INSERT INTO public.product_entitlement_events (
    user_id, product, event_type, to_status, to_tier, source, metadata
  )
  SELECT ps.user_id, 'core', 'created', ps.status, ps.tier, 'legacy_core',
         '{"backfill": true}'::jsonb
  FROM   public.product_subscriptions ps
  WHERE  ps.product='core' AND ps.source='legacy_core'
    AND  NOT EXISTS (
      SELECT 1 FROM public.product_entitlement_events pee
      WHERE  pee.user_id=ps.user_id AND pee.product='core'
        AND  pee.event_type='created' AND (pee.metadata->>'backfill')='true'
    );

  RETURN jsonb_build_object(
    'ok', true, 'inserted', v_inserted, 'total_core_rows', v_skipped
  );
END;
$$;

REVOKE ALL     ON FUNCTION public.backfill_core_product_subscriptions() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.backfill_core_product_subscriptions() FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.backfill_core_product_subscriptions() TO service_role;

COMMENT ON TABLE public.product_subscriptions IS
  'IV-WEB-ECOSYSTEM-UNIFICATION-01 v2: per-subscription state. '
  'UNIQUE(user_id, product, stripe_subscription_id). '
  'Multiple subscriptions per product supported. '
  'resolve_product_entitlement aggregates. PRODUCTION PROTECTION: gate required.';
