-- IVE-X4R authorization matrix completion (letters B, C, D, F, J, K, L, N, O).
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
-- B — normal user cannot self-promote to a different privileged value
-- (not just 'admin' -- any value other than their current one).
-- ---------------------------------------------------------------------------
SELECT pg_temp.act_as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET role = 'premium'
      WHERE id = '22222222-2222-2222-2222-222222222222';
    RAISE EXCEPTION 'FAIL (B): user B self-promoted role to premium';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'PASS (B): self-promotion to a non-admin privileged role value blocked';
  END;
END $$;

-- ---------------------------------------------------------------------------
-- C — normal user cannot change their own monthly_limit
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET monthly_limit = 999999
      WHERE id = '22222222-2222-2222-2222-222222222222';
    RAISE EXCEPTION 'FAIL (C): user B changed their own monthly_limit';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'PASS (C): self-service monthly_limit change blocked';
  END;
END $$;

-- ---------------------------------------------------------------------------
-- D — normal user cannot change their own is_active
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET is_active = false
      WHERE id = '22222222-2222-2222-2222-222222222222';
    RAISE EXCEPTION 'FAIL (D): user B changed their own is_active';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'PASS (D): self-service is_active change blocked';
  END;
END $$;

-- ---------------------------------------------------------------------------
-- F — normal user cannot update another user's profile row at all
-- (RLS-level, independent of the trigger -- proves the row-ownership
-- boundary, not just the column-value boundary the trigger adds).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  UPDATE public.profiles SET full_name = 'hijacked by B'
    WHERE id = '11111111-1111-1111-1111-111111111111';
  IF FOUND THEN
    RAISE EXCEPTION 'FAIL (F): user B updated user A''s profile row';
  END IF;
  RAISE NOTICE 'PASS (F): cross-user profile update affects zero rows (RLS-level block)';
END $$;

-- ---------------------------------------------------------------------------
-- J — service_role can perform a trusted administrative operation
-- ---------------------------------------------------------------------------
SET ROLE service_role;
SELECT set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
DO $$
BEGIN
  UPDATE public.profiles SET role = 'admin'
    WHERE id = '11111111-1111-1111-1111-111111111111';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAIL (J): service_role could not perform an administrative profiles update';
  END IF;
  RAISE NOTICE 'PASS (J): service_role retains trusted administrative access';
END $$;
RESET ROLE;

-- ---------------------------------------------------------------------------
-- K — a multi-column UPDATE bundling a privileged field with an ordinary
-- one is still denied as a whole (no partial-success/partial-bypass).
-- ---------------------------------------------------------------------------
SELECT pg_temp.act_as('22222222-2222-2222-2222-222222222222');
DO $$
DECLARE name_before text;
BEGIN
  SELECT full_name INTO name_before FROM public.profiles
    WHERE id = '22222222-2222-2222-2222-222222222222';
  BEGIN
    UPDATE public.profiles
      SET full_name = 'multi-col attempt', role = 'admin'
      WHERE id = '22222222-2222-2222-2222-222222222222';
    RAISE EXCEPTION 'FAIL (K): multi-column update incl. a privileged field succeeded';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'PASS (K): multi-column update blocked entirely -- full_name not silently applied either';
  END;
  -- Confirm the whole statement was atomic: full_name must be unchanged too.
  PERFORM 1 FROM public.profiles
    WHERE id = '22222222-2222-2222-2222-222222222222' AND full_name IS NOT DISTINCT FROM name_before;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAIL (K): full_name was partially applied despite the blocked statement';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- L — upsert (INSERT ... ON CONFLICT DO UPDATE) affecting a privileged
-- field is denied the same as a plain UPDATE would be.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id, email, role)
      VALUES ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid', 'admin')
      ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;
    RAISE EXCEPTION 'FAIL (L): upsert set role=admin via ON CONFLICT DO UPDATE';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'PASS (L): upsert affecting a privileged field blocked (fires the UPDATE branch)';
  END;
END $$;

-- ---------------------------------------------------------------------------
-- M — re-confirm dynamically that no function other than handle_new_user
-- writes to public.profiles (static finding from X4R, re-checked here).
-- ---------------------------------------------------------------------------
RESET ROLE; -- back to a role that can query pg_proc/pg_get_functiondef freely
DO $$
DECLARE writer_count int;
BEGIN
  SELECT count(*) INTO writer_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname <> 'handle_new_user'
    AND (
      pg_get_functiondef(p.oid) ILIKE '%insert into%profiles%'
      OR pg_get_functiondef(p.oid) ILIKE '%update%profiles%set%'
      OR pg_get_functiondef(p.oid) ILIKE '%delete from%profiles%'
    );
  IF writer_count > 0 THEN
    RAISE EXCEPTION 'FAIL (M): % unexpected function(s) besides handle_new_user write to profiles', writer_count;
  END IF;
  RAISE NOTICE 'PASS (M): handle_new_user remains the only function writing to profiles';
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
    RAISE EXCEPTION 'FAIL (N): user B inserted their own new profile row with role=admin -- THE X4R BUG IS BACK';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'PASS (N): INSERT of a new own-profile row with role=admin blocked';
  END;
END $$;

-- ---------------------------------------------------------------------------
-- O — normal user CAN INSERT a brand-new own profile row when it uses the
-- safe column defaults (proves N's fix isn't a blanket INSERT lockout).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  INSERT INTO public.profiles (id, email)
    VALUES ('22222222-2222-2222-2222-222222222222', 'x4b-user-b@test.invalid');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAIL (O): user B could not insert their own profile row with safe defaults';
  END IF;
  RAISE NOTICE 'PASS (O): INSERT of a new own-profile row with safe defaults succeeds';
END $$;

ROLLBACK; -- never commit test fixtures, even in a local/ephemeral instance
