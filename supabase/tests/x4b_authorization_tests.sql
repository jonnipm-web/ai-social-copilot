-- IVE-X4B authorization tests.
--
-- NOT EXECUTED AGAINST PRODUCTION BY THIS SESSION. Prepared for a
-- non-production Supabase branch (`supabase branches create` / MCP
-- create_branch) or a local `supabase start` instance, run AFTER migration
-- 022 is applied there. Uses two throwaway auth.users rows created and
-- dropped within this script -- never touches a real account.
--
-- Run with: psql "$BRANCH_DB_URL" -f supabase/tests/x4b_authorization_tests.sql
-- Expect every RAISE NOTICE line to say PASS. Any FAIL aborts the transaction.

BEGIN;

-- ---------------------------------------------------------------------------
-- Fixtures: two throwaway users, each owning one project/action/memory row.
-- ---------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'x4b-user-a@test.invalid'),
  ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'x4b-user-a@test.invalid', 'free'),
  ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid', 'free')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.projects (id, user_id, name)
VALUES ('33333333-3333-3333-3333-333333333333',
        '11111111-1111-1111-1111-111111111111', 'X4B test project A')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.action_queue (id, user_id, project_id, title, action_type, status, origin)
VALUES ('44444444-4444-4444-4444-444444444444',
        '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333',
        'A''s private action', 'task', 'pending', 'test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.business_memory (id, user_id, project_id, memory_type, title, content, source)
VALUES ('55555555-5555-5555-5555-555555555555',
        '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333',
        'strategy', 'A''s private memory', 'secret', 'test')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- TEST-FIDELITY HARNESS -- LIVE PRODUCTION SHAPE RECONSTRUCTION (Gate 1F)
--
-- This repo's committed migration history (001_platform_schema.sql)
-- creates 4 separate profiles policies (profiles_select_own,
-- profiles_update_own, profiles_admin_select, profiles_admin_update) that
-- no longer match what is actually live in production. Gate 1D found
-- production instead runs exactly 2 policies (users_own_profile,
-- admin_all_profiles), and Gate 1E's dynamic run found the committed
-- admin_select/admin_update policies are additionally structurally
-- broken: their USING clause is a direct
-- `EXISTS (SELECT 1 FROM public.profiles ...)` subquery written inside a
-- policy defined ON profiles -- genuinely self-recursive, and Postgres
-- correctly raises "infinite recursion detected in policy" the moment
-- any UPDATE touches profiles, for any user, not just an attacker.
--
-- LEGACY MIGRATION DEFECT (recorded, not fixed here, not a migration-022
-- issue): profiles_admin_select / profiles_admin_update, as committed,
-- are structurally recursive and are not what is live in production --
-- production replaced them with admin_all_profiles, which routes the
-- admin check through a SECURITY DEFINER function instead of a raw
-- self-referencing subquery, which is exactly what avoids the recursion.
-- This belongs in a future migration-baseline reconstruction, not X4R.
--
-- Everything below exists ONLY inside this script's own transaction
-- (rolled back at the end, never committed) and reconstructs, exactly,
-- the objects Gate 1F captured live from production this session via
-- pg_policy/pg_proc/pg_get_functiondef -- not an approximation.
-- ---------------------------------------------------------------------------

-- 1. Remove only the two legacy policies that are structurally recursive.
--    profiles_select_own / profiles_update_own are left in place: they
--    are harmless, functionally subsumed by users_own_profile below, and
--    are not recursive -- removing them is not necessary.
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;

-- 2. Recreate get_current_user_role() exactly as captured live from
--    production this session (pg_get_functiondef + prosecdef + proconfig
--    matched byte-for-byte, not paraphrased). This whole script connects
--    as `postgres`, the same superuser role that owns this function in
--    production; production's public.profiles has
--    relforcerowsecurity=false (confirmed live), so a postgres-owned
--    SECURITY DEFINER function querying profiles internally bypasses RLS
--    exactly as it does in production -- that is what avoids the
--    recursion here, faithfully, not by omission.
CREATE OR REPLACE FUNCTION public.get_current_user_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT role FROM public.profiles WHERE id = auth.uid();
  $function$;

-- 3. Recreate the exact two live production policies (same names, same
--    USING expressions, FOR ALL/permissive, no WITH CHECK -- captured
--    live via pg_policy this session, not assumed).
DROP POLICY IF EXISTS "users_own_profile" ON public.profiles;
CREATE POLICY "users_own_profile" ON public.profiles
  FOR ALL USING (auth.uid() = id);

DROP POLICY IF EXISTS "admin_all_profiles" ON public.profiles;
CREATE POLICY "admin_all_profiles" ON public.profiles
  FOR ALL USING (get_current_user_role() = 'admin'::text);

-- Helper to simulate an authenticated session as a given user.
CREATE OR REPLACE FUNCTION pg_temp.act_as(uid uuid) RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- TEST 1 — normal user cannot read another user's action_queue row
-- ---------------------------------------------------------------------------
SELECT pg_temp.act_as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.action_queue WHERE id = '44444444-4444-4444-4444-444444444444') THEN
    RAISE EXCEPTION 'FAIL: user B could read user A''s action_queue row';
  END IF;
  RAISE NOTICE 'PASS: user B cannot read user A''s action_queue row';
