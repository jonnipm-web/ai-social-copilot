-- INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §23-25 — DB-layer
-- enforcement for action_queue's AEF-governed statuses.
--
-- STATUS: Module Lab only. NOT applied to production by this mission.
--
-- *** WRITTEN, NOT LIVE-TESTED ***
-- This environment has no working disposable-PostgreSQL connection this
-- mission (a real local PostgreSQL 17 service was found running, but the
-- available credential did not authenticate; see this mission's final
-- report, POSTGRES_RESULT). Per §24: "Test in disposable PostgreSQL
-- before considering complete." This migration is a reviewed, careful
-- DESIGN, not a verified fix -- do not treat it as done until run through
-- scripts/ci/run_disposable_db_tests.sh (or an equivalent CI job) at least
-- once. Self-review notes are left inline below precisely so that
-- verification pass can start from "does this match the design" rather
-- than "what was even intended".
--
-- THE GAP (Macro-03's own residual, restated in this mission's brief):
-- ActionQueueService.updateStatus()/create() (Dart) refuse to write
-- 'executing'/'completed' directly -- but that is an APPLICATION-layer
-- guard. The database's own RLS policy (action_queue_user, baseline
-- migration 20260907120000) is `FOR ALL USING (auth.uid() = user_id)`,
-- with no WITH CHECK and no column restriction at all: an authenticated
-- owner's own JWT can UPDATE action_queue directly (via PostgREST, a raw
-- HTTP call, anything bypassing the Dart app) and set status='completed'
-- with no receipt at all. This migration closes that gap at the one layer
-- that cannot be bypassed by skipping the app.
--
-- THE FIX: two additive CHECK constraints mirroring, at the database
-- layer, the exact same fail-closed rule lib/data/models/aef_runtime.dart's
-- aefReceiptOutcomeToActionStatus() already enforces client-side:
--   1. status IN ('executing','completed') requires BOTH
--      aef_operation_id AND aef_receipt_id to be set (mirrors
--      ActionQueueService's own _refuseIfAefGovernedOnly + the existing
--      aef_receipt_requires_operation_check from
--      20260929000000_action_queue_aef_governance.sql).
--   2. status='completed' requires aef_receipt_outcome='SUCCESS' (mirrors
--      aefReceiptOutcomeToActionStatus's own SUCCESS-only rule for the
--      'completed' status).
--
-- NOT VALID (critical, self-reviewed): action_queue is an
-- APPLIED_PRODUCTION table that has had a working 'completed' status
-- since long before AEF or these aef_* columns existed. A production row
-- can genuinely be status='completed' with aef_receipt_id IS NULL today
-- (a self-attested completion from before this mission's governance work,
-- or from Free/Pro's own pre-AEF Action Engine history). Adding these
-- constraints WITHOUT NOT VALID would either fail to apply outright or
-- retroactively invalidate real historical rows -- exactly the same
-- reasoning already established for business_memory_content_len_check
-- (20260924000000_ive_memory_governance.sql: "Size cap for NEW rows only
-- (NOT VALID): legacy rows are left untouched"). NOT VALID means: enforced
-- for every INSERT and every UPDATE from the moment this migration
-- applies, but existing rows are not scanned/rejected at migration time.
--
-- RESIDUAL LIMITATION (honest, not hidden): these are same-row column-
-- consistency checks, not a foreign-key verification against a real,
-- persisted AefReceipt/AefOperation (aef_operations/aef_receipts still
-- live in the LAB-only 20260925000000 migration, not yet applied to
-- production -- same reasoning 20260929000000_action_queue_aef_governance.sql
-- already gave for omitting that FK). A sufficiently deliberate attacker
-- who already knows this schema could still construct a syntactically
-- consistent fake receipt (random UUIDs, outcome='SUCCESS') and pass these
-- CHECKs. This is a REAL improvement -- it closes the "wrote a client bug
-- or hit the REST API directly with no receipt at all" class of bypass
-- entirely -- not a complete one. Full protection needs a real FK to
-- aef_receipts once that migration is production-applied; tracked as a
-- named next-macro item, not silently treated as solved by this file.
--
-- No RLS policy change: WITH CHECK on the existing FOR ALL policy was
-- considered and rejected here -- it would duplicate exactly what these
-- CHECK constraints already enforce table-wide (for every write path, not
-- just the one RLS policy covers) with more surface area to get wrong.
-- CHECK constraints are the narrower, safer mechanism for this specific
-- gap.
--
-- Idempotent: safe to re-run (guarded).
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'action_queue_governed_status_requires_receipt_check') THEN
    ALTER TABLE public.action_queue
      ADD CONSTRAINT action_queue_governed_status_requires_receipt_check
      CHECK (status NOT IN ('executing', 'completed') OR (aef_operation_id IS NOT NULL AND aef_receipt_id IS NOT NULL))
      NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'action_queue_completed_requires_success_check') THEN
    ALTER TABLE public.action_queue
      ADD CONSTRAINT action_queue_completed_requires_success_check
      CHECK (status <> 'completed' OR aef_receipt_outcome = 'SUCCESS')
      NOT VALID;
  END IF;
END $$;

COMMIT;

-- Verification checklist for whoever runs this in a real disposable
-- PostgreSQL (do all of these before removing this migration's "WRITTEN,
-- NOT LIVE-TESTED" status from the mission report):
--   1. scripts/ci/migration_manifest.sh --write, then --check (idempotent
--      hash + duplicate detection).
--   2. scripts/ci/run_disposable_db_tests.sh end to end (applies every
--      migration in order, then re-applies every LAB migration a second
--      time to prove idempotency -- this file's DO $$ guards must survive
--      that).
--   3. A direct INSERT/UPDATE test proving: (a) status='completed' with
--      NULL aef_receipt_id is REJECTED; (b) status='completed' with a
--      non-NULL aef_receipt_id but aef_receipt_outcome='FAILURE' is
--      REJECTED; (c) status='completed' with aef_receipt_outcome='SUCCESS'
--      and both aef_operation_id/aef_receipt_id set SUCCEEDS; (d) status
--      IN ('pending','approved','cancelled') with all three aef_* columns
--      NULL SUCCEEDS unaffected (the overwhelming majority of legitimate
--      writes, per action_queue_provider.dart's approve()/cancel()).
--   4. Confirm a pre-existing row seeded with status='completed' and
--      aef_receipt_id NULL (simulating real historical data) is NOT
--      rejected by the migration itself (NOT VALID working as intended),
--      but IS rejected by a follow-up UPDATE that tries to re-touch it.
