-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Migration 00010
-- Codex CLASS D R2 P1 fix: NULL event_id bypasses equal-timestamp tie-breaker.
--
-- PROBLEM (confirmed in migration 20261016000007, lines 164-185 and 284-295):
--   In upsert_product_subscription ON CONFLICT WHERE and in
--   apply_stripe_subscription_state WHERE, the equal-timestamp branch included:
--
--     OR EXCLUDED.last_stripe_event_id IS NULL   (upsert)
--     OR p_stripe_event_id IS NULL               (apply_stripe)
--
--   This allowed a call with a non-null event_created that exactly matches the
--   stored timestamp AND a NULL event_id to always win the tie-break, overwriting
--   a newer state regardless of the stored event_id. A delayed retry or any
--   caller that omits the event_id can therefore resurrect or revoke entitlement
--   based on arrival order when two events share the same second-precision timestamp.
--
-- FIX:
--   Remove the NULL-incoming-event-id shortcut from the equal-timestamp branch.
--   At equal timestamps, a NULL incoming event_id is now treated as stale (cannot
--   win a tie-break against a stored non-null event_id).
--
--   Callers with no timestamp at all (p_stripe_event_created IS NULL / p_event_created
--   IS NULL) are unaffected: that is the legacy-backward-compat path and runs BEFORE
--   the equal-timestamp check.
--
--   Also adds an explicit fast-path to the pre-check in upsert_product_subscription
--   so that stored-has-ID + incoming-is-NULL at equal timestamps returns STALE_EVENT
--   without reaching the INSERT/ON CONFLICT path.
--
-- IDEMPOTENT: safe to re-run (CREATE OR REPLACE).
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

SET search_path = public, pg_catalog, pg_temp;

