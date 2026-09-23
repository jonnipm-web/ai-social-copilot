-- IVE-INTELLIGENCE-CORE-01 — governed durable memory on public.business_memory.
--
-- STATUS: Module Lab only. NOT applied to production by this mission.
--
-- Why evolve business_memory instead of a new table: it already is the
-- durable, user-owned, optionally project-bound memory store (and the only
-- one the external agent writes). A second table would duplicate it
-- (debt D2 is about the device-local IVE memory, which this mission stops
-- using for anything user-specific).
--
-- Additive changes (no column dropped, no row deleted, no value rewritten
-- except the two derived backfills below):
--   scope          'project' | 'user'     (derived from project_id)
--   origin         'user_authored' | 'ive_derived' | 'system_derived' | 'external_agent_derived'
--   status         'active' | 'superseded' | 'expired'
--   dedup_key      sha-256 of category|scope|project|normalized text (set by the IVE core)
--   superseded_by  the newer memory that replaced this one
--   updated_at, expires_at
--
-- Origin is PROVENANCE, not privilege: memory is always injected into the
-- model as untrusted data and can never grant a capability. 'system_derived'
-- is reserved for service_role writers; authenticated users (and the
-- external agent, which uses the user's JWT) cannot write it.
--
-- RLS (replaces "business_memory_user" FOR ALL USING (auth.uid() = user_id),
-- which had no WITH CHECK on project ownership — IVE-F06):
--   SELECT/DELETE  own rows
--   INSERT/UPDATE  own rows, project_id NULL or a project the caller owns,
--                  origin not 'system_derived'
-- anon: no access.
--
-- Rollback: DROP the four new policies, recreate
--   CREATE POLICY "business_memory_user" ON public.business_memory FOR ALL USING (auth.uid() = user_id);
-- then (optional) DROP the added columns/index/trigger. Legacy readers and the
-- external agent's inserts keep working before and after (new columns have
-- defaults; scope is derived by trigger when omitted).
--
-- Idempotent: safe to re-run.

ALTER TABLE public.business_memory ADD COLUMN IF NOT EXISTS scope         text;
ALTER TABLE public.business_memory ADD COLUMN IF NOT EXISTS origin        text NOT NULL DEFAULT 'user_authored';
ALTER TABLE public.business_memory ADD COLUMN IF NOT EXISTS status        text NOT NULL DEFAULT 'active';
ALTER TABLE public.business_memory ADD COLUMN IF NOT EXISTS dedup_key     text;
ALTER TABLE public.business_memory ADD COLUMN IF NOT EXISTS superseded_by uuid;
ALTER TABLE public.business_memory ADD COLUMN IF NOT EXISTS updated_at    timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.business_memory ADD COLUMN IF NOT EXISTS expires_at    timestamptz;

-- Derived backfills (deterministic, re-runnable).
UPDATE public.business_memory SET scope = CASE WHEN project_id IS NULL THEN 'user' ELSE 'project' END
WHERE scope IS NULL;
UPDATE public.business_memory SET origin = 'external_agent_derived'
WHERE source = 'ive_strategic_execution_agent' AND origin = 'user_authored';

-- scope follows project_id when a writer omits it (legacy writers).
CREATE OR REPLACE FUNCTION public.business_memory_derive_scope()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.scope IS NULL THEN
    NEW.scope := CASE WHEN NEW.project_id IS NULL THEN 'user' ELSE 'project' END;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_business_memory_derive_scope ON public.business_memory;
CREATE TRIGGER trg_business_memory_derive_scope
  BEFORE INSERT OR UPDATE ON public.business_memory
  FOR EACH ROW EXECUTE FUNCTION public.business_memory_derive_scope();

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_scope_check') THEN
    ALTER TABLE public.business_memory ADD CONSTRAINT business_memory_scope_check
      CHECK (scope IN ('project', 'user')
             AND ((scope = 'project') = (project_id IS NOT NULL)));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_origin_check') THEN
    ALTER TABLE public.business_memory ADD CONSTRAINT business_memory_origin_check
      CHECK (origin IN ('user_authored', 'ive_derived', 'system_derived', 'external_agent_derived'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_status_check') THEN
    ALTER TABLE public.business_memory ADD CONSTRAINT business_memory_status_check
      CHECK (status IN ('active', 'superseded', 'expired'));
  END IF;
  -- Size cap for NEW rows only (NOT VALID): legacy rows are left untouched.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_memory_content_len_check') THEN
    ALTER TABLE public.business_memory ADD CONSTRAINT business_memory_content_len_check
      CHECK (char_length(content) <= 2000) NOT VALID;
  END IF;
END $$;

-- One ACTIVE memory per dedup key per user: duplicates are refused by the
-- database even if a writer skips the core's dedup step.
CREATE UNIQUE INDEX IF NOT EXISTS uq_business_memory_active_dedup
  ON public.business_memory (user_id, dedup_key)
  WHERE status = 'active' AND dedup_key IS NOT NULL;

ALTER TABLE public.business_memory ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.business_memory FROM anon;

DROP POLICY IF EXISTS "business_memory_user"          ON public.business_memory;
DROP POLICY IF EXISTS "business_memory_select_own"    ON public.business_memory;
DROP POLICY IF EXISTS "business_memory_insert_own"    ON public.business_memory;
DROP POLICY IF EXISTS "business_memory_update_own"    ON public.business_memory;
DROP POLICY IF EXISTS "business_memory_delete_own"    ON public.business_memory;

CREATE POLICY "business_memory_select_own" ON public.business_memory
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "business_memory_insert_own" ON public.business_memory
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND origin <> 'system_derived'
    AND (project_id IS NULL
         OR EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_id AND p.user_id = auth.uid()))
  );

CREATE POLICY "business_memory_update_own" ON public.business_memory
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND origin <> 'system_derived'
    AND (project_id IS NULL
         OR EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_id AND p.user_id = auth.uid()))
  );

CREATE POLICY "business_memory_delete_own" ON public.business_memory
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);
