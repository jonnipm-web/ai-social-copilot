P0 DATABASE MIGRATION EXECUTION REPORT
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
SCHEMA PRE-FLIGHT
==================================================

STATUS: PASS (por análise de código — sem acesso direto ao DB)

TABELAS VERIFICADAS (via supabase/migrations/*.sql):
  projects            — criada em 002_projects.sql / 006_rls_projects.sql
  knowledge_items     — criada em 003_phase6_knowledge.sql
  content_items       — criada em 001_initial_schema.sql
  knowledge_analysis  — criada em 003_phase6_knowledge.sql

NOTA TÉCNICA:
  Não foi possível executar pre-flight direto em produção.
  Razão: proxy do ambiente bloqueia supabase.co com 403 Forbidden.
  O script MIGRATION_EXECUTION_013_014_015.sql contém bloco PRE-FLIGHT
  embutido (Bloco 0) que realiza as mesmas verificações ao ser executado
  no Supabase Dashboard pelo PO.

==================================================
CONTENT_ITEMS DISCREPANCY
==================================================

STATUS: RESOLVED

COLUNAS SOB INVESTIGAÇÃO:
  knowledge_item_id   UUID
  auto_generated      BOOLEAN NOT NULL DEFAULT FALSE
  keywords            JSONB NOT NULL DEFAULT '[]'
  opportunity_score   INT NOT NULL DEFAULT 0

CAUSA: Estas colunas foram adicionadas pela MIGRATION 005
  Arquivo: supabase/migrations/005_phase8_tables.sql
  Linhas relevantes:
    ALTER TABLE content_items
      ADD COLUMN IF NOT EXISTS knowledge_item_id UUID REFERENCES knowledge_items(id) ON DELETE SET NULL,
      ADD COLUMN IF NOT EXISTS auto_generated BOOLEAN NOT NULL DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS keywords JSONB NOT NULL DEFAULT '[]',
      ADD COLUMN IF NOT EXISTS opportunity_score INT NOT NULL DEFAULT 0;

  As migrations 013/014/015 NÃO precisam recriar essas colunas.
  Nenhum conflito de schema detectado entre 005 e 013-015.

VERIFICAÇÃO:
  005_phase8_tables.sql já aplicada em produção (pré-requisito
  da migração 014, que adiciona project_id em content_items).
  O PRE-FLIGHT embutido no script verifica presença das 4 colunas
  antes de prosseguir (Bloco 0, secção 0E).

==================================================
MIGRATION 013 — ADD project_id TO knowledge_items
==================================================

STATUS: NOT APPLIED (bloqueio de ambiente — ver BLOQUEIO abaixo)

OPERAÇÃO:
  ALTER TABLE public.knowledge_items
    ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL;
  CREATE INDEX IF NOT EXISTS knowledge_items_project_id_idx ON public.knowledge_items(project_id);

IDEMPOTÊNCIA: SIM (IF NOT EXISTS em coluna e índice)
DESTRUIÇÃO DE DADOS: NÃO
ROLLBACK DISPONÍVEL:
  ALTER TABLE public.knowledge_items DROP COLUMN IF EXISTS project_id;
  DROP INDEX IF EXISTS knowledge_items_project_id_idx;

VALIDAÇÃO (pós-execução esperada):
  - Coluna project_id existe em knowledge_items:       PENDING
  - FK project_id → projects(id) criada:               PENDING
  - Índice knowledge_items_project_id_idx criado:      PENDING

==================================================
MIGRATION 014 — ADD project_id TO content_items
==================================================

STATUS: NOT APPLIED (bloqueio de ambiente — ver BLOQUEIO abaixo)

OPERAÇÃO:
  ALTER TABLE public.content_items
    ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL;
  CREATE INDEX IF NOT EXISTS content_items_project_id_idx ON public.content_items(project_id);

IDEMPOTÊNCIA: SIM (IF NOT EXISTS)
DESTRUIÇÃO DE DADOS: NÃO
ROLLBACK DISPONÍVEL:
  ALTER TABLE public.content_items DROP COLUMN IF EXISTS project_id;
  DROP INDEX IF EXISTS content_items_project_id_idx;

VALIDAÇÃO (pós-execução esperada):
  - Coluna project_id existe em content_items:        PENDING
  - FK project_id → projects(id) criada:              PENDING
  - Índice content_items_project_id_idx criado:       PENDING

==================================================
MIGRATION 015 — ADD project_id TO knowledge_analysis + BACKFILL
==================================================

STATUS: NOT APPLIED (bloqueio de ambiente — ver BLOQUEIO abaixo)

OPERAÇÃO:
  ALTER TABLE public.knowledge_analysis
    ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL;
  CREATE INDEX IF NOT EXISTS knowledge_analysis_project_id_idx ON public.knowledge_analysis(project_id);
  UPDATE public.knowledge_analysis ka
    SET project_id = ki.project_id
    FROM public.knowledge_items ki
    WHERE ka.knowledge_item_id = ki.id
      AND ki.project_id IS NOT NULL
      AND ka.project_id IS NULL;

IDEMPOTÊNCIA: SIM para DDL; UPDATE já idempotente (AND ka.project_id IS NULL)
DESTRUIÇÃO DE DADOS: NÃO — apenas preenchimento de coluna nullable
ROLLBACK DISPONÍVEL:
  ALTER TABLE public.knowledge_analysis DROP COLUMN IF EXISTS project_id;
  DROP INDEX IF EXISTS knowledge_analysis_project_id_idx;

BACKFILL:
  ROWS EXPECTED:  PENDING (verificável via PRE-CHECK embutido no script)
  ROWS UPDATED:   PENDING (execução não realizada neste ambiente)

VALIDAÇÃO (pós-execução esperada):
  - Coluna project_id existe em knowledge_analysis:    PENDING
  - FK project_id → projects(id) criada:              PENDING
  - Índice knowledge_analysis_project_id_idx criado:  PENDING
  - Backfill: nenhuma análise com project_id=NULL     PENDING
    quando ki.project_id IS NOT NULL

==================================================
PGRST204
==================================================

STATUS: NOT RESOLVED

CAUSA: As migrations 013/014/015 não foram aplicadas neste ambiente.
  As colunas project_id em knowledge_items, content_items e
  knowledge_analysis não existem em produção até o PO executar
  o script no Supabase Dashboard.

AÇÃO INCLUÍDA NO SCRIPT:
  Bloco 5 do script executa:
    NOTIFY pgrst, 'reload schema';
  Isso invalida o cache do PostgREST após as migrations,
  resolvendo o PGRST204 em 2-3 segundos.

==================================================
PROJECT ↔ KNOWLEDGE LINK
==================================================

STATUS: PENDING — aguarda migrations 013/014/015

APÓS AS MIGRATIONS:
  - knowledge_items.project_id → FK para projects(id) ON DELETE SET NULL
  - content_items.project_id   → FK para projects(id) ON DELETE SET NULL
  - knowledge_analysis.project_id → FK + backfill do ki.project_id

  Filtro de Cofre por projeto depende de knowledge_items.project_id.
  Enquanto as migrations não forem aplicadas, itens do Cofre
  NÃO são vinculados ao projeto correto.

==================================================
CONTENT SERVICE
==================================================

STATUS: PENDING — aguarda migrations 013/014/015

  content_items.project_id não existe em produção.
  Qualquer filtro por projeto em ContentService retorna resultado
  incorreto (todos os itens ou erro PGRST204).

==================================================
DATA LOSS
==================================================

STATUS: NENHUM RISCO DETECTADO

  - Todas as colunas são nullable (ON DELETE SET NULL)
  - Nenhuma migration DROP, TRUNCATE ou ALTER TYPE
  - Backfill da 015 preenche NULLs sem apagar dados existentes
  - IF NOT EXISTS em todos os DDL: re-executar é seguro

==================================================
BLOQUEIO TÉCNICO — POR QUE AS MIGRATIONS NÃO FORAM APLICADAS
==================================================

  AMBIENTE: Claude Code remoto (container cloud)
  PROXY: bloqueia supabase.co com 403 Forbidden
  CLI: supabase não vinculado (sem token de acesso)
  PSQL: instalado, mas sem senha de DB disponível
  CREDENCIAIS: .env.example tem ANON_KEY mas não SERVICE_ROLE ou DB_PASSWORD

  RESOLUÇÃO GERADA:
    Arquivo: docs/roadmap/MIGRATION_EXECUTION_013_014_015.sql
    Instrução: PO deve abrir Supabase Dashboard → SQL Editor,
               colar o script completo e clicar em Run.
    O script executa: pre-flight + 013 + 014 + 015 + cache reload
    + verificação final — tudo em uma execução.

==================================================
SCRIPT DE EXECUÇÃO
==================================================

  Arquivo:  docs/roadmap/MIGRATION_EXECUTION_013_014_015.sql
  Status:   PRONTO — commitado neste branch
  Uso:      Supabase Dashboard → SQL Editor → colar → Run
  Saída esperada:
    PRE-FLIGHT PASS: todas as pré-condições atendidas.
    POST-CHECK 013: PASS — project_id criada, FK OK, índice OK.
    POST-CHECK 014: PASS — project_id criada, FK OK, índice OK.
    POST-CHECK 015: PASS — project_id criada, FK OK, índice OK, backfill completo.
    SCHEMA CACHE: notificação NOTIFY pgrst reload enviada.
    Tabela de resultados: 3 linhas (uma por tabela)

==================================================
NEXT BLOCKERS
==================================================

  1. MIGRATIONS 013/014/015 (BLOQUEANTE — CRÍTICO)
     Ação: PO executar MIGRATION_EXECUTION_013_014_015.sql no Supabase Dashboard
     Sem isso: Cofre sem vínculo de projeto, PGRST204 persiste, content service incorreto

  2. DEPLOY extract-knowledge (BLOQUEANTE para ingestão por URL)
     Ação: supabase functions deploy extract-knowledge
     Sem isso: T-02 a T-06 falham (PDF, DOCX, Drive via URL, retry)

  3. SHA-1 GOOGLE DRIVE OAUTH (BLOQUEANTE para Drive login)
     Ação: PO seguir GOOGLE_DRIVE_OAUTH_FIX_INSTRUCTIONS.md
     Sem isso: Drive login retorna código 10 em todos os dispositivos

  4. APK REBUILD + DEVICE TEST (PÓS-MIGRATE)
     Após migrations e deploy: instalar APK novo no Galaxy S25 Ultra
     Testar: Cofre → novo item → URL PDF → analisar → scores preenchidos

==================================================
FINAL STATUS
==================================================

  NO-GO — BLOQUEADO

  RAZÃO:
    Migrations 013/014/015 NÃO aplicadas.
    project_id inexiste em knowledge_items, content_items, knowledge_analysis.
    Filtro de Cofre por projeto retorna dados incorretos em produção.
    PGRST204 não resolvido.

  CAMINHO PARA GO:
    1. PO executa MIGRATION_EXECUTION_013_014_015.sql no Dashboard
    2. Confirma output "PASS" nos 3 post-checks
    3. PO reporta resultado ao Claude para validação pós-apply
    4. Claude gera relatório de validação E2E
    5. Deploy extract-knowledge (RED GATE)
    6. SHA-1 Drive OAuth (RED GATE)
    7. APK rebuild + device test

  CÓDIGO PRONTO: SIM
    Todos os fixes de código estão commitados no branch.
    Aguarda apenas ações do PO nas etapas acima.

==================================================
FIM DO RELATÓRIO
==================================================
