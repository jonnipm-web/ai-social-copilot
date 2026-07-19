-- ============================================================
-- MIGRATION 022 — ASSET INTELLIGENCE FOUNDATION
-- ============================================================
-- STATUS: PROPOSTA — NÃO APLICAR SEM AUTORIZAÇÃO EXPLÍCITA
-- Criada em: 2026-07-19
-- Branch: integration/build-week-ive-v1
--
-- OBJETIVO:
--   Criar a tabela `assets` que sustenta a camada
--   Project → Assets → Asset Intelligence.
--
-- IMPACTO EM DADOS EXISTENTES:
--   NENHUM — apenas adiciona tabela nova.
--   Projetos sem assets continuam 100% válidos.
--   Todas as tabelas existentes permanecem inalteradas.
--
-- ROLLBACK: ver seção ao final.
-- ============================================================

-- ── 1. Tabela principal: assets ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.assets (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id          UUID        NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,

  -- Hierarquia opcional: asset filho aponta para asset pai do mesmo projeto
  -- Proteção contra auto-referência e ciclos: ver trigger abaixo.
  parent_asset_id     UUID        NULL REFERENCES public.assets(id) ON DELETE SET NULL,

  -- Identidade
  name                TEXT        NOT NULL,
  type                TEXT        NOT NULL,
  subtype             TEXT        NULL,
  description         TEXT        NULL,

  -- Ciclo de vida
  status              TEXT        NOT NULL DEFAULT 'idea',

  -- Classificação de mercado
  category            TEXT        NULL,
  niche               TEXT        NULL,
  target_market       TEXT        NULL,
  target_audience     TEXT        NULL,

  -- Modelo de negócio
  business_model      TEXT        NULL,
  revenue_model       TEXT        NULL,

  -- Estratégia
  lifecycle_stage     TEXT        NULL,
  strategic_priority  INTEGER     NULL DEFAULT 0,

  -- Dados estruturados extensíveis (Asset Intelligence, scores, etc.)
  metadata            JSONB       NOT NULL DEFAULT '{}',

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Garantias de domínio
  CONSTRAINT assets_name_not_empty  CHECK (char_length(trim(name)) > 0),
  CONSTRAINT assets_type_not_empty  CHECK (char_length(trim(type)) > 0),
  CONSTRAINT assets_status_valid    CHECK (status IN (
    'idea', 'research', 'validation', 'planned',
    'active', 'paused', 'completed', 'archived'
  )),
  CONSTRAINT assets_type_valid      CHECK (type IN (
    'product', 'service', 'book', 'series', 'website', 'app',
    'course', 'content_property', 'brand', 'module',
    'market', 'niche', 'technology', 'intellectual_property', 'other'
  )),
  -- Impede que um asset seja seu próprio pai
  CONSTRAINT assets_no_self_reference CHECK (id != parent_asset_id)
);

COMMENT ON TABLE  public.assets IS
  'Ativos estratégicos de um projeto. Suporta hierarquia pai-filho via parent_asset_id.';
COMMENT ON COLUMN public.assets.parent_asset_id IS
  'Asset pai — deve pertencer ao mesmo user_id e project_id. Protegido por trigger.';
COMMENT ON COLUMN public.assets.metadata IS
  'JSONB extensível para Asset Intelligence, scores, evidências e dados futuros.';


-- ── 2. Índices de performance ────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_assets_user_id
  ON public.assets (user_id);

CREATE INDEX IF NOT EXISTS idx_assets_project_id
  ON public.assets (project_id);

-- Composto: consulta principal do service (fetchAll)
CREATE INDEX IF NOT EXISTS idx_assets_user_project
  ON public.assets (user_id, project_id);

CREATE INDEX IF NOT EXISTS idx_assets_parent_asset_id
  ON public.assets (parent_asset_id)
  WHERE parent_asset_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_assets_type
  ON public.assets (type);

