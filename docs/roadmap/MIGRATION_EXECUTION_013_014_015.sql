-- ============================================================
-- SCRIPT DE EXECUÇÃO — MIGRATIONS 013 / 014 / 015
-- AI Social Copilot
-- Data: 2026-07-24
-- Branch: claude/access-social-copilot-wJ6B5
-- ============================================================
-- INSTRUÇÕES:
--   Executar no Supabase Dashboard → SQL Editor
--   Colar este script COMPLETO e clicar em Run.
--   O script inclui pre-checks, migrations e post-checks.
--   Se qualquer RAISE EXCEPTION ocorrer: a migration não foi
--   aplicada. Ler a mensagem de erro e reportar ao Claude.
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- BLOCO 0 — PRE-FLIGHT (aborta se condições não atendidas)
-- ════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_count INT;
BEGIN
  -- 0A: tabela projects existe?
  SELECT COUNT(*) INTO v_count
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'projects';
  IF v_count = 0 THEN
    RAISE EXCEPTION 'PRE-FLIGHT FAIL: tabela projects não existe. Aplicar migrations 001-006 primeiro.';
  END IF;

  -- 0B: tabela knowledge_items existe?
  SELECT COUNT(*) INTO v_count
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'knowledge_items';
  IF v_count = 0 THEN
    RAISE EXCEPTION 'PRE-FLIGHT FAIL: tabela knowledge_items não existe. Aplicar migration 003 primeiro.';
  END IF;

  -- 0C: tabela content_items existe?
  SELECT COUNT(*) INTO v_count
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'content_items';
  IF v_count = 0 THEN
    RAISE EXCEPTION 'PRE-FLIGHT FAIL: tabela content_items não existe. Aplicar migration 001 primeiro.';
  END IF;

  -- 0D: tabela knowledge_analysis existe?
  SELECT COUNT(*) INTO v_count
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'knowledge_analysis';
  IF v_count = 0 THEN
    RAISE EXCEPTION 'PRE-FLIGHT FAIL: tabela knowledge_analysis não existe. Aplicar migration 003 primeiro.';
  END IF;

  -- 0E: colunas da migration 005 já existem em content_items?
  --     (knowledge_item_id, auto_generated, keywords, opportunity_score)
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'content_items'
    AND column_name  IN ('knowledge_item_id', 'auto_generated', 'keywords', 'opportunity_score');
  IF v_count < 4 THEN
    RAISE EXCEPTION 'PRE-FLIGHT FAIL: migration 005 não aplicada. Faltam % de 4 colunas em content_items (knowledge_item_id, auto_generated, keywords, opportunity_score). Aplicar 005 antes desta sequência.', (4 - v_count);
  END IF;

  RAISE NOTICE 'PRE-FLIGHT PASS: todas as pré-condições atendidas.';
END;
$$;


-- ════════════════════════════════════════════════════════════
-- BLOCO 1 — MIGRATION 013
-- ADD project_id TO knowledge_items
-- ════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_items'
    AND column_name  = 'project_id';

  IF v_count > 0 THEN
    RAISE NOTICE 'MIGRATION 013: project_id já existe em knowledge_items — SKIPPED (idempotente).';
  ELSE
    RAISE NOTICE 'MIGRATION 013: aplicando ADD COLUMN project_id em knowledge_items...';
  END IF;
END;
$$;

-- migration 013 (idempotente — IF NOT EXISTS)
ALTER TABLE public.knowledge_items
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS knowledge_items_project_id_idx ON public.knowledge_items(project_id);

-- post-check 013
DO $$
DECLARE
  v_col_count  INT;
  v_fk_count   INT;
  v_idx_count  INT;
BEGIN
  -- coluna existe?
  SELECT COUNT(*) INTO v_col_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_items'
    AND column_name  = 'project_id';

  -- FK existe?
  SELECT COUNT(*) INTO v_fk_count
  FROM information_schema.referential_constraints rc
  JOIN information_schema.key_column_usage kcu
    ON rc.constraint_name = kcu.constraint_name
  WHERE kcu.table_schema  = 'public'
    AND kcu.table_name    = 'knowledge_items'
    AND kcu.column_name   = 'project_id';

  -- índice existe?
  SELECT COUNT(*) INTO v_idx_count
  FROM pg_indexes
  WHERE tablename = 'knowledge_items'
    AND indexname = 'knowledge_items_project_id_idx';

  IF v_col_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 013 FAIL: project_id NÃO criada em knowledge_items.';
  END IF;
  IF v_fk_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 013 FAIL: FK project_id → projects NÃO criada.';
  END IF;
  IF v_idx_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 013 FAIL: índice knowledge_items_project_id_idx NÃO criado.';
  END IF;

  RAISE NOTICE 'POST-CHECK 013: PASS — project_id criada, FK OK, índice OK.';
