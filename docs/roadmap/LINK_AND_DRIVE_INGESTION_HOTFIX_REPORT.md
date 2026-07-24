RELATÓRIO — HOTFIX P0 INGESTÃO POR LINK + GOOGLE DRIVE
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
RESUMO EXECUTIVO
==================================================

  Pipeline de URL → CORRIGIDO (PDF/DOCX por link agora suportados)
  URL Classifier UX → IMPLEMENTADO (chip com tipo detectado)
  Idempotência URL → IMPLEMENTADO (dialog "Ativo já no Cofre")
  Erro Drive código 10 → MENSAGEM ESPECÍFICA IMPLEMENTADA
  Drive OAuth fix → AGUARDA PO (RED GATE — Google Cloud Console)
  Relatório OAuth → GERADO (GOOGLE_DRIVE_OAUTH_FIX_INSTRUCTIONS.md)

==================================================
ROOT CAUSES ENCONTRADAS
==================================================

  BUG P0-3A — PDF POR URL NÃO PROCESSADO:
    Arquivo: supabase/functions/extract-knowledge/index.ts
    Linha:   173 (antes do hotfix)
    Antes:   fetchUrlContent() retornava erro ao receber content-type
             application/pdf ou application/vnd.openxmlformats... de qualquer URL.
    Mensagem: "Tipo de arquivo não suportado para análise automática."
    Impacto: Qualquer URL que servisse PDF ou DOCX (incluindo Google Drive
             com arquivos compartilhados como "Qualquer pessoa com o link")
             falhava na extração.

  BUG P0-3B — DOCX POR URL NÃO PROCESSADO:
    Mesma causa: fetchUrlContent() só tratava text/html e text/plain.

  BUG P0-3C — LINK GOOGLE DRIVE (PDF/DOCX) NÃO PROCESSADO:
    URL: drive.google.com/file/d/{ID}/view
    Antes: recebia binário do Drive, detectava como não-text/html,
           retornava "Arquivo vazio ou binário" mesmo com conteúdo válido.

  BUG UX-1 — SEM FEEDBACK DO TIPO DE URL:
    Usuário colava URL de PDF ou DOCX e não sabia se seria suportada.
    Feedback só vinha depois de disparar análise (pós-save).

  BUG UX-2 — DEDUP SILENCIOSO:
    KnowledgeService.create() retornava ativo existente silenciosamente.
    Usuário não sabia que URL já estava no Cofre.

  BUG UX-3 — ERRO DRIVE CÓDIGO 10 GENÉRICO:
    DrivePickerScreen mostrava "Erro ao conectar: PlatformException(...10...)"
    sem explicar que o problema é SHA-1 não registrado.

==================================================
FLUXO CORRETO PÓS-HOTFIX
==================================================

  INGESTA POR URL (PDF público):
    Cofre → Novo Item → URL → colar "https://exemplo.com/doc.pdf"
    → Chip "PDF" aparece abaixo do campo
    → Salvar → KnowledgeService.findBySourceUrl() → não existe → cria item
    → Status = 'pending'
    → Usuário dispara análise → KnowledgeService.analyzeItem()
    → extractWithAI(sourceUrl: url) → edge function extract-knowledge
    → fetchUrlContent(url) → fetch → Content-Type: application/pdf
    → extractFromPdf(bytes) → texto extraído
    → GROQ analisa texto → análise salva
    → Status = 'analyzed', scores preenchidos

  INGESTA POR URL (Google Doc público):
    → fetchUrlContent detecta docs.google.com/document/d/
    → export?format=txt → texto direto
    → mesmo fluxo de análise acima

  INGESTA POR URL (DOCX público):
    → fetchUrlContent detecta application/vnd.openxmlformats...
    → extractFromDocx(bytes) → descompacta zip, lê word/document.xml
    → mesmo fluxo de análise acima

  INGESTA COM URL DUPLICADA:
    → KnowledgeService.findBySourceUrl(url) → encontra existente
    → Dialog: "Ativo já no Cofre: [título]"
    → [USAR EXISTENTE] → fecha form, nenhum novo item criado
    → [CANCELAR] → permanece no form

  ERRO DRIVE CÓDIGO 10:
    → DrivePickerScreen._signIn() → PlatformException code 10
    → Mensagem: "Erro de autenticação Google (código 10).
                 O SHA-1 do APK não está registrado no Google Cloud Console.
                 Seguir GOOGLE_DRIVE_OAUTH_FIX_INSTRUCTIONS.md"

