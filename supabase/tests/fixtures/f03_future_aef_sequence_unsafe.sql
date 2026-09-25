-- F-03 adversarial fixture (NOT a migration): a "future" AEF migration that
-- creates new AEF sequences and FORGETS the deny-by-default REVOKE block.
-- Under production-equivalent default privileges both sequences are exposed.
CREATE TABLE IF NOT EXISTS public.aef_future_items (
  id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  note text
);
CREATE SEQUENCE IF NOT EXISTS public.future_counter OWNED BY public.aef_future_items.note;