END;
$$;


-- ════════════════════════════════════════════════════════════
-- BLOCO 2 — MIGRATION 014
-- ADD project_id TO content_items
-- ════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'content_items'
    AND column_name  = 'project_id';

  IF v_count > 0 THEN
    RAISE NOTICE 'MIGRATION 014: project_id já existe em content_items — SKIPPED (idempotente).';
  ELSE
    RAISE NOTICE 'MIGRATION 014: aplicando ADD COLUMN project_id em content_items...';
  END IF;
END;
$$;

-- migration 014
ALTER TABLE public.content_items
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS content_items_project_id_idx ON public.content_items(project_id);

-- post-check 014
DO $$
DECLARE
  v_col_count INT;
  v_fk_count  INT;
  v_idx_count INT;
BEGIN
  SELECT COUNT(*) INTO v_col_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'content_items'
    AND column_name  = 'project_id';

  SELECT COUNT(*) INTO v_fk_count
  FROM information_schema.referential_constraints rc
  JOIN information_schema.key_column_usage kcu
    ON rc.constraint_name = kcu.constraint_name
  WHERE kcu.table_schema  = 'public'
    AND kcu.table_name    = 'content_items'
    AND kcu.column_name   = 'project_id';

  SELECT COUNT(*) INTO v_idx_count
  FROM pg_indexes
  WHERE tablename = 'content_items'
    AND indexname = 'content_items_project_id_idx';

  IF v_col_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 014 FAIL: project_id NÃO criada em content_items.';
  END IF;
  IF v_fk_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 014 FAIL: FK project_id → projects NÃO criada.';
  END IF;
  IF v_idx_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 014 FAIL: índice content_items_project_id_idx NÃO criado.';
  END IF;

  RAISE NOTICE 'POST-CHECK 014: PASS — project_id criada, FK OK, índice OK.';
END;
$$;


-- ════════════════════════════════════════════════════════════
-- BLOCO 3 — PRE-CHECK ESPECÍFICO DE 015
-- (verifica pré-requisito 013 e conta linhas do backfill)
-- ════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_ki_has_project_id INT;
  v_backfill_rows     INT;
BEGIN
  -- pré-requisito: 013 aplicada?
  SELECT COUNT(*) INTO v_ki_has_project_id
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_items'
    AND column_name  = 'project_id';

  IF v_ki_has_project_id = 0 THEN
    RAISE EXCEPTION 'PRE-CHECK 015 FAIL: migration 013 não foi aplicada. knowledge_items.project_id inexistente. Aplicar 013 primeiro.';
  END IF;

  -- contar linhas que o backfill vai atualizar
  SELECT COUNT(*) INTO v_backfill_rows
  FROM public.knowledge_analysis ka
  JOIN public.knowledge_items ki ON ka.knowledge_item_id = ki.id
  WHERE ki.project_id IS NOT NULL
    AND ka.project_id IS NULL;

  RAISE NOTICE 'PRE-CHECK 015: pré-requisito 013 OK. Linhas a atualizar no backfill: %', v_backfill_rows;
END;
$$;


-- ════════════════════════════════════════════════════════════
-- BLOCO 4 — MIGRATION 015
-- ADD project_id TO knowledge_analysis + BACKFILL
-- ════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_analysis'
    AND column_name  = 'project_id';

  IF v_count > 0 THEN
    RAISE NOTICE 'MIGRATION 015: project_id já existe em knowledge_analysis — DDL SKIPPED (idempotente).';
  ELSE
    RAISE NOTICE 'MIGRATION 015: aplicando ADD COLUMN project_id em knowledge_analysis...';
  END IF;
END;
$$;

