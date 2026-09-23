-- IVE-INTELLIGENCE-CORE-01 — RLS / constraint tests for governed memory
-- (public.business_memory after migration 20260924000000). DISPOSABLE
-- database only. Every check RAISEs on failure; a clean run ends with
-- 'IVE_MEMORY_RLS: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

INSERT INTO auth.users (id, email) VALUES
  ('a1000000-0000-0000-0000-00000000000a', 'mem-a@test.invalid'),
  ('b1000000-0000-0000-0000-00000000000b', 'mem-b@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.profiles (id, email, role) VALUES
  ('a1000000-0000-0000-0000-00000000000a', 'mem-a@test.invalid', 'free'),
  ('b1000000-0000-0000-0000-00000000000b', 'mem-b@test.invalid', 'free')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.projects (id, user_id, name) VALUES
  ('a2000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-00000000000a', 'A project 1'),
  ('a2000000-0000-0000-0000-0000000000a2', 'a1000000-0000-0000-0000-00000000000a', 'A project 2'),
  ('b2000000-0000-0000-0000-0000000000b1', 'b1000000-0000-0000-0000-00000000000b', 'B project')
ON CONFLICT (id) DO NOTHING;
DELETE FROM public.business_memory WHERE user_id IN ('a1000000-0000-0000-0000-00000000000a', 'b1000000-0000-0000-0000-00000000000b');

-- B owns one project memory (inserted as owner, before RLS checks).
INSERT INTO public.business_memory (id, user_id, project_id, memory_type, title, content, source)
VALUES ('b3000000-0000-0000-0000-0000000000b1', 'b1000000-0000-0000-0000-00000000000b',
        'b2000000-0000-0000-0000-0000000000b1', 'goal', 'B goal', 'B secret strategy for project B', 'test');

CREATE OR REPLACE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', uid, false);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', false);
END $$;

-- ── T01 legacy writer shape (external agent: no scope/origin) still works,
--        scope is derived, origin defaults, status active ─────────────────
SELECT pg_temp.act_as('a1000000-0000-0000-0000-00000000000a');
SET ROLE authenticated;
INSERT INTO public.business_memory (user_id, project_id, memory_type, title, content, source)
VALUES ('a1000000-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-0000000000a1', 'goal', 't', 'A goal for project one here', 'ive_strategic_execution_agent');
DO $$ BEGIN
  IF (SELECT scope FROM public.business_memory WHERE content = 'A goal for project one here') <> 'project'
     OR (SELECT status FROM public.business_memory WHERE content = 'A goal for project one here') <> 'active' THEN
    RAISE EXCEPTION 'T01 legacy insert not normalized';
  END IF;
END $$;

-- ── T02 cannot attach memory to ANOTHER user's project (IVE-F06) ────────
DO $$ BEGIN
  BEGIN
    INSERT INTO public.business_memory (user_id, project_id, memory_type, title, content, source)
    VALUES ('a1000000-0000-0000-0000-00000000000a', 'b2000000-0000-0000-0000-0000000000b1', 'goal', 't', 'pollute B project', 'x');
    RAISE EXCEPTION 'T02 cross-project insert succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- ── T03 cannot write as another user ────────────────────────────────────
DO $$ BEGIN
  BEGIN
    INSERT INTO public.business_memory (user_id, project_id, memory_type, title, content, source)
    VALUES ('b1000000-0000-0000-0000-00000000000b', NULL, 'goal', 't', 'impersonation attempt', 'x');
    RAISE EXCEPTION 'T03 cross-user insert succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- ── T04 cannot claim the service-only origin ────────────────────────────
DO $$ BEGIN
  BEGIN
    INSERT INTO public.business_memory (user_id, memory_type, title, content, source, origin)
    VALUES ('a1000000-0000-0000-0000-00000000000a', 'goal', 't', 'forged system memory', 'x', 'system_derived');
    RAISE EXCEPTION 'T04 system_derived accepted from authenticated';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- ── T05 non-owner sees nothing of B; updates/deletes of B affect 0 rows ─
DO $$
DECLARE n int;
BEGIN
  IF EXISTS (SELECT 1 FROM public.business_memory WHERE user_id = 'b1000000-0000-0000-0000-00000000000b') THEN
    RAISE EXCEPTION 'T05a cross-user read';
  END IF;
  UPDATE public.business_memory SET content = 'hijack' WHERE id = 'b3000000-0000-0000-0000-0000000000b1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'T05b cross-user update'; END IF;
  DELETE FROM public.business_memory WHERE id = 'b3000000-0000-0000-0000-0000000000b1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'T05c cross-user delete'; END IF;
END $$;

-- ── T06 cannot re-point an own memory to someone else's project ─────────
DO $$ BEGIN
  BEGIN
    UPDATE public.business_memory SET project_id = 'b2000000-0000-0000-0000-0000000000b1'
    WHERE content = 'A goal for project one here';
    RAISE EXCEPTION 'T06 re-point to foreign project succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- ── T07 own project → own other project is allowed (scope stays project)
