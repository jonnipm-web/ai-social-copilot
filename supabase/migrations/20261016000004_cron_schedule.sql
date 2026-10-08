-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Entitlement Replay Scheduler
--
-- Registers a pg_cron job to run process_pending_entitlement_events every
-- 5 minutes, ensuring pending_retry events are processed automatically.
-- This makes replay recovery a deployment-time requirement, not an optional
-- operational step (P1-H fix).
--
-- Requires: pg_cron extension (Supabase Pro/Team plans).
-- Fallback: if pg_cron is unavailable, the entitlement-reconcile Edge Function
-- MUST be scheduled via Supabase dashboard → Edge Functions → Schedule,
-- or via an external scheduler (e.g., GitHub Actions cron, Render cron).
--
-- IDEMPOTENT: safe to re-run (unschedule + reschedule).
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

-- Enable pg_net extension if available (for Edge Function HTTP invocation fallback)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_net') THEN
    CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
  END IF;
END $$;

-- Deployment gate: the migration FAILS unless pg_cron is available OR the operator
-- has explicitly confirmed an alternative scheduler by setting the PostgreSQL
-- session variable app.external_scheduler_confirmed = 'confirmed' before applying.
--
-- How to confirm an alternative scheduler:
--   SET app.external_scheduler_confirmed = 'confirmed';
--   \i supabase/migrations/20261016000004_cron_schedule.sql
--
-- The override is intentionally a per-session setting so it cannot be set via a
-- generic migration runner without the operator explicitly opting in.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Remove existing job if re-running migration (idempotent)
    PERFORM cron.unschedule('process-pending-entitlement-events')
    FROM cron.job
    WHERE jobname = 'process-pending-entitlement-events';

    -- Schedule: run every 5 minutes, process up to 50 events per batch
    PERFORM cron.schedule(
      'process-pending-entitlement-events',
      '*/5 * * * *',
      $cron_cmd$SELECT public.process_pending_entitlement_events(50)$cron_cmd$
    );

    RAISE NOTICE 'pg_cron: scheduled process-pending-entitlement-events every 5 minutes';
  ELSIF current_setting('app.external_scheduler_confirmed', true) = 'confirmed' THEN
    -- Operator confirmed that an external or Edge Function scheduler is in place.
    RAISE NOTICE
      'pg_cron not available: external scheduler confirmed by operator. '
      'Ensure the entitlement-reconcile Edge Function (or equivalent) is scheduled '
      'before applying webhook changes. See supabase/functions/entitlement-reconcile/index.ts.';
  ELSE
    -- No scheduler available and operator has not confirmed an alternative.
    -- Fail loudly so pending_retry events do not accumulate silently in production.
    RAISE EXCEPTION
      'DEPLOYMENT_GATE_FAILURE: pg_cron is not available and no alternative scheduler '
      'has been confirmed (app.external_scheduler_confirmed is not ''confirmed''). '
      'Paid users may remain without entitlements if pending_retry events accumulate. '
      'Configure an external scheduler and set app.external_scheduler_confirmed=confirmed '
      'before applying this migration. '
      'See supabase/functions/entitlement-reconcile/index.ts for setup instructions.';
  END IF;
END $$;

-- Note: COMMENT ON EXTENSION pg_net omitted — pg_net may not be installed on all plans.
