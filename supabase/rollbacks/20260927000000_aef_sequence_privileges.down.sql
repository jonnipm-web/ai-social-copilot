-- Rollback for migration 20260927000000_aef_sequence_privileges.sql
-- (IV-AEF-PRE-RUNTIME-CLOSURE-01). NOT a migration.
--
-- Structural rollback: nothing to undo — the migration creates no object.
-- Security rollback: deliberately NOT performed. Re-granting USAGE/SELECT/
-- UPDATE on the audit sequence to anon/authenticated/service_role would
-- restore a known availability/integrity weakness (P03). Rolling back the
-- persistence migration (20260925000000 down) drops the sequence together
-- with its table, which is the only supported way to remove it.
--
-- This script only verifies that the hardened state is intact, so an
-- operator following a rollback runbook sees an explicit, reviewed outcome.
DO $$
BEGIN
  IF to_regclass('public.aef_audit_events') IS NOT NULL
     AND (has_sequence_privilege('anon', pg_get_serial_sequence('public.aef_audit_events', 'id'), 'USAGE')
          OR has_sequence_privilege('authenticated', pg_get_serial_sequence('public.aef_audit_events', 'id'), 'UPDATE')) THEN
    RAISE EXCEPTION 'AEF sequence privileges are not hardened — re-apply 20260927000000, do not roll back to a weaker state';
  END IF;
  RAISE NOTICE 'AEF sequence rollback: no-op by design (security state kept)';
END $$;
