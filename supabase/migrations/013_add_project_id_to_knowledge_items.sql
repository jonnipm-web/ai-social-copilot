-- Etapa 3: Adiciona project_id à tabela knowledge_items
-- Permite filtrar conhecimentos por projeto

ALTER TABLE knowledge_items
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS knowledge_items_project_id_idx ON knowledge_items(project_id);
