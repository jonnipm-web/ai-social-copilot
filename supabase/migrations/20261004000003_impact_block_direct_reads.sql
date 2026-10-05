-- IV-IMPACT-MACRO-08 Fix 1 — block direct authenticated table reads.
--
-- PROBLEM
--   Migration 20260924010000 grants SELECT to `authenticated` on all
--   impact_* tables. PostgreSQL RLS limits reads to owner_id = auth.uid(),
--   but does NOT enforce the Impact module gate. A FREE/PRO user can query
--   their own Impact data directly via the Supabase REST API, bypassing
--   requireModuleAccess in the Edge Function entirely.
--
-- FIX
--   1. Create a SECURITY DEFINER boolean function `impact_has_module_access`
--      that returns TRUE only for users whose role permits Impact access.
--      For EXPERIMENTAL phase: admin-only.
--      For commercial phase: expand to 'pro', 'premium', 'free' as needed.
--   2. Add `AND public.impact_has_module_access()` to every *_select_own
--      RLS policy on Impact tables. Direct reads by non-entitled users now
--      receive empty results (RLS silently filters; not a 403/404 oracle).
--
-- INVARIANTS
--   - RLS is PRESERVED — ownership check is still required.
--   - service_role (Edge Function writes) bypasses RLS intentionally.
--   - User JWT reads in the store also pass through RLS + module check;
--     since the Edge Function already called requireModuleAccess before
--     creating the user-JWT client, this adds defense-in-depth only.
--
-- PRODUCTION PROTECTION
--   NOT APPLIED to production. Requires Agente Martins + Paulo gate.

SET search_path = public, extensions;

-- ─── module access check ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.impact_has_module_access()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_role text;
BEGIN
  -- NULL uid = unauthenticated: never allowed.
  IF auth.uid() IS NULL THEN RETURN false; END IF;

  SELECT COALESCE(role, 'free')
  INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  -- EXPERIMENTAL phase: admin-only.
  -- When Impact is promoted to commercialEnabled=true, extend this to:
  --   RETURN v_role IN ('admin', 'pro', 'premium', 'free');
  -- Gate: Agente Martins + Paulo must authorize that change.
  RETURN v_role IN ('admin');
END;
$$;

REVOKE ALL ON FUNCTION public.impact_has_module_access() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.impact_has_module_access() TO authenticated;

COMMENT ON FUNCTION public.impact_has_module_access() IS
  'IV-IMPACT-MACRO-08 Fix 1: blocks direct authenticated table reads for '
  'non-entitled users. EXPERIMENTAL: admin-only. Extend to pro/premium/free '
  'when commercialEnabled=true (requires AM+Paulo gate).';

-- ─── rebuild RLS policies with module-access guard ────────────────────────────

-- impact_investigations
DROP POLICY IF EXISTS impact_investigations_select_own ON public.impact_investigations;
CREATE POLICY impact_investigations_select_own ON public.impact_investigations
  FOR SELECT TO authenticated
  USING (
    public.impact_has_module_access()
    AND owner_id = auth.uid()
    AND (project_id IS NULL OR EXISTS (
      SELECT 1 FROM public.projects p
      WHERE p.id = impact_investigations.project_id AND p.user_id = auth.uid()
    ))
  );

-- All child tables: sources, claims, evidence, verifications, conflicts,
-- disputes, audit_events + artifacts, evidence_candidates, registry_conflicts
-- — each already has an investigation_id FK.
-- Codex P1: impact_artifacts, impact_evidence_candidates, impact_registry_conflicts
--   were missing the module-access guard in the initial fix.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'impact_sources', 'impact_claims', 'impact_evidence', 'impact_verifications',
    'impact_conflicts', 'impact_disputes', 'impact_audit_events',
    'impact_artifacts', 'impact_evidence_candidates', 'impact_registry_conflicts'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_own', t);
    EXECUTE format($p$
      CREATE POLICY %I ON public.%I FOR SELECT TO authenticated
      USING (
        public.impact_has_module_access()
        AND EXISTS (
          SELECT 1 FROM public.impact_investigations i
          WHERE i.id = %I.investigation_id
            AND i.owner_id = auth.uid()
        )
      )
    $p$, t || '_select_own', t, t);
  END LOOP;
END $$;
