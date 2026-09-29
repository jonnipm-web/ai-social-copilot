-- COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-03) — Owner decision: FREE tier
-- monthly AI-analysis quota raised from 5 to 15/month, so a FREE user can
-- complete a meaningful value journey (at least one full project analysis)
-- before hitting the upgrade wall. PRO (300) and admin (99999) are
-- untouched by this migration.
--
-- Two places encode the FREE default as a literal, both updated together:
--   1. public.profiles.monthly_limit's column DEFAULT (used by
--      handle_new_user(), which inserts only (id, email) and relies on
--      column defaults for role/monthly_limit/is_active — see
--      20260907120000_baseline_production_pre_x4r.sql).
--   2. prevent_self_privilege_escalation()'s INSERT branch (added in
--      20260907120001_x4b_search_path_and_role_protection.sql), which
--      compares NEW.monthly_limit against the literal 5 as the "known-safe
--      default" a non-admin/non-service-role INSERT must match. Leaving
--      this at 5 after changing the column default would make EVERY new
--      signup fail this trigger (handle_new_user()'s insert would carry
--      the new default of 15, which no longer matches the hardcoded 5),
--      turning this into a fail-closed outage for all new signups instead
--      of a quota bump. Both must change atomically.
-- Existing FREE users are backfilled explicitly below (existing accounts
-- must not depend on creating a new one to receive the new limit) --
-- scoped to role = 'free' AND monthly_limit = 5 only, so it never touches
-- pro/premium/beta_tester/admin rows or any FREE row a human deliberately
-- set to a different, non-default limit.
--
-- LAB until rehearsed — see migration_manifest.tsv.

ALTER TABLE public.profiles ALTER COLUMN monthly_limit SET DEFAULT 15;

UPDATE public.profiles
SET monthly_limit = 15
WHERE role = 'free' AND monthly_limit = 5;

CREATE OR REPLACE FUNCTION public.prevent_self_privilege_escalation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path = 'public'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- No OLD row exists yet -- compare against the column defaults
    -- ('free' / 15 / true) instead. handle_new_user()'s own insert never
    -- sets these columns, so it always matches and is never blocked here.
    IF (NEW.role IS DISTINCT FROM 'free'
        OR NEW.monthly_limit IS DISTINCT FROM 15
        OR NEW.is_active IS DISTINCT FROM true)
       AND auth.role() <> 'service_role'
       AND NOT public.is_admin_user()
    THEN
      RAISE EXCEPTION 'not authorized to set role, monthly_limit, or is_active on insert'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- TG_OP = 'UPDATE'
  IF (NEW.role IS DISTINCT FROM OLD.role
      OR NEW.monthly_limit IS DISTINCT FROM OLD.monthly_limit
      OR NEW.is_active IS DISTINCT FROM OLD.is_active)
     AND auth.role() <> 'service_role'
     AND NOT public.is_admin_user()
  THEN
    RAISE EXCEPTION 'not authorized to change role, monthly_limit, or is_active on profiles'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;
