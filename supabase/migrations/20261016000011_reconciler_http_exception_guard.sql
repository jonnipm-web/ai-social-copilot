-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Migration 00011
-- Codex CLASS D R3 P1 fix: net.http_post exception can bypass SQL backstop.
--
-- PROBLEM (migration 20261016000009, lines 44-61):
--   If net.http_post(...) raises an exception at the FUNCTION CALL level
--   (e.g. schema mismatch if pg_net is not in the `net` schema, execute
--   permission denied, or any other pg_net-level error), the unhandled
--   RAISE causes the entire PL/pgSQL function to abort. The SQL backstop
--   at line 61 (process_pending_entitlement_events) then never runs, and
--   cron reports success while pending_retry rows accumulate.
--
--   On the actual Supabase production instance pg_net is installed in the
--   `net` schema (Supabase default), so net.http_post works in practice.
--   However the defensive fix — wrapping the HTTP enqueue in a
--   BEGIN/EXCEPTION block — guarantees the SQL backstop runs regardless
--   of any pg_net-level failure, and makes the code correct on any
--   pg_net installation schema.
--
-- FIX:
--   Wrap PERFORM net.http_post(...) in BEGIN/EXCEPTION WHEN OTHERS so
--   that pg_net errors are swallowed locally and process_pending_entitlement_events
--   always executes in the same cron tick.
--
-- IDEMPOTENT: safe to re-run (CREATE OR REPLACE).
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
  v_project_url    text;
  v_service_key    text;
  v_sql_result     jsonb;
  v_http_enqueued  boolean := false;
BEGIN
  v_project_url := current_setting('app.supabase_project_url', true);
  v_service_key := current_setting('app.service_role_key',      true);

  IF v_project_url IS NOT NULL AND v_project_url <> ''
     AND v_service_key IS NOT NULL AND v_service_key <> ''
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
  THEN
    -- Preferred path: invoke Edge Function via HTTP (asynchronous via pg_net).
    -- Wrapped in BEGIN/EXCEPTION so a pg_net-level error (schema mismatch,
    -- execute permission, extension error) does not abort the function and
    -- cause the SQL backstop below to be skipped.
    BEGIN
      PERFORM net.http_post(
        url     := v_project_url || '/functions/v1/entitlement-reconcile?batch=' || p_batch_size,
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_service_key
        ),
        body    := (jsonb_build_object('batch', p_batch_size))::text::bytea
      );
      v_http_enqueued := true;
    EXCEPTION WHEN OTHERS THEN
      -- net.http_post raised — swallow and fall through to SQL backstop.
      -- The HTTP request was not enqueued; the SQL backstop below is the only
      -- processing path this tick. This is safe: process_pending_entitlement_events
      -- is idempotent and handles its own locking.
      v_http_enqueued := false;
    END;

    -- SQL backstop — always runs in the Edge Function path.
    -- When the EF succeeds it will sync stripe_price_configs and process all
    -- pending events (including unknown-price ones). The SQL backstop here
    -- guarantees that events with known price mappings are processed even when
    -- the HTTP enqueue fails or the EF itself errors.
    -- Duplicate processing is safe: process_pending_entitlement_events uses
    -- SELECT ... FOR UPDATE SKIP LOCKED and sets is_processed=true atomically.
    -- Unknown-price events remain pending_retry until the EF successfully syncs
    -- stripe_price_configs — accepted limitation, unchanged from pre-migration.
    SELECT public.process_pending_entitlement_events(p_batch_size) INTO v_sql_result;
    RETURN jsonb_build_object(
      'invocation',    'edge_function_with_sql_backstop',
      'http_enqueued', v_http_enqueued,
      'batch',         p_batch_size,
      'sql_result',    v_sql_result
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

-- ACL: unchanged (no anon/authenticated execute; called by pg_cron and service_role only)
REVOKE EXECUTE ON FUNCTION public.invoke_entitlement_reconciler(int)
  FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.invoke_entitlement_reconciler(int)
  TO service_role;
