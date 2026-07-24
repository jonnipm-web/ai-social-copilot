P0 DATABASE MIGRATION EXECUTION REPORT
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5
Execução: PO via Supabase Dashboard → SQL Editor
Validação: Claude (análise de screenshots pós-execução)

==================================================
SCHEMA PRE-FLIGHT
==================================================

STATUS: PASS

TABELAS VERIFICADAS:
  projects            EXISTE
  knowledge_items     EXISTE
  content_items       EXISTE
  knowledge_analysis  EXISTE
  migration 005       APLICADA (4 colunas em content_items confirmadas)

==================================================
CONTENT_ITEMS DISCREPANCY
==================================================

STATUS: RESOLVED

  Colunas knowledge_item_id, auto_generated, keywords, opportunity_score
  adicionadas pela migration 005 (005_phase8_tables.sql).
  Sem conflito com migrations 013/014/015.

==================================================
MIGRATION 013 — ADD project_id TO knowledge_items
==================================================

STATUS:     APPLIED
VALIDAÇÃO:  PASS

  Coluna project_id (uuid, nullable):  CRIADA
  FK project_id → projects(id):        CRIADA  (ON DELETE SET NULL)
  Índice knowledge_items_project_id_idx: CRIADO

==================================================
MIGRATION 014 — ADD project_id TO content_items
==================================================

STATUS:     APPLIED
VALIDAÇÃO:  PASS

  Coluna project_id (uuid, nullable):  CRIADA
  FK project_id → projects(id):        CRIADA  (ON DELETE SET NULL)
  Índice content_items_project_id_idx: CRIADO

==================================================
MIGRATION 015 — ADD project_id TO knowledge_analysis + BACKFILL
==================================================

STATUS:        APPLIED
VALIDAÇÃO:     PASS

  Coluna project_id (uuid, nullable):           CRIADA
  FK project_id → projects(id):                 CRIADA  (ON DELETE SET NULL)
  Índice knowledge_analysis_project_id_idx:     CRIADO
  Backfill (analises_sem_project_id_pendentes): 0  (COMPLETO)

==================================================
PGRST204
==================================================

STATUS: RESOLVED

  NOTIFY pgrst, 'reload schema' executado ao final do script.
  PostgREST recarregou schema cache.
  Colunas project_id visíveis para queries via API REST.

==================================================
PROJECT ↔ KNOWLEDGE LINK
==================================================

STATUS: PASS

  knowledge_items.project_id     → FK para projects(id) ON DELETE SET NULL
  content_items.project_id       → FK para projects(id) ON DELETE SET NULL
  knowledge_analysis.project_id  → FK para projects(id) ON DELETE SET NULL + backfill completo

  Filtro de Cofre por projeto agora funcionará corretamente.

==================================================
CONTENT SERVICE
==================================================

STATUS: PASS (estrutura pronta)

  content_items.project_id existe em produção.
  ContentService pode filtrar por projeto sem erro PGRST204.

==================================================
DATA LOSS
==================================================

STATUS: NENHUM

  Todas as colunas adicionadas como nullable.
  Nenhum dado existente foi removido ou alterado.
  Backfill apenas preencheu NULLs com valores corretos.

==================================================
NEXT BLOCKERS
==================================================

  1. DEPLOY extract-knowledge (BLOQUEANTE para ingestão por URL)
     Ação: supabase functions deploy extract-knowledge
     Sem isso: PDF/DOCX por URL não processados (T-02 a T-06 falham)

  2. SHA-1 GOOGLE DRIVE OAUTH (BLOQUEANTE para Drive login)
     Ação: PO seguir GOOGLE_DRIVE_OAUTH_FIX_INSTRUCTIONS.md
     Sem isso: Drive login retorna código 10

  3. APK REBUILD + DEVICE TEST
     Após deploy e SHA-1: instalar APK novo no Galaxy S25 Ultra
     Testar: Cofre → novo item → URL PDF → analisar → scores preenchidos
     Testar: Cofre filtrado por projeto → itens corretos

==================================================
FINAL STATUS
==================================================

  GO PARA BANCO DE DADOS: SIM

  Migrations 013, 014 e 015 aplicadas e validadas em produção.
  Schema atualizado. PGRST204 resolvido. Backfill completo.

  PRÓXIMO PASSO: Deploy de extract-knowledge (RED GATE — aguarda PO)

==================================================
FIM DO RELATÓRIO
==================================================
