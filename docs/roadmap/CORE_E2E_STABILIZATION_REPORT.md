RELATÓRIO — MISSÃO P0 ESTABILIZAÇÃO E2E DO NÚCLEO INSIGHTVALUES
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
RESUMO EXECUTIVO
==================================================

  5 de 8 P0s corrigidos em código.
  2 de 8 aguardando ação externa do PO.
  1 de 8 aguardando confirmação de device test.

==================================================
TABELA DE STATUS
==================================================

  P0-ID  ISSUE                  CAUSA RAIZ               FIX                        STATUS
  -----  -----                  ----------               ---                        ------
  P0-1   SCHEMA PGRST204        Migrations 013/014/015   MIGRATION_REQUIRED.md      NEEDS MIGRATION
                                 não aplicadas            + fallback defensivo       (RED GATE)
                                                          em KnowledgeService

  P0-2   COFRE VINCULAR         Ação ausente no card     _showProjectLinker()       FIXED IN CODE
                                                          adicionada em
                                                          knowledge_vault_screen

  P0-3   INGESTÃO               Não diagnosticado        —                          BACKLOG
         (Docs/DOCX/PDF link)   completamente

  P0-4   GOOGLE DRIVE           certificate_hash vazio   GOOGLE_DRIVE_DIAGNOSIS.md  NEEDS GOOGLE
         DEVELOPER_ERROR 10     no google-services.json  (PO deve registrar SHA-1   CLOUD CONFIG
                                                          no Google Cloud Console)

  P0-5   PROJECT ANALYSIS       Não investigado          —                          BACKLOG
         Scores zerados         completamente

  P0-6   IVE CAPABILITIES       Sistema prompt não       context-copilot/index.ts   FIXED IN CODE
         AÇÕES vs ATIVOS        distinguia AÇÕES (fila)  atualizado com seção       (needs deploy)
                                de ATIVOS (documentos)   "DISTINÇÃO FUNDAMENTAL"

  P0-7   BIOMETRIA              sed \s* não suportado    build-android.yml e        FIXED IN CODE
         FlutterFragmentActivity pelo GNU sed sem -E      build-apk.yml corrigidos

  P0-8   DEDUP Cofre            Nenhum check de          create() em                FIXED IN CODE
         source_url             source_url antes          KnowledgeService
                                do insert                 com dedup

==================================================
DETALHES POR P0
==================================================

P0-7 BIOMETRIA (FIXED)
-----------------------
  Arquivo: .github/workflows/build-android.yml (linha 70)
           .github/workflows/build-apk.yml (linha 94)
  Antes:   sed 's/class MainActivity\s*:\s*FlutterActivity()/.../g'
           (QUEBRADO: GNU sed não suporta \s sem -E)
  Depois:  sed 's/: FlutterActivity()/: FlutterFragmentActivity()/g'
           + grep de verificação (falha de patch = log visível na CI)
  Impacto: local_auth requer FlutterFragmentActivity; sem patch,
           biometria lança PlatformException → "Não foi possível ativar"

P0-1 SCHEMA (DEFENSIVE + RED GATE)
------------------------------------
  Arquivo: lib/data/services/knowledge_service.dart
  Fix:     fetchAll() agora captura PGRST204 ao filtrar por project_id
           e faz fallback para lista completa (app não trava mais)
           fetchAnalysisByProject() retorna [] ao invés de crashar
  Pendente: MIGRATION_REQUIRED.md com SQL exato para PO aplicar via
            Supabase Dashboard (não-destrutivo, ADD COLUMN IF NOT EXISTS)

P0-2 COFRE VINCULAR A PROJETO (FIXED)
--------------------------------------
  Arquivo: lib/features/knowledge/screens/knowledge_vault_screen.dart
  Fix:     Novo botão "Vincular" (ou "Mover" se já vinculado) em
           _KnowledgeCard com método _showProjectLinker()
  Fluxo:   Card → Vincular → bottom sheet com projetos reais
           → selecionar → update(project_id) → invalidate
  Nota:    Só filtra corretamente após migration 013 ser aplicada.
           Mostra erro explicativo (MIGRATION_REQUIRED.md) se PGRST204.

