-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Migration 00007
-- R25-A: Tuple ordering (event_created, event_id) for deterministic stale-event detection.
-- R25-B: invoke_entitlement_reconciler() calls Edge Function via pg_net when configured;
--        falls back to SQL worker when pg_net or project URL is unavailable.
--
-- PROBLEM SOLVED (R25-A):
--   Stripe event timestamps have second-level precision. Two events at the same second
--   (e.g., a cancel and an activate triggered programmatically) resolved non-deterministically
--   by arrival order. The guard `event_created < stored` treated equal timestamps as "apply",
--   meaning whichever arrived second could overwrite the first, permanently locking the
--   wrong state. Fix: add event_id as a deterministic tie-breaker. Stripe guarantees
--   event IDs are unique and lexicographically ordered within a project, so the higher
--   event_id at equal timestamps is always the authoritative winner.
--
-- PROBLEM SOLVED (R25-B):
--   pg_cron scheduled only the SQL worker (process_pending_entitlement_events), which reads
--   stripe_price_configs. That table is populated ONLY by the Edge Function via STRIPE_PRICE_MAP.
--   If the Edge Function was never scheduled, unknown-price events remained pending_retry
--   indefinitely. Fix: the new invoke_entitlement_reconciler() function calls the Edge Function
--   via net.http_post when configured, with automatic fallback to the SQL worker.
--
-- IDEMPOTENT: safe to re-run.
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

-- ── Part 1: Add last_stripe_event_id columns ─────────────────────────────────
-- product_subscriptions: per-subscription event ordering
ALTER TABLE public.product_subscriptions
  ADD COLUMN IF NOT EXISTS last_stripe_event_id text NULL;

-- subscriptions: user-global event ordering (legacy Core table)
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS last_stripe_event_id text NULL;

