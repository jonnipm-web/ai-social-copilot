-- IV-WEB-ECOSYSTEM-UNIFICATION-01
-- Migration 00006: Atomic Core cancellation RPC (P1-A fix)
--
-- Solves the TOCTOU race in the P1-I Core cancellation path:
-- Previously: write product_subscriptions → read resolve_product_entitlement (separate RPC)
--             → conditionally write legacy subscriptions/profiles (separate RPC)
-- A concurrent activation between the resolver read and the legacy write could
-- downgrade legacy state even though a new active Core sub now exists.
--
-- Fix: all three steps run inside ONE PostgreSQL transaction protected by a
-- per-user advisory lock so no concurrent webhook can interleave.

CREATE OR REPLACE FUNCTION public.cancel_core_entitlement_atomic(
  -- Product subscription params (mirrors upsert_product_subscription)
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
  -- Legacy state params (mirrors apply_stripe_subscription_state)
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
  -- Advisory transaction lock derived from user_id UUID (64-bit signed integer).
  -- Serializes all cancel_core_entitlement_atomic calls for the same user so no
  -- concurrent activation can interleave between step 2 and step 3.
  -- Released automatically when the transaction ends.
  PERFORM pg_advisory_xact_lock(
    ('x' || substr(md5(p_user_id::text), 1, 16))::bit(64)::bigint
  );

  -- Step 1: Apply the product subscription cancel atomically within this transaction.
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

  -- Step 2: Evaluate entitlement while still holding the advisory lock.
  -- Any concurrent activation that tries to call cancel_core_entitlement_atomic
  -- for the same user will block here until our transaction commits.
  SELECT public.resolve_product_entitlement(p_user_id, p_product) INTO v_ent_result;

  -- Step 3: If no active Core sub remains, downgrade legacy subscriptions/profiles.
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
      p_monthly_limit          => p_legacy_monthly_limit
    ) INTO v_legacy_result;
    v_legacy_applied := COALESCE(v_legacy_result, false);

    -- R22-A fix: if the user-global timestamp guard blocked the legacy write
    -- (e.g., a newer event from a DIFFERENT sub advanced last_event_created)
    -- but the aggregate entitlement is truly inactive, force-downgrade profiles
    -- so authorization reflects the real state.
    -- Guard: subscriptions row must exist (missing row = broken mapping, not stale).
    IF NOT COALESCE(v_legacy_applied, false)
       AND EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id)
    THEN
      -- Only downgrade Stripe-managed roles. admin/beta_tester/premium are
      -- granted outside of Stripe billing and must never be changed by webhook events.
      -- Mirrors the protection in apply_stripe_subscription_state (migration 20261010000000).
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

COMMENT ON FUNCTION public.cancel_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) IS 'Atomically cancels a Core subscription and conditionally downgrades legacy state (P1-A fix). Advisory lock per user prevents the TOCTOU race where a concurrent activation could interleave between the product write and the legacy-state decision.';

-- ── activate_core_entitlement_atomic ──────────────────────────────────────────
--
-- R12 P1 fix: extend the advisory-lock pattern to the activation path.
--
-- Previously the TypeScript activation path called apply_stripe_subscription_state
-- (legacy write) and upsert_product_subscription (product write) as two separate
-- RPCs. A concurrent cancel_core_entitlement_atomic could acquire the lock between
-- those two calls, find no product row yet, and downgrade legacy state — leaving the
-- user with profiles.role='free' despite a new active subscription.
--
-- Fix: both writes happen inside ONE PostgreSQL transaction under the SAME advisory
-- lock key as cancel_core_entitlement_atomic. If a cancel arrives concurrently, it
-- blocks on pg_advisory_xact_lock until the activation transaction commits, at which
-- point the product row is visible and the resolver correctly concludes the
-- entitlement is alive.
--
-- Behavioral note: if either write fails the entire transaction rolls back (no
-- partial state). TypeScript propagates the error (500) and Stripe retries.
-- This is stricter than the previous behaviour where legacy could succeed even if
-- the product write failed, but it is more correct for the atomicity guarantee.

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
  -- Same advisory lock key as cancel_core_entitlement_atomic: a concurrent
  -- cancel will block here until our transaction commits, guaranteeing it
  -- sees the product row we are about to write.
  PERFORM pg_advisory_xact_lock(
    ('x' || substr(md5(p_user_id::text), 1, 16))::bit(64)::bigint
  );

  -- Step 1: Product activation — write per-subscription row first so the resolver
  -- reflects the correct state before we decide what legacy role/limit to set.
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

  -- Step 2: Resolve current aggregated entitlement across ALL Core subscriptions.
  -- This gives the authoritative tier even when this subscription is one of several.
  SELECT public.resolve_product_entitlement(p_user_id, p_product) INTO v_ent_result;

  -- Step 3: Apply legacy activation only if the aggregated entitlement is active.
  -- R17-B fix: derive role/limit from the POST-WRITE aggregate resolver tier, not from the
  -- incoming event's individual tier. Prevents a lower-tier activation from overwriting an
  -- existing higher-tier legacy state (e.g., activating a 'pro' sub when 'premium' already exists).
  IF COALESCE((v_ent_result->>'allowed')::boolean, false) THEN
    v_resolved_tier  := v_ent_result->>'tier';
    -- R24 fix: Stripe billing is capped at 'pro'. Migration 20261010000000 defines
    -- 'premium' as manually granted only; this function must never elevate profiles.role
    -- to 'premium' via a billing event. tier='premium' → 'pro' (paid, but capped).
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
      p_monthly_limit          => v_apply_limit
    ) INTO v_legacy_applied;

    -- Step 4: R16-C fix — if legacy write was skipped by the user-global timestamp guard
    -- (e.g., a newer event for a DIFFERENT subscription already advanced last_event_created),
    -- the product entitlement is active but profiles.role/monthly_limit may still be 'free'.
    -- Conditions: (a) product row was written this invocation (upsert ok=true, not STALE_EVENT),
    -- (b) subscriptions row EXISTS (stale = user-global guard rejected, not missing-row).
    -- Without (a): both upsert and legacy are stale (same-sub duplicate) — nothing to repair.
    -- Without (b): mapping is broken — force-update would silently create inconsistency.
    IF NOT COALESCE(v_legacy_applied, false)
       AND COALESCE((v_upsert_result->>'ok')::boolean, false)
       AND EXISTS (SELECT 1 FROM public.subscriptions WHERE user_id = p_user_id)
    THEN
      -- v_resolved_role/limit already derived above from the aggregate resolver tier.
      -- R24: v_resolved_role is capped at 'pro' so only free/NULL profiles need upgrading.
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

COMMENT ON FUNCTION public.activate_core_entitlement_atomic(
  uuid,text,text,text,text,text,text,text,timestamptz,boolean,text,timestamptz,jsonb,text,int
) IS 'Atomically activates a Core subscription: (1) writes product row, (2) resolves aggregated entitlement, (3) applies legacy state; if legacy write is skipped by the user-global timestamp guard (cross-subscription ordering), force-updates profiles.role from the resolver result (R12+R16-C P1 fix). Advisory lock serializes concurrent cancel calls.';
