-- SEC-00A P0 FIX: profiles_update_own missing WITH CHECK
--
-- Without WITH CHECK, any authenticated user could self-promote to admin by
-- writing role='admin' directly via the Supabase client. Adding WITH CHECK
-- restricts what values can be written by users updating their own row:
-- only the non-privileged roles (free, pro, premium, beta_tester) are allowed.
-- The 'admin' role can only be assigned by an existing admin via
-- profiles_admin_update policy.

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role IN ('free', 'pro', 'premium', 'beta_tester')
  );
