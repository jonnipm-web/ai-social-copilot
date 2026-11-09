-- strategy-builder is INTERNAL in module_policy.ts (Owner decision: Strategy
-- Builder = HOLD/POST_V1, admin-only until a separate production-gate
-- decision). The original predicate (20261002000000) still admitted every
-- plan, so the DB was wider than the server: SB-48 drift. This aligns the DB
-- with the server, mirroring quant-watchlists' INTERNAL predicate (QB-16).
-- Promoting the module again needs a NEW migration that re-admits the plans,
-- and SB-48 must be updated with it.
CREATE OR REPLACE FUNCTION public.strategy_builder_access_allowed()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = public, pg_temp AS $$
DECLARE
  uid uuid := auth.uid();
  allowed boolean := false;
BEGIN
  IF uid IS NULL THEN
    RETURN false;
  END IF;
  SELECT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = uid AND p.role = 'admin') INTO allowed;
  IF NOT allowed AND to_regclass('public.subject_roles') IS NOT NULL THEN
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.subject_roles r WHERE r.subject_type = ''user'' AND r.subject_id = $1 AND r.role = ''admin'')'
      INTO allowed USING uid;
  END IF;
  RETURN coalesce(allowed, false);
END $$;
-- ── end predicate
