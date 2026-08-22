-- =============================================================================
-- SEC-01: Comprehensive profiles security
-- Supersedes migration 022 (which remains in history but is further hardened here)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Harden is_admin_user() — fix search_path to prevent injection attacks
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_admin_user() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;
GRANT  EXECUTE ON FUNCTION public.is_admin_user() TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Fix profiles_admin policies to use is_admin_user()
--    Original policies used a recursive sub-select on profiles that can trigger
--    "infinite recursion detected in policy for relation profiles".
--    is_admin_user() is SECURITY DEFINER and bypasses RLS — no recursion.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
CREATE POLICY "profiles_admin_select" ON public.profiles
  FOR SELECT USING (public.is_admin_user());

DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
CREATE POLICY "profiles_admin_update" ON public.profiles
  FOR UPDATE
  USING  (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Replace profiles_update_own
--    022 limited WITH CHECK to non-admin role values; this is insufficient
--    because plan/monthly_limit/is_active were still unprotected.
--    Defence now lives in the trigger below — the RLS policy only controls
--    row visibility (which row can be updated: own row only).
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE
  USING  (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Privileged field protection trigger
--    Fires BEFORE UPDATE on every profiles row.
--    Service role (auth.uid() IS NULL) and admin users bypass the check.
--    All other authenticated callers are denied writes to privileged fields
--    regardless of how they arrived (client SDK, direct REST, webhook, etc.)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.protect_privileged_profile_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  -- Null uid = service_role key or non-JWT context (migrations, server functions)
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Read the calling user's current role without RLS (SECURITY DEFINER)
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();

  -- Admin callers may write any field
  IF v_caller_role = 'admin' THEN
    RETURN NEW;
  END IF;

  -- Deny privileged field modifications for all other callers
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'permission denied for column "role" of relation "profiles"'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.monthly_limit IS DISTINCT FROM OLD.monthly_limit THEN
    RAISE EXCEPTION 'permission denied for column "monthly_limit" of relation "profiles"'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
    RAISE EXCEPTION 'permission denied for column "is_active" of relation "profiles"'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_privileged_profile_fields ON public.profiles;
CREATE TRIGGER enforce_privileged_profile_fields
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_privileged_profile_fields();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Usage tracking table for server-side quota enforcement
--    Counters are managed exclusively via the check_and_increment_usage() RPC.
--    No direct INSERT/UPDATE permitted to authenticated users via RLS.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.usage_tracking (
  user_id    UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month      TEXT    NOT NULL,   -- 'YYYY-MM'
  call_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, month)
);

ALTER TABLE public.usage_tracking ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "usage_tracking_select_own" ON public.usage_tracking;
CREATE POLICY "usage_tracking_select_own" ON public.usage_tracking
  FOR SELECT USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Atomic quota check + increment RPC
--    Call this from every Edge Function before invoking Groq.
--    Returns TRUE if the call is allowed (quota not exceeded).
--    Returns FALSE if quota exceeded or user not found.
--    Uses row-level locking to prevent race conditions / double-counting.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_and_increment_usage()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id       UUID;
  v_monthly_limit INTEGER;
  v_current_month TEXT;
  v_current_count INTEGER;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  v_current_month := to_char(now(), 'YYYY-MM');

  -- Lock the profile row to prevent concurrent limit changes during check
  SELECT monthly_limit INTO v_monthly_limit
  FROM public.profiles
  WHERE id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Ensure a tracking row exists for this month
  INSERT INTO public.usage_tracking (user_id, month, call_count, updated_at)
  VALUES (v_user_id, v_current_month, 0, now())
  ON CONFLICT (user_id, month) DO NOTHING;

  -- Lock tracking row and read current count atomically
  SELECT call_count INTO v_current_count
  FROM public.usage_tracking
  WHERE user_id = v_user_id AND month = v_current_month
  FOR UPDATE;

  IF v_current_count >= v_monthly_limit THEN
    RETURN FALSE;
  END IF;

  UPDATE public.usage_tracking
  SET call_count = call_count + 1, updated_at = now()
  WHERE user_id = v_user_id AND month = v_current_month;

  RETURN TRUE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_and_increment_usage() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.check_and_increment_usage() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- CLASSIFICATION of profiles columns (documentation, not enforced by SQL type)
-- USER_WRITABLE:     full_name, email
-- SERVER_CONTROLLED: role, monthly_limit, is_active
-- SYSTEM_MANAGED:    id, created_at, updated_at
-- ─────────────────────────────────────────────────────────────────────────────
