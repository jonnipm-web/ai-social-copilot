-- F-03 (IV-IVE-AEF-RUNTIME-INTEGRATION-01) — catalog scan, DISPOSABLE database only.
-- Every sequence named aef_* in public, OR owned (identity/serial/OWNED BY) by
-- an aef_* table, OR used by a column default of an aef_* table — in ANY
-- schema (Codex RG3-02) — must grant nothing to PUBLIC, anon, authenticated or
-- service_role (effective privileges, so group-role grants count). Runs on
-- the fully migrated schema in CI, so a FUTURE migration that creates an AEF
-- sequence and forgets the REVOKE fails the build — independently of the
-- author remembering the rule, and of the static lint.
\set ON_ERROR_STOP 1
DO $$
DECLARE s oid; r text; p text; bad text[] := ARRAY[]::text[];
BEGIN
  FOR s IN SELECT c.oid FROM pg_class c
            WHERE c.relkind = 'S'
              AND ((c.relnamespace = 'public'::regnamespace AND left(c.relname, 4) = 'aef_')
                   OR EXISTS (SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
                               WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                                 AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_')
                   OR EXISTS (SELECT 1 FROM pg_depend d JOIN pg_attrdef ad ON ad.oid = d.objid JOIN pg_class t ON t.oid = ad.adrelid
                               WHERE d.classid = 'pg_attrdef'::regclass AND d.refclassid = 'pg_class'::regclass
                                 AND d.refobjid = c.oid AND left(t.relname, 4) = 'aef_')) LOOP
    FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      FOREACH p IN ARRAY ARRAY['USAGE', 'SELECT', 'UPDATE'] LOOP
        IF has_sequence_privilege(r, s, p) THEN bad := bad || format('%s:%s:%s', s::regclass, r, p); END IF;
      END LOOP;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('s', c.relowner))) a
                WHERE c.oid = s AND a.grantee = 0) THEN
      bad := bad || format('%s:PUBLIC', s::regclass);
    END IF;
  END LOOP;
  IF array_length(bad, 1) > 0 THEN
    RAISE EXCEPTION 'AEF_SEQUENCE_CATALOG_SCAN: FAIL — exposed: %', array_to_string(bad, ', ');
  END IF;
END $$;
SELECT 'AEF_SEQUENCE_CATALOG_SCAN: PASS';
