-- 022_phase11h_context_integration.sql
-- Phase 11H: adiciona colunas de contexto, versionamento e soft delete em market_analyses

ALTER TABLE market_analyses
  ADD COLUMN IF NOT EXISTS context_snapshot JSONB,
  ADD COLUMN IF NOT EXISTS source_ids       TEXT[]       DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS coverage         FLOAT4,
  ADD COLUMN IF NOT EXISTS missing_data     TEXT[]       DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS version          INTEGER      DEFAULT 1,
  ADD COLUMN IF NOT EXISTS supersedes_id    UUID         REFERENCES market_analyses(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS confidence       FLOAT4,
  ADD COLUMN IF NOT EXISTS generated_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_at       TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS market_analyses_deleted_at_idx    ON market_analyses (deleted_at);
CREATE INDEX IF NOT EXISTS market_analyses_supersedes_id_idx ON market_analyses (supersedes_id);
