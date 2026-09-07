-- Etapa 3: Adiciona project_id à tabela content_items (biblioteca)
-- Permite filtrar conteúdos por projeto

ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS content_items_project_id_idx ON content_items(project_id);
