-- INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02 — ROLE ≠ PLAN storage.
--
-- STATUS: Module Lab only. NOT applied to production by this mission.
--
-- Problem: public.profiles.role stores a commercial PLAN (free/pro/premium)
-- and an authorization ROLE (admin/beta_tester) in ONE column. Stripe
-- (apply_stripe_subscription_state) overwrites that column on every
-- subscription change, so a beta tester who pays loses beta eligibility,
-- and an admin who subscribes/cancels has their authorization rewritten by
-- billing. (Codex Gate 1, CX1-02.)
--
-- Fix (additive, non-destructive): roles get their own table. profiles.role
-- is NOT modified, NOT dropped, and keeps being written by Stripe exactly as
-- today — it remains the PLAN source. The server entitlement authority
-- (supabase/functions/_shared/entitlement.ts) computes:
--     plan  = profiles.role if it is free|pro|premium, else 'free'
--     roles = legacy role from profiles.role (admin|beta_tester)
--             ∪ rows of public.subject_roles for this subject
-- The union keeps every existing admin/beta_tester working with no sync
-- trigger. Revoking a role therefore means removing it from BOTH places
-- (documented in MODULE_ARCHITECTURE.md §13).
--
-- Tenancy: subject_type is constrained to 'user' today; the primary key
-- already includes it so organization/workspace subjects can be added by
-- widening the CHECK, without reshaping the table.
--
-- Security:
--   * RLS enabled; the ONLY policy lets an authenticated user SELECT their
--     own rows. No INSERT/UPDATE/DELETE policy exists → clients can never
--     grant themselves a role. Grants are revoked as defense in depth.
--   * Writes happen only through service_role (bypasses RLS) — e.g. an
--     operator granting beta access. No SECURITY DEFINER function is added.
--   * anon has no access at all.
--
-- Rollout (controlled, see MODULE_ARCHITECTURE.md §13):
--   1. apply this migration;  2. verify the backfill counts;
--   3. set ENTITLEMENT_SUBJECT_ROLES=1 on the Edge Functions (the source
--      reads this table only when the flag is on; before that, the legacy
--      single-column source is used and this table is ignored).
-- Rollback: unset ENTITLEMENT_SUBJECT_ROLES (instant, no data change); the
-- table can then be dropped with `DROP TABLE public.subject_roles;` — no
-- other object depends on it.
--
-- Idempotent: safe to re-run.

-- ── preconditions (IV-AEF-PRE-RUNTIME-CLOSURE-01, P05) ─────────────────
-- Fail fast, before creating or altering anything, when an object this
-- migration references is missing or has an incompatible shape: public.profiles(id uuid, role) (backfill source), auth.uid() (RLS policy),
-- the API roles (grants).
DO $$
DECLARE v_missing text[] := ARRAY[]::text[];
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'id' AND data_type = 'uuid') THEN
    v_missing := v_missing || 'public.profiles.id uuid'::text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role') THEN
    v_missing := v_missing || 'public.profiles.role'::text;
  END IF;
  IF to_regprocedure('auth.uid()') IS NULL
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('auth.uid()')) IS DISTINCT FROM 'uuid'::regtype THEN
    v_missing := v_missing || 'auth.uid() returning uuid'::text;
  END IF;
  IF (SELECT count(*) FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')) <> 3 THEN
    v_missing := v_missing || 'roles anon/authenticated/service_role'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'LAB_PRECONDITION (20260923000000_entitlement_subject_roles): missing or incompatible: %', array_to_string(v_missing, ', ')
      USING ERRCODE = 'AE010';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.subject_roles (
  subject_type text        NOT NULL DEFAULT 'user',
  subject_id   uuid        NOT NULL,
  role         text        NOT NULL,
  source       text        NOT NULL,
  granted_by   uuid        NULL,
  granted_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT subject_roles_pkey PRIMARY KEY (subject_type, subject_id, role),
  CONSTRAINT subject_roles_subject_type_check CHECK (subject_type IN ('user')),
  CONSTRAINT subject_roles_role_check CHECK (role IN ('admin', 'beta_tester')),
  CONSTRAINT subject_roles_source_check CHECK (source IN ('legacy_profiles_role', 'operator_grant'))
);

ALTER TABLE public.subject_roles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.subject_roles FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.subject_roles FROM authenticated;
GRANT SELECT ON TABLE public.subject_roles TO authenticated;

DROP POLICY IF EXISTS "subject_roles_select_own" ON public.subject_roles;
CREATE POLICY "subject_roles_select_own" ON public.subject_roles
  FOR SELECT TO authenticated
  USING (subject_type = 'user' AND subject_id = auth.uid());

-- Backfill: every existing admin / beta_tester keeps that role as a ROLE,
-- independent of any future plan change. Plans are not copied anywhere.
INSERT INTO public.subject_roles (subject_type, subject_id, role, source)
SELECT 'user', p.id, p.role, 'legacy_profiles_role'
FROM public.profiles p
WHERE p.role IN ('admin', 'beta_tester')
ON CONFLICT (subject_type, subject_id, role) DO NOTHING;
