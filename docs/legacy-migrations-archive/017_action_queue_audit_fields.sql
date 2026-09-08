-- Fase 10C: Campos de auditoria para action_queue
-- Transforma ações em entidades completas com origem, plano, justificativa e riscos

ALTER TABLE action_queue
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS origin       TEXT    DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS sources      JSONB   DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS rationale    TEXT,
  ADD COLUMN IF NOT EXISTS plan         JSONB   DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS risks        JSONB   DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ DEFAULT NOW();

COMMENT ON COLUMN action_queue.description IS 'Descrição detalhada da ação';
COMMENT ON COLUMN action_queue.origin       IS 'Origem: manual | opportunity_lab | market_analysis | auto_bootstrap | knowledge_engine';
COMMENT ON COLUMN action_queue.sources      IS 'Referências de origem (IDs ou títulos)';
COMMENT ON COLUMN action_queue.rationale    IS 'Justificativa gerada pela IA';
COMMENT ON COLUMN action_queue.plan         IS 'Plano de execução (lista de passos)';
COMMENT ON COLUMN action_queue.risks        IS 'Riscos identificados';
COMMENT ON COLUMN action_queue.updated_at   IS 'Última atualização';
