-- IVE-X4R authorization matrix completion (letters B, C, D, F, J, K, L, M,
-- N, O, plus P added in Gate 1E -- not part of the original A-O lettering).
--
-- NOT EXECUTED ANYWHERE BY THIS SESSION. Prepared as part of the CI
-- environment discovery proposal (Authorization Gate 1B) -- companion to
-- x4b_authorization_tests.sql, which already covers A, E, G (partially, on
-- action_queue), I. Letter H is not a distinct test (every test in both
-- files runs as the 'authenticated' Postgres role, which IS "authenticated
-- direct DB path" -- there is no separate path to test). Letter M is a
-- static-enumeration finding (X4R: handle_new_user is the only function in
-- `public` that writes to profiles), re-confirmable locally with the same
-- pg_proc query used in production, not a dynamic SQL test in the usual
-- sense -- included below as a dynamic re-confirmation for completeness.
--
-- Run with: psql "$DB_URL" -f supabase/tests/x4r_authorization_matrix_completion.sql
-- Expect every RAISE NOTICE line to say PASS. Any FAIL aborts the transaction.
-- Requires x4b_authorization_tests.sql's fixtures to exist in the same
-- session/transaction, OR run standalone -- fixtures are re-created here
-- independently so this file also works on its own.
--
-- IVE-X4R-MB2: the TEST-FIDELITY HARNESS that used to live here (Gate 1F,
-- itself superseding a narrower Gate 1C shim) is removed. It existed
-- only because the legacy migration history (archived at
-- docs/legacy-migrations-archive/) did not reproduce production's real
-- profiles authorization shape -- the canonical baseline
-- (supabase/migrations/20260907120000_baseline_production_pre_x4r.sql)
-- now creates users_own_profile / admin_all_profiles /
-- get_current_user_role() natively, and never creates the recursive
-- legacy profiles_admin_select / profiles_admin_update policies at all,
-- so no reconstruction is needed here anymore.

BEGIN;

INSERT INTO auth.users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'x4b-user-a@test.invalid'),
  ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'x4b-user-a@test.invalid', 'free'),
  ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid', 'free')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.act_as(uid uuid) RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- IVE-X4R-T1 ORACLE FIX (applies to B, C, D, K, L, N below): the original
-- pattern asserted PASS/FAIL via
-- `EXCEPTION WHEN insufficient_privilege OR raise_exception`. That is
-- unsound: a plain `RAISE EXCEPTION 'FAIL ...'` with no ERRCODE defaults
-- to SQLSTATE P0001, which IS the `raise_exception` condition name -- so
-- if the dangerous operation had actually succeeded, the test's own FAIL
-- signal would have been caught by the very same handler and misreported
-- as PASS. Confirmed as a real, not merely theoretical, gap while
-- re-verifying these exact letters directly against production during
-- IVE-X4R-MB4 (the MCP query tool used there doesn't even surface RAISE
-- NOTICE output, so the original pattern's result was unobservable
-- there regardless).
--
-- Fixed for every letter below by splitting into two unconditionally
-- sound steps: (1) attempt the dangerous operation inside a block that
-- swallows ANY error via `WHEN OTHERS` -- this step asserts nothing;
-- (2) query the ACTUAL resulting state afterward, unguarded, and raise
-- unambiguously if it shows the dangerous change took effect. Nothing
-- can swallow step 2's RAISE EXCEPTION, because nothing is watching for
-- it.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- B — normal user cannot self-promote to a different privileged value
-- (not just 'admin' -- any value other than their current one).
-- ---------------------------------------------------------------------------
SELECT pg_temp.act_as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET role = 'premium'
      WHERE id = '22222222-2222-2222-2222-222222222222';
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
DO $$
DECLARE actual_role text;
BEGIN
  SELECT role INTO actual_role FROM public.profiles WHERE id = '22222222-2222-2222-2222-222222222222';
  IF actual_role = 'premium' THEN
    RAISE EXCEPTION 'B|FAIL|role changed to premium';
  END IF;
  RAISE NOTICE 'B|PASS|self-promotion to a non-admin privileged role value blocked, role remains %', actual_role;
END $$;

-- ---------------------------------------------------------------------------
-- C — normal user cannot change their own monthly_limit
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET monthly_limit = 999999
      WHERE id = '22222222-2222-2222-2222-222222222222';
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
DO $$
DECLARE actual_limit int;
BEGIN
  SELECT monthly_limit INTO actual_limit FROM public.profiles WHERE id = '22222222-2222-2222-2222-222222222222';
  IF actual_limit = 999999 THEN
    RAISE EXCEPTION 'C|FAIL|monthly_limit changed to 999999';
  END IF;
  RAISE NOTICE 'C|PASS|self-service monthly_limit change blocked, value remains %', actual_limit;
END $$;

-- ---------------------------------------------------------------------------
-- D — normal user cannot change their own is_active
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET is_active = false
      WHERE id = '22222222-2222-2222-2222-222222222222';
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
DO $$
DECLARE actual_active boolean;
BEGIN
  SELECT is_active INTO actual_active FROM public.profiles WHERE id = '22222222-2222-2222-2222-222222222222';
  IF actual_active = false THEN
    RAISE EXCEPTION 'D|FAIL|is_active changed to false';
  END IF;
  RAISE NOTICE 'D|PASS|self-service is_active change blocked, value remains %', actual_active;
