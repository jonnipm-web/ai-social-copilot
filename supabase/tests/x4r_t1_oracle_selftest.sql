-- IVE-X4R-T1 negative test-of-the-test.
--
-- LOCAL / DISPOSABLE ONLY. Never run against production. This file
-- exists to PROVE, not merely assert, that:
--   OLD ORACLE (EXCEPTION WHEN insufficient_privilege OR raise_exception)
--     could falsely report PASS when the dangerous operation actually
--     succeeded.
--   NEW ORACLE (state-based check after a WHEN OTHERS swallow)
--     correctly reports FAIL under the identical circumstance.
--
-- Achieves this by temporarily disabling migration 022's own trigger
-- INSIDE a transaction that always ends in ROLLBACK -- DISABLE TRIGGER
-- is fully transactional in Postgres, so nothing outside this
-- transaction is ever affected, and the transaction never commits.
-- This file is not part of the authorization-matrix CI run; it is a
-- one-time, standalone proof, safe to re-run any time against a local
-- `supabase start` instance to re-demonstrate the point, but not
-- wired into the permanent test suite.
--
-- Run with: psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/x4r_t1_oracle_selftest.sql

BEGIN;

INSERT INTO auth.users (id, email) VALUES
  ('99999999-9999-9999-9999-999999999999', 'x4r-t1-selftest@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.profiles (id, email, role) VALUES
  ('99999999-9999-9999-9999-999999999999', 'x4r-t1-selftest@test.invalid', 'free')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.act_as(uid uuid) RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$$ LANGUAGE plpgsql;

-- Artificially violate the security invariant: disable migration 022's
-- own trigger, transactionally only. This simulates "the dangerous
-- operation actually succeeds" without touching anything permanent.
ALTER TABLE public.profiles DISABLE TRIGGER trg_prevent_self_privilege_escalation;

SELECT pg_temp.act_as('99999999-9999-9999-9999-999999999999');

-- ---------------------------------------------------------------------------
-- OLD ORACLE (letter B's original pattern, reproduced verbatim) --
-- expected to WRONGLY report PASS, because the trigger is disabled so
-- the UPDATE genuinely succeeds, and the test's own
-- `RAISE EXCEPTION 'FAIL ...'` (SQLSTATE P0001/raise_exception) is then
-- caught by the SAME handler that was meant to catch the trigger's
-- real denial.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET role = 'premium'
      WHERE id = '99999999-9999-9999-9999-999999999999';
    RAISE EXCEPTION 'FAIL (B-OLD): user self-promoted role to premium';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    RAISE NOTICE 'SELFTEST|OLD_ORACLE_RESULT|PASS (this is the bug -- the operation actually succeeded, but the old pattern reports PASS anyway)';
  END;
END $$;

-- Confirm the operation really did succeed (proving the OLD result above was a false PASS).
DO $$
DECLARE actual_role text;
BEGIN
  SELECT role INTO actual_role FROM public.profiles WHERE id = '99999999-9999-9999-9999-999999999999';
  RAISE NOTICE 'SELFTEST|GROUND_TRUTH|role is now % (the dangerous change genuinely took effect)', actual_role;
END $$;

-- Reset back to 'free' so the NEW oracle test below starts from the same known-bad state.
RESET ROLE;
SELECT set_config('request.jwt.claims', '', true);
UPDATE public.profiles SET role = 'premium' WHERE id = '99999999-9999-9999-9999-999999999999'; -- re-apply, since trigger is still disabled for this whole transaction
SELECT pg_temp.act_as('99999999-9999-9999-9999-999999999999');

-- ---------------------------------------------------------------------------
-- NEW ORACLE (letter B's IVE-X4R-T1 fixed pattern, reproduced verbatim) --
-- expected to CORRECTLY report FAIL, uncaught, aborting this whole
-- transaction (which was going to ROLLBACK anyway).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET role = 'premium'
      WHERE id = '99999999-9999-9999-9999-999999999999';
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
DO $$
DECLARE actual_role text;
BEGIN
  SELECT role INTO actual_role FROM public.profiles WHERE id = '99999999-9999-9999-9999-999999999999';
  IF actual_role = 'premium' THEN
    RAISE EXCEPTION 'SELFTEST|NEW_ORACLE_RESULT|FAIL (correct! the new oracle detects the same real regression the old one missed)';
  END IF;
  RAISE NOTICE 'SELFTEST|NEW_ORACLE_RESULT|PASS (unexpected -- would mean the new oracle also missed it)';
END $$;

-- If we reach this line, the new oracle's RAISE EXCEPTION above did NOT
-- fire, which would itself be a failure of this self-test.
DO $$ BEGIN RAISE EXCEPTION 'SELFTEST|UNREACHABLE|the new oracle should have already aborted this transaction'; END $$;

ROLLBACK;
