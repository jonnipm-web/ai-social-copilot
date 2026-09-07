-- ============================================================
-- 008_knowledge_vault_columns.sql
-- Colunas faltantes nas tabelas do Cofre de Conhecimento
-- ============================================================

-- ── knowledge_items: colunas adicionadas pelo código mas ausentes na tabela ──
ALTER TABLE public.knowledge_items
  ADD COLUMN IF NOT EXISTS opportunity_score INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS auto_title        TEXT,
  ADD COLUMN IF NOT EXISTS auto_type         TEXT,
  ADD COLUMN IF NOT EXISTS auto_niche        TEXT,
  ADD COLUMN IF NOT EXISTS auto_audience     TEXT;

-- ── knowledge_analysis: colunas usadas pelo analyzeItem() mas ausentes na tabela ──
ALTER TABLE public.knowledge_analysis
  ADD COLUMN IF NOT EXISTS score_opportunity  INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_hotmart      INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_shopify      INT  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hotmart_data       JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS shopify_data       JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS persona_training   JSONB DEFAULT '{}';