END $$;

-- ---------------------------------------------------------------------------
-- F — normal user cannot update another user's profile row at all
-- (RLS-level, independent of the trigger -- proves the row-ownership
-- boundary, not just the column-value boundary the trigger adds).
-- ---------------------------------------------------------------------------
-- SAFE as originally written (no exception-catching involved) --
-- message format updated for consistency only.
DO $$
BEGIN
  UPDATE public.profiles SET full_name = 'hijacked by B'
    WHERE id = '11111111-1111-1111-1111-111111111111';
  IF FOUND THEN
    RAISE EXCEPTION 'F|FAIL|user B updated user A''s profile row';
  END IF;
  RAISE NOTICE 'F|PASS|cross-user profile update affects zero rows (RLS-level block)';
END $$;

-- ---------------------------------------------------------------------------
-- J — service_role can perform a trusted administrative operation
-- ---------------------------------------------------------------------------
SET ROLE service_role;
SELECT set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
-- SAFE as originally written (no exception-catching involved) --
-- message format updated for consistency only.
DO $$
BEGIN
  UPDATE public.profiles SET role = 'admin'
    WHERE id = '11111111-1111-1111-1111-111111111111';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'J|FAIL|service_role could not perform an administrative profiles update';
  END IF;
  RAISE NOTICE 'J|PASS|service_role retains trusted administrative access';
END $$;
RESET ROLE;

-- ---------------------------------------------------------------------------
-- K — a multi-column UPDATE bundling a privileged field with an ordinary
-- one is still denied as a whole (no partial-success/partial-bypass).
-- ---------------------------------------------------------------------------
SELECT pg_temp.act_as('22222222-2222-2222-2222-222222222222');
DO $$
DECLARE name_before text; role_after text; name_after text;
BEGIN
  SELECT full_name INTO name_before FROM public.profiles
    WHERE id = '22222222-2222-2222-2222-222222222222';
  BEGIN
    UPDATE public.profiles
      SET full_name = 'multi-col attempt', role = 'admin'
      WHERE id = '22222222-2222-2222-2222-222222222222';
  EXCEPTION WHEN OTHERS THEN NULL; END;

  -- Sole assertion: query actual resulting state. role must be
  -- unchanged, AND (proving atomicity -- no partial column apply)
  -- full_name must be unchanged too, in the same query.
  SELECT role, full_name INTO role_after, name_after FROM public.profiles
    WHERE id = '22222222-2222-2222-2222-222222222222';
  IF role_after = 'admin' THEN
    RAISE EXCEPTION 'K|FAIL|multi-column update incl. a privileged field succeeded (role=admin)';
  END IF;
  IF name_after IS DISTINCT FROM name_before THEN
    RAISE EXCEPTION 'K|FAIL|full_name was partially applied despite the blocked statement';
  END IF;
  RAISE NOTICE 'K|PASS|multi-column update blocked entirely -- full_name not silently applied either';
END $$;

-- ---------------------------------------------------------------------------
-- L — upsert (INSERT ... ON CONFLICT DO UPDATE) affecting a privileged
-- field is denied the same as a plain UPDATE would be.
--
-- Note on mechanism (corrected during Gate 1C audit): per PostgreSQL's
-- documented trigger-firing order for INSERT ... ON CONFLICT DO UPDATE,
-- the BEFORE INSERT row trigger fires for the proposed row BEFORE the
-- conflict is even detected -- it always fires once, regardless of
-- whether the statement ultimately inserts or falls back to the UPDATE
-- action. So this attempt is actually blocked by the trigger's INSERT
-- branch (NEW.role='admin' vs the safe default), not its UPDATE branch;
-- if a conflict were reached at all, the UPDATE branch would apply a
-- second, independent check. Either branch raises the same ERRCODE
-- 42501, so the test's PASS/FAIL outcome is correct either way -- this
-- note only corrects which mechanism is actually exercised.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id, email, role)
      VALUES ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid', 'admin')
      ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
DO $$
DECLARE actual_role text;
BEGIN
  SELECT role INTO actual_role FROM public.profiles WHERE id = '22222222-2222-2222-2222-222222222222';
  IF actual_role = 'admin' THEN
    RAISE EXCEPTION 'L|FAIL|upsert set role=admin via ON CONFLICT DO UPDATE';
  END IF;
  RAISE NOTICE 'L|PASS|upsert affecting a privileged field blocked, role remains %', actual_role;
END $$;