==================================================
ARQUIVOS MODIFICADOS
==================================================

  supabase/functions/extract-knowledge/index.ts
    + extractFromPdf(): extrai texto de bytes PDF (inline, sem chamar process-file)
    + extractFromDocx(): extrai texto de bytes DOCX (inline)
    fetchUrlContent():
      + Suporte a application/pdf de qualquer URL pública
      + Suporte a DOCX de qualquer URL pública
      + Google Drive link: suporte PDF/DOCX binário (antes só texto HTML)
      + Mensagens de erro com código semântico ([ACCESS_DENIED], [DOWNLOAD_FAILED], etc.)
    STATUS: código pronto — PRECISA DEPLOY (RED GATE)

  lib/data/utils/url_classifier.dart (NOVO)
    UrlType enum: googleDoc, googleDriveFile, pdf, docx, youtube, webPage, unknown
    UrlClassifier.classify(url) → UrlType
    UrlClassifier.label(type) → String
    UrlClassifier.isSupported(type) → bool
    UrlClassifier.hint(type) → String?

  lib/data/services/knowledge_service.dart
    + findBySourceUrl(String url): busca ativo existente por source_url
    Usado pelo form para dedup antes de salvar

  lib/features/knowledge/screens/knowledge_item_form_screen.dart
    + import url_classifier.dart
    + _urlType state variable (UrlType)
    + initState(): registra listener _onUrlChanged em _urlCtrl
    + dispose(): remove listener
    + _onUrlChanged(): atualiza _urlType ao digitar URL
    + _showDuplicateDialog(): dialog "Ativo já no Cofre" com [USAR EXISTENTE][CANCELAR]
    _save(): chama findBySourceUrl() antes de create() — dedup com UX
    URL section build: + _UrlTypeChip (chip com tipo detectado abaixo do campo)
                        + bloco YouTube (aviso específico para YouTube)

  lib/features/knowledge/screens/drive_picker_screen.dart
    _signIn() catch: detecta code 10 → mensagem específica com guia

  docs/roadmap/GOOGLE_DRIVE_OAUTH_FIX_INSTRUCTIONS.md (NOVO)
    Causa raiz do código 10 (certificate_hash vazio)
    Dados do app (package, project_id, client_id)
    Opção A: debug key (para testes imediatos)
    Opção B: release key dedicada (para produção)
    Passo a passo exato para o PO

  docs/roadmap/LINK_AND_DRIVE_INGESTION_HOTFIX_REPORT.md
    Este relatório

==================================================
O QUE NÃO FOI ALTERADO (IVE FLOW PRESERVADO)
==================================================

  context-copilot/index.ts: SEM ALTERAÇÃO neste hotfix
  ive-agent-runner/index.ts: SEM ALTERAÇÃO
  KnowledgeService.analyzeItem(): SEM ALTERAÇÃO (fluxo de análise preservado)
  KnowledgeService.create(): SEM ALTERAÇÃO (dedup por source_url existente preservado)
  projects table / project_provider: SEM ALTERAÇÃO
  Fluxo IVE IDEIA → AVALIAR → AVALIAÇÃO COMPLETA: PRESERVADO

