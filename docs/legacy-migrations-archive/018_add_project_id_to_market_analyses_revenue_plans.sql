-- Adiciona project_id em market_analyses (relação direta, elimina matching por substring)
ALTER TABLE market_analyses
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS market_analyses_project_id_idx
  ON market_analyses(project_id);

-- Back-fill a partir da direção inversa (projects.market_analysis_id → analysis.id)
UPDATE market_analyses ma
SET project_id = p.id
FROM projects p
WHERE p.market_analysis_id = ma.id
  AND ma.project_id IS NULL;

-- Adiciona project_id em revenue_plans (elimina matching por project_name string)
ALTER TABLE revenue_plans
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS revenue_plans_project_id_idx
  ON revenue_plans(project_id);

-- Back-fill revenue_plans a partir de market_analyses.project_id
UPDATE revenue_plans rp
SET project_id = ma.project_id
FROM market_analyses ma
WHERE rp.market_analysis_id = ma.id
  AND ma.project_id IS NOT NULL
  AND rp.project_id IS NULL;
