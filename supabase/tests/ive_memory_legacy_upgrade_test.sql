-- IVE-INTELLIGENCE-CORE-01 — legacy-data upgrade test for migration
-- 20260924000000_ive_memory_governance (Codex Gate 1 IG1-04).
--
-- Run by scripts/ci/run_disposable_db_tests.sh in TWO phases on a separate
-- disposable database:
--   phase 'seed'   : after every migration EXCEPT 20260924000000 — inserts
--                    legacy rows exactly as today's writers can (duplicates,
--                    oversized content, external-agent rows, user-level rows)
--   phase 'verify' : after 20260924000000 was applied on top of that data
-- Ends with 'IVE_MEMORY_UPGRADE: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

\if :{?phase}
\else
  \set phase verify
\endif

SELECT :'phase' = 'seed' AS is_seed \gset
\if :is_seed
INSERT INTO auth.users (id, email) VALUES ('c1000000-0000-0000-0000-00000000000c', 'legacy@test.invalid') ON CONFLICT DO NOTHING;
INSERT INTO public.profiles (id, email, role) VALUES ('c1000000-0000-0000-0000-00000000000c', 'legacy@test.invalid', 'free') ON CONFLICT DO NOTHING;
INSERT INTO public.projects (id, user_id, name) VALUES ('c2000000-0000-0000-0000-0000000000c1', 'c1000000-0000-0000-0000-00000000000c', 'Legacy project') ON CONFLICT DO NOTHING;
-- exact duplicates (same user, project, type, content)
INSERT INTO public.business_memory (user_id, project_id, memory_type, title, content, source)
SELECT 'c1000000-0000-0000-0000-00000000000c', 'c2000000-0000-0000-0000-0000000000c1', 'goal', 'dup', 'Same legacy memory text', 'legacy'
FROM generate_series(1, 3);
-- oversized legacy content (> 2000 chars)
INSERT INTO public.business_memory (user_id, project_id, memory_type, title, content, source)
VALUES ('c1000000-0000-0000-0000-00000000000c', NULL, 'context_summary', 'big', repeat('y', 5000), 'legacy');
-- external agent rows
INSERT INTO public.business_memory (user_id, project_id, memory_type, title, content, source)
VALUES ('c1000000-0000-0000-0000-00000000000c', 'c2000000-0000-0000-0000-0000000000c1', 'decision', 'agent', 'Agent decided X', 'ive_strategic_execution_agent');
SELECT 'IVE_MEMORY_UPGRADE: SEEDED';
\else
DO $$
BEGIN
  IF (SELECT count(*) FROM public.business_memory WHERE user_id = 'c1000000-0000-0000-0000-00000000000c') <> 5 THEN
    RAISE EXCEPTION 'U01 legacy rows were lost or duplicated by the migration';
  END IF;
  IF EXISTS (SELECT 1 FROM public.business_memory WHERE user_id = 'c1000000-0000-0000-0000-00000000000c' AND dedup_key IS NOT NULL) THEN
    RAISE EXCEPTION 'U02 legacy rows must keep dedup_key NULL (unique index is partial on NOT NULL)';
  END IF;
  IF (SELECT count(*) FROM public.business_memory WHERE user_id = 'c1000000-0000-0000-0000-00000000000c' AND content = 'Same legacy memory text' AND status = 'active') <> 3 THEN
    RAISE EXCEPTION 'U03 duplicate legacy rows must survive untouched and active';
  END IF;
  IF (SELECT char_length(content) FROM public.business_memory WHERE title = 'big' AND user_id = 'c1000000-0000-0000-0000-00000000000c') <> 5000 THEN
    RAISE EXCEPTION 'U04 oversized legacy content must be preserved (NOT VALID constraint)';
  END IF;
  IF (SELECT origin FROM public.business_memory WHERE source = 'ive_strategic_execution_agent' AND user_id = 'c1000000-0000-0000-0000-00000000000c') <> 'external_agent_derived' THEN
    RAISE EXCEPTION 'U05 external agent rows must be backfilled as external_agent_derived';
  END IF;
  IF EXISTS (SELECT 1 FROM public.business_memory WHERE user_id = 'c1000000-0000-0000-0000-00000000000c'
             AND ((project_id IS NULL AND scope <> 'user') OR (project_id IS NOT NULL AND scope <> 'project'))) THEN
    RAISE EXCEPTION 'U06 scope backfill inconsistent';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'uq_business_memory_active_dedup') THEN
    RAISE EXCEPTION 'U07 unique dedup index missing after upgrade';
  END IF;
END $$;
SELECT 'IVE_MEMORY_UPGRADE: PASS';
\endif
