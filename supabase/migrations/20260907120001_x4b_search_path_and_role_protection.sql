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
-- information_schema.column_privileges / pg_trigger on 2026-09-03,
-- CORRECTED in X4R (see note below):
--   - RLS policy "users_own_profile": FOR ALL USING (auth.uid() = id), no
--     WITH CHECK (Postgres reuses USING as the implicit WITH CHECK, so this
--     only constrains *which row* -- it does not constrain *which columns or
--     values* within that row).
--   - profiles.role IS constrained to a fixed set of values by
--     profiles_role_check: CHECK (role = ANY (ARRAY['free','pro','premium',
--     'beta_tester','admin'])), defined since migration 001. 'admin' is one
--     of the explicitly allowed values, so this constraint does not prevent
--     the self-promotion -- it only means arbitrary garbage strings were
--     never possible, which was never the actual gap.
--   - No trigger existed on public.profiles before this migration.
--   - Table-level UPDATE is GRANTed to `authenticated` with no column-level
--     restriction.
--
-- X4R CORRECTION: the X4 report (docs/ive/X4B_FINDINGS.md, written in the
-- session that produced this migration) stated profiles.role had "NO CHECK
-- constraint restricting its values." That was a factual error in this
-- session's own prior investigation, not a change to production between X4
-- and X4R -- the constraint has existed since migration 001, confirmed by
-- grepping the local migration files, which this session's X4 pass evidently
-- failed to catch. Flagged here rather than silently corrected, because the
-- error was in a security report and deserves an explicit trail. It does not
-- change the core conclusion: 'admin' remains a constraint-legal value, so
-- the self-promotion path was, and without this migration still is, real.
--
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
-- CHANGE: a BEFORE INSERT OR UPDATE trigger blocks setting/changing role,
-- monthly_limit, or is_active unless the acting session is already an admin
-- (is_admin_user()) or is the service_role (so dashboard/ops/service-role-
-- driven admin promotion, and any future canonical execution-engine admin
-- tooling, still works). No other column is affected -- full_name/email
-- remain freely editable by the row's own owner, exactly as today.
--
-- IVE-X4R correction: the version of this migration shipped in X4 (branch
-- claude/ive-x4-security-boundary-closure, commit 52d9884) covered UPDATE
-- only. Independent adversarial re-review in X4R found a real, if narrow,
-- INSERT-path bypass: RLS's users_own_profile policy is FOR ALL with no
-- explicit WITH CHECK, so its implicit fallback (auth.uid() = id) is ALSO
-- what gates INSERT -- meaning any authenticated user whose profiles row
-- does not yet exist could INSERT one directly with role='admin', bypassing
-- an UPDATE-only trigger entirely. In the normal flow handle_new_user()
-- (BEFORE this migration's trigger fires, and confirmed the only other
-- function anywhere in `public` that writes to profiles) auto-creates the
-- row with default values immediately on signup, but this session found no
-- proof that window can never be raced, and chose not to assume it can't be.
-- Fixed by extending the same trigger to BEFORE INSERT OR UPDATE and
-- branching on TG_OP (INSERT has no OLD row, so the check compares against
-- the column's own known-safe defaults instead). handle_new_user()'s own
-- insert is unaffected: it never sets role/monthly_limit/is_active itself,
-- so those columns take their defaults on that insert, which trivially
-- match the "safe" comparison below regardless of what auth.role() resolves
-- to during that trigger cascade -- this was deliberately designed not to
-- depend on knowing Supabase Auth's exact internal role context for that
-- cascade, which this session could not verify empirically.
--
-- ROLLBACK: DROP TRIGGER trg_prevent_self_privilege_escalation ON public.profiles;
--           DROP FUNCTION public.prevent_self_privilege_escalation();
-- ============================================================================

-- Deliberately SECURITY INVOKER, not DEFINER: this function needs no
-- elevated privilege of its own -- is_admin_user() already self-elevates
-- for the one check that needs to read another user's row, and reading
-- NEW/OLD inside a row trigger is not subject to a separate RLS check.
-- Making it SECURITY DEFINER anyway would be exactly the unnecessary-
-- privilege anti-pattern Supabase's own advisor flags elsewhere in this
-- schema (anon_security_definer_function_executable /
-- authenticated_security_definer_function_executable) -- least privilege,
-- not "SECURITY DEFINER by habit."
CREATE OR REPLACE FUNCTION public.prevent_self_privilege_escalation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path = 'public'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- No OLD row exists yet -- compare against the column defaults
    -- ('free' / 5 / true) instead. handle_new_user()'s own insert never
    -- sets these columns, so it always matches and is never blocked here.
    IF (NEW.role IS DISTINCT FROM 'free'
        OR NEW.monthly_limit IS DISTINCT FROM 5
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

DROP TRIGGER IF EXISTS trg_prevent_self_privilege_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_self_privilege_escalation
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_self_privilege_escalation();