-- migration 015
ALTER TABLE public.knowledge_analysis
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS knowledge_analysis_project_id_idx ON public.knowledge_analysis(project_id);

-- backfill
UPDATE public.knowledge_analysis ka
SET    project_id = ki.project_id
FROM   public.knowledge_items ki
WHERE  ka.knowledge_item_id = ki.id
  AND  ki.project_id IS NOT NULL
  AND  ka.project_id IS NULL;

-- post-check 015
DO $$
DECLARE
  v_col_count      INT;
  v_fk_count       INT;
  v_idx_count      INT;
  v_backfill_check INT;
BEGIN
  SELECT COUNT(*) INTO v_col_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_analysis'
    AND column_name  = 'project_id';

  SELECT COUNT(*) INTO v_fk_count
  FROM information_schema.referential_constraints rc
  JOIN information_schema.key_column_usage kcu
    ON rc.constraint_name = kcu.constraint_name
  WHERE kcu.table_schema = 'public'
    AND kcu.table_name   = 'knowledge_analysis'
    AND kcu.column_name  = 'project_id';

  SELECT COUNT(*) INTO v_idx_count
  FROM pg_indexes
  WHERE tablename = 'knowledge_analysis'
    AND indexname = 'knowledge_analysis_project_id_idx';

  -- backfill: nenhuma análise deve ter project_id=NULL se seu ki tem project_id
  SELECT COUNT(*) INTO v_backfill_check
  FROM public.knowledge_analysis ka
  JOIN public.knowledge_items ki ON ka.knowledge_item_id = ki.id
  WHERE ki.project_id IS NOT NULL
    AND ka.project_id IS NULL;

  IF v_col_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 015 FAIL: project_id NÃO criada em knowledge_analysis.';
  END IF;
  IF v_fk_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 015 FAIL: FK project_id → projects NÃO criada.';
  END IF;
  IF v_idx_count = 0 THEN
    RAISE EXCEPTION 'POST-CHECK 015 FAIL: índice knowledge_analysis_project_id_idx NÃO criado.';
  END IF;
  IF v_backfill_check > 0 THEN
    RAISE EXCEPTION 'POST-CHECK 015 FAIL: backfill incompleto — % análises ainda com project_id NULL.', v_backfill_check;
  END IF;

  RAISE NOTICE 'POST-CHECK 015: PASS — project_id criada, FK OK, índice OK, backfill completo.';
END;
$$;


-- ════════════════════════════════════════════════════════════
-- BLOCO 5 — POSTGREST SCHEMA CACHE INVALIDATION
-- ════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
  RAISE NOTICE 'SCHEMA CACHE: notificação NOTIFY pgrst reload enviada.';
  RAISE NOTICE 'Aguarde 2-3 segundos para o PostgREST processar antes de testar o app.';
END;
$$;


-- ════════════════════════════════════════════════════════════
-- BLOCO 6 — VERIFICAÇÃO FINAL E2E (informacional)
-- ════════════════════════════════════════════════════════════

-- Mostrar schema atual das 3 tabelas alteradas
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   IN ('knowledge_items', 'content_items', 'knowledge_analysis')
  AND column_name  = 'project_id'
ORDER BY table_name;

-- Mostrar FKs criadas
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name  AS references_table,
  rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
JOIN information_schema.referential_constraints rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema     = 'public'
  AND tc.constraint_type  = 'FOREIGN KEY'
  AND kcu.column_name     = 'project_id'
  AND tc.table_name       IN ('knowledge_items', 'content_items', 'knowledge_analysis')
ORDER BY tc.table_name;

-- Mostrar índices criados
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE indexname IN (
  'knowledge_items_project_id_idx',
  'content_items_project_id_idx',
  'knowledge_analysis_project_id_idx'
)
ORDER BY tablename;

-- ════════════════════════════════════════════════════════════
-- FIM DO SCRIPT
-- Resultado esperado no painel de mensagens:
--   PRE-FLIGHT PASS: todas as pré-condições atendidas.
--   MIGRATION 013: PASS
--   MIGRATION 014: PASS
--   MIGRATION 015: PASS
--   SCHEMA CACHE: notificação enviada.
--   Tabela de resultados: 3 linhas (uma por tabela)
-- ════════════════════════════════════════════════════════════
