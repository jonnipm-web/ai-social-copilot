MIGRATIONS 013 / 014 / 015 — RED GATE REVIEW
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5
Revisor: Claude Code (auditoria de código — NÃO executado em banco)

==================================================
SUMÁRIO EXECUTIVO
==================================================

  013  ADD project_id TO knowledge_items    SAFE TO APPLY
  014  ADD project_id TO content_items      SAFE TO APPLY
  015  ADD project_id TO knowledge_analysis SAFE WITH CONDITIONS

  ORDEM SEGURA:          013 → 014 → 015 (obrigatória)
  ROLLBACK DISPONÍVEL:   SIM (para todas as três)
  GO / NO-GO:            GO — aguarda apenas autorização do PO
  NOTA CRÍTICA:          015 contém UPDATE (backfill); executar DEPOIS
                         de confirmar 013 aplicada com sucesso

==================================================
SEÇÃO 1 — AUDITORIA POR MIGRATION
==================================================

──────────────────────────────────────────────────
MIGRATION 013
──────────────────────────────────────────────────

  ARQUIVO: 013_add_project_id_to_knowledge_items.sql

  PURPOSE:
    Adiciona coluna project_id à tabela knowledge_items.
    Permite filtrar ativos do Cofre de Conhecimento por projeto.
    Corrige o erro PGRST204: "Could not find the 'project_id' column
    of 'knowledge_items'" observado em produção.

  SQL (completo):
    ALTER TABLE knowledge_items
      ADD COLUMN IF NOT EXISTS project_id UUID
        REFERENCES projects(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS knowledge_items_project_id_idx
      ON knowledge_items(project_id);

  TABLES AFFECTED:
    knowledge_items (ALTER)
    (projects — apenas como referência FK, sem modificação)

  COLUMNS:
    CRIADA: project_id UUID NULL (default implícito NULL)
    FK:     REFERENCES projects(id) ON DELETE SET NULL
    NOTA:   IF NOT EXISTS garante idempotência — aplica sem erro
            se já existir

  INDEXES:
    CRIADO: knowledge_items_project_id_idx ON knowledge_items(project_id)
    IF NOT EXISTS — idempotente

  FOREIGN KEYS:
    CRIADA: project_id → projects(id) ON DELETE SET NULL
    (quando projeto é deletado, knowledge_item.project_id vira NULL —
    NÃO deleta o ativo — comportamento correto)

  RLS:
    NENHUMA policy criada ou alterada por esta migration.
    Policies existentes (ki_select_own, ki_insert_own, ki_update_own,
    ki_delete_own) continuam válidas — filtram por user_id, não por
    project_id.

  DATA TRANSFORMATION:
    NENHUM UPDATE, DELETE ou BACKFILL.
    Linhas existentes recebem project_id = NULL implicitamente.
    Ativos sem projeto continuam funcionais — campo é nullable.

  DESTRUCTIVE:
    NÃO. ADD COLUMN IF NOT EXISTS é operação additive.
    Não altera, remove ou reescreve dados existentes.

  REVERSIBLE:
    SIM.
    ROLLBACK:
      ALTER TABLE knowledge_items DROP COLUMN IF EXISTS project_id;
      (DROP INDEX é automático ao dropar a coluna)

  DEPENDENCIES:
    REQUER: tabela projects já existente (criada em 006_phase9_tables.sql)
    CÓDIGO: KnowledgeService.fetchAll(projectId) — usa .eq('project_id')
            KnowledgeService.create() — passa project_id no insert
            KnowledgeService.findBySourceUrl() — não usa project_id
            KnowledgeItemNotifier.update() — pode atualizar project_id
            knowledge_vault_screen._showProjectLinker() — faz update de
            project_id (código commit 303a3de)

  REQUIRED FOR:
    - Filtrar Cofre de Conhecimento por projeto: SIM (BLOQUEANTE)
    - Vincular ativos a projetos: SIM (BLOQUEANTE)
    - Botão "Vincular a Projeto" no card do Cofre: SIM
    - PGRST204 error removal (fetchAll com projectId): SIM
    - IVE: NÃO diretamente (mas melhora contexto)
    - Asset ingestion: NÃO bloqueante

  RISK:
    LOW
    Razão: ADD COLUMN IF NOT EXISTS é a operação PostgreSQL mais segura.
    Não há locking prolongado em tabelas grandes (operação online no
    PostgreSQL 11+). FK com ON DELETE SET NULL é convencional.

  STATUS RECOMMENDED:
    SAFE TO APPLY

──────────────────────────────────────────────────
MIGRATION 014
──────────────────────────────────────────────────

  ARQUIVO: 014_add_project_id_to_content_items.sql

  PURPOSE:
    Adiciona coluna project_id à tabela content_items (Biblioteca).
    Permite filtrar itens de biblioteca por projeto.
    Necessário para ContentService.fetchAll(projectId) e
    ContentService.upsertFromKnowledge(..., projectId) funcionarem.

  SQL (completo):
    ALTER TABLE content_items
      ADD COLUMN IF NOT EXISTS project_id UUID
        REFERENCES projects(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS content_items_project_id_idx
      ON content_items(project_id);

  TABLES AFFECTED:
    content_items (ALTER)
    (projects — apenas como referência FK)

  COLUMNS:
    CRIADA: project_id UUID NULL
    FK:     REFERENCES projects(id) ON DELETE SET NULL

  INDEXES:
    CRIADO: content_items_project_id_idx ON content_items(project_id)

  FOREIGN KEYS:
    CRIADA: project_id → projects(id) ON DELETE SET NULL

  RLS:
    NENHUMA alteração.
    Policies existentes ("content_items_own", "content_items_admin_sel")
    continuam válidas.

  DATA TRANSFORMATION:
    NENHUM. Linhas existentes recebem project_id = NULL.

  DESTRUCTIVE:
    NÃO.

  REVERSIBLE:
    SIM.
    ROLLBACK:
      ALTER TABLE content_items DROP COLUMN IF EXISTS project_id;

  DEPENDENCIES:
    REQUER: tabela content_items já existente (001_platform_schema.sql)
    REQUER: tabela projects já existente (006_phase9_tables.sql)
    NÃO depende de 013.

    CÓDIGO que depende desta coluna:
      ContentService.fetchAll({String? projectId}) — linha 13:
        query.eq('project_id', projectId)
      ContentService.upsertFromKnowledge(projectId) — linha 81:
        if (projectId != null) 'project_id': projectId
      ContentService.upsertFromProject(projectId) — linha 120:
        'project_id': projectId

    SEM 014, qualquer chamada que escreve ou lê project_id em
    content_items lançará PGRST204 ou erro de schema.

  REQUIRED FOR:
    - Biblioteca indexada por projeto: SIM (BLOQUEANTE)
    - Sync knowledge → Library com vínculo de projeto: SIM
    - Sync idea → Library (upsertFromProject): SIM
    - IVE contexto por projeto (content_items filtrado): SIM
    - Asset ingestion: NÃO bloqueante direto

  RISK:
    LOW
    Mesma análise que 013. Tabela content_items tem schema mais antigo
    (migration 001) — operação online segura.

  STATUS RECOMMENDED:
    SAFE TO APPLY

──────────────────────────────────────────────────
MIGRATION 015
──────────────────────────────────────────────────

  ARQUIVO: 015_add_project_id_to_knowledge_analysis.sql

  PURPOSE:
    Adiciona project_id à tabela knowledge_analysis.
    Permite filtrar análises por projeto SEM JOIN com knowledge_items.
    Inclui BACKFILL: propaga project_id de knowledge_items para
    knowledge_analysis onde já existe ligação.

  SQL (completo):
    ALTER TABLE knowledge_analysis
      ADD COLUMN IF NOT EXISTS project_id UUID
        REFERENCES projects(id) ON DELETE SET NULL;

    CREATE INDEX IF NOT EXISTS knowledge_analysis_project_id_idx
      ON knowledge_analysis(project_id);

    UPDATE knowledge_analysis ka
    SET    project_id = ki.project_id
    FROM   knowledge_items ki
    WHERE  ka.knowledge_item_id = ki.id
      AND  ki.project_id IS NOT NULL
      AND  ka.project_id IS NULL;

  TABLES AFFECTED:
    knowledge_analysis (ALTER + UPDATE)

  COLUMNS:
    CRIADA: project_id UUID NULL
    FK:     REFERENCES projects(id) ON DELETE SET NULL

  INDEXES:
    CRIADO: knowledge_analysis_project_id_idx

  FOREIGN KEYS:
    CRIADA: project_id → projects(id) ON DELETE SET NULL

  RLS:
    NENHUMA alteração às policies existentes.

  DATA TRANSFORMATION:
    SIM — UPDATE de backfill presente.
    Condição: propaga project_id SOMENTE para linhas onde:
      1. knowledge_item associado tem project_id NOT NULL
      2. knowledge_analysis.project_id ainda é NULL
    Efeito: análises de ativos já vinculados a projetos (após 013)
    recebem project_id por propagação.
    ESCOPO: afeta ZERO registros se 013 não foi aplicada antes
    (pois knowledge_items.project_id seria NULL para todos).

  DESTRUCTIVE:
    NÃO. UPDATE não deleta dados. SET project_id = valor derivado
    de dado existente — não altera outros campos, não apaga linhas.

  REVERSIBLE:
    SIM, com ressalva.
    ROLLBACK DDL:
      ALTER TABLE knowledge_analysis DROP COLUMN IF EXISTS project_id;
    NOTA SOBRE O BACKFILL: ao dropar a coluna, o project_id propagado
    é perdido. Porém como é campo derivado (pode ser recalculado de
    knowledge_items.project_id via JOIN), a perda é aceitável —
    pode ser replicado ao reaplicar 015.

  DEPENDENCIES:
    REQUER 013 aplicada ANTES:
      O UPDATE de backfill faz FROM knowledge_items ki WHERE ki.project_id
      IS NOT NULL. Sem 013, essa coluna não existe e a migration falhará
      com erro de coluna desconhecida.
    REQUER: tabela knowledge_analysis existente (003_knowledge_vault.sql)

    CÓDIGO que depende desta coluna:
      KnowledgeService.fetchAnalysisByProject(projectId) — linha 116:
        .eq('project_id', projectId)
        (defensivo: retorna [] se PGRST204 — já tratado)
      KnowledgeService.saveAnalysis() — linha 219 (indiretamente):
        ao salvar análise via upsert, project_id é passado de
        KnowledgeAnalysis.projectId que vem de knowledge_item.projectId

  REQUIRED FOR:
    - Filtrar análises por projeto sem JOIN: SIM (PERFORMANCE)
    - KnowledgeAnalysisNotifier.fetchAnalysisByProject: SIM
    - Tela de projeto mostrando análises dos ativos: SIM
    - IVE contexto completo por projeto: SIM
    - Asset ingestion: NÃO bloqueante

  RISK:
    MEDIUM (pelo UPDATE, não pelo DDL)
    Razão:
      O UPDATE é leve e seguro do ponto de vista lógico, mas é um
      statement de escrita. Em banco com muitas análises, pode
      causar lock breve.
      PRÉ-CHECK recomendado: contar quantas linhas serão afetadas
      antes de aplicar (query fornecida na Seção 5).
      O UPDATE só afeta análises onde ki.project_id IS NOT NULL —
      que hoje em produção provavelmente é ZERO (pois 013 não foi
      aplicada ainda, logo nenhum ki tem project_id preenchido).
      Portanto risco prático é mínimo.

  STATUS RECOMMENDED:
    SAFE WITH CONDITIONS
    Condição: aplicar APENAS APÓS 013 ter sido aplicada com sucesso.

==================================================
SEÇÃO 2 — SCHEMA REAL vs CÓDIGO
==================================================

  SCHEMA ATUAL EM PRODUÇÃO (esperado, sem migrations 013/014/015):
    knowledge_items:
      id, user_id, title, source_type, source_url, file_name,
      content, niche, target_audience, language, persona_id,
      status, created_at, updated_at,
      opportunity_score, auto_title, auto_type, auto_niche,
      auto_audience           ← adicionadas em 008
      SEM project_id          ← CAUSA DO PGRST204

    knowledge_analysis:
      id, knowledge_item_id, user_id, summary, keywords_primary,
      keywords_secondary, keywords_longtail, entities, topics,
      content_pillars, audience_pain_points, audience_desires,
      commercial_angles, ctas, campaign_ideas, post_ideas,
      article_ideas, seo_opportunities, adsense_opportunities,
      amazon_kdp_opportunities, score_seo, score_adsense,
      score_amazon_kdp, score_linkedin, score_social, score_details,
      created_at, updated_at,
      score_opportunity, score_hotmart, score_shopify,
      hotmart_data, shopify_data, persona_training ← adicionadas em 008
      SEM project_id          ← causa fetchAnalysisByProject PGRST204

    content_items:
      id, user_id, persona_id, title, type, description, base_text,
      niche, target_audience, commercial_objective, language, status,
      created_at, updated_at
      SEM project_id          ← ContentService.upsertFromKnowledge falha
      SEM knowledge_item_id   ← verificar (pode estar em outra migration)
      SEM auto_generated, keywords, opportunity_score

  DISCREPÂNCIA DETECTADA:
    ContentService.upsertFromKnowledge() usa:
      knowledge_item_id, auto_generated, keywords, opportunity_score
    Esses campos NÃO aparecem na migration 001 nem em 014.
    Verificar se existe migration específica para content_items columns.
    (Não encontrada no escopo 013-015 — possível migration anterior)

  RESPOSTA AO PGRST204:
    A. project_id em knowledge_items → CRIADO pela 013 (CONFIRMADO)
    B. join table many-to-many → NÃO. A arquitetura usa FK direta
       project_id UUID nas tabelas filho. Não há tabela intermediária
       nas migrations 013/014/015.
    C. Código depende de project_id? SIM — em 4 serviços:
       KnowledgeService, ContentService, knowledge_vault_screen,
       project_command_center_screen
    D. Conflito com arquitetura canônica ASSET CANÔNICO →
       PROJECTS → MANY-TO-MANY?
       NÃO HÁ CONFLITO.
       A arquitetura das migrations 013/014/015 usa FK direta
       (knowledge_item → project, 1:N), não many-to-many.
       A tabela `assets` (migration 022, ainda proposta) é uma entidade
       separada com relação direta a projects. As duas arquiteturas
       coexistem sem conflito:
         knowledge_items.project_id = link "item pertence a projeto" (1:N)
         assets = entidade de primeiro nível (architecture nova, 022+)
         Não há substituição — são camadas distintas.

==================================================
SEÇÃO 3 — MIGRATIONS OBSOLETAS?
==================================================

  013 — NÃO É OBSOLETA.
    O código atual usa explicitamente knowledge_items.project_id.
    A feature "Vincular a Projeto" no Cofre depende desta coluna.
    A arquitetura nova (022+ assets) não substitui essa FK —
    são dois níveis de granularidade diferentes.
    VEREDICTO: NECESSÁRIA.

  014 — NÃO É OBSOLETA.
    ContentService usa project_id em content_items ativamente.
    upsertFromProject() escreve project_id.
    upsertFromKnowledge() propaga project_id do item de origem.
    VEREDICTO: NECESSÁRIA.

  015 — NÃO É OBSOLETA.
    KnowledgeService.fetchAnalysisByProject() usa project_id.
    Sem ela, o fetch retorna [] (fallback defensivo) mas o filtro
    nunca funciona de verdade.
    O backfill é correto: deriva o valor de ki.project_id que 013 criou.
    VEREDICTO: NECESSÁRIA. SAFE WITH CONDITIONS (requer 013 primeiro).

==================================================
SEÇÃO 4 — ORDEM SEGURA DE APLICAÇÃO
==================================================

  ORDEM OBRIGATÓRIA:

    013 → 014 → 015

  JUSTIFICATIVA:
    013: cria knowledge_items.project_id — deve ser a PRIMEIRA.
         Sem ela, 015 falhará no UPDATE de backfill (FROM knowledge_items
         ki WHERE ki.project_id IS NOT NULL — coluna inexistente).

    014: independente de 013, mas faz sentido aplicar junto.
         content_items.project_id não tem dependência com 013.

    015: DEPENDE de 013 estar aplicada.
         O UPDATE de backfill lê knowledge_items.project_id.
         Se 013 não foi aplicada: ERRO de coluna desconhecida no UPDATE.
         Alternativa segura: aplicar 015 SOMENTE após confirmar 013 com
         o pré-check da Seção 5.

  POSSO APLICAR 014 E 013 EM PARALELO?
    Tecnicamente SIM — são tabelas diferentes sem dependência entre si.
    Por segurança e rastreabilidade, aplicar sequencialmente.

==================================================
SEÇÃO 5 — PRÉ-CHECKS (queries de validação)
==================================================

  ANTES DE APLICAR QUALQUER MIGRATION, executar no Supabase SQL Editor:

  ── PRÉ-CHECK GERAL ─────────────────────────────────────────────

  -- 1. Verificar se tabelas existem
  SELECT table_name, table_type
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('knowledge_items', 'knowledge_analysis', 'content_items', 'projects')
  ORDER BY table_name;
  -- Esperado: 4 linhas com TABLE_TYPE = 'BASE TABLE'

  -- 2. Verificar schema atual de knowledge_items
  SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'knowledge_items'
  ORDER BY ordinal_position;
  -- Confirmar: project_id NÃO existe ainda (migration 013 não aplicada)
  -- Após 013: project_id EXISTE com data_type = 'uuid', is_nullable = 'YES'

  -- 3. Verificar schema atual de knowledge_analysis
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'knowledge_analysis'
  ORDER BY ordinal_position;
  -- Confirmar: project_id NÃO existe (migration 015 não aplicada)

  -- 4. Verificar schema atual de content_items
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'content_items'
  ORDER BY ordinal_position;
  -- Confirmar: project_id NÃO existe (migration 014 não aplicada)

  ── PRÉ-CHECK 013 ────────────────────────────────────────────────

  -- 5. Contar knowledge_items existentes (auditoria de volume)
  SELECT COUNT(*) AS total_knowledge_items FROM knowledge_items;

  -- 6. Verificar FK de destino (tabela projects) existe
  SELECT COUNT(*) AS total_projects FROM projects;
  -- Deve retornar > 0 ou ao menos ser acessível

  -- 7. Verificar se project_id já existe em knowledge_items (idempotência)
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_items'
    AND column_name  = 'project_id';
  -- 0 = pode aplicar 013
  -- 1 = coluna já existe, IF NOT EXISTS evita erro mas verificar FK

  ── PRÉ-CHECK 014 ────────────────────────────────────────────────

  -- 8. Contar content_items existentes
  SELECT COUNT(*) AS total_content_items FROM content_items;

  -- 9. Verificar se project_id já existe em content_items
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'content_items'
    AND column_name  = 'project_id';
  -- 0 = pode aplicar 014

  ── PRÉ-CHECK 015 (CRÍTICO — verificar antes do UPDATE) ──────────

  -- 10. Confirmar 013 aplicada (PRÉ-REQUISITO de 015)
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_items'
    AND column_name  = 'project_id';
  -- DEVE retornar 1. Se retornar 0: NÃO aplicar 015.

  -- 11. Quantas linhas o UPDATE de backfill afetará?
  SELECT COUNT(*) AS linhas_a_atualizar
  FROM knowledge_analysis ka
  JOIN knowledge_items ki ON ka.knowledge_item_id = ki.id
  WHERE ki.project_id IS NOT NULL
    AND ka.project_id IS NULL;
  -- Esperado em produção atual: 0 (pois 013 não aplicada ainda)
  -- Se > 0: revisar antes de confirmar

  -- 12. Verificar se project_id já existe em knowledge_analysis
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_analysis'
    AND column_name  = 'project_id';
  -- 0 = pode aplicar 015

==================================================
SEÇÃO 6 — PÓS-CHECKS (após cada migration)
==================================================

  ── APÓS 013 ─────────────────────────────────────────────────────

  -- A. Confirmar coluna criada
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_items'
    AND column_name  = 'project_id';
  -- Esperado: 1 linha, data_type='uuid', is_nullable='YES'

  -- B. Confirmar FK criada
  SELECT
    tc.constraint_name,
    ccu.table_name  AS foreign_table,
    rc.delete_rule
  FROM information_schema.table_constraints tc
  JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
  JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
  WHERE tc.table_name = 'knowledge_items'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND ccu.column_name = 'project_id';
  -- Esperado: 1 linha, foreign_table='projects', delete_rule='SET NULL'

  -- C. Confirmar índice criado
  SELECT indexname, indexdef
  FROM pg_indexes
  WHERE tablename = 'knowledge_items'
    AND indexname  = 'knowledge_items_project_id_idx';
  -- Esperado: 1 linha

  -- D. Confirmar dados preservados
  SELECT COUNT(*) FROM knowledge_items;
  -- Deve bater com o total do pré-check 5

  -- E. Confirmar PostgREST cache reconhece a nova coluna
  --    (executar uma query simples via cliente da app ou REST direto)
  SELECT id, project_id FROM knowledge_items LIMIT 1;
  -- Se retornar PGRST204: invalidar cache PostgREST (NOTIFY pgrst, 'reload schema')

  ── APÓS 014 ─────────────────────────────────────────────────────

  -- F. Confirmar coluna criada
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'content_items'
    AND column_name  = 'project_id';
  -- Esperado: 1 linha

  -- G. Confirmar índice criado
  SELECT indexname FROM pg_indexes
  WHERE tablename = 'content_items'
    AND indexname  = 'content_items_project_id_idx';

  -- H. Dados preservados
  SELECT COUNT(*) FROM content_items;
  -- Deve bater com pré-check 8

  ── APÓS 015 ─────────────────────────────────────────────────────

  -- I. Confirmar coluna criada
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'knowledge_analysis'
    AND column_name  = 'project_id';

  -- J. Verificar resultado do backfill
  SELECT COUNT(*) AS analises_com_projeto
  FROM knowledge_analysis
  WHERE project_id IS NOT NULL;
  -- Esperado hoje: 0 (pois 013 acabou de ser aplicada e nenhum
  -- knowledge_item tem project_id preenchido ainda pelo usuário)

  -- K. Verificar linkage funcionando (JOIN entre as 3 tabelas)
  SELECT
    ki.title          AS item_title,
    ki.project_id     AS item_project_id,
    ka.project_id     AS analysis_project_id,
    p.name            AS project_name
  FROM knowledge_items ki
  JOIN knowledge_analysis ka ON ka.knowledge_item_id = ki.id
  LEFT JOIN projects p       ON p.id = ki.project_id
  LIMIT 5;
  -- Confirma que knowledge_analysis.project_id = knowledge_items.project_id
  -- após o usuário vincular um ativo a um projeto

  -- L. Invalidar cache PostgREST
  NOTIFY pgrst, 'reload schema';
  -- Executar APÓS todas as migrations para garantir que o cliente
  -- Flutter (via Supabase) reconheça as novas colunas imediatamente

==================================================
SEÇÃO 7 — ROLLBACK COMPLETO
==================================================

  ROLLBACK 015 (executar primeiro se aplicada):
    ALTER TABLE knowledge_analysis DROP COLUMN IF EXISTS project_id;
    DROP INDEX IF EXISTS knowledge_analysis_project_id_idx;
    -- O backfill é revertido implicitamente (coluna removida)

  ROLLBACK 014:
    ALTER TABLE content_items DROP COLUMN IF EXISTS project_id;
    DROP INDEX IF EXISTS content_items_project_id_idx;

  ROLLBACK 013 (executar por último):
    ALTER TABLE knowledge_items DROP COLUMN IF EXISTS project_id;
    DROP INDEX IF EXISTS knowledge_items_project_id_idx;
    -- IMPORTANTE: dropar 013 antes de 015 não é possível se 015
    -- ainda existir (FK de ka.project_id para projects não depende
    -- de ki.project_id, mas a FK do UPDATE sim).
    -- Na prática: dropar na ordem inversa: 015 → 014 → 013.

==================================================
RESUMO FINAL
==================================================

  013 — ADD project_id TO knowledge_items
    Status:      SAFE TO APPLY
    Risk:        LOW
    Destructive: NÃO
    Reversible:  SIM
    Nota:        Resolve PGRST204. Deve ser a PRIMEIRA.

  014 — ADD project_id TO content_items
    Status:      SAFE TO APPLY
    Risk:        LOW
    Destructive: NÃO
    Reversible:  SIM
    Nota:        Independente de 013. Aplicar junto.

  015 — ADD project_id TO knowledge_analysis + BACKFILL
    Status:      SAFE WITH CONDITIONS
    Risk:        MEDIUM (UPDATE presente)
    Destructive: NÃO
    Reversible:  SIM (backfill recalculável)
    Nota:        Aplicar SOMENTE após 013. Executar pré-check 10
                 e 11 antes. Esperar 0 linhas afetadas hoje.

  RECOMMENDED ACTION:
    Aplicar 013, 014 e 015 sequencialmente no Supabase Dashboard.
    Usar o SQL Editor: Dashboard → SQL Editor → colar SQL → Run.
    Executar pré-checks da Seção 5 antes.
    Executar pós-checks da Seção 6 depois.
    Executar NOTIFY pgrst, 'reload schema' ao final.

  SAFE ORDER:
    013 → 014 → 015

  ROLLBACK AVAILABLE:
    SIM — para todas as três, na ordem inversa: 015 → 014 → 013

  GO / NO-GO PARA APLICAR:
    GO — migrations são seguras, não destrutivas e necessárias.
    Aguardam apenas autorização e janela de manutenção do PO.
    NÃO HÁ CONFLITO com a arquitetura canônica (assets/022+).
    NÃO HÁ MIGRATION OBSOLETA — todas as três são necessárias para
    o código atual do branch.

==================================================
NÃO EXECUTAR.
Aguardar autorização explícita do Product Owner.
==================================================