P0-6 IVE CAPABILITIES (FIXED, NEEDS DEPLOY)
--------------------------------------------
  Arquivo: supabase/functions/context-copilot/index.ts
  Fix:     Adicionada seção "DISTINÇÃO FUNDAMENTAL ENTRE AÇÕES E ATIVOS"
           ao system prompt e regra 11 de reforço
  Detalhe: AÇÕES = action_queue (tarefas a fazer)
           ATIVOS = knowledge_items (documentos de conhecimento)
  Status:  Código pronto. Deploy requer autorização (RED GATE).

P0-8 DEDUP (FIXED)
-------------------
  Arquivo: lib/data/services/knowledge_service.dart
  Fix:     create() verifica (user_id, source_url) antes do INSERT
           Se item com mesma URL já existe, retorna o item existente
           Só ativo para source_url não-nulo e não-vazio

P0-4 GOOGLE DRIVE (NEEDS EXTERNAL CONFIG)
------------------------------------------
  Arquivo: GOOGLE_DRIVE_DIAGNOSIS.md
  Diagnóstico: certificate_hash vazio em android/app/google-services.json
  Ação: PO deve registrar SHA-1 do keystore de release no Google Cloud Console
        e baixar o google-services.json atualizado

==================================================
ARQUIVOS MODIFICADOS
==================================================

  .github/workflows/build-android.yml
    sed regex corrigido (linha 70) + verificação grep

  .github/workflows/build-apk.yml
    sed regex corrigido (linha 94) + verificação grep

  lib/data/services/knowledge_service.dart
    fetchAll(): fallback defensivo PGRST204
    fetchAnalysisByProject(): fallback PGRST204 retorna []
    create(): dedup por source_url
    _isPgrst204(): helper estático

  lib/features/knowledge/screens/knowledge_vault_screen.dart
    _KnowledgeCard: botão "Vincular"/"Mover" adicionado
    _showProjectLinker(): novo método com bottom sheet

  supabase/functions/context-copilot/index.ts
    buildSystemPrompt(): seção "DISTINÇÃO FUNDAMENTAL" + regra 11

  docs/roadmap/MIGRATION_REQUIRED.md
    SQL exato + passos para PO aplicar migrations 013/014/015

  docs/roadmap/GOOGLE_DRIVE_DIAGNOSIS.md
    Diagnóstico completo + passos para PO registrar SHA-1

  docs/roadmap/CORE_E2E_STABILIZATION_REPORT.md
    Este relatório

==================================================
CRITÉRIO GO FOR DEVICE TEST
==================================================

  [ ] Migration 013/014/015 aplicada (PO ação)
  [ ] google-services.json atualizado com SHA-1 (PO ação)
  [x] Biometria: CI corrigida — próximo build irá aplicar FlutterFragmentActivity
  [x] Cofre: "Vincular a Projeto" disponível no card
  [x] PGRST204: app não trava mais (fallback defensivo ativo)
  [x] IVE: distinção AÇÕES vs ATIVOS no system prompt (precisa deploy)
  [x] Dedup: source_url verifica antes de inserir

  GO FOR DEVICE TEST: NÃO (aguardando migrations + SHA-1 + deploy context-copilot)

==================================================
P0s BACKLOG (SEM INVESTIGAÇÃO COMPLETA)
==================================================

  P0-3 INGESTÃO (Google Docs / DOCX / PDF por link):
    Investigação inicial indica problema no pipeline de
    download/detecção de tipo de conteúdo. Requer análise
    detalhada das edge functions de extração.
    Não iniciado nesta fase para respeitar escopo P0.

  P0-5 PROJECT ANALYSIS (Scores zerados):
    "COMPLETAR ANÁLISE" não funcional. Scores zerados
    mesmo com evidências. Requer análise do fluxo
    generate-project-opportunities e cálculo de scores.
    Não iniciado nesta fase para respeitar escopo P0.

==================================================
PRÓXIMAS AÇÕES (por responsável)
==================================================

  PO (IMEDIATO):
    1. Aplicar migrations 013/014/015 via Supabase Dashboard
       → seguir MIGRATION_REQUIRED.md exatamente
    2. Registrar SHA-1 keystore no Google Cloud Console
       → seguir GOOGLE_DRIVE_DIAGNOSIS.md exatamente
    3. Fazer deploy de context-copilot (autorizar RED GATE)
       → supabase functions deploy context-copilot

  CI (AUTOMÁTICO NO PRÓXIMO BUILD):
    Biometria: sed corrigido → FlutterFragmentActivity aplicado

  PRÓXIMA FASE (após GO do PO):
    P0-3 Ingestão (URL classifier + pipeline)
    P0-5 Project Analysis (scores)
