-- INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02 — RLS / privilege tests
-- for public.subject_roles (migration 20260923000000). Runs against a
-- DISPOSABLE database that has every migration applied (never production).
-- Every check RAISEs on failure; a clean run ends with 'SUBJECT_ROLES_RLS: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

-- ── fixtures (as the migration owner) ─────────────────────────────────
INSERT INTO auth.users (id, email) VALUES
  ('a0000000-0000-0000-0000-00000000000a', 'admin@test.invalid'),
  ('b0000000-0000-0000-0000-00000000000b', 'beta@test.invalid'),
  ('c0000000-0000-0000-0000-00000000000c', 'free@test.invalid'),
  ('d0000000-0000-0000-0000-00000000000d', 'pro@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.profiles (id, email, role) VALUES
  ('a0000000-0000-0000-0000-00000000000a', 'admin@test.invalid', 'admin'),
  ('b0000000-0000-0000-0000-00000000000b', 'beta@test.invalid', 'beta_tester'),
  ('c0000000-0000-0000-0000-00000000000c', 'free@test.invalid', 'free'),
  ('d0000000-0000-0000-0000-00000000000d', 'pro@test.invalid', 'pro')
ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

-- Re-apply the migration's backfill statement (idempotency is tested by the
-- runner re-running the whole migration file before this script).
INSERT INTO public.subject_roles (subject_type, subject_id, role, source)
SELECT 'user', p.id, p.role, 'legacy_profiles_role' FROM public.profiles p
WHERE p.role IN ('admin', 'beta_tester')
ON CONFLICT (subject_type, subject_id, role) DO NOTHING;

DO $$ BEGIN
  IF (SELECT count(*) FROM public.subject_roles) <> 2 THEN
    RAISE EXCEPTION 'T01 backfill: expected exactly admin+beta rows, got %', (SELECT count(*) FROM public.subject_roles);
  END IF;
  IF EXISTS (SELECT 1 FROM public.subject_roles WHERE role NOT IN ('admin','beta_tester')) THEN
    RAISE EXCEPTION 'T02 backfill copied a plan value into roles';
  END IF;
END $$;

-- helper: act as an authenticated end user
CREATE OR REPLACE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', uid, false);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', false);
END $$;

-- ── T03 non-owner (free user) sees nothing ─────────────────────────────
SELECT pg_temp.act_as('c0000000-0000-0000-0000-00000000000c');
SET ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.subject_roles) <> 0 THEN RAISE EXCEPTION 'T03 non-owner can read other subjects roles'; END IF;
END $$;

-- ── T04 self-grant is impossible (insert / update / delete) ────────────
DO $$ BEGIN
  BEGIN
    INSERT INTO public.subject_roles (subject_type, subject_id, role, source)
    VALUES ('user', 'c0000000-0000-0000-0000-00000000000c', 'admin', 'operator_grant');
    RAISE EXCEPTION 'T04a self-grant INSERT succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.subject_roles SET subject_id = 'c0000000-0000-0000-0000-00000000000c';
    RAISE EXCEPTION 'T04b UPDATE was permitted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    DELETE FROM public.subject_roles;
    RAISE EXCEPTION 'T04c DELETE was permitted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- ── T05 legacy protection still holds: a user cannot promote profiles.role
DO $$ BEGIN
  BEGIN
    UPDATE public.profiles SET role = 'admin' WHERE id = 'c0000000-0000-0000-0000-00000000000c';
    IF (SELECT role FROM public.profiles WHERE id = 'c0000000-0000-0000-0000-00000000000c') = 'admin' THEN
      RAISE EXCEPTION 'T05 self-promotion via profiles.role succeeded';
    END IF;
  EXCEPTION WHEN others THEN
    IF SQLERRM LIKE 'T05%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ── T06 owner reads exactly their own role rows ────────────────────────
SELECT pg_temp.act_as('a0000000-0000-0000-0000-00000000000a');
SET ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.subject_roles) <> 1
     OR (SELECT role FROM public.subject_roles LIMIT 1) <> 'admin' THEN
    RAISE EXCEPTION 'T06 owner does not see exactly own admin row';
  END IF;
END $$;
RESET ROLE;

-- ── T07 anonymous has no access at all ─────────────────────────────────
SET ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM 1 FROM public.subject_roles;
    RAISE EXCEPTION 'T07 anon can read subject_roles';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- ── T08 operator grant through service_role works; CHECKs hold ─────────
SET ROLE service_role;
INSERT INTO public.subject_roles (subject_type, subject_id, role, source)
VALUES ('user', 'd0000000-0000-0000-0000-00000000000d', 'beta_tester', 'operator_grant');
DO $$ BEGIN
  BEGIN
    INSERT INTO public.subject_roles (subject_type, subject_id, role, source)
    VALUES ('user', 'd0000000-0000-0000-0000-00000000000d', 'superuser', 'operator_grant');
    RAISE EXCEPTION 'T08a unknown role accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    INSERT INTO public.subject_roles (subject_type, subject_id, role, source)
    VALUES ('organization', 'd0000000-0000-0000-0000-00000000000d', 'admin', 'operator_grant');
    RAISE EXCEPTION 'T08b non-user subject accepted before tenancy exists';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;

-- ── T09 billing rewrites the PLAN, the ROLE survives (CX1-02) ──────────
UPDATE public.profiles SET role = 'pro' WHERE id = 'b0000000-0000-0000-0000-00000000000b';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.subject_roles
                 WHERE subject_id = 'b0000000-0000-0000-0000-00000000000b' AND role = 'beta_tester') THEN
    RAISE EXCEPTION 'T09 beta role lost when the plan changed';
  END IF;
END $$;

-- ── T10 the paying beta tester reads plan + role as themselves ─────────
SELECT pg_temp.act_as('b0000000-0000-0000-0000-00000000000b');
SET ROLE authenticated;
DO $$ BEGIN
  IF (SELECT role FROM public.profiles WHERE id = auth.uid()) <> 'pro' THEN RAISE EXCEPTION 'T10a plan not readable by owner'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.subject_roles WHERE role = 'beta_tester') THEN RAISE EXCEPTION 'T10b role not readable by owner'; END IF;
END $$;
RESET ROLE;

SELECT 'SUBJECT_ROLES_RLS: PASS';
