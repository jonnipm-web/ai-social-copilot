-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Replay Worker Infrastructure
--
-- Adds retry metadata to product_entitlement_events and implements
-- process_pending_entitlement_events() for automatic reconciliation.
--
-- REQUIREMENTS:
-- - Finds pending_retry events where attempts < max_attempts
-- - Lock/claim idempotent (advisory lock per event id)
-- - Increments attempts on transient failure
-- - Marks processed on success
-- - Marks final_failure after max_attempts
-- - No duplicate entitlement writes
-- - Logs structured errors
--
-- IDEMPOTENT: safe to re-run.
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

-- ── Retry metadata columns on product_entitlement_events ────────────────────
ALTER TABLE public.product_entitlement_events
  ADD COLUMN IF NOT EXISTS stripe_subscription_id text  NULL,
  ADD COLUMN IF NOT EXISTS stripe_customer_id     text  NULL,
  ADD COLUMN IF NOT EXISTS stripe_price_id        text  NULL,
  -- P1-C fix: store complete Stripe snapshot so replay does not write NULL
  -- for period-end (granting indefinite access) and can enforce ordering guard.
  ADD COLUMN IF NOT EXISTS stripe_event_created   timestamptz NULL,
  ADD COLUMN IF NOT EXISTS current_period_end     timestamptz NULL,
  ADD COLUMN IF NOT EXISTS cancel_at_period_end   boolean     NULL,
  ADD COLUMN IF NOT EXISTS attempts               int   NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_attempts           int   NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS last_attempt_at        timestamptz NULL,
  ADD COLUMN IF NOT EXISTS is_processed           boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS processing_error       text  NULL;

-- event_type now also includes 'final_failure'
ALTER TABLE IF EXISTS public.product_entitlement_events
  DROP CONSTRAINT IF EXISTS pee_event_type_check;
ALTER TABLE IF EXISTS public.product_entitlement_events
  ADD CONSTRAINT pee_event_type_check CHECK (
    event_type IN (
      'created','activated','upgraded','downgraded',
      'canceled','expired','reinstated','admin_grant','trial_started',
      'pending_retry','final_failure'
    )
  );

-- Index for efficient worker scan
CREATE INDEX IF NOT EXISTS pee_pending_retry_idx
  ON public.product_entitlement_events (attempts, last_attempt_at)
  WHERE event_type = 'pending_retry'
    AND is_processed = false;

