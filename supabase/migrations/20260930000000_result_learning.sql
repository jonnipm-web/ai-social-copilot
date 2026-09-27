-- INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §7-9 — Result -> Learning.
--
-- STATUS: Module Lab only. NOT applied to production by this mission.
--
-- Completes the missing final link ACTION -> RECEIPT -> RESULT -> LEARNING
-- by evolving business_memory (IV-IVE-INTELLIGENCE-CORE-01's own governed,
-- durable, user-owned memory store -- see 20260924000000_ive_memory_
-- governance.sql) rather than creating a second, parallel memory system.
-- business_memory already carries everything a learning entry needs except
-- the specific link back to the governed action/operation/receipt it came
-- from, and an explicit epistemic verification_state -- both added here,
-- purely additively.
--
--   source_action_id     the action_queue row this learning came from
--                         (NULL for memory that never went through AEF,
--                         e.g. ordinary user-authored notes)
--   source_operation_id  the AEF durable operation id
--   source_receipt_id    the persisted ExecutionReceipt id
--   verification_state   'verified'   -- a real AEF receipt with outcome
--                                          SUCCESS backs this entry
--                         'unverified' -- an AEF-derived entry whose outcome
--                                          was FAILURE/PARTIAL/NOT_EXECUTED/
--                                          UNKNOWN_OUTCOME -- the execution
--                                          fact itself is real (a receipt
--                                          exists) but it is NOT to be read
--                                          as "the task succeeded"
--                         NULL         -- not AEF-derived; verification is
--                                          not applicable (existing rows,
--                                          user-authored/ive_derived memory)
--
-- Every AEF-derived row MUST be origin='system_derived' (§8: derived
-- learning is never self-attested by the authenticated user's own JWT --
-- business_memory_insert_own/update_own already refuse origin=
-- 'system_derived' for the authenticated role; only service_role, i.e. a
-- trusted Edge Function boundary, can write it). This is enforced below as
-- a CHECK, not just a convention.
--
-- Idempotency comes from the EXISTING mechanism (dedup_key + the unique
-- partial index uq_business_memory_active_dedup already in
-- 20260924000000_ive_memory_governance.sql), not a new one: the writer
-- computes dedup_key = sha256('action_result|' || operation_id || '|' ||
-- receipt_id), so a retried/replayed terminal result can never insert a
-- second row for the same governed fact.
--
-- No FK to aef_operations/aef_receipts: those tables live in the still-LAB
-- AEF persistence migration (20260925000000), itself not yet applied to
-- production, and business_memory (like action_queue) already IS in
-- production -- a hard FK here would make this migration inapplicable
-- until AEF's own migration lands first. Same pattern as action_queue's own
-- aef_operation_id/aef_receipt_id in 20260929000000_action_queue_aef_governance.sql.
--
-- Nothing existing is altered, dropped, or renamed; every new column
-- defaults to NULL, so every existing row and every write path that
-- doesn't know about Result->Learning is completely unaffected.
BEGIN;

ALTER TABLE public.business_memory
  ADD COLUMN IF NOT EXISTS source_action_id    uuid NULL,
  ADD COLUMN IF NOT EXISTS source_operation_id uuid NULL,
  ADD COLUMN IF NOT EXISTS source_receipt_id   uuid NULL,
  ADD COLUMN IF NOT EXISTS verification_state  text NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_verification_state_check') THEN
    ALTER TABLE public.business_memory
      ADD CONSTRAINT business_memory_verification_state_check
      CHECK (verification_state IS NULL OR verification_state IN ('verified', 'unverified'));
  END IF;

  -- A receipt id without its operation id would be an unrecordable claim --
  -- same rule as action_queue's own aef_receipt_id/aef_operation_id pair.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_receipt_requires_operation_check') THEN
    ALTER TABLE public.business_memory
      ADD CONSTRAINT business_memory_receipt_requires_operation_check
      CHECK (source_receipt_id IS NULL OR source_operation_id IS NOT NULL);
  END IF;

  -- verification_state is only meaningful for an AEF-derived row: it must
  -- be set together with a receipt, and absent otherwise.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_verification_requires_receipt_check') THEN
    ALTER TABLE public.business_memory
      ADD CONSTRAINT business_memory_verification_requires_receipt_check
      CHECK ((verification_state IS NULL) = (source_receipt_id IS NULL));
  END IF;

  -- §8: derived learning can never be self-attested by the authenticated
  -- user's own JWT -- a row that names a source action must be
  -- system_derived (service_role-only per the existing RLS policies).
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_learning_origin_check') THEN
    ALTER TABLE public.business_memory
      ADD CONSTRAINT business_memory_learning_origin_check
      CHECK (source_action_id IS NULL OR origin = 'system_derived');
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_business_memory_source_action
  ON public.business_memory USING btree (source_action_id)
  WHERE (source_action_id IS NOT NULL);

COMMIT;
