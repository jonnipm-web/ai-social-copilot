-- ============================================================
-- Migration 020 — P0 Stabilization: schema cache fixes
-- ============================================================
-- Garante que TODAS as colunas usadas pelo app existam no banco,
-- independente da ordem em que as migrations anteriores foram aplicadas.
-- Usa ADD COLUMN IF NOT EXISTS em tudo — safe para re-executar.

-- ── opportunity_lab: campos de auditoria (migration 016 pode não ter sido aplicada) ──
ALTER TABLE opportunity_lab
  ADD COLUMN IF NOT EXISTS origin       TEXT    DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS sources      JSONB   DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS rationale    TEXT,
  ADD COLUMN IF NOT EXISTS confidence   INTEGER DEFAULT 0
    CHECK (confidence >= 0 AND confidence <= 100),
  ADD COLUMN IF NOT EXISTS risks        JSONB   DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS action_steps JSONB   DEFAULT '[]';

-- ── action_queue: campos adicionados por migration 017 ───────────────────────
ALTER TABLE action_queue
  ADD COLUMN IF NOT EXISTS origin          TEXT DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS sources         JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS rationale       TEXT,
  ADD COLUMN IF NOT EXISTS confidence      INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS risks           JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS action_steps    JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS description     TEXT DEFAULT '';

-- ── action_queue: campos adicionados por migration 019 ───────────────────────
ALTER TABLE action_queue
  ADD COLUMN IF NOT EXISTS market_score       INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS market_analysis_id UUID REFERENCES market_analyses(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS action_queue_market_analysis_id_idx
  ON action_queue(market_analysis_id);

-- ── knowledge_items: colunas extras usadas pelo analyzeItem() ────────────────
ALTER TABLE knowledge_items
  ADD COLUMN IF NOT EXISTS opportunity_score INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS auto_title        TEXT,
  ADD COLUMN IF NOT EXISTS auto_type         TEXT,
  ADD COLUMN IF NOT EXISTS auto_niche        TEXT,
  ADD COLUMN IF NOT EXISTS auto_audience     TEXT;

-- ── knowledge_analysis: colunas extras geradas pelo extract-knowledge ────────
ALTER TABLE knowledge_analysis
  ADD COLUMN IF NOT EXISTS score_opportunity  INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_hotmart      INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_shopify      INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hotmart_data       JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS shopify_data       JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS persona_training   JSONB DEFAULT '{}';

-- ── knowledge_items: project_id (migration 013 pode não ter sido aplicada) ───
ALTER TABLE knowledge_items
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS knowledge_items_project_id_idx
  ON knowledge_items(project_id);

-- ── knowledge_analysis: project_id (migration 015 pode não ter sido aplicada) ─
ALTER TABLE knowledge_analysis
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS knowledge_analysis_project_id_idx
  ON knowledge_analysis(project_id);

-- ── Backfill project_id em knowledge_analysis a partir de knowledge_items ─────
UPDATE knowledge_analysis ka
SET    project_id = ki.project_id
FROM   knowledge_items ki
WHERE  ka.knowledge_item_id = ki.id
  AND  ki.project_id IS NOT NULL
  AND  ka.project_id IS NULL;

-- ── Habilitar features para todos os usuários ────────────────────────────────
UPDATE feature_flags
SET    enabled = true
WHERE  feature_name IN (
  'opportunity_lab_enabled',
  'action_engine_enabled',
  'copilot_enabled',
  'business_memory_enabled',
  'ecosystem_view_enabled'
);

-- Garante que os registros existam (caso a migration 007 não tenha sido aplicada)
INSERT INTO feature_flags (feature_name, enabled, plan_required) VALUES
  ('business_memory_enabled',  true, 'free'),
  ('ecosystem_view_enabled',   true, 'free'),
  ('advisor_enabled',          true, 'free'),
  ('opportunity_lab_enabled',  true, 'free'),
  ('action_engine_enabled',    true, 'free'),
  ('copilot_enabled',          true, 'free')
ON CONFLICT (feature_name) DO UPDATE SET enabled = EXCLUDED.enabled;
