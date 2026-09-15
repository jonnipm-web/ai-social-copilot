-- IVE-COMMERCIAL-EXPERIENCE-14S — Project Ownership Security Closure
--
-- Root cause (found by Codex Gate P0 during mission 14, escalated as an
-- ARCHITECTURAL DECISION REQUIRED since fixing it needs this migration,
-- which mission 14 — implementation-only, no production changes — could
-- not make):
--
--   public.market_analyses and public.opportunity_lab each carry a
--   nullable project_id referencing public.projects, but their RLS
--   policies only ever validated the row's OWN user_id — never that the
--   referenced project actually belongs to that same user. An
--   authenticated user could INSERT (or UPDATE) a row they own
--   (user_id = auth.uid(), satisfying the existing check) while pointing
--   project_id at a project owned by a DIFFERENT user, associating their
--   own content with someone else's project. Reproduced against a real,
--   disposable Postgres instance before writing this migration (see
--   mission 14S report, Section "THREAT MODEL PROOF").
--
-- Fix strategy (mission 14S Section 06/09 — smallest correct strategy,
-- no new SECURITY DEFINER function):
--   Each affected table carries exactly ONE existing permissive policy
--   (`FOR ALL USING (auth.uid() = user_id)`, no WITH CHECK — Postgres
--   defaults WITH CHECK to the USING expression when omitted). There is
--   no second permissive policy on either table, so there is no
--   OR-bypass risk from a broader sibling policy (verified against every
--   migration file, not just the baseline). REPLACE each policy,
--   splitting it explicitly:
--     - USING stays `auth.uid() = user_id` — read/delete visibility is
--       UNCHANGED, no regression to existing SELECT/DELETE behavior.
--     - WITH CHECK gains an additional project-ownership predicate,
--       applied only to INSERT and UPDATE (the only commands WITH CHECK
--       governs) — this is exactly where a forged/changed project_id
--       must be rejected.
--   A plain EXISTS subquery against public.projects is used directly in
--   the policy expression — no new SECURITY DEFINER function/trigger,
--   per mission Section 09's stated preference. No recursion risk:
--   public.projects' own RLS policy (`auth.uid() = user_id`) does not
--   reference market_analyses, opportunity_lab, or itself in any way
--   (verified against every migration file) — this is a one-way,
--   acyclic reference from market_analyses/opportunity_lab -> projects,
--   nothing like the historical recursive profiles-policy failure.
--
-- Non-destructive: no rows are modified or deleted; NULL project_id
-- continues to be accepted unconditionally (existing product semantics
-- preserved); no schema/column changes; no broad grant changes.
--
-- PRE-DEPLOY PREREQUISITE (READ-ONLY, run manually against production
-- BEFORE applying this migration — mission 14S Section 10): because
-- WITH CHECK re-validates the ENTIRE resulting row on every UPDATE (not
-- just the changed columns), any pre-existing row where
-- row.user_id <> (the referenced project's user_id) would become
-- un-updatable (any field) until its project_id is corrected or cleared,
-- even though it remains fully readable/deletable. Run this query first;
-- if it returns any rows, that is a deployment prerequisite to resolve
-- (correct or null out project_id on those rows) before applying this
-- migration, not something this migration does on your behalf:
--
--   SELECT 'market_analyses' AS table_name, id, user_id, project_id
--   FROM public.market_analyses
--   WHERE project_id IS NOT NULL
--     AND NOT EXISTS (
--       SELECT 1 FROM public.projects p
--       WHERE p.id = market_analyses.project_id
--         AND p.user_id = market_analyses.user_id
--     )
--   UNION ALL
--   SELECT 'opportunity_lab' AS table_name, id, user_id, project_id
--   FROM public.opportunity_lab
--   WHERE project_id IS NOT NULL
--     AND NOT EXISTS (
--       SELECT 1 FROM public.projects p
--       WHERE p.id = opportunity_lab.project_id
--         AND p.user_id = opportunity_lab.user_id
--     );

-- ── market_analyses ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users manage own market_analyses" ON public.market_analyses;

CREATE POLICY "Users manage own market_analyses" ON public.market_analyses
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND (
      project_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = project_id AND p.user_id = auth.uid()
      )
    )
  );

-- ── opportunity_lab ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "opportunity_lab_user" ON public.opportunity_lab;

CREATE POLICY "opportunity_lab_user" ON public.opportunity_lab
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND (
      project_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = project_id AND p.user_id = auth.uid()
      )
    )
  );
