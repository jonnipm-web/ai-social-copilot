-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Reconciler SQL backstop (P1-R33-A fix)
--
-- Problem: invoke_entitlement_reconciler uses net.http_post asynchronously
-- (fire-and-forget). If the Edge Function fails (bad URL, expired service key,
-- undeployed function, 5xx), pg_cron reports success while pending_retry rows
-- accumulate unprocessed indefinitely.
--
-- Fix: in the Edge Function path, always also run process_pending_entitlement_events
-- as an immediate SQL backstop. The EF (when successful) will sync stripe_price_configs
-- and process all pending events including unknown-price ones. The SQL backstop
-- guarantees that events with known price mappings are processed even on EF failure.
-- Duplicate processing is safe: process_pending_entitlement_events marks rows
-- is_processed = true atomically; EF retries see those rows and skip them.
--
-- IDEMPOTENT: safe to re-run.
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

SET search_path = public, pg_catalog, pg_temp;

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
  v_sql_result  jsonb;
BEGIN
  v_project_url := current_setting('app.supabase_project_url', true);
  v_service_key := current_setting('app.service_role_key',      true);

  IF v_project_url IS NOT NULL AND v_project_url <> ''
     AND v_service_key IS NOT NULL AND v_service_key <> ''
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
  THEN
    -- Preferred path: invoke Edge Function via HTTP (asynchronous via pg_net).
    -- The Edge Function syncs STRIPE_PRICE_MAP → stripe_price_configs before
    -- calling process_pending_entitlement_events, so unknown-price events are
    -- resolved on each scheduled run when the EF succeeds.
    PERFORM net.http_post(
      url     := v_project_url || '/functions/v1/entitlement-reconcile?batch=' || p_batch_size,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_service_key
      ),
      body    := (jsonb_build_object('batch', p_batch_size))::text::bytea
    );
    -- P1-R33-A fix: SQL backstop — net.http_post is fire-and-forget; if the EF
    -- fails (bad URL, expired key, undeployed, 5xx), this guarantees events with
    -- known price mappings are still processed in this cron tick.
    -- Duplicate processing is safe: process_pending_entitlement_events uses
    -- SELECT ... FOR UPDATE SKIP LOCKED and sets is_processed=true atomically;
    -- any row the EF later processes will already have is_processed=true (no-op).
    -- Unknown-price events (product='unknown') remain pending_retry until the EF
    -- successfully syncs stripe_price_configs — that is the accepted limitation
    -- of the SQL-only path and is unchanged from the pre-migration behaviour.
    SELECT public.process_pending_entitlement_events(p_batch_size) INTO v_sql_result;
    RETURN jsonb_build_object(
      'invocation',  'edge_function_with_sql_backstop',
      'batch',       p_batch_size,
      'sql_result',  v_sql_result
    );
  ELSE
    -- Fallback: call SQL worker directly.
    -- stripe_price_configs will NOT be synced in this path.
    -- Unknown-price events remain pending_retry until the Edge Function is invoked.
    SELECT public.process_pending_entitlement_events(p_batch_size) INTO v_sql_result;
    RETURN jsonb_build_object('invocation', 'sql_worker', 'batch', p_batch_size, 'result', v_sql_result);
  END IF;
END;
$$;
