-- Migration 022 — IVE-X4B: search_path hardening + profiles self-promotion fix
--
-- PREPARED, NOT APPLIED TO PRODUCTION. This file was written and committed to
-- branch claude/ive-x4-security-boundary-closure for owner review. It has not
-- been run against the production database (nzngvbajrnruknpzzjbf) by this
-- session. Read-only queries against the live schema (pg_proc, pg_policies,
-- pg_constraint, information_schema) were used to derive the exact current
-- function bodies preserved below, so this migration reproduces existing
-- behavior verbatim plus the two additive changes documented in each section.
--
-- ============================================================================
-- PART 1 — SET search_path on SECURITY DEFINER functions flagged by Supabase's
-- own security advisor (function_search_path_mutable). A SECURITY DEFINER
-- function without an explicit search_path is vulnerable, in general, to a
-- search_path-hijacking privilege escalation: a caller could create an object
-- in a schema that resolves earlier in their session's search_path, causing
-- an unqualified reference inside the function to silently resolve to the
-- attacker's object instead of the intended one, while the function still
-- runs with the definer's elevated privileges.
--
-- BEFORE: is_admin_user() and handle_new_user() have no SET search_path.
-- AFTER:  both explicitly pin search_path.
-- WHY EQUIVALENT, NOT MERELY STRICTER: both functions' bodies already
-- reference every object schema-qualified (public.profiles, auth.uid()) --
-- there is no unqualified identifier for a hijacked schema to intercept
-- today. This change closes the *general* vulnerability class as a defense-
-- in-depth measure (Supabase's own linter recommendation) so a *future* edit
-- that introduces an unqualified reference doesn't silently reopen it. It is
-- not, itself, evidence of a live exploit against the current function
-- bodies -- see docs/ive/X4B_FINDINGS.md for the precise claim.
--
-- set_updated_at / update_project_events_updated_at /
-- update_executive_contexts_updated_at are plain SECURITY INVOKER trigger
-- functions (not SECURITY DEFINER) -- the advisor still flags missing
-- search_path as general hygiene, but the risk here is materially lower
-- (no privilege elevation involved). Fixed for completeness/consistency.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_admin_user()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $function$
begin
  insert into public.profiles (id, email)
    values (new.id, new.email)
    on conflict (id) do nothing;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path = 'public'
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_project_events_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path = 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_executive_contexts_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path = 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

-- ============================================================================
-- PART 2 — profiles self-promotion fix (CRITICAL, confirmed exploitable)
--
-- FACT, confirmed by live inspection of pg_policies / pg_constraint /
-- information_schema.column_privileges / pg_trigger on 2026-09-03:
--   - RLS policy "users_own_profile": FOR ALL USING (auth.uid() = id), no
--     WITH CHECK (Postgres reuses USING as the implicit WITH CHECK, so this
--     only constrains *which row* -- it does not constrain *which columns or
--     values* within that row).
--   - profiles.role is a plain `text` column, NOT NULL default 'free', with
--     NO CHECK constraint restricting its values.
--   - No trigger existed on public.profiles before this migration.
--   - Table-level UPDATE is GRANTed to `authenticated` with no column-level
--     restriction.
-- CONCLUSION: any authenticated user could set their own profiles.role to
-- 'admin' via a normal PostgREST UPDATE (e.g.
-- supabase.from('profiles').update({role:'admin'}).eq('id', myUserId)),
-- which then grants them the is_admin_user()/get_current_user_role() bypass
-- on campaign_calendar, campaigns, knowledge_analysis, knowledge_items,
-- knowledge_strategies, calendar_items, content_items, personas, and full
-- read/write on the entire profiles table (including other users' rows) via
-- admin_all_profiles. This was NOT executed against production by this
-- session (see docs/ive/X4B_FINDINGS.md) -- it is a static proof from the
-- live catalog definitions, not a live exploit demonstration.
--
-- CHANGE: a BEFORE UPDATE trigger blocks changes to role, monthly_limit, or
-- is_active unless the acting session is already an admin (is_admin_user())
-- or is the service_role (so dashboard/ops/service-role-driven admin
-- promotion, and any future canonical execution-engine admin tooling, still
-- works). No other column is affected -- full_name/email remain freely
-- editable by the row's own owner, exactly as today.
--
-- ROLLBACK: DROP TRIGGER trg_prevent_self_privilege_escalation ON public.profiles;
--           DROP FUNCTION public.prevent_self_privilege_escalation();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.prevent_self_privilege_escalation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $function$
BEGIN
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

DROP TRIGGER IF EXISTS trg_prevent_self_privilege_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_self_privilege_escalation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_self_privilege_escalation();
