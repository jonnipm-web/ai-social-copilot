-- F-03 adversarial fixture (NOT a migration): a "future" AEF migration that
-- creates new AEF sequences and FORGETS the deny-by-default REVOKE block.
-- Under production-equivalent default privileges both sequences are exposed.
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
