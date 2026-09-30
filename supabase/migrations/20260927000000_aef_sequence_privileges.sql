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
-- Every sequence in public named aef_* OR owned (identity / serial) by an
-- aef_* table — one predicate, shared by the postcondition, the rollback
-- verifier, the tests and the deploy preflight.
DO $$
DECLARE s oid;
BEGIN
  FOR s IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'S'
       AND (left(c.relname, 4) = 'aef_' OR EXISTS (
             SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
              WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_'))
  LOOP
    EXECUTE format('REVOKE ALL ON SEQUENCE %s FROM PUBLIC, anon, authenticated, service_role', s::regclass);
  END LOOP;
END $$;

-- ── postcondition: fail the migration if any API role or PUBLIC keeps access ─
-- Effective privileges (has_sequence_privilege follows role membership), so a
-- grant from another grantor or through a group role is caught even though
-- the owner's REVOKE cannot remove it.
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
          RAISE EXCEPTION 'AEF_POSTCONDITION: role % still has % on sequence %', r, p, s::regclass USING ERRCODE = 'AE011';
        END IF;
      END LOOP;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('s', c.relowner))) a
                WHERE c.oid = s AND a.grantee = 0) THEN
      RAISE EXCEPTION 'AEF_POSTCONDITION: PUBLIC still has a privilege on sequence %', s::regclass USING ERRCODE = 'AE011';
    END IF;
  END LOOP;
END $$;
