-- Fase 10: Adiciona project_id à tabela knowledge_analysis
-- Permite filtrar análises por projeto sem JOIN com knowledge_items
-- Propagado automaticamente ao analisar um knowledge_item com project_id

ALTER TABLE knowledge_analysis
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS knowledge_analysis_project_id_idx ON knowledge_analysis(project_id);

-- Backfill: propaga project_id dos knowledge_items para analyses existentes
UPDATE knowledge_analysis ka
SET    project_id = ki.project_id
FROM   knowledge_items ki
WHERE  ka.knowledge_item_id = ki.id
  AND  ki.project_id IS NOT NULL
  AND  ka.project_id IS NULL;
