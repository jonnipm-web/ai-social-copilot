-- IVE-COMMERCIAL-EXPERIENCE-12 (Phase B, mission Sections 09-14) —
-- persistent per-project Resource Allocation, replacing the
-- previously-ephemeral client-only simulation on resource_allocation_
-- screen.dart (which stays as-is: a portfolio-wide "how should I split
-- a budget across all my projects" recommendation tool, unrelated to
-- this table — this table stores what the user has actually SAVED as
-- the current committed allocation for ONE specific project).
--
-- NOT APPLIED IN THIS MISSION — per mission Section 14 ("migration file
-- MAY be created after design review. Production migration MUST NOT be
-- applied"). Prepared for Codex read-only pre-migration audit and for
-- Agente Martins' controlled-deploy authorization in a future mission.
--
-- DESIGN DECISIONS (Section 09-11):
--   - ONE ROW PER PROJECT (UNIQUE(project_id)), not a history/version
--     table — mission's own fast-track preference ("current saved state
--     + auditability over a full historical financial-planning
--     subsystem"). `updated_at` gives a minimal "when was this last
--     changed" signal; a full audit trail can reuse the existing
--     diagnostic_events pipeline (already proven for quota/AI events in
--     Phase A) if ever needed, rather than duplicating audit
--     infrastructure here.
--   - Ownership DERIVED THROUGH THE PROJECT (RLS joins to `projects`),
--     not a duplicated `user_id` column — mission Section 09's own
--     preference ("prefer deriving ownership through the project when
--     safe rather than duplicating unnecessary authority"). `projects`
--     already has its own RLS-enforced `user_id`; this table cannot be
--     read/written for a project the caller doesn't own, and there is
--     no separate authority to keep in sync or let drift.
--   - MONEY AS INTEGER MINOR UNITS (`budget_allocated_cents`, bigint),
--     never float — mission Section 10's explicit requirement.
--   - CURRENCY explicit, defaulted to 'BRL' (the only currency this
--     product's UI has ever displayed — see resource_allocation_
--     screen.dart's `R$` labels and market_analysis's revenue
--     formatting) but stored as its own column with a narrow check
--     constraint, not silently assumed nor over-built with FX
--     conversion (mission Section 10: "do not overbuild FX").
--   - HOURS as a plain non-negative integer with a generous but finite
--     upper bound (mission Section 11: "reasonable upper bound... no
--     NaN/infinity/negative allocation" — a CHECK constraint is the
--     database-level backstop; the client also validates before
--     attempting to save).

CREATE TABLE IF NOT EXISTS public.project_resource_allocations (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id              uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  hours_allocated         integer NOT NULL DEFAULT 0
                            CHECK (hours_allocated >= 0 AND hours_allocated <= 100000),
  budget_allocated_cents  bigint NOT NULL DEFAULT 0
                            CHECK (budget_allocated_cents >= 0),
  currency                text NOT NULL DEFAULT 'BRL'
                            CHECK (currency IN ('BRL', 'USD', 'EUR')),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id)
);

CREATE INDEX IF NOT EXISTS idx_project_resource_allocations_project_id
  ON public.project_resource_allocations (project_id);

-- ── RLS — ownership derived through the owning project, not duplicated ──────
ALTER TABLE public.project_resource_allocations ENABLE ROW LEVEL SECURITY;

-- Idempotent re-run safety (CREATE POLICY has no IF NOT EXISTS form —
-- IVE-COMMERCIAL-STABILITY-08 already established this exact pattern).
DROP POLICY IF EXISTS "Users manage own project resource allocations"
  ON public.project_resource_allocations;

CREATE POLICY "Users manage own project resource allocations"
  ON public.project_resource_allocations
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.projects p
      WHERE p.id = project_resource_allocations.project_id
        AND p.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.projects p
      WHERE p.id = project_resource_allocations.project_id
        AND p.user_id = auth.uid()
    )
  );

-- No SECURITY DEFINER function is introduced or required — the RLS
-- policy above is sufficient for read/write/update/delete authorization,
-- and this migration does not grant anything beyond the standard
-- authenticated-role table privileges every other user-owned table in
-- this schema already relies on.

-- ── updated_at maintenance ───────────────────────────────────────────────────
-- Mirrors the plain-trigger pattern already used elsewhere in this schema
-- for `updated_at` columns (no new mechanism introduced).
CREATE OR REPLACE FUNCTION public.set_project_resource_allocations_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_project_resource_allocations_updated_at
  ON public.project_resource_allocations;

CREATE TRIGGER trg_project_resource_allocations_updated_at
  BEFORE UPDATE ON public.project_resource_allocations
  FOR EACH ROW
  EXECUTE FUNCTION public.set_project_resource_allocations_updated_at();

-- DEPLOY NOTE: this migration has no ordering dependency on any
-- application code deploy — the client's upsert (onConflict: 'project_id')
-- requires the UNIQUE(project_id) constraint above to exist first, same
-- deploy-ordering rule already documented in
-- 20260916000000_market_intelligence_current_state.sql. Apply this
-- migration BEFORE deploying application code that writes to this table.
