-- AEF DB test setup — creates stub tables for Supabase-specific dependencies
-- and applies the AEF migrations in an isolated test database.
-- Run against: aef_test_i7 database.

-- ── auth schema stub ──────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text
);

-- ── public.projects stub ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL
);

-- ── public.impact_investigations stub ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.impact_investigations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  status     text NOT NULL DEFAULT 'ACTIVE'
);

-- ── Supabase helpers used by migrations ──────────────────────────────────────
-- auth.uid() is called in RLS policies; in tests we provide a stub that
-- returns the current session variable 'app.current_user_id'.
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    current_setting('app.current_user_id', true)::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid
  )
$$;

-- ── pg_catalog stub for anon / authenticated roles (Supabase-specific) ────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END;
$$;
