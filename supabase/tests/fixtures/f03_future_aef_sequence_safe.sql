-- F-03 fixture (NOT a migration): the same future migration WITH the canonical
-- deny-by-default block (as in 20260925 / 20260927).
CREATE TABLE IF NOT EXISTS public.aef_future_items (
  id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  note text
);
CREATE SEQUENCE IF NOT EXISTS public.future_counter OWNED BY public.aef_future_items.note;
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
