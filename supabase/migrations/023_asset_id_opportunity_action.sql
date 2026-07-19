-- ============================================================
-- MIGRATION 023 — ASSET_ID EM OPPORTUNITY_LAB E ACTION_QUEUE
-- ============================================================
-- STATUS: PROPOSTA — NÃO APLICAR SEM AUTORIZAÇÃO EXPLÍCITA
-- Criada em: 2026-07-19
-- Branch: integration/build-week-ive-v1
-- Depende de: 022_asset_intelligence_foundation.sql (tabela assets)
--
-- OBJETIVO:
--   Adicionar asset_id nullable a opportunity_lab e action_queue,
--   permitindo que oportunidades e ações sejam vinculadas a um asset
--   específico dentro de um projeto.
--
-- IMPACTO EM DADOS EXISTENTES:
--   NENHUM — apenas adiciona colunas nullable.
--   Todas as linhas existentes recebem asset_id = NULL automaticamente.
--   Projetos, oportunidades e ações sem asset continuam 100% válidos.
--
-- PRÉ-REQUISITO:
--   Migration 022 aplicada (tabela public.assets deve existir).
--
-- ROLLBACK: ver seção ao final.
-- ============================================================

-- ── 1. opportunity_lab ───────────────────────────────────────────────────────

ALTER TABLE public.opportunity_lab
  ADD COLUMN IF NOT EXISTS asset_id UUID NULL
    REFERENCES public.assets(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.opportunity_lab.asset_id IS
  'Asset ao qual esta oportunidade está vinculada. '
  'NULL = oportunidade de projeto (sem asset específico).';

-- Índice para consultas por asset (fetchByAsset)
CREATE INDEX IF NOT EXISTS idx_opportunity_lab_asset_id
  ON public.opportunity_lab (asset_id)
  WHERE asset_id IS NOT NULL;

-- Índice composto para consulta filtrada por usuário + asset
CREATE INDEX IF NOT EXISTS idx_opportunity_lab_user_asset
  ON public.opportunity_lab (user_id, asset_id)
  WHERE asset_id IS NOT NULL;


-- ── 2. action_queue ──────────────────────────────────────────────────────────

ALTER TABLE public.action_queue
  ADD COLUMN IF NOT EXISTS asset_id UUID NULL
    REFERENCES public.assets(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.action_queue.asset_id IS
  'Asset ao qual esta ação está vinculada. '
  'NULL = ação de projeto (sem asset específico).';

-- Índice para consultas por asset (fetchByAsset)
CREATE INDEX IF NOT EXISTS idx_action_queue_asset_id
  ON public.action_queue (asset_id)
  WHERE asset_id IS NOT NULL;

-- Índice composto para consulta filtrada por usuário + asset
CREATE INDEX IF NOT EXISTS idx_action_queue_user_asset
  ON public.action_queue (user_id, asset_id)
  WHERE asset_id IS NOT NULL;


-- ── 3. RLS — sem mudanças ────────────────────────────────────────────────────
-- As políticas existentes em opportunity_lab e action_queue já filtram
-- por auth.uid() = user_id. A nova coluna asset_id herda essas políticas.
-- Não é necessário adicionar novas políticas para asset_id.


-- ── 4. Validação de ownership via trigger ────────────────────────────────────
-- Impede que asset_id aponte para um asset de outro usuário ou projeto.
-- Protege contra bypass via service role.

CREATE OR REPLACE FUNCTION public.validate_asset_id_ownership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_project_id UUID;
BEGIN
  IF NEW.asset_id IS NOT NULL THEN
    -- O asset deve pertencer ao mesmo usuário
    IF NOT EXISTS (
      SELECT 1 FROM public.assets a
      WHERE  a.id      = NEW.asset_id
        AND  a.user_id = NEW.user_id
    ) THEN
      RAISE EXCEPTION
        'asset_id % não pertence ao user_id %',
        NEW.asset_id, NEW.user_id;
    END IF;

    -- Se houver project_id na linha, o asset deve pertencer ao mesmo projeto
    IF NEW.project_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.assets a
        WHERE  a.id         = NEW.asset_id
          AND  a.project_id = NEW.project_id
      ) THEN
        RAISE EXCEPTION
          'asset_id % não pertence ao project_id %',
          NEW.asset_id, NEW.project_id;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.validate_asset_id_ownership IS
  'Valida que asset_id pertence ao mesmo user_id (e project_id se presente). '
  'Aplicado em opportunity_lab e action_queue.';

-- Trigger em opportunity_lab
DROP TRIGGER IF EXISTS trg_opportunity_lab_asset_ownership ON public.opportunity_lab;
CREATE TRIGGER trg_opportunity_lab_asset_ownership
  BEFORE INSERT OR UPDATE ON public.opportunity_lab
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_id_ownership();

-- Trigger em action_queue
DROP TRIGGER IF EXISTS trg_action_queue_asset_ownership ON public.action_queue;
CREATE TRIGGER trg_action_queue_asset_ownership
  BEFORE INSERT OR UPDATE ON public.action_queue
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_id_ownership();


-- ============================================================
-- AUDITORIA DE SEGURANÇA
-- ============================================================
-- DROP TABLE:        NÃO
-- TRUNCATE:          NÃO
-- DELETE sem filtro: NÃO
-- ALTER destructivo: NÃO
-- Impacto em dados:  NENHUM — ADD COLUMN nullable
-- Tabelas afetadas:  opportunity_lab (+1 col), action_queue (+1 col)
-- Tabelas intactas:  assets, projects, profiles, todas as demais
-- ============================================================


-- ============================================================
-- ROLLBACK
-- ============================================================
--
-- Para reverter de forma segura (antes de qualquer dado com asset_id):
--
--   DROP TRIGGER IF EXISTS trg_opportunity_lab_asset_ownership ON public.opportunity_lab;
--   DROP TRIGGER IF EXISTS trg_action_queue_asset_ownership    ON public.action_queue;
--   DROP FUNCTION IF EXISTS public.validate_asset_id_ownership CASCADE;
--   ALTER TABLE public.opportunity_lab DROP COLUMN IF EXISTS asset_id;
--   ALTER TABLE public.action_queue    DROP COLUMN IF EXISTS asset_id;
--
-- Se já houver linhas com asset_id preenchido:
--   UPDATE public.opportunity_lab SET asset_id = NULL;
--   UPDATE public.action_queue    SET asset_id = NULL;
--   -- (depois executar o ALTER TABLE DROP COLUMN acima)
--
-- Nenhuma outra tabela é afetada pelo rollback.
-- ============================================================
