-- ============================================================
-- MIGRATION 024 — ASSET RESOURCES (INGESTION HUB)
-- ============================================================
-- STATUS: PROPOSTA — NÃO APLICAR SEM AUTORIZAÇÃO EXPLÍCITA
-- Criada em: 2026-07-19
-- Branch: integration/build-week-ive-v1
-- Depende de: 022_asset_intelligence_foundation.sql (tabela assets)
--
-- OBJETIVO:
--   Criar a tabela `asset_resources` que armazena recursos vinculados
--   a um ativo: documentos, URLs, textos, imagens, dados extraídos.
--   Todo item ingerido pelo Asset Ingestion Hub que for classificado como
--   RESOURCE ou EVIDENCE é persistido aqui.
--
-- IMPACTO EM DADOS EXISTENTES:
--   NENHUM — apenas adiciona tabela nova.
--   Assets existentes continuam 100% válidos sem resources.
--
-- PRÉ-REQUISITO:
--   Migration 022 aplicada (tabela public.assets deve existir).
--
-- ROLLBACK: ver seção ao final.
-- ============================================================


-- ── 1. Tabela principal: asset_resources ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.asset_resources (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id        UUID        NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Tipo de recurso
  resource_type   TEXT        NOT NULL DEFAULT 'resource',

  -- Identidade
  title           TEXT        NOT NULL,
  description     TEXT        NULL,

  -- Provenance — origem do dado
  source_type     TEXT        NULL,
  source_id       TEXT        NULL,
  source_name     TEXT        NULL,
  source_url      TEXT        NULL,
  parser_version  TEXT        NULL,
  confidence      FLOAT       NOT NULL DEFAULT 1.0,

  -- Conteúdo
  raw_text        TEXT        NULL,
  structured_data JSONB       NULL,

  -- Arquivo (se importado de arquivo)
  storage_path    TEXT        NULL,
  mime_type       TEXT        NULL,
  size_bytes      BIGINT      NULL,

  -- De-duplicação
  fingerprint     TEXT        NULL,

  -- Extensível
  metadata        JSONB       NOT NULL DEFAULT '{}',

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Garantias de domínio
  CONSTRAINT asset_resources_title_not_empty  CHECK (char_length(trim(title)) > 0),
  CONSTRAINT asset_resources_type_valid       CHECK (resource_type IN (
    'resource', 'evidence', 'reference', 'document', 'image', 'url', 'text', 'data'
  )),
  CONSTRAINT asset_resources_confidence_range CHECK (confidence >= 0 AND confidence <= 1)
);

COMMENT ON TABLE public.asset_resources IS
  'Recursos vinculados a um ativo via Asset Ingestion Hub. '
  'Inclui documentos, URLs, textos, imagens e dados estruturados.';

COMMENT ON COLUMN public.asset_resources.resource_type IS
  'Tipo: resource (genérico), evidence (evidência de pesquisa), '
  'reference (referência), document, image, url, text, data.';

COMMENT ON COLUMN public.asset_resources.fingerprint IS
  'SHA-256 do conteúdo original para de-duplicação.';

COMMENT ON COLUMN public.asset_resources.provenance IS
  'Provenance estruturada em metadata["provenance"] — source_type, '
  'source_id, source_name, source_url, imported_at, parser_version, confidence.';


-- ── 2. Índices ────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_asset_resources_asset_id
  ON public.asset_resources (asset_id);

CREATE INDEX IF NOT EXISTS idx_asset_resources_user_id
  ON public.asset_resources (user_id);

CREATE INDEX IF NOT EXISTS idx_asset_resources_user_asset
  ON public.asset_resources (user_id, asset_id);

CREATE INDEX IF NOT EXISTS idx_asset_resources_fingerprint
  ON public.asset_resources (fingerprint)
  WHERE fingerprint IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_asset_resources_source_url
  ON public.asset_resources (source_url)
  WHERE source_url IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_asset_resources_resource_type
  ON public.asset_resources (resource_type);


-- ── 3. Trigger updated_at ─────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_asset_resources_updated_at ON public.asset_resources;
CREATE TRIGGER trg_asset_resources_updated_at
  BEFORE UPDATE ON public.asset_resources
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 4. RLS ───────────────────────────────────────────────────────────────────

ALTER TABLE public.asset_resources ENABLE ROW LEVEL SECURITY;

CREATE POLICY "asset_resources_select_own"
  ON public.asset_resources FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "asset_resources_insert_own"
  ON public.asset_resources FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "asset_resources_update_own"
  ON public.asset_resources FOR UPDATE
  USING    (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "asset_resources_delete_own"
  ON public.asset_resources FOR DELETE
  USING (auth.uid() = user_id);


-- ── 5. Trigger de ownership ──────────────────────────────────────────────────
-- Valida que o asset_id pertence ao mesmo user_id.
-- Protege contra bypass via service role.

CREATE OR REPLACE FUNCTION public.validate_asset_resource_ownership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id      = NEW.asset_id
      AND a.user_id = NEW.user_id
  ) THEN
    RAISE EXCEPTION
      'asset_id % não pertence ao user_id %',
      NEW.asset_id, NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.validate_asset_resource_ownership IS
  'Valida que asset_id de um resource pertence ao mesmo user_id. '
  'Protege contra inserção de resource em asset de outro usuário.';

DROP TRIGGER IF EXISTS trg_asset_resource_ownership ON public.asset_resources;
CREATE TRIGGER trg_asset_resource_ownership
  BEFORE INSERT OR UPDATE ON public.asset_resources
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_resource_ownership();


-- ============================================================
-- AUDITORIA DE SEGURANÇA
-- ============================================================
-- DROP TABLE:        NÃO
-- TRUNCATE:          NÃO
-- DELETE sem filtro: NÃO
-- ALTER destructivo: NÃO
-- Impacto em dados:  NENHUM — apenas nova tabela
-- Tabelas afetadas:  asset_resources (nova)
-- Tabelas intactas:  assets, opportunity_lab, action_queue, projects
-- ============================================================


-- ============================================================
-- ROLLBACK
-- ============================================================
--
--   DROP TABLE IF EXISTS public.asset_resources CASCADE;
--   DROP FUNCTION IF EXISTS public.validate_asset_resource_ownership CASCADE;
--
-- O CASCADE remove índices, triggers e políticas automaticamente.
-- Nenhuma outra tabela é afetada.
-- ============================================================