CREATE INDEX IF NOT EXISTS idx_assets_status
  ON public.assets (status);

CREATE INDEX IF NOT EXISTS idx_assets_niche
  ON public.assets (niche)
  WHERE niche IS NOT NULL;


-- ── 3. Trigger updated_at ────────────────────────────────────────────────────
-- Reutiliza a função public.set_updated_at() criada em 001_platform_schema.sql.
-- Não cria função duplicada.

DROP TRIGGER IF EXISTS trg_assets_updated_at ON public.assets;
CREATE TRIGGER trg_assets_updated_at
  BEFORE UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 4. Trigger: validação de hierarquia (parent ownership) ──────────────────
-- Impede que parent_asset_id aponte para asset de outro user_id ou project_id.
-- Esta proteção é adicional ao RLS — defende contra bypass via service role.

CREATE OR REPLACE FUNCTION public.validate_asset_parent_ownership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.parent_asset_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.assets p
      WHERE  p.id         = NEW.parent_asset_id
        AND  p.user_id    = NEW.user_id
        AND  p.project_id = NEW.project_id
    ) THEN
      RAISE EXCEPTION
        'parent_asset_id % não pertence ao mesmo user_id/project_id',
        NEW.parent_asset_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.validate_asset_parent_ownership IS
  'Valida que parent_asset_id pertence ao mesmo user_id e project_id. '
  'Protege contra bypass via service role. Não detecta ciclos de grafo '
  '(ex: A→B→A) — ciclos profundos devem ser tratados em camada de aplicação.';

DROP TRIGGER IF EXISTS trg_assets_parent_ownership ON public.assets;
CREATE TRIGGER trg_assets_parent_ownership
  BEFORE INSERT OR UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_parent_ownership();


-- ── 5. Row-Level Security ────────────────────────────────────────────────────

ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;

-- SELECT: somente assets do próprio usuário
CREATE POLICY "assets_select_own"
  ON public.assets FOR SELECT
  USING (auth.uid() = user_id);

-- INSERT: somente para o próprio usuário; user_id deve bater com auth.uid()
CREATE POLICY "assets_insert_own"
  ON public.assets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: somente assets do próprio usuário
CREATE POLICY "assets_update_own"
  ON public.assets FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: somente assets do próprio usuário
CREATE POLICY "assets_delete_own"
  ON public.assets FOR DELETE
  USING (auth.uid() = user_id);


-- ── 6. Futuras colunas (documentação — NÃO aplicar agora) ───────────────────
--
-- Quando Fase B (Asset Intelligence Scores) for autorizada:
--   ALTER TABLE public.assets ADD COLUMN opportunity_score INTEGER DEFAULT 0;
--   ALTER TABLE public.assets ADD COLUMN roi_score         FLOAT   DEFAULT 0;
--   ALTER TABLE public.assets ADD COLUMN momentum_score    INTEGER DEFAULT 0;
--
-- Quando Fase C (Opportunity Lab por asset) for autorizada:
--   ALTER TABLE public.opportunity_lab  ADD COLUMN asset_id UUID REFERENCES public.assets(id);
--   ALTER TABLE public.action_queue     ADD COLUMN asset_id UUID REFERENCES public.assets(id);
--
-- Todos os campos futuros são NULLABLE para garantir compatibilidade retroativa.


-- ============================================================
-- ROLLBACK
-- ============================================================
--
-- Para reverter esta migration de forma segura:
--
--   DROP TABLE IF EXISTS public.assets CASCADE;
--   DROP FUNCTION IF EXISTS public.validate_asset_parent_ownership CASCADE;
--
-- O CASCADE remove automaticamente:
--   - todos os índices da tabela
--   - todos os triggers da tabela
--   - todas as políticas RLS da tabela
--   - qualquer FK futura que referencie public.assets
--
-- Nenhuma tabela existente é afetada pelo rollback.
-- ============================================================
