-- IV-WEB-ECOSYSTEM-UNIFICATION-01 — Pending retry idempotency (P1-R31-A)
--
-- Without this index, concurrent Stripe webhook deliveries of the same event
-- could each fail the upsert_product_subscription RPC and each insert an
-- independent pending_retry row.  The worker would replay both rows; the second
-- replay would be STALE (tuple ordering) so final state remains correct, but the
-- duplicate row inflates attempt counts and audit trails.
--
-- The partial index covers only unprocessed pending_retry rows so that a new
-- retry row can be created after a previous one has been fully processed
-- (is_processed = true).
--
-- IDEMPOTENT: safe to re-run.
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

SET search_path = public, pg_catalog, pg_temp;

CREATE UNIQUE INDEX IF NOT EXISTS pee_pending_retry_dedup_idx
  ON public.product_entitlement_events (user_id, stripe_event_id, product)
  WHERE event_type = 'pending_retry'
    AND is_processed = false;
