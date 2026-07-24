RELATÓRIO — ENTITY LIFECYCLE / ANALYSIS FAILURE HOTFIX
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
ROOT CAUSE
==================================================

BUG 1 — STATUS INCORRETO PARA PROJETOS REAIS:
  Arquivo: project_command_center_screen.dart, _save() — linha 70
  Antes:   'status': 'idea'  (hardcoded para TODOS, inclusive projetos reais)
  Depois:  'status': _isIdeaMode ? 'idea' : 'active'

  Consequência do bug: Projetos reais criados com status='idea' apareciam
  com label "Ideia" no card e ficavam presos no estado "ideia" mesmo sendo
  projetos intencionais. Filtro "ATIVOS" não os exibia.

BUG 2 — ANÁLISE FALHOU SEM RECUPERAÇÃO PARA IDEIAS:
  Arquivo: project_command_center_screen.dart, _ProjectDetailSheetState
  Seção:   _evaluationError display (anterior: ~linha 1673)

  Antes: Erro de avaliação mostrava apenas mensagem + botão fechar (X).
  Usuário ficava sem opções após falha. A ideia persistia em estado ambíguo
  (ideia criada, análise não realizada, sem indicação de próximos passos).

  Consequência: usuário via ideia como "projeto indevido" porque o tipo foi
  definido antes da análise, e a falha não oferecia nem retry nem rollback.

BUG 3 — ANÁLISE DE PROJETO SEM RETRY:
  Arquivo: project_command_center_screen.dart, _analysisError display
  Seção:   ~linha 1448

  Antes: Erro de análise de projeto real mostrava mensagem + X.
  Sem opção de tentar novamente sem fechar o sheet e reabrir.

BUG 4 — ESTADO 'DRAFT' AUSENTE NA LÓGICA DO CARD:
  Arquivo: project_command_center_screen.dart, _ProjectCard._statusLabel
  Antes:   case 'draft' caía no default 'Ideia'
  Depois:  case 'draft': return 'Rascunho'

==================================================
CURRENT WRONG FLOW (antes do hotfix)
==================================================

IDEIA:
  FAB → "Somente uma Ideia" → form → SALVAR
  → ProjectsNotifier.create({status: 'idea', is_idea: true})
  → Registro criado no banco (CORRETO)
  → Usuário abre detalhe → toca "AVALIAR IDEIA COM IVE"
  → _evaluateIdea() → FALHA
  → Mostra mensagem de erro + botão X (fechar)
  → NENHUMA AÇÃO DE RECUPERAÇÃO DISPONÍVEL
  → Ideia permanece em estado: capturada, sem avaliação, sem indicação

PROJETO REAL:
  FAB → "Projeto Real" → form → SALVAR
  → ProjectsNotifier.create({status: 'idea'})  ← ERRADO (deveria ser 'active')
  → Card mostra label "Ideia"  ← CONFUSO
  → Filtro "ATIVOS" não encontra o projeto
  → Usuário abre detalhe → toca "ANALISAR PROJETO" → FALHA
  → Mensagem de erro + X — sem retry

==================================================
FIXED FLOW (após hotfix)
==================================================

IDEIA:
  FAB → "Somente uma Ideia" → form → SALVAR
  → ProjectsNotifier.create({status: 'idea', is_idea: true})
  → Registro criado no banco (CORRETO — tipo = IDEIA por intenção do usuário)
  → Usuário abre detalhe → toca "AVALIAR IDEIA COM IVE"
  → _evaluateIdea() → FALHA
  → Mostra: AVALIAÇÃO FALHOU + 3 opções de recuperação:
      [TENTAR NOVAMENTE] → chama _evaluateIdea() novamente
      [SALVAR COMO RASCUNHO] → persiste analysis_status='failed', idea_state='draft'
      [EXCLUIR IDEIA] → confirmação → delete(id) → fecha sheet (rollback)
  → Tipo de entidade NÃO foi alterado pela falha de análise

PROJETO REAL:
  FAB → "Projeto Real" → form → SALVAR
  → ProjectsNotifier.create({status: 'active', is_idea: false})  ← CORRETO
  → Card mostra label "Ativo"  ← CORRETO
  → Filtro "ATIVOS" encontra o projeto  ← CORRETO
  → Usuário toca "ANALISAR PROJETO" → FALHA
  → Mostra erro + [TENTAR NOVAMENTE] inline

ASSET (Cofre):
  Cofre → Novo Item → form → SALVAR
  → KnowledgeService.create() → KnowledgeItem persistido (status='pending')
  → NENHUM PROJETO CRIADO ← confirmado por auditoria
  → Análise é disparada manualmente → falha → status='error'
  → Card mostra badge "Erro" + botão "Analisar com IA" para retry
  → Tipo NÃO foi alterado pela falha