-- ---------------------------------------------------------------------------
-- M — re-confirm dynamically that no function other than handle_new_user
-- writes to public.profiles (static finding from X4R, re-checked here).
-- ---------------------------------------------------------------------------
RESET ROLE; -- back to a role that can query pg_proc/pg_get_functiondef freely
DO $$
DECLARE writer_count int;
BEGIN
  -- TEST-HARNESS DEFECT FIX (Gate 1F, found dynamically THIS run, reproduced
  -- and isolated read-only against production before fixing): joining
  -- pg_proc to pg_namespace and calling pg_get_functiondef(p.oid) in the
  -- WHERE clause makes PostgreSQL raise a genuine, reproducible
  -- 'ERROR: 42809: "array_agg" is an aggregate function' -- confirmed live
  -- (not an artifact of any tool wrapper) by running the exact query
  -- against production read-only and bisecting it clause by clause: the
  -- JOIN itself is what triggers it; the equivalent join-free
  -- `p.pronamespace = 'public'::regnamespace` form returns the identical
  -- correct result without error. Not a security-relevant finding, purely
  -- a test-query-shape defect.
  SELECT count(*) INTO writer_count
  FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace
    AND p.proname <> 'handle_new_user'
    AND (
      pg_get_functiondef(p.oid) ILIKE '%insert into%profiles%'
      OR pg_get_functiondef(p.oid) ILIKE '%update%profiles%set%'
      OR pg_get_functiondef(p.oid) ILIKE '%delete from%profiles%'
    );
  IF writer_count > 0 THEN
    RAISE EXCEPTION 'M|FAIL|% unexpected function(s) besides handle_new_user write to profiles', writer_count;
  END IF;
  RAISE NOTICE 'M|PASS|handle_new_user remains the only function writing to profiles';
END $$;

-- ---------------------------------------------------------------------------
-- N — normal user cannot INSERT a brand-new own profile row with
-- role='admin' (the exact INSERT-path bypass X4R found and fixed).
-- Delete the fixture row first to simulate "row doesn't exist yet".
-- ---------------------------------------------------------------------------
DELETE FROM public.profiles WHERE id = '22222222-2222-2222-2222-222222222222';
SELECT pg_temp.act_as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id, email, role)
      VALUES ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid', 'admin');
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
-- Sole assertion for letter N (THE critical case -- the exact
-- INSERT-path bypass X4R found and 022 fixes): a row must not exist
-- at all, or if one somehow exists, it must not be role='admin'.
DO $$
DECLARE row_role text; row_found boolean;
BEGIN
  SELECT role INTO row_role FROM public.profiles WHERE id = '22222222-2222-2222-2222-222222222222';
  row_found := FOUND;
  IF row_found AND row_role = 'admin' THEN
    RAISE EXCEPTION 'N|FAIL|user B inserted their own new profile row with role=admin -- THE X4R BUG IS BACK';
  END IF;
  RAISE NOTICE 'N|PASS|INSERT of a new own-profile row with role=admin blocked (row_created=%, role=%)', row_found, row_role;
END $$;

-- ---------------------------------------------------------------------------
-- O — normal user CAN INSERT a brand-new own profile row when it uses the
-- safe column defaults (proves N's fix isn't a blanket INSERT lockout).
-- ---------------------------------------------------------------------------
-- SAFE as originally written (no exception-catching involved) --
-- message format updated for consistency only.
DO $$
BEGIN
  INSERT INTO public.profiles (id, email)
    VALUES ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'O|FAIL|user B could not insert their own profile row with safe defaults';
  END IF;
  RAISE NOTICE 'O|PASS|INSERT of a new own-profile row with safe defaults succeeds';
END $$;

-- ---------------------------------------------------------------------------
-- P (Gate 1E addition, not part of the original A-O lettering) — the real
-- signup cascade (INSERT INTO auth.users -> on_auth_user_created AFTER
-- INSERT trigger -> handle_new_user() SECURITY DEFINER -> INSERT INTO
-- profiles) still completes without error under migration 022's new
-- BEFORE INSERT trigger, and the resulting row has the intended safe
-- defaults (role='free', monthly_limit=5, is_active=true) -- not merely
-- reasoned about in migration 022's own comment, but actually exercised
-- end-to-end here for the first time.
-- ---------------------------------------------------------------------------
RESET ROLE; -- back to postgres -- a real signup is driven by GoTrue, not
            -- by the 'authenticated' role this file has been simulating
DO $$
DECLARE new_role text; new_limit int; new_active boolean;
BEGIN
  INSERT INTO auth.users (id, email)
    VALUES ('66666666-6666-6666-6666-666666666666', 'x4r-signup-cascade@test.invalid');

  SELECT role, monthly_limit, is_active INTO new_role, new_limit, new_active
    FROM public.profiles WHERE id = '66666666-6666-6666-6666-666666666666';

  IF new_role IS NULL THEN
    RAISE EXCEPTION 'P|FAIL|signup cascade did not create a profiles row at all';
  END IF;
  IF new_role IS DISTINCT FROM 'free' OR new_limit IS DISTINCT FROM 5 OR new_active IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'P|FAIL|trigger-created profile has unsafe values (role=%, monthly_limit=%, is_active=%)', new_role, new_limit, new_active;
  END IF;
  RAISE NOTICE 'P|PASS|real signup cascade (auth.users insert -> handle_new_user -> profiles insert) completes and yields safe defaults (role=%, monthly_limit=%, is_active=%)', new_role, new_limit, new_active;
END $$;

ROLLBACK; -- never commit test fixtures, even in a local/ephemeral instance
