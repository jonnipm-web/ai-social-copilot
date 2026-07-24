MIGRATION REQUIRED — P0-1 SCHEMA
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
STATUS: RED GATE — AGUARDANDO AUTORIZAÇÃO DO PO
==================================================

SINTOMA CONFIRMADO EM DISPOSITIVO:
  PostgrestException: Could not find the 'project_id' column
  of 'knowledge_items' in the schema cache
  Code: PGRST204

CAUSA RAIZ:
  As migrations 013, 014 e 015 existem no repositório mas NÃO
  foram aplicadas ao banco de dados de produção Supabase.
  O PostgREST rejeita queries com a coluna inexistente.

ESTADO ATUAL (SEM MIGRATION):
  - Código Flutter tem tratamento defensivo: se PGRST204 ocorrer
    ao filtrar por project_id, faz fallback para lista completa
    sem travar o app (implementado em 2026-07-24)
  - "Vincular a Projeto" no Cofre mostra erro explicativo
    em vez de crash

IMPACTO SE NÃO APLICAR:
  - Filtro de itens do Cofre por projeto não funciona
  - "Vincular a Projeto" no Cofre persiste relação mas não
    filtra corretamente até migration ser aplicada
  - Análise de projeto (COMPLETAR ANÁLISE) não carrega
    knowledge_items do projeto

==================================================
MIGRATIONS A APLICAR (em ordem)
==================================================

PASSO 1 — Acessar o Supabase Dashboard:
  https://supabase.com/dashboard
  Selecionar o projeto: AI Social Copilot
  Ir em: Database > SQL Editor

PASSO 2 — Executar Migration 013:
  (adiciona project_id em knowledge_items)

  ALTER TABLE knowledge_items
    ADD COLUMN IF NOT EXISTS project_id UUID
    REFERENCES projects(id) ON DELETE SET NULL;

  CREATE INDEX IF NOT EXISTS knowledge_items_project_id_idx
    ON knowledge_items(project_id);

PASSO 3 — Executar Migration 014:
  (adiciona project_id em content_items)

  ALTER TABLE content_items
    ADD COLUMN IF NOT EXISTS project_id UUID
    REFERENCES projects(id) ON DELETE SET NULL;

  CREATE INDEX IF NOT EXISTS content_items_project_id_idx
    ON content_items(project_id);

PASSO 4 — Executar Migration 015:
  (adiciona project_id em knowledge_analysis + backfill)

  ALTER TABLE knowledge_analysis
    ADD COLUMN IF NOT EXISTS project_id UUID
    REFERENCES projects(id) ON DELETE SET NULL;

  CREATE INDEX IF NOT EXISTS knowledge_analysis_project_id_idx
    ON knowledge_analysis(project_id);

  UPDATE knowledge_analysis ka
    SET project_id = ki.project_id
    FROM knowledge_items ki
    WHERE ka.knowledge_item_id = ki.id
      AND ki.project_id IS NOT NULL
      AND ka.project_id IS NULL;

PASSO 5 — Verificar no SQL Editor:
  SELECT column_name
  FROM information_schema.columns
  WHERE table_name IN ('knowledge_items','content_items','knowledge_analysis')
    AND column_name = 'project_id';

  Esperado: 3 linhas retornadas (uma por tabela).

PASSO 6 — Invalidar cache do PostgREST:
  No Dashboard: Database > PostgREST > "Reload schema"
  (ou aguardar 5 minutos para auto-invalidação)

PASSO 7 — Testar no app:
  Cofre > selecionar filtro de projeto
  Esperado: apenas itens do projeto aparecem (sem PGRST204)

==================================================
RETROCOMPATIBILIDADE
==================================================

  ADD COLUMN IF NOT EXISTS = operação não-destrutiva.
  Registros existentes receberão project_id = NULL.
  Nenhum dado é alterado exceto o backfill da migration 015
  (que propaga project_id de knowledge_items para knowledge_analysis).

  O backfill é seguro: só atualiza rows onde ki.project_id IS NOT NULL
  e ka.project_id IS NULL (não sobrescreve valores existentes).

==================================================
ARQUIVOS DE MIGRATION NO REPO
==================================================

  supabase/migrations/013_add_project_id_to_knowledge_items.sql
  supabase/migrations/014_add_project_id_to_content_items.sql
  supabase/migrations/015_add_project_id_to_knowledge_analysis.sql
