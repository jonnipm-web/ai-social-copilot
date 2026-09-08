-- Phase 10H: Knowledge → Action Engine
-- Ensure revenue_plans.market_analysis_id is nullable
-- (bootstrap-generated plans have no market analysis)

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'revenue_plans'
      AND column_name  = 'market_analysis_id'
      AND is_nullable  = 'NO'
  ) THEN
    ALTER TABLE revenue_plans ALTER COLUMN market_analysis_id DROP NOT NULL;
  END IF;
END;
$$;

-- Index for faster lookup of bootstrap-generated plans by project name
CREATE INDEX IF NOT EXISTS idx_revenue_plans_project_name
  ON revenue_plans (user_id, project_name)
  WHERE market_analysis_id IS NULL;

-- Index for action_queue by project_id (already exists likely, but ensure)
CREATE INDEX IF NOT EXISTS idx_action_queue_project_id
  ON action_queue (project_id);

-- Index for opportunity_lab by project_id
CREATE INDEX IF NOT EXISTS idx_opportunity_lab_project_id
  ON opportunity_lab (project_id);
