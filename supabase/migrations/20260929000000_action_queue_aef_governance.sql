-- INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — Action Engine <-> AEF governance.
--
-- STATUS: Module Lab only. NOT applied to production by this mission.
--
-- action_queue (public.action_queue, APPLIED_PRODUCTION baseline migration
-- 20260907120000) has never recorded whether an "executed"/"completed"
-- transition went through any governance -- status was always a bare,
-- client-asserted string. This adds purely additive, nullable provenance
-- columns so a governed transition (via the new action-engine-runtime AEF
-- bridge) can record the REAL outcome it received from AefGovernance,
-- distinct from a self-attested manual status change:
--
--   aef_operation_id   the AEF durable operation this transition went
--                       through, if any (NULL = never AEF-governed,
--                       e.g. a purely self-performed real-world task)
--   aef_receipt_id      the persisted ExecutionReceipt id, once one exists
--   aef_receipt_outcome the receipt's own outcome (SUCCESS/FAILURE/PARTIAL/
--                       NOT_EXECUTED/UNKNOWN_OUTCOME) -- mirrors
--                       aef_receipts.outcome verbatim, never invented
--                       client-side
--
-- No FK to public.aef_operations/aef_receipts: those tables live in the
-- AEF persistence migration (20260925000000), itself not yet applied to
-- production, and this table (action_queue) already IS in production --
-- a hard FK here would make this migration inapplicable until AEF's own
-- migration lands first. The ids are informational cross-references,
-- verified application-side (governance.getOperation) rather than by the
-- database, exactly like every other cross-migration-boundary reference
-- in this codebase's LAB work.
--
-- Nothing existing is altered, dropped, or renamed; no row's current
-- status/value changes; both new UUID columns and the outcome column
-- default to NULL, so every existing row (and every write path that
-- doesn't yet know about AEF governance) is completely unaffected.
BEGIN;

ALTER TABLE public.action_queue
  ADD COLUMN IF NOT EXISTS aef_operation_id   uuid NULL,
  ADD COLUMN IF NOT EXISTS aef_receipt_id      uuid NULL,
  ADD COLUMN IF NOT EXISTS aef_receipt_outcome text NULL;

-- ADD CONSTRAINT has no IF NOT EXISTS in Postgres; without this guard the
-- idempotency re-apply (scripts/ci/run_disposable_db_tests.sh, every LAB
-- migration) would fail the second time with "constraint already exists" --
-- mirrors the pg_constraint guard already used in 20260924000000_ive_memory_governance.sql.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'action_queue_aef_receipt_outcome_check') THEN
    ALTER TABLE public.action_queue
      ADD CONSTRAINT action_queue_aef_receipt_outcome_check
      CHECK (aef_receipt_outcome IS NULL OR aef_receipt_outcome IN ('SUCCESS', 'FAILURE', 'PARTIAL', 'NOT_EXECUTED', 'UNKNOWN_OUTCOME'));
  END IF;

  -- A governed transition never claims a receipt without recording which
  -- operation it came from -- catches an application bug writing a receipt
  -- id without its operation, the reverse (an operation id with no receipt
  -- yet) is a normal, valid AWAITING_APPROVAL/AUTHORIZED/EXECUTING state.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'action_queue_aef_receipt_requires_operation_check') THEN
    ALTER TABLE public.action_queue
      ADD CONSTRAINT action_queue_aef_receipt_requires_operation_check
      CHECK (aef_receipt_id IS NULL OR aef_operation_id IS NOT NULL);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_action_queue_aef_operation
  ON public.action_queue USING btree (aef_operation_id)
  WHERE (aef_operation_id IS NOT NULL);

COMMIT;
