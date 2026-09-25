-- IV-AEF-PRE-RUNTIME-CLOSURE-01 — AEF sequence privileges (preflight P03).
--
-- MODULE LAB ONLY. Not applied to production or to any shared database.
--
-- Root cause (reproduced on a disposable database with production's default
-- privileges): the production project grants USAGE, SELECT, UPDATE on every
-- NEW sequence in schema public to anon, authenticated and service_role
-- (ALTER DEFAULT PRIVILEGES … ON SEQUENCES). The identity sequence of
-- public.aef_audit_events, created by 20260925000000, therefore inherits
-- anon=rwU: any API role could nextval/setval it and make audit inserts fail
-- (a primary-key collision after setval backwards) — an availability /
-- integrity attack on the audit trail, not a data exposure.
--
-- Contract (AEF_SEQUENCE_PRIVILEGE_MODEL.md): no API role — PUBLIC, anon,
-- authenticated, service_role — holds any privilege on any AEF sequence.
-- Every insert that consumes the sequence runs inside SECURITY DEFINER RPCs
-- owned by the migration owner, which needs no grant. Idempotent. Rollback
-- deliberately does not re-grant (see the .down.sql).

-- ── precondition: the objects this migration hardens must exist ─────────
DO $$
BEGIN
  IF to_regclass('public.aef_audit_events') IS NULL
     OR pg_get_serial_sequence('public.aef_audit_events', 'id') IS NULL THEN
    RAISE EXCEPTION 'AEF_PRECONDITION: public.aef_audit_events and its identity sequence are missing — apply 20260925000000_aef_persistence first'
      USING ERRCODE = 'AE010';
  END IF;
END $$;

-- ── deny by default on every AEF sequence ───────────────────────────────
-- Covers the audit identity sequence and any sequence owned by (or named
-- after) an AEF table, so a future AEF sequence is hardened on re-apply.
DO $$
DECLARE s regclass;
BEGIN
  FOR s IN
    SELECT DISTINCT c.oid::regclass
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN pg_depend d ON d.objid = c.oid AND d.classid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')
      LEFT JOIN pg_class t ON t.oid = d.refobjid
     WHERE n.nspname = 'public' AND c.relkind = 'S'
       AND (left(c.relname, 4) = 'aef_' OR left(t.relname, 4) = 'aef_')
  LOOP
    EXECUTE format('REVOKE ALL ON SEQUENCE %s FROM PUBLIC, anon, authenticated, service_role', s);
  END LOOP;
END $$;

-- ── postcondition: fail the migration if any API role still has access ─
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname, g.rolname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN (VALUES ('anon'), ('authenticated'), ('service_role')) g(rolname)
     WHERE n.nspname = 'public' AND c.relkind = 'S' AND left(c.relname, 4) = 'aef_'
       AND (has_sequence_privilege(g.rolname, c.oid, 'USAGE') OR has_sequence_privilege(g.rolname, c.oid, 'SELECT')
            OR has_sequence_privilege(g.rolname, c.oid, 'UPDATE'))
  LOOP
    RAISE EXCEPTION 'AEF_POSTCONDITION: role % still has a privilege on sequence %', r.rolname, r.relname USING ERRCODE = 'AE011';
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace,
                    aclexplode(coalesce(c.relacl, acldefault('s', c.relowner))) a
              WHERE n.nspname = 'public' AND c.relkind = 'S' AND left(c.relname, 4) = 'aef_' AND a.grantee = 0) THEN
    RAISE EXCEPTION 'AEF_POSTCONDITION: PUBLIC still has a privilege on an AEF sequence' USING ERRCODE = 'AE011';
  END IF;
END $$;