-- ── Part 1: upsert_product_subscription — fix NULL tie-break bypass ───────────
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
  v_old_status                text;
  v_old_tier                  text;
  v_last_stripe_event_created timestamptz;
  v_last_stripe_event_id      text;
  v_event_type                text;
  v_rows_applied              int;
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
  SELECT status, tier, last_stripe_event_created, last_stripe_event_id
  INTO   v_old_status, v_old_tier, v_last_stripe_event_created, v_last_stripe_event_id
  FROM   public.product_subscriptions
  WHERE  user_id = p_user_id
    AND  product  = p_product
    AND  stripe_subscription_id = p_stripe_subscription_id;

  -- R25-A: Tuple stale-event skip (per-subscription ordering).
  IF p_stripe_event_created IS NOT NULL
     AND v_last_stripe_event_created IS NOT NULL
  THEN
    IF p_stripe_event_created < v_last_stripe_event_created THEN
      RETURN jsonb_build_object(
        'ok', false, 'skipped', true,
        'reason', 'STALE_EVENT', 'product', p_product
      );
    END IF;
    -- Same timestamp: use event_id tie-breaker.
    IF p_stripe_event_created = v_last_stripe_event_created THEN
      -- 00010 fix: NULL incoming event_id cannot win against a stored non-null event_id.
      IF v_last_stripe_event_id IS NOT NULL AND p_stripe_event_id IS NULL THEN
        RETURN jsonb_build_object(
          'ok', false, 'skipped', true,
          'reason', 'STALE_EVENT', 'product', p_product
        );
      END IF;
      -- Both non-null: incoming must be strictly greater to win tie-break.
      IF p_stripe_event_id IS NOT NULL
         AND v_last_stripe_event_id IS NOT NULL
         AND p_stripe_event_id <= v_last_stripe_event_id
      THEN
        RETURN jsonb_build_object(
          'ok', false, 'skipped', true,
          'reason', 'STALE_EVENT', 'product', p_product
        );
      END IF;
    END IF;
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
    last_stripe_event_created, last_stripe_event_id, metadata
  ) VALUES (
    p_user_id, p_product, p_tier, p_status, p_source,
    p_stripe_subscription_id, p_stripe_customer_id, p_stripe_price_id,
    p_current_period_end, p_cancel_at_period_end,
    p_stripe_event_created, p_stripe_event_id, p_metadata
  )
  ON CONFLICT (user_id, product, stripe_subscription_id) DO UPDATE SET
    tier                      = EXCLUDED.tier,
    status                    = EXCLUDED.status,
    source                    = EXCLUDED.source,
    stripe_customer_id        = COALESCE(EXCLUDED.stripe_customer_id,        product_subscriptions.stripe_customer_id),
    stripe_price_id           = COALESCE(EXCLUDED.stripe_price_id,           product_subscriptions.stripe_price_id),
    current_period_end        = EXCLUDED.current_period_end,
    cancel_at_period_end      = EXCLUDED.cancel_at_period_end,
    last_stripe_event_created = COALESCE(EXCLUDED.last_stripe_event_created, product_subscriptions.last_stripe_event_created),
    last_stripe_event_id      = COALESCE(EXCLUDED.last_stripe_event_id,      product_subscriptions.last_stripe_event_id),
    metadata                  = EXCLUDED.metadata,
    updated_at                = now()
  -- R25-A + 00010 fix: apply only when incoming tuple >= stored tuple.
  -- At equal timestamps, NULL incoming event_id is STALE (cannot win tie-break
  -- against a stored non-null event_id). Removed: OR EXCLUDED.last_stripe_event_id IS NULL.
  WHERE (
    product_subscriptions.last_stripe_event_created IS NULL
    OR EXCLUDED.last_stripe_event_created IS NULL
    OR product_subscriptions.last_stripe_event_created < EXCLUDED.last_stripe_event_created
    OR (
      product_subscriptions.last_stripe_event_created = EXCLUDED.last_stripe_event_created
      AND (
        product_subscriptions.last_stripe_event_id IS NULL
        OR (
          EXCLUDED.last_stripe_event_id IS NOT NULL
          AND EXCLUDED.last_stripe_event_id >= product_subscriptions.last_stripe_event_id
        )
      )
    )
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

  -- P1-G fix: cascade non-active status to synthetic legacy rows
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

-- ACL unchanged (same signature as migration 00007)
REVOKE EXECUTE ON FUNCTION public.upsert_product_subscription(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb
) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.upsert_product_subscription(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb
) TO service_role;

-- ── Part 2: apply_stripe_subscription_state — fix NULL tie-break bypass ───────
CREATE OR REPLACE FUNCTION public.apply_stripe_subscription_state(
  p_user_id                uuid,
  p_event_created          timestamptz,
  p_stripe_subscription_id text,
  p_stripe_price_id        text,
  p_status                 text,
  p_current_period_end     timestamptz,
  p_cancel_at_period_end   boolean,
  p_role                   text,
  p_monthly_limit          integer,
  p_stripe_event_id        text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
  v_row_count integer;
  v_applied   boolean;
BEGIN
  -- R25-A: tuple ordering on (last_event_created, last_stripe_event_id).
  -- Apply if:
  --   a) stored timestamp is NULL (no prior event)
  --   b) incoming timestamp is NULL (legacy callers, always apply — backward-compat)
  --   c) incoming is strictly newer
  --   d) same timestamp with tie-breaker advantage (higher event_id or no stored id)
  --      00010 fix: removed "OR p_stripe_event_id IS NULL" from (d).
  --      NULL incoming event_id at equal timestamp is STALE (cannot win tie-break
  --      against a stored non-null event_id). Legacy callers with no timestamp at
  --      all hit case (b) and are unaffected.
  UPDATE public.subscriptions
  SET stripe_subscription_id = p_stripe_subscription_id,
      stripe_price_id        = p_stripe_price_id,
      status                 = p_status,
      current_period_end     = p_current_period_end,
      cancel_at_period_end   = p_cancel_at_period_end,
      last_event_created     = COALESCE(p_event_created, last_event_created),
      last_stripe_event_id   = COALESCE(p_stripe_event_id, last_stripe_event_id)
  WHERE user_id = p_user_id
    AND (
      last_event_created IS NULL        -- (a) no prior event
      OR p_event_created IS NULL        -- (b) legacy caller, no ordering info → apply
      OR p_event_created > last_event_created  -- (c) strictly newer
      OR (
        p_event_created = last_event_created   -- (d) same timestamp: use event_id tie-breaker
        AND (
          last_stripe_event_id IS NULL
          OR (
            p_stripe_event_id IS NOT NULL
            AND p_stripe_event_id >= last_stripe_event_id
          )
        )
      )
    );

  GET DIAGNOSTICS v_row_count = ROW_COUNT;
  v_applied := v_row_count > 0;

  IF v_applied THEN
    UPDATE public.profiles
    SET role = p_role,
        monthly_limit = p_monthly_limit
    WHERE id = p_user_id
      AND role IN ('free', 'pro');
  END IF;

  RETURN v_applied;
END;
$function$;

-- ACL: same as migration 00007 (no anon/authenticated execute; service_role only via SECURITY DEFINER callers)
REVOKE EXECUTE ON FUNCTION public.apply_stripe_subscription_state(
  uuid, timestamptz, text, text, text, timestamptz, boolean, text, integer, text
) FROM anon, authenticated;
