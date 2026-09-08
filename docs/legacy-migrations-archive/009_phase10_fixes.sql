-- ============================================================
-- 009_phase10_fixes.sql
-- Ativar feature flags para admin e garantir integridade das tabelas
-- ============================================================

-- ── Ativar todos os módulos do Business OS para todos os usuários ──
-- (ajuste plan_required conforme necessário no futuro)
INSERT INTO feature_flags (feature_name, enabled, plan_required) VALUES
  ('business_memory_enabled', true, 'free'),
  ('ecosystem_view_enabled',  true, 'free'),
  ('advisor_enabled',         true, 'free'),
  ('opportunity_lab_enabled', true, 'free'),
  ('action_engine_enabled',   true, 'free'),
  ('copilot_enabled',         true, 'free')
ON CONFLICT (feature_name) DO UPDATE
  SET enabled      = EXCLUDED.enabled,
      plan_required = EXCLUDED.plan_required;

-- ── Garantir que knowledge_items tenha as colunas da migração 008 ──
ALTER TABLE public.knowledge_items
  ADD COLUMN IF NOT EXISTS opportunity_score INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS auto_title        TEXT,
  ADD COLUMN IF NOT EXISTS auto_type         TEXT,
  ADD COLUMN IF NOT EXISTS auto_niche        TEXT,
  ADD COLUMN IF NOT EXISTS auto_audience     TEXT;

-- ── Garantir que knowledge_analysis tenha as colunas da migração 008 ──
ALTER TABLE public.knowledge_analysis
  ADD COLUMN IF NOT EXISTS score_opportunity  INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_hotmart      INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_shopify      INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hotmart_data       JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS shopify_data       JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS persona_training   JSONB DEFAULT '{}';

-- ── Garantir índices nas tabelas Phase 10 ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_opportunity_lab_user   ON opportunity_lab(user_id);
CREATE INDEX IF NOT EXISTS idx_opportunity_lab_status ON opportunity_lab(status);
CREATE INDEX IF NOT EXISTS idx_action_queue_user      ON action_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_action_queue_status    ON action_queue(status);
CREATE INDEX IF NOT EXISTS idx_roi_metrics_user       ON roi_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_roi_metrics_project    ON roi_metrics(project_id);
CREATE INDEX IF NOT EXISTS idx_projects_user          ON projects(user_id);
CREATE INDEX IF NOT EXISTS idx_advisor_profiles_user  ON advisor_profiles(user_id);
