-- Rollback for migration 20260925000000_aef_persistence.sql (IV-AEF-PERSISTENCE-01).
--
-- NOT a migration: the Supabase CLI never runs this directory. It exists so a
-- rollback is a reviewed, tested script rather than an improvised one
-- (Codex Gate 1 G1-05). Tested on a disposable database by
-- scripts/ci/run_disposable_db_tests.sh (down, verify nothing left, up again).
--
-- DESTRUCTIVE: drops every AEF operation, gate, receipt and audit event.
-- Run only with explicit owner approval, as the table owner, in one
-- transaction. The append-only triggers block DELETE/TRUNCATE by design, so
-- rollback is DROP TABLE (which those triggers do not intercept).
BEGIN;

-- Order matters: non-trigger functions first (one takes the aef_operations
-- row type as an argument, which blocks DROP TABLE), then the tables (their
-- triggers go with them), then the trigger functions.
DO $$
DECLARE f regprocedure;
BEGIN
  FOR f IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_' AND p.prorettype <> 'trigger'::regtype LOOP
    EXECUTE format('DROP FUNCTION %s', f);
  END LOOP;
END $$;

DROP TABLE IF EXISTS public.aef_receipts;
DROP TABLE IF EXISTS public.aef_human_gates;
DROP TABLE IF EXISTS public.aef_audit_events;
DROP TABLE IF EXISTS public.aef_audit_heads;
DROP TABLE IF EXISTS public.aef_operations;

DO $$
DECLARE f regprocedure;
BEGIN
  FOR f IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_' LOOP
    EXECUTE format('DROP FUNCTION %s', f);
  END LOOP;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = 'public' AND left(c.relname, 4) = 'aef_')
     OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_') THEN
    RAISE EXCEPTION 'AEF rollback incomplete';
  END IF;
END $$;

COMMIT;
