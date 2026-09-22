-- INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02 — OWNER ACTION
-- READ-ONLY production preflight. Aggregates only: no row ids, no emails,
-- no content leave the database. Safe to run in the Supabase SQL editor.
--
-- Answers two questions:
--  (1) MPA-F06 — migration 20260919000000_project_ownership_boundary_closure
--      is ALREADY APPLIED in production (list_migrations: 20260915194037).
--      Its WITH CHECK makes any pre-existing row whose project belongs to a
--      different user readable/deletable but NOT updatable. cross_user_project
--      > 0 on market_analyses / opportunity_lab = rows that are stuck today.
--      The other tables are reported for future enforcement (orphans, null
--      owners, cross-user links would block the same pattern there).
--  (2) Entitlement migration 20260923000000_entitlement_subject_roles —
--      how many rows the backfill will create (admin + beta_tester), and
--      whether any profiles.role value falls outside the five the
--      entitlement authority understands (would be denied: ENTITLEMENT_UNAVAILABLE).
--
-- Expected for a clean state: cross_user_project = 0 everywhere,
-- null_owner = 0, profiles.role only in {free, pro, premium, beta_tester, admin}.
BEGIN TRANSACTION READ ONLY;

SELECT t AS table_name, total, null_owner, orphan_project, cross_user_project FROM (
  SELECT 'market_analyses' t, count(*) total, count(*) FILTER (WHERE r.user_id IS NULL) null_owner,
    count(*) FILTER (WHERE r.project_id IS NOT NULL AND p.id IS NULL) orphan_project,
    count(*) FILTER (WHERE p.id IS NOT NULL AND p.user_id IS DISTINCT FROM r.user_id) cross_user_project
  FROM public.market_analyses r LEFT JOIN public.projects p ON p.id = r.project_id
  UNION ALL
  SELECT 'opportunity_lab', count(*), count(*) FILTER (WHERE r.user_id IS NULL),
    count(*) FILTER (WHERE r.project_id IS NOT NULL AND p.id IS NULL),
    count(*) FILTER (WHERE p.id IS NOT NULL AND p.user_id IS DISTINCT FROM r.user_id)
  FROM public.opportunity_lab r LEFT JOIN public.projects p ON p.id = r.project_id
  UNION ALL
  SELECT 'action_queue', count(*), count(*) FILTER (WHERE r.user_id IS NULL),
    count(*) FILTER (WHERE r.project_id IS NOT NULL AND p.id IS NULL),
    count(*) FILTER (WHERE p.id IS NOT NULL AND p.user_id IS DISTINCT FROM r.user_id)
  FROM public.action_queue r LEFT JOIN public.projects p ON p.id = r.project_id
  UNION ALL
  SELECT 'knowledge_items', count(*), count(*) FILTER (WHERE r.user_id IS NULL),
    count(*) FILTER (WHERE r.project_id IS NOT NULL AND p.id IS NULL),
    count(*) FILTER (WHERE p.id IS NOT NULL AND p.user_id IS DISTINCT FROM r.user_id)
  FROM public.knowledge_items r LEFT JOIN public.projects p ON p.id = r.project_id
  UNION ALL
  SELECT 'business_memory', count(*), count(*) FILTER (WHERE r.user_id IS NULL),
    count(*) FILTER (WHERE r.project_id IS NOT NULL AND p.id IS NULL),
    count(*) FILTER (WHERE p.id IS NOT NULL AND p.user_id IS DISTINCT FROM r.user_id)
  FROM public.business_memory r LEFT JOIN public.projects p ON p.id = r.project_id
  UNION ALL
  SELECT 'projects', count(*), count(*) FILTER (WHERE user_id IS NULL), 0, 0 FROM public.projects
) s ORDER BY 1;

SELECT coalesce(role, '<null>') AS profiles_role, count(*) AS profiles
FROM public.profiles GROUP BY role ORDER BY 1;

SELECT count(*) FILTER (WHERE role IN ('admin', 'beta_tester')) AS subject_roles_backfill_rows,
       count(*) FILTER (WHERE role IS NULL OR role NOT IN ('free','pro','premium','beta_tester','admin')) AS unmappable_roles
FROM public.profiles;

ROLLBACK;
