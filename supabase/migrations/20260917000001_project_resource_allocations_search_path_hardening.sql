-- IVE-COMMERCIAL-EXPERIENCE-12D — post-apply security-advisor finding.
--
-- Applying 20260917000000_project_resource_allocations.sql to production
-- surfaced a new Supabase linter WARN ("function_search_path_mutable")
-- on set_project_resource_allocations_updated_at: it had no pinned
-- search_path. The function is NOT SECURITY DEFINER and its body only
-- references NEW/OLD and the built-in now(), so there is no privilege-
-- escalation exposure — but every other function in this schema already
-- pins search_path (see x4b_search_path_and_role_protection, and
-- is_admin_user's own proconfig = {search_path=public}), so this closes
-- the gap consistently rather than leaving one new function as the only
-- unpinned one.
--
-- Applied directly to production as part of mission 12D's controlled
-- deploy (immediately after the base migration, same session).

ALTER FUNCTION public.set_project_resource_allocations_updated_at()
  SET search_path = public;
