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
DECLARE s oid; r text; p text;
BEGIN
  FOR s IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'S'
       AND (left(c.relname, 4) = 'aef_' OR EXISTS (
             SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
              WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_'))
  LOOP
    FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      FOREACH p IN ARRAY ARRAY['USAGE', 'SELECT', 'UPDATE'] LOOP
        IF has_sequence_privilege(r, s, p) THEN
          RAISE EXCEPTION 'AEF sequence % is exposed (% has %) — re-apply 20260927000000, do not roll back to a weaker state', s::regclass, r, p;
        END IF;
      END LOOP;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('s', c.relowner))) a
                WHERE c.oid = s AND a.grantee = 0) THEN
      RAISE EXCEPTION 'AEF sequence % is exposed to PUBLIC — re-apply 20260927000000', s::regclass;
    END IF;
  END LOOP;
  RAISE NOTICE 'AEF sequence rollback: no-op by design (security state kept)';
END $$;