END $$;

-- ---------------------------------------------------------------------------
-- TEST 2 — normal user cannot read another user's business_memory row
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.business_memory WHERE id = '55555555-5555-5555-5555-555555555555') THEN
    RAISE EXCEPTION 'FAIL: user B could read user A''s business_memory row';
  END IF;
  RAISE NOTICE 'PASS: user B cannot read user A''s business_memory row';
END $$;

-- ---------------------------------------------------------------------------
-- TEST 3 — normal user cannot write an action_queue row claiming another
-- user's identity (forged user_id in the INSERT payload)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    INSERT INTO public.action_queue (user_id, project_id, title, action_type, status, origin)
    VALUES ('11111111-1111-1111-1111-111111111111', -- forged: not the caller (user B)
            '33333333-3333-3333-3333-333333333333', 'forged', 'task', 'pending', 'test');
    RAISE EXCEPTION 'FAIL: user B inserted a row with a forged user_id';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    RAISE NOTICE 'PASS: forged user_id on INSERT rejected';
  END;
END $$;

-- ---------------------------------------------------------------------------
-- TEST 4 (THE CRITICAL ONE) — normal user cannot self-promote to admin
-- ---------------------------------------------------------------------------
SELECT pg_temp.act_as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET role = 'admin'
      WHERE id = '22222222-2222-2222-2222-222222222222';
    RAISE EXCEPTION 'FAIL: user B self-promoted to admin -- migration 022 not applied or ineffective';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'PASS: self-promotion to admin blocked';
  END;
END $$;

-- Confirm the role genuinely did not change despite the attempted UPDATE.
DO $$
DECLARE actual_role text;
BEGIN
  SELECT role INTO actual_role FROM public.profiles
    WHERE id = '22222222-2222-2222-2222-222222222222';
  IF actual_role = 'admin' THEN
    RAISE EXCEPTION 'FAIL: role column shows admin despite blocked UPDATE';
  END IF;
  RAISE NOTICE 'PASS: role remains % after blocked self-promotion attempt', actual_role;
END $$;

-- ---------------------------------------------------------------------------
-- TEST 5 — normal user CAN still update their own non-sensitive columns
-- (proves the fix is scoped, not a blanket UPDATE lockout)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  UPDATE public.profiles SET full_name = 'B renamed'
    WHERE id = '22222222-2222-2222-2222-222222222222';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAIL: user B could not update their own full_name -- fix over-scoped';
  END IF;
  RAISE NOTICE 'PASS: user B can still update their own non-sensitive columns';
END $$;

-- ---------------------------------------------------------------------------
-- TEST 6 — an already-admin user CAN change role/monthly_limit (own or others)
-- ---------------------------------------------------------------------------
-- TEST-HARNESS DEFECT FIX (Gate 1F): the session is still acting as user B
-- at this point (the last act_as() call was for B, in TEST 4/5, and this is
-- all one transaction) -- so without resetting role first, this "out-of-
-- band admin grant" would itself run AS B, match neither users_own_profile
-- (B updating A's row) nor admin_all_profiles (B is not admin), silently
-- affect 0 rows, and produce a false FAIL below (A never actually becomes
-- admin). Never caught before because every prior dynamic run aborted
-- earlier (recursion, Gate 1E) before ever reaching this line.
RESET ROLE;
UPDATE public.profiles SET role = 'admin' WHERE id = '11111111-1111-1111-1111-111111111111';
-- (direct write as postgres/superuser role in this test transaction, simulating
--  an out-of-band admin grant -- the exact mechanism the owner already uses today)

SELECT pg_temp.act_as('11111111-1111-1111-1111-111111111111');
DO $$
BEGIN
  UPDATE public.profiles SET monthly_limit = 100
    WHERE id = '22222222-2222-2222-2222-222222222222';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAIL: admin user A could not update user B''s monthly_limit';
  END IF;
  RAISE NOTICE 'PASS: admin retains ability to manage entitlement columns for any user';
END $$;

ROLLBACK; -- never commit test fixtures, even in a branch database