UPDATE public.business_memory SET project_id = 'a2000000-0000-0000-0000-0000000000a2'
WHERE content = 'A goal for project one here';

-- ── T08 scope must match project_id ─────────────────────────────────────
DO $$ BEGIN
  BEGIN
    INSERT INTO public.business_memory (user_id, project_id, scope, memory_type, title, content, source)
    VALUES ('a1000000-0000-0000-0000-00000000000a', NULL, 'project', 'goal', 't', 'project scope without project', 'x');
    RAISE EXCEPTION 'T08 inconsistent scope accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- ── T09 one ACTIVE row per dedup key; superseded rows do not collide ────
INSERT INTO public.business_memory (user_id, memory_type, title, content, source, origin, dedup_key)
VALUES ('a1000000-0000-0000-0000-00000000000a', 'preference', 't', 'Prefers weekly summaries', 'ive_intelligence_core', 'ive_derived', 'k1');
DO $$ BEGIN
  BEGIN
    INSERT INTO public.business_memory (user_id, memory_type, title, content, source, origin, dedup_key)
    VALUES ('a1000000-0000-0000-0000-00000000000a', 'preference', 't', 'Prefers weekly summaries', 'ive_intelligence_core', 'ive_derived', 'k1');
    RAISE EXCEPTION 'T09a duplicate active memory accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
UPDATE public.business_memory SET status = 'superseded' WHERE dedup_key = 'k1';
INSERT INTO public.business_memory (user_id, memory_type, title, content, source, origin, dedup_key)
VALUES ('a1000000-0000-0000-0000-00000000000a', 'preference', 't', 'Prefers weekly summaries', 'ive_intelligence_core', 'ive_derived', 'k1');

-- ── T09b legacy writer moves a memory project → none → project without
--         mentioning scope: scope follows (Codex Final IF-01) ──────────────
INSERT INTO public.business_memory (id, user_id, project_id, memory_type, title, content, source)
VALUES ('a3000000-0000-0000-0000-0000000000a9', 'a1000000-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-0000000000a1', 'goal', 't', 'moving memory', 'legacy');
UPDATE public.business_memory SET project_id = NULL WHERE id = 'a3000000-0000-0000-0000-0000000000a9';
DO $$ BEGIN
  IF (SELECT scope FROM public.business_memory WHERE id = 'a3000000-0000-0000-0000-0000000000a9') <> 'user' THEN
    RAISE EXCEPTION 'T09b scope not re-derived when project_id was cleared';
  END IF;
END $$;
UPDATE public.business_memory SET project_id = 'a2000000-0000-0000-0000-0000000000a2' WHERE id = 'a3000000-0000-0000-0000-0000000000a9';
DO $$ BEGIN
  IF (SELECT scope FROM public.business_memory WHERE id = 'a3000000-0000-0000-0000-0000000000a9') <> 'project' THEN
    RAISE EXCEPTION 'T09b scope not re-derived when project_id was set';
  END IF;
END $$;

-- ── T09c a NEW external-agent row gets truthful provenance (IF-02) ──────
INSERT INTO public.business_memory (id, user_id, memory_type, title, content, source)
VALUES ('a3000000-0000-0000-0000-0000000000aa', 'a1000000-0000-0000-0000-00000000000a', 'decision', 't', 'agent wrote this', 'ive_strategic_execution_agent');
DO $$ BEGIN
  IF (SELECT origin FROM public.business_memory WHERE id = 'a3000000-0000-0000-0000-0000000000aa') <> 'external_agent_derived' THEN
    RAISE EXCEPTION 'T09c future agent row mislabeled';
  END IF;
END $$;

-- ── T10 oversized NEW content rejected ──────────────────────────────────
DO $$ BEGIN
  BEGIN
    INSERT INTO public.business_memory (user_id, memory_type, title, content, source)
    VALUES ('a1000000-0000-0000-0000-00000000000a', 'goal', 't', repeat('x', 2001), 'x');
    RAISE EXCEPTION 'T10 oversized memory accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;

-- ── T11 anonymous: no access ────────────────────────────────────────────
SET ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM 1 FROM public.business_memory;
    RAISE EXCEPTION 'T11 anon can read business_memory';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- ── T12 service_role may write system_derived (reserved writer) ─────────
SET ROLE service_role;
INSERT INTO public.business_memory (user_id, memory_type, title, content, source, origin)
VALUES ('a1000000-0000-0000-0000-00000000000a', 'context_summary', 't', 'system summary row', 'system', 'system_derived');
RESET ROLE;

-- ── T13 B still sees exactly its own untouched row ──────────────────────
SELECT pg_temp.act_as('b1000000-0000-0000-0000-00000000000b');
SET ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.business_memory) <> 1
     OR (SELECT content FROM public.business_memory LIMIT 1) <> 'B secret strategy for project B' THEN
    RAISE EXCEPTION 'T13 owner view wrong or tampered';
  END IF;
END $$;
RESET ROLE;

SELECT 'IVE_MEMORY_RLS: PASS';
