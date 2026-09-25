-- F-03 fixture (NOT a migration): the same future migration WITH the canonical
-- deny-by-default block (as in 20260925 / 20260927).
CREATE TABLE IF NOT EXISTS public.aef_future_items (
  id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  note text
);
CREATE SEQUENCE IF NOT EXISTS public.future_counter OWNED BY public.aef_future_items.note;

-- Codex RG3-02: a sequence NOT owned by an AEF table but used by its default,
-- and a sequence in ANOTHER schema used by an AEF default, with an explicit grant
-- (OWNED BY across schemas is impossible in PostgreSQL).
CREATE SEQUENCE IF NOT EXISTS public.shared_counter;
CREATE TABLE IF NOT EXISTS public.aef_future_counters (id bigint DEFAULT nextval('public.shared_counter'));
CREATE SCHEMA IF NOT EXISTS aef_private;
CREATE SEQUENCE IF NOT EXISTS aef_private.other_seq;
GRANT UPDATE ON SEQUENCE aef_private.other_seq TO anon;
CREATE TABLE IF NOT EXISTS public.aef_future_other (ref bigint DEFAULT nextval('aef_private.other_seq'));
DO $$
DECLARE s oid;
BEGIN
  FOR s IN SELECT c.oid FROM pg_class c
            WHERE c.relkind = 'S'
              AND ((c.relnamespace = 'public'::regnamespace AND left(c.relname, 4) = 'aef_')
                   OR EXISTS (SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
                               WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                                 AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_')
                   OR EXISTS (SELECT 1 FROM pg_depend d JOIN pg_attrdef ad ON ad.oid = d.objid JOIN pg_class t ON t.oid = ad.adrelid
                               WHERE d.classid = 'pg_attrdef'::regclass AND d.refclassid = 'pg_class'::regclass
                                 AND d.refobjid = c.oid AND left(t.relname, 4) = 'aef_'))
  LOOP
    EXECUTE format('REVOKE ALL ON SEQUENCE %s FROM PUBLIC, anon, authenticated, service_role', s::regclass);
  END LOOP;
END $$;