==================================================
FILES CHANGED
==================================================

  lib/data/models/project.dart
    + getter analysisStatus: 'pending'|'analyzing'|'completed'|'failed'|'draft'

  lib/features/projects/screens/project_command_center_screen.dart
    _save(): status correto por tipo de entidade
    _ProjectCard._statusLabel: case 'draft' → 'Rascunho'
    _ProjectDetailSheetState:
      + _saveIdeaAsDraft(): persiste analysis_status='failed', idea_state='draft'
      + _deleteIdeaAndClose(): rollback com confirmação
      evaluationError UI: substituído por seção de recuperação com 3 botões
      analysisError UI: adicionado botão [Tentar Novamente]
    + _RecoveryButton: widget reutilizável para ações de recuperação

  docs/roadmap/ENTITY_LIFECYCLE_ANALYSIS_FAILURE_REPORT.md
    Este relatório

==================================================
MISCLASSIFIED RECORDS FOUND
==================================================

AUDITED BY CODE ANALYSIS — NÃO POR QUERY NO BANCO:

  Registros potencialmente afetados pelo BUG 1 (status='idea' para projetos reais):
    Todos os projetos reais criados ANTES deste hotfix têm status='idea'.
    Quantidade: desconhecida sem query no banco.

  SQL PARA IDENTIFICAR:
    SELECT id, name, created_at, status,
           details_json->>'is_idea' as is_idea
    FROM projects
    WHERE status = 'idea'
      AND (details_json->>'is_idea' = 'false' OR details_json->>'is_idea' IS NULL)
    ORDER BY created_at DESC;

  SQL PARA CORRIGIR (APROVAÇÃO DO PO NECESSÁRIA — RED GATE):
    UPDATE projects
    SET status = 'active', updated_at = NOW()
    WHERE status = 'idea'
      AND (details_json->>'is_idea' = 'false' OR details_json->>'is_idea' IS NULL);

  NOTA: Não executar automaticamente. Listar primeiro, validar, e então corrigir.

==================================================
TESTS
==================================================

  TESTE A — Adicionar ativo → análise falha → NÃO cria projeto:
    Cofre → Novo Item → preencher → Salvar
    Esperado: item aparece no Cofre com status 'Pendente'
    Esperado: NENHUM registro em projects criado
    Testar: seção Projetos não tem novo entry

  TESTE B — Criar ideia → análise falha → permanece ideia:
    Projetos → FAB → Somente uma Ideia → preencher → Salvar
    Abrir detalhe → AVALIAR IDEIA COM IVE (com edge function offline)
    Esperado: seção de recuperação com 3 botões
    Sub-teste B1: toca Tentar Novamente → re-dispara avaliação
    Sub-teste B2: toca Salvar como Rascunho → badge "Rascunho" no card
    Sub-teste B3: toca Excluir Ideia → confirmação → ideia removida → sheet fecha

  TESTE C — Criar projeto real → análise falha → projeto existe com status correto:
    Projetos → FAB → Projeto Real → preencher → Salvar
    Esperado: card mostra "Ativo" (não "Ideia")
    Esperado: filtro "ATIVOS" encontra o projeto
    Abrir detalhe → ANALISAR PROJETO (com edge function offline)
    Esperado: erro + botão [Tentar Novamente]
    Sub-teste: toca Tentar Novamente → nova tentativa de análise

  TESTE D — Retry de análise → sucesso → atualiza mesmo registro:
    Após falha → Tentar Novamente → análise bem-sucedida
    Esperado: ive_evaluation salvo em detailsJson
    Esperado: idea_state = 'evaluated'
    Esperado: NÃO cria duplicata no banco

  TESTE E — Cancelar (Excluir Ideia) após falha:
    Criar ideia → avaliar → falhar → Excluir Ideia → confirmar
    Esperado: ideia removida de projects
    Esperado: lista de projetos não tem mais a ideia
    Esperado: NÃO fica entidade indevida criada

==================================================
COMMIT
==================================================

  Hotfix P0 — entity lifecycle: status correto + recovery na falha de análise
  Commit: a ser criado

==================================================
FINAL STATUS
==================================================

  BUG 1 (STATUS ERRADO):          CORRIGIDO
  BUG 2 (SEM RECOVERY PARA IDEA): CORRIGIDO
  BUG 3 (SEM RETRY PARA PROJETO): CORRIGIDO
  BUG 4 (DRAFT NO CARD):          CORRIGIDO
  MISCLASSIFIED RECORDS:          DOCUMENTADO — AGUARDA QUERY/CORREÇÃO DO PO

==================================================
GO / NO-GO
==================================================

  GO PARA CÓDIGO: SIM
    Todos os 4 bugs corrigidos em código.
    Nenhuma migration necessária.
    Nenhum deploy de edge function necessário.
    Retrocompatível: projetos existentes com status='idea' continuam
    visíveis e funcionais; apenas novos projetos reais iniciam como 'active'.

  GO PARA DEVICE TEST: AGUARDA
    Depende das migrations P0-1 e SHA-1 Google (ver MIGRATION_REQUIRED.md
    e GOOGLE_DRIVE_DIAGNOSIS.md).
    Biometria: corrigida na CI (sed fix em build-android.yml/build-apk.yml).

  REGRA FINAL RESPEITADA:
    FALHA DE ANÁLISE NÃO ALTERA TIPO DE ENTIDADE.
    Tipo vem da intenção do usuário (escolha no dialog _showEntityChoice).
    Ideia permanece ideia. Projeto permanece projeto. Asset permanece asset.
    Rollback disponível via "Excluir Ideia" com confirmação.