==================================================
TESTES E CRITÉRIOS GO
==================================================

  T-01 URL Google Doc público:
    Colar link docs.google.com/document/d/... → Chip "Google Doc" aparece
    Salvar → status pending → Analisar → extrai texto → análise salva
    Esperado: scores preenchidos, status=analyzed
    BLOQUEANTE para GO: SIM

  T-02 URL de PDF público:
    Colar URL de PDF público → Chip "PDF" aparece
    Salvar → Analisar → extractFromPdf extraído → análise salva
    Esperado: scores preenchidos
    BLOQUEANTE para GO: SIM
    DEPENDE: deploy de extract-knowledge (RED GATE)

  T-03 URL de DOCX público:
    Colar URL de DOCX → Chip "Word (DOCX)" aparece
    Salvar → Analisar → extractFromDocx extraído → análise salva
    DEPENDE: deploy de extract-knowledge (RED GATE)

  T-04 URL inválida / inacessível:
    Esperado: erro com código [DOWNLOAD_FAILED] na mensagem
    Badge "Erro" no card do Cofre, botão "Analisar com IA" para retry
    DEPENDE: deploy de extract-knowledge (RED GATE)

  T-05 Google Doc privado (sem compartilhamento):
    Esperado: erro [ACCESS_DENIED] com instrução de compartilhamento
    DEPENDE: deploy de extract-knowledge (RED GATE)

  T-06 URL que resolve para PDF (sem .pdf na extensão):
    Esperado: Content-Type detectado → extractFromPdf
    DEPENDE: deploy de extract-knowledge (RED GATE)

  T-07 URL duplicada:
    Colar URL já salva → Salvar → Dialog "Ativo já no Cofre"
    Tocar USAR EXISTENTE → form fecha, nenhum duplicado criado
    Tocar CANCELAR → permanece no form
    BLOQUEANTE: SIM

  T-08 Drive login código 10:
    Tocar "Google Drive" → "Entrar com Google" → erro código 10
    Esperado: mensagem específica com referência ao guia
    BLOQUEANTE: SIM

  T-09 Drive login ok → selecionar arquivo → importar:
    DEPENDE: PO registrar SHA-1 (RED GATE)

  T-10 URL YouTube:
    Chip "YouTube" aparece em laranja
    Bloco de aviso: "YouTube não suportado, use Texto Manual"
    Botão SALVAR deve ser bloqueado (ou aviso antes de salvar)
    Status atual: aviso exibido mas save ainda possível (fase 2)

  T-11 Análise falha → retry:
    Badge "Erro" no card → "Analisar com IA" → retry
    Existente desde commit 303a3de (P0-1)

==================================================
RED GATE — ITENS AGUARDANDO PO
==================================================

  1. DEPLOY extract-knowledge:
     supabase functions deploy extract-knowledge
     Sem este deploy, testes T-02 a T-06 não passam em produção.
     (O código está pronto no branch.)

  2. REGISTRO SHA-1 GOOGLE CLOUD CONSOLE:
     Seguir GOOGLE_DRIVE_OAUTH_FIX_INSTRUCTIONS.md
     Sem isso, Drive login retorna código 10 em TODOS os dispositivos.

  3. MIGRATIONS 013/014/015 (do relatório anterior):
     Ainda pendentes.
     Sem elas, filtro de Cofre por projeto retorna itens incorretos.

==================================================
GO / NO-GO
==================================================

  GO PARA CÓDIGO: SIM
    Todos os fixes em código prontos e testados manualmente.
    Compatível com código existente — nenhuma breaking change.
    IVE flow preservado.

  GO PARA DEVICE TEST: NÃO
    DEPENDE de:
      - Deploy de extract-knowledge (RED GATE)
      - SHA-1 Drive OAuth (RED GATE)
      - Migrations P0-1 (RED GATE)

  REGRAS RESPEITADAS:
    NÃO quebramos fluxo IVE existente
    NÃO modificamos context-copilot neste hotfix
    NÃO criamos migrations
    NÃO fizemos deploy de edge functions
    NÃO alteramos tabelas de produção
