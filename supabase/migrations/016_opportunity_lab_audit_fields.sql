-- Fase 10B: Campos de auditoria para opportunity_lab
-- Permite rastrear origem, fontes, justificativa, confiança, riscos e próximos passos

ALTER TABLE opportunity_lab
  ADD COLUMN IF NOT EXISTS origin       TEXT    DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS sources      JSONB   DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS rationale    TEXT,
  ADD COLUMN IF NOT EXISTS confidence   INTEGER DEFAULT 0 CHECK (confidence >= 0 AND confidence <= 100),
  ADD COLUMN IF NOT EXISTS risks        JSONB   DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS action_steps JSONB   DEFAULT '[]';

COMMENT ON COLUMN opportunity_lab.origin       IS 'Origem: manual | market_analysis | auto_bootstrap | knowledge_engine';
COMMENT ON COLUMN opportunity_lab.sources      IS 'Lista de referências de origem (IDs ou títulos)';
COMMENT ON COLUMN opportunity_lab.rationale    IS 'Justificativa gerada pela IA';
COMMENT ON COLUMN opportunity_lab.confidence   IS 'Nível de confiança da IA (0–100)';
COMMENT ON COLUMN opportunity_lab.risks        IS 'Lista de riscos identificados';
COMMENT ON COLUMN opportunity_lab.action_steps IS 'Próximos passos recomendados';