-- ── Part 2: upsert_product_subscription — tuple ordering ─────────────────────
-- Same 13-param signature as migration 00002. CREATE OR REPLACE replaces the body.
-- Key changes:
--   1. Capture v_last_stripe_event_id from the stored row.
--   2. Pre-check: STALE if incoming (event_created, event_id) < stored tuple.
--   3. INSERT: persist last_stripe_event_id.
--   4. ON CONFLICT WHERE: apply only when incoming tuple >= stored tuple.
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
  v_last_stripe_event_id      text;           -- R25-A: tie-breaker
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
  -- Stale if incoming (event_created, event_id) is strictly less-than stored tuple.
  -- Idempotent replay (same tuple) is also treated as stale — no-op.
  IF p_stripe_event_created IS NOT NULL
     AND v_last_stripe_event_created IS NOT NULL
  THEN
    IF p_stripe_event_created < v_last_stripe_event_created THEN
      RETURN jsonb_build_object(
        'ok', false, 'skipped', true,
        'reason', 'STALE_EVENT', 'product', p_product
      );
    END IF;
    -- Same timestamp: use event_id tie-breaker
    IF p_stripe_event_created = v_last_stripe_event_created
       AND p_stripe_event_id    IS NOT NULL
       AND v_last_stripe_event_id IS NOT NULL
       AND p_stripe_event_id <= v_last_stripe_event_id
    THEN
      RETURN jsonb_build_object(
        'ok', false, 'skipped', true,
        'reason', 'STALE_EVENT', 'product', p_product
      );
    END IF;
    -- If either event_id is NULL at same timestamp: let the ON CONFLICT WHERE decide.
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
  -- R25-A: Apply only when incoming tuple (event_created, event_id) >= stored tuple.
  -- Conditions for applying:
  --   1. No stored timestamp → apply (new row or NULL → always advance)
  --   2. No incoming timestamp → apply (no ordering info)
  --   3. Incoming is strictly newer → apply
  --   4. Same timestamp with tie-breaker advantage → apply
  --      4a. No stored event_id → apply (first event at this second)
  --      4b. No incoming event_id → apply (can't compare, be permissive)
  --      4c. Incoming event_id >= stored → apply (includes idempotent replay)
  WHERE (
    product_subscriptions.last_stripe_event_created IS NULL
    OR EXCLUDED.last_stripe_event_created IS NULL
    OR product_subscriptions.last_stripe_event_created < EXCLUDED.last_stripe_event_created
    OR (
      product_subscriptions.last_stripe_event_created = EXCLUDED.last_stripe_event_created
      AND (
        product_subscriptions.last_stripe_event_id IS NULL
        OR EXCLUDED.last_stripe_event_id IS NULL
        OR EXCLUDED.last_stripe_event_id >= product_subscriptions.last_stripe_event_id
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

-- ACL unchanged (same signature)
REVOKE EXECUTE ON FUNCTION public.upsert_product_subscription(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb
) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.upsert_product_subscription(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb
) TO service_role;

-- ── Part 3: apply_stripe_subscription_state — tuple ordering ─────────────────
-- Drops the 9-param overload and creates a 10-param version with p_stripe_event_id.
-- Callers in migrations 00006+ must add p_stripe_event_id => ... to their calls.
-- Default NULL preserves backward compatibility for any callers not yet updated.
DROP FUNCTION IF EXISTS public.apply_stripe_subscription_state(
  uuid, timestamptz, text, text, text, timestamptz, boolean, text, integer
);

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
  p_stripe_event_id        text DEFAULT NULL  -- R25-A: tie-breaker
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
  -- Replaces the old `>= last_event_created` which allowed equal timestamps without a tie-breaker.
  -- NULL incoming timestamp (b) preserves backward compatibility: callers that omit
  -- p_event_created still get their writes applied, consistent with migration 20261010000000.
  UPDATE public.subscriptions
  SET stripe_subscription_id = p_stripe_subscription_id,
      stripe_price_id        = p_stripe_price_id,
      status                 = p_status,
      current_period_end     = p_current_period_end,
      cancel_at_period_end   = p_cancel_at_period_end,
      last_event_created     = p_event_created,
      last_stripe_event_id   = p_stripe_event_id
  WHERE user_id = p_user_id
    AND (
      last_event_created IS NULL        -- (a) no prior event
      OR p_event_created IS NULL        -- (b) legacy caller, no ordering info → apply
      OR p_event_created > last_event_created  -- (c) strictly newer
      OR (
        p_event_created = last_event_created   -- (d) same timestamp: use event_id tie-breaker
        AND (
          last_stripe_event_id IS NULL
          OR p_stripe_event_id IS NULL
          OR p_stripe_event_id >= last_stripe_event_id
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

-- ── Part 4: Update cancel/activate atomic functions to pass event_id ──────────
-- Recreates both functions (same signatures as migration 00006) with one change:
-- apply_stripe_subscription_state now receives p_stripe_event_id => p_stripe_event_id.
CREATE OR REPLACE FUNCTION public.cancel_core_entitlement_atomic(
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
  p_metadata                jsonb       DEFAULT '{}',
  p_legacy_role             text        DEFAULT 'free',
  p_legacy_monthly_limit    int         DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_upsert_result  jsonb;
  v_ent_result     jsonb;
  v_legacy_applied boolean := false;
  v_legacy_result  boolean;
BEGIN
  PERFORM pg_advisory_xact_lock(
    ('x' || substr(md5(p_user_id::text), 1, 16))::bit(64)::bigint
  );

  SELECT public.upsert_product_subscription(
    p_user_id                => p_user_id,
    p_product                => p_product,
    p_tier                   => p_tier,
    p_status                 => p_status,
    p_source                 => p_source,
    p_stripe_subscription_id => p_stripe_subscription_id,
    p_stripe_price_id        => p_stripe_price_id,
    p_stripe_customer_id     => p_stripe_customer_id,
    p_current_period_end     => p_current_period_end,
    p_cancel_at_period_end   => p_cancel_at_period_end,
    p_stripe_event_id        => p_stripe_event_id,
    p_stripe_event_created   => p_stripe_event_created,
    p_metadata               => p_metadata
  ) INTO v_upsert_result;

  SELECT public.resolve_product_entitlement(p_user_id, p_product) INTO v_ent_result;

  IF NOT COALESCE((v_ent_result->>'allowed')::boolean, false) THEN
    SELECT public.apply_stripe_subscription_state(
      p_user_id                => p_user_id,
      p_event_created          => p_stripe_event_created,
      p_stripe_subscription_id => p_stripe_subscription_id,
      p_stripe_price_id        => p_stripe_price_id,
      p_status                 => p_status,
      p_current_period_end     => p_current_period_end,
      p_cancel_at_period_end   => p_cancel_at_period_end,
      p_role                   => p_legacy_role,
      p_monthly_limit          => p_legacy_monthly_limit,
      p_stripe_event_id        => p_stripe_event_id     -- R25-A: pass event_id for tuple ordering
    ) INTO v_legacy_result;
    v_legacy_applied := COALESCE(v_legacy_result, false);

    -- R22-A fix: force-downgrade if global guard blocked but entitlement inactive
    IF NOT COALESCE(v_legacy_applied, false)
       AND EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id)
    THEN
      UPDATE public.profiles
         SET role          = 'free',
             monthly_limit = 15
       WHERE id = p_user_id
         AND role = 'pro';
      v_legacy_applied := true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'upsert',         v_upsert_result,
    'entitlement',    v_ent_result,
    'legacy_applied', v_legacy_applied
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cancel_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) TO service_role;

CREATE OR REPLACE FUNCTION public.activate_core_entitlement_atomic(
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
  p_metadata                jsonb       DEFAULT '{}',
  p_legacy_role             text        DEFAULT 'free',
  p_legacy_monthly_limit    int         DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_upsert_result  jsonb;
  v_ent_result     jsonb;
  v_legacy_applied boolean := false;
  v_resolved_tier  text;
  v_resolved_role  text;
  v_resolved_limit int;
  v_apply_role     text;
  v_apply_limit    int;
BEGIN
  PERFORM pg_advisory_xact_lock(
    ('x' || substr(md5(p_user_id::text), 1, 16))::bit(64)::bigint
  );

  SELECT public.upsert_product_subscription(
    p_user_id                => p_user_id,
    p_product                => p_product,
    p_tier                   => p_tier,
    p_status                 => p_status,
    p_source                 => p_source,
    p_stripe_subscription_id => p_stripe_subscription_id,
    p_stripe_price_id        => p_stripe_price_id,
    p_stripe_customer_id     => p_stripe_customer_id,
    p_current_period_end     => p_current_period_end,
    p_cancel_at_period_end   => p_cancel_at_period_end,
    p_stripe_event_id        => p_stripe_event_id,
    p_stripe_event_created   => p_stripe_event_created,
    p_metadata               => p_metadata
  ) INTO v_upsert_result;

  SELECT public.resolve_product_entitlement(p_user_id, p_product) INTO v_ent_result;

  IF COALESCE((v_ent_result->>'allowed')::boolean, false) THEN
    v_resolved_tier  := v_ent_result->>'tier';
    -- R24: cap Stripe-managed role to 'pro'; 'premium' is manually granted only
    v_resolved_role  := CASE WHEN v_resolved_tier IN ('premium', 'pro') THEN 'pro' ELSE 'free' END;
    v_resolved_limit := CASE v_resolved_role WHEN 'pro' THEN 300 ELSE 15 END;
    v_apply_role  := v_resolved_role;
    v_apply_limit := v_resolved_limit;
    SELECT public.apply_stripe_subscription_state(
      p_user_id                => p_user_id,
      p_event_created          => p_stripe_event_created,
      p_stripe_subscription_id => p_stripe_subscription_id,
      p_stripe_price_id        => p_stripe_price_id,
      p_status                 => p_status,
      p_current_period_end     => p_current_period_end,
      p_cancel_at_period_end   => p_cancel_at_period_end,
      p_role                   => v_apply_role,
      p_monthly_limit          => v_apply_limit,
      p_stripe_event_id        => p_stripe_event_id     -- R25-A: pass event_id for tuple ordering
    ) INTO v_legacy_applied;

    -- R16-C fix: force-update if legacy was blocked by user-global guard
    IF NOT COALESCE(v_legacy_applied, false)
       AND COALESCE((v_upsert_result->>'ok')::boolean, false)
       AND EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id)
    THEN
      -- R24: v_resolved_role is capped at 'pro'
      UPDATE public.profiles
         SET role          = v_resolved_role,
             monthly_limit = v_resolved_limit
       WHERE id   = p_user_id
         AND (role = 'free' OR role IS NULL);
      v_legacy_applied := true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'legacy_applied', v_legacy_applied,
    'upsert',         v_upsert_result,
    'entitlement',    v_ent_result
  );
END;
$$;

REVOKE ALL ON FUNCTION public.activate_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.activate_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.activate_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) TO service_role;

COMMENT ON FUNCTION public.cancel_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) IS 'Atomically cancels a Core subscription (R25-A: tuple ordering, R22-A: force-downgrade, R24: premium protection).';

COMMENT ON FUNCTION public.activate_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) IS 'Atomically activates a Core subscription (R25-A: tuple ordering, R24: cap to pro, R16-C: force-update).';

-- ── Part 5: invoke_entitlement_reconciler ─────────────────────────────────────
-- Calls the entitlement-reconcile Edge Function via pg_net when configured;
-- falls back to process_pending_entitlement_events() (SQL worker) otherwise.
-- The Edge Function (1) syncs STRIPE_PRICE_MAP → stripe_price_configs, and
-- (2) calls process_pending_entitlement_events. Without the Edge Function,
-- unknown-price events cannot be resolved from within the SQL worker alone.
--
-- Configuration (set as DB-level settings before applying):
--   ALTER DATABASE <db> SET app.supabase_project_url = 'https://<ref>.supabase.co';
--   ALTER DATABASE <db> SET app.service_role_key = '<service_role_key>';
--
-- Security: the service_role_key is stored in pg_settings (database-level).
-- This is consistent with standard Supabase pg_cron → Edge Function patterns.
-- Never expose this value to client-side callers.
CREATE OR REPLACE FUNCTION public.invoke_entitlement_reconciler(
  p_batch_size int DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_project_url text;
  v_service_key text;
  v_result      jsonb;
BEGIN
  v_project_url := current_setting('app.supabase_project_url', true);
  v_service_key := current_setting('app.service_role_key',      true);

  IF v_project_url IS NOT NULL AND v_project_url <> ''
     AND v_service_key IS NOT NULL AND v_service_key <> ''
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
  THEN
    -- Preferred path: invoke Edge Function via HTTP.
    -- The Edge Function syncs STRIPE_PRICE_MAP → stripe_price_configs before
    -- calling process_pending_entitlement_events, ensuring unknown-price events
    -- can be resolved on each scheduled run.
    PERFORM net.http_post(
      url     := v_project_url || '/functions/v1/entitlement-reconcile?batch=' || p_batch_size,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_service_key
      ),
      body    := (jsonb_build_object('batch', p_batch_size))::text::bytea
    );
    RETURN jsonb_build_object('invocation', 'edge_function', 'batch', p_batch_size);
  ELSE
    -- Fallback: call SQL worker directly.
    -- stripe_price_configs will NOT be synced in this path.
    -- Unknown-price events remain pending_retry until the Edge Function is invoked.
    SELECT public.process_pending_entitlement_events(p_batch_size) INTO v_result;
    RETURN jsonb_build_object('invocation', 'sql_worker', 'batch', p_batch_size, 'result', v_result);
  END IF;
END;
$$;

REVOKE ALL     ON FUNCTION public.invoke_entitlement_reconciler(int) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.invoke_entitlement_reconciler(int) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.invoke_entitlement_reconciler(int) TO service_role;

COMMENT ON FUNCTION public.invoke_entitlement_reconciler(int) IS
  'Invokes entitlement-reconcile Edge Function via net.http_post when configured; '
  'falls back to process_pending_entitlement_events (SQL worker) otherwise. '
  'Requires app.supabase_project_url and app.service_role_key DB settings + pg_net extension '
  'for the Edge Function path.';

-- ── Part 6: Update pg_cron schedule ──────────────────────────────────────────
-- Replaces the old cron job (process-pending-entitlement-events, SQL-worker-only)
-- with invoke-entitlement-reconciler which calls the Edge Function when configured.
-- When pg_net and project URL/key are available, this ensures STRIPE_PRICE_MAP
-- is synced to stripe_price_configs on every scheduled run — resolving the
-- Codex P1-R25-B finding.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Remove all prior entitlement-related cron jobs (idempotent)
    PERFORM cron.unschedule(jobname)
    FROM cron.job
    WHERE jobname IN (
      'process-pending-entitlement-events',
      'entitlement-reconcile-ef',
      'invoke-entitlement-reconciler'
    );

    PERFORM cron.schedule(
      'invoke-entitlement-reconciler',
      '*/5 * * * *',
      $cmd$SELECT public.invoke_entitlement_reconciler(50)$cmd$
    );

    RAISE NOTICE
      'pg_cron: scheduled invoke-entitlement-reconciler every 5 minutes. '
      'Set app.supabase_project_url + app.service_role_key for Edge Function invocation; '
      'falls back to SQL worker otherwise.';
  ELSIF current_setting('app.external_scheduler_confirmed', true) = 'confirmed' THEN
    RAISE NOTICE
      'pg_cron not available: external scheduler confirmed. '
      'Ensure entitlement-reconcile Edge Function is scheduled externally.';
  ELSE
    RAISE EXCEPTION
      'DEPLOYMENT_GATE_FAILURE: pg_cron is not available and no alternative scheduler '
      'has been confirmed. Set app.external_scheduler_confirmed=confirmed to proceed.';
  END IF;
END $$;