-- ── process_pending_entitlement_events ───────────────────────────────────────
-- Processes up to p_batch_size pending_retry events.
-- Uses pg_try_advisory_xact_lock for per-event concurrency safety.
-- Returns a jsonb summary of processed/failed/skipped counts.
CREATE OR REPLACE FUNCTION public.process_pending_entitlement_events(
  p_batch_size int DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_rec         record;
  v_sub_id      text;
  v_result      jsonb;
  v_processed   int := 0;
  v_failed      int := 0;
  v_final       int := 0;
  v_skipped     int := 0;
  v_resolved    int := 0;
  v_upsert_ok   boolean;
  v_upsert_err  text;
  v_product     text;
  v_tier        text;
  v_status      text;
  v_user_id     uuid;
  v_cfg_product         text;
  v_cfg_tier            text;
  -- R15 P1-A fix: Core replay routing
  v_legacy_role         text;
  v_legacy_monthly_limit int;
  v_core_result         jsonb;
BEGIN
  -- P1-J fix: before scanning pending_retry events, resolve unknown-product events
  -- using stripe_price_configs (populated by entitlement-reconcile Edge Function).
  -- This enables the pg_cron SQL worker to process unknown-price events without
  -- requiring the Edge Function to be scheduled separately.
  UPDATE public.product_entitlement_events pee
  SET    product          = spc.product,
         to_tier          = spc.tier,
         processing_error = NULL,
         attempts         = 0
  FROM   public.stripe_price_configs spc
  WHERE  pee.event_type   = 'pending_retry'
    AND  pee.is_processed  = false
    AND  COALESCE(pee.product, 'unknown') = 'unknown'
    AND  pee.stripe_price_id IS NOT NULL
    AND  spc.price_id = pee.stripe_price_id;

  GET DIAGNOSTICS v_resolved = ROW_COUNT;

  FOR v_rec IN
    SELECT pee.id, pee.user_id, pee.product, pee.to_tier, pee.to_status,
           pee.stripe_subscription_id, pee.stripe_customer_id,
           pee.stripe_price_id, pee.stripe_event_id, pee.metadata,
           pee.stripe_event_created, pee.current_period_end, pee.cancel_at_period_end,
           pee.attempts, pee.max_attempts
    FROM   public.product_entitlement_events pee
    WHERE  pee.event_type  = 'pending_retry'
      AND  pee.is_processed = false
      AND  pee.attempts < pee.max_attempts
      -- P1-D fix: unknown-product events not yet in stripe_price_configs are handled
      -- by the Edge Function. Excluding them prevents infinite scan spam; they remain
      -- in pending_retry until the Edge Function resolves their product column or
      -- stripe_price_configs is populated by the Edge Function (P1-J fix).
      AND  COALESCE(pee.product, 'unknown') <> 'unknown'
    ORDER  BY pee.created_at
    LIMIT  p_batch_size
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Try advisory lock to prevent concurrent workers replaying the same event
    IF NOT pg_try_advisory_xact_lock(('x' || left(md5(v_rec.id::text), 15))::bit(60)::bigint) THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    v_user_id := v_rec.user_id;
    v_product := COALESCE(v_rec.product, 'unknown');
    v_tier    := COALESCE(v_rec.to_tier, 'free');
    v_status  := COALESCE(v_rec.to_status, 'active');

    -- UNMAPPED_PRICE / unknown product: excluded from scan above (AND product <> 'unknown').
    -- This branch is defense-in-depth only; should never be reached.
    -- The Edge Function resolves unknown-product events automatically when STRIPE_PRICE_MAP
    -- is updated, making this path fully recoverable without operator SQL action.
    IF v_product = 'unknown' THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    -- P1-E fix: NEVER replay with a synthetic fallback key. Events without
    -- stripe_subscription_id were created before the snapshot columns existed; a
    -- replay_<event_id> key creates an unrevocable orphan row that no webhook will ever
    -- cancel (because Stripe knows the real sub ID, not the synthetic one).
    IF v_rec.stripe_subscription_id IS NULL THEN
      UPDATE public.product_entitlement_events SET
        event_type       = 'final_failure',
        attempts         = attempts + 1,
        last_attempt_at  = now(),
        processing_error = 'LEGACY_NO_SUB_ID: event predates stripe_subscription_id column; '
                           'replay would create an unrevocable orphan row. '
                           'Manual reconciliation required.'
      WHERE id = v_rec.id;
      v_final := v_final + 1;
      CONTINUE;
    END IF;

    v_sub_id := v_rec.stripe_subscription_id;

    -- Attempt to re-apply the entitlement.
    -- R15 P1-A fix: Core events route through the same atomic RPCs as live webhooks
    -- (activate_core_entitlement_atomic / cancel_core_entitlement_atomic) so that both
    -- product_subscriptions and legacy tables (subscriptions/profiles) are written
    -- atomically under the per-user advisory lock.  Without this, an unknown-price Core
    -- event resolved via stripe_price_configs would update product_subscriptions but
    -- leave profiles.role='free' — access granted by the resolver but denied by legacy
    -- authorization checks (billing quota, etc.).
    --
    -- Non-Core products write only product_subscriptions (no legacy tables involved).
    v_upsert_ok  := false;
    v_upsert_err := NULL;

    IF v_product = 'core' THEN
      -- Derive legacy role/limit from tier+status (mirrors entitlementForStatus in TypeScript).
      v_legacy_role := CASE
        WHEN v_status IN ('active', 'trialing') THEN
          CASE v_tier WHEN 'premium' THEN 'premium' ELSE 'pro' END
        ELSE 'free'
      END;
      v_legacy_monthly_limit := CASE v_legacy_role
        WHEN 'premium' THEN 1000
        WHEN 'pro'     THEN 300
        ELSE 15
      END;

      BEGIN
        IF v_status IN ('active', 'trialing') THEN
          SELECT public.activate_core_entitlement_atomic(
            p_user_id                => v_user_id,
            p_product                => v_product,
            p_tier                   => v_tier,
            p_status                 => v_status,
            p_source                 => 'stripe',
            p_stripe_subscription_id => v_sub_id,
            p_stripe_price_id        => v_rec.stripe_price_id,
            p_stripe_customer_id     => v_rec.stripe_customer_id,
            p_current_period_end     => v_rec.current_period_end,
            p_cancel_at_period_end   => COALESCE(v_rec.cancel_at_period_end, false),
            p_stripe_event_id        => v_rec.stripe_event_id,
            p_stripe_event_created   => v_rec.stripe_event_created,
            p_metadata               => COALESCE(v_rec.metadata, '{}'::jsonb),
            p_legacy_role            => v_legacy_role,
            p_legacy_monthly_limit   => v_legacy_monthly_limit
          ) INTO v_core_result;
          v_upsert_ok := COALESCE((v_core_result->'upsert'->>'ok')::boolean, false)
                      OR COALESCE((v_core_result->'upsert'->>'skipped')::boolean, false);
        ELSE
          SELECT public.cancel_core_entitlement_atomic(
            p_user_id                => v_user_id,
            p_product                => v_product,
            p_tier                   => v_tier,
            p_status                 => v_status,
            p_source                 => 'stripe',
            p_stripe_subscription_id => v_sub_id,
            p_stripe_price_id        => v_rec.stripe_price_id,
            p_stripe_customer_id     => v_rec.stripe_customer_id,
            p_current_period_end     => v_rec.current_period_end,
            p_cancel_at_period_end   => COALESCE(v_rec.cancel_at_period_end, false),
            p_stripe_event_id        => v_rec.stripe_event_id,
            p_stripe_event_created   => v_rec.stripe_event_created,
            p_metadata               => COALESCE(v_rec.metadata, '{}'::jsonb),
            p_legacy_role            => v_legacy_role,
            p_legacy_monthly_limit   => v_legacy_monthly_limit
          ) INTO v_core_result;
          v_upsert_ok := COALESCE((v_core_result->'upsert'->>'ok')::boolean, false)
                      OR COALESCE((v_core_result->'upsert'->>'skipped')::boolean, false);
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_upsert_err := SQLERRM;
        v_upsert_ok  := false;
      END;

    ELSE
      -- Non-Core product: upsert product_subscriptions only (no legacy write).
      -- P2-B fix: treat skipped=true (STALE_EVENT) as success, not failure.
      BEGIN
        SELECT (result->>'ok' = 'true') OR (result->>'skipped' = 'true')
        INTO   v_upsert_ok
        FROM (
          SELECT public.upsert_product_subscription(
            p_user_id                => v_user_id,
            p_product                => v_product,
            p_tier                   => v_tier,
            p_status                 => v_status,
            p_source                 => 'stripe',
            p_stripe_subscription_id => v_sub_id,
            p_stripe_customer_id     => v_rec.stripe_customer_id,
            p_stripe_price_id        => v_rec.stripe_price_id,
            -- P1-C fix: pass stored snapshot so replay does not overwrite newer
            -- state (ordering guard) and preserves original period-end (no NULL).
            p_stripe_event_created   => v_rec.stripe_event_created,
            p_current_period_end     => v_rec.current_period_end,
            p_cancel_at_period_end   => COALESCE(v_rec.cancel_at_period_end, false),
            p_stripe_event_id        => v_rec.stripe_event_id,
            p_metadata               => COALESCE(v_rec.metadata, '{}'::jsonb)
          ) AS result
        ) sub;
      EXCEPTION WHEN OTHERS THEN
        v_upsert_err := SQLERRM;
        v_upsert_ok  := false;
      END;
    END IF;

    IF v_upsert_ok = true THEN
      -- Success: require explicit true — NULL (unexpected RPC response) is treated as failure
      UPDATE public.product_entitlement_events SET
        is_processed     = true,
        attempts         = attempts + 1,
        last_attempt_at  = now(),
        processing_error = NULL
      WHERE id = v_rec.id;
      v_processed := v_processed + 1;
    ELSE
      -- Failure
      UPDATE public.product_entitlement_events SET
        attempts         = attempts + 1,
        last_attempt_at  = now(),
        processing_error = COALESCE(v_upsert_err, 'upsert returned ok=false')
      WHERE id = v_rec.id;

      IF v_rec.attempts + 1 >= v_rec.max_attempts THEN
        UPDATE public.product_entitlement_events SET
          event_type = 'final_failure'
        WHERE id = v_rec.id;
        v_final  := v_final  + 1;
      ELSE
        v_failed := v_failed + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed,
    'failed',    v_failed,
    'final',     v_final,
    'skipped',   v_skipped,
    'resolved',  v_resolved
  );
END;
$$;

REVOKE ALL     ON FUNCTION public.process_pending_entitlement_events(int) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.process_pending_entitlement_events(int) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.process_pending_entitlement_events(int) TO service_role;

COMMENT ON FUNCTION public.process_pending_entitlement_events(int) IS
  'IV-WEB-ECOSYSTEM-UNIFICATION-01: replay worker for pending_retry '
  'entitlement events. Called by entitlement-reconcile Edge Function '
  '(scheduled). service_role only. PRODUCTION PROTECTION: gate required.';
