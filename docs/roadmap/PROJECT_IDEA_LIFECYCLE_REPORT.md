RELATÓRIO — PROJECT & IDEA LIFECYCLE
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
1. OBJETIVO
==================================================

Distinguir "Projeto Real" de "Somente uma Ideia" dentro da
área de projetos, com:

  - Diálogo de escolha ao criar (Projeto vs Ideia)
  - Diferenciação visual (emoji 💡 + badge "SOMENTE IDEIA")
  - Barra de filtros (TODOS / PROJETOS / IDEIAS / ATIVOS / etc.)
  - Ciclo de vida da ideia em detailsJson (sem migration)
  - Avaliação da Ideia pela IVE com contexto dos projetos reais
  - Promover Ideia → Projeto
  - Vincular Ideia a Projeto existente
  - Auto-indexação de ideias na Biblioteca (content_items)

==================================================
2. DECISÃO DE ARQUITETURA — SEM MIGRATION
==================================================

CAMPO UTILIZADO: projects.details_json (JSONB, existente)

  detailsJson['is_idea']           bool   — true = ideia
  detailsJson['idea_state']        String — 'captured' | 'evaluated'
                                            | 'promoted' | 'linked'
  detailsJson['ive_evaluation']    Map    — resultado bruto da IVE
  detailsJson['linked_project_id'] String — ID do projeto real vinculado
  detailsJson['promoted_at']       String — ISO8601 da promoção

RETROCOMPATIBILIDADE:
  Projetos sem 'is_idea' em detailsJson = projetos reais.
  is_idea: false = projeto real (explícito).
  is_idea: true  = ideia.

==================================================
3. MODELO (project.dart)
==================================================

ADICIONADO:
  bool get isIdea => detailsJson['is_idea'] == true
  String get ideaState => detailsJson['idea_state'] ?? 'captured'
  Map<String,dynamic> get iveEvaluation => detailsJson['ive_evaluation'] ?? {}

copyWith() ESTENDIDO:
  Aceita agora Map<String,dynamic>? detailsJson como parâmetro.

==================================================
4. BIBLIOTECA (content_service.dart)
==================================================

NOVO MÉTODO: upsertFromProject()

  - Cria ou atualiza entrada em content_items com:
      type = 'idea', knowledge_item_id IS NULL
  - Chave de upsert: (user_id, project_id, type='idea', knowledge_item_id IS NULL)
  - Chamado automaticamente ao criar uma ideia

==================================================
5. PROVIDER (project_provider.dart)
==================================================

MODIFICADO: create()
  - Se project.isIdea: chama ContentService().upsertFromProject()
    para auto-indexação na Biblioteca (erro suprimido — não-bloqueante)

NOVOS MÉTODOS:

  promoteToProject(id)
    detailsJson['is_idea'] = false
    detailsJson['idea_state'] = 'promoted'
    detailsJson['promoted_at'] = ISO8601
    → updateFields()

  saveIveEvaluation(id, evaluation)
    detailsJson['ive_evaluation'] = evaluation
    detailsJson['idea_state'] = 'evaluated'
    → updateFields()

  linkIdeaToProject(ideaId, linkedProjectId)
    detailsJson['linked_project_id'] = linkedProjectId
    detailsJson['idea_state'] = 'linked'
    status = 'completed'
    → updateFields()

==================================================
6. TELA (project_command_center_screen.dart)
==================================================

TELA PRINCIPAL:

  _filter: 'all' | 'projects' | 'ideas' | 'active' | 'paused' | 'completed'
  _isIdeaMode: bool — modo do formulário

  NOVO: _showEntityChoice()
    Diálogo com duas opções:
      - Projeto Real (ícone foguete verde)
      - Somente uma Ideia (emoji 💡)
    Define _isIdeaMode antes de abrir o formulário.

  NOVO: _buildFilterBar()
    Barra horizontal scrollável com 6 filtros (chips).

  NOVO: _buildFilteredEmpty()
    Mensagem quando o filtro não retorna resultados.

  MODIFICADO: _save()
    Passa details_json: {'is_idea': _isIdeaMode}

  MODIFICADO: _buildProjectList()
    Filtra por _filter antes de ordenar.

  MODIFICADO: _buildForm()
    Título, cor e borda variam por _isIdeaMode.

  MODIFICADO: _buildEmpty()
    Botão chama _showEntityChoice() em vez de abrir form direto.

_ProjectCard (MODIFICADO):
  _statusColor: ideias → roxo (0xFFAB83FF)
  _statusLabel: ideias → 'Ideia' | 'Avaliada' | 'Promovida' | 'Vinculada'
  Círculo de rank: ideias → emoji 💡

_ProjectDetailSheet (MODIFICADO):

  NOVOS CAMPOS DE ESTADO:
    _evaluating, _evaluationError, _localEvaluation

  NOVOS MÉTODOS:
    _evaluateIdea()
      - Busca projetos reais como contexto (até 5)
      - Chama generate-project-opportunities com o contexto
      - Salva via saveIveEvaluation()
      - Exibe resultado inline via Builder widget

    _promoteToProject()
      - Chama projectsNotifierProvider.notifier.promoteToProject()
      - Fecha o sheet

    _showProjectLinker()
      - Exibe bottom sheet com lista de projetos reais
      - Chama linkIdeaToProject() ao selecionar

  NOVO BADGE: "💡 SOMENTE IDEIA" no cabeçalho (se isIdea)

  NOVA SEÇÃO: AVALIAÇÃO DA IDEIA (se isIdea)
    - Botão AVALIAR IDEIA COM IVE (quando sem avaliação)
    - Spinner durante avaliação
    - Erro inline (com fechar)
    - Resultado: top-3 oportunidades + botão Reavaliar (Builder widget)

  NOVA SEÇÃO: DECISÃO (se isIdea)
    - [Transformar] → promoteToProject
    - [Vincular] → showProjectLinker

  BOTÃO EXCLUIR: "Excluir Ideia" (se isIdea) vs "Excluir Projeto"

==================================================
7. FLUXO COMPLETO — IDEIA
==================================================

CRIAR IDEIA:
  Tela principal → + → "Somente uma Ideia"
  → Formulário (borda roxa, título "Nova Ideia")
  → Salvar → create({..., details_json: {is_idea: true}})
  → Auto-indexação na Biblioteca via upsertFromProject()
  → Card aparece com 💡 e badge "SOMENTE IDEIA"
  → Filtro "IDEIAS" a exibe

AVALIAR COM IVE:
  Card → Detalhe → "AVALIAR IDEIA COM IVE"
  → _evaluateIdea(): gera oportunidades com projetos reais como contexto
  → Salva iveEvaluation em detailsJson
  → idea_state = 'evaluated'
  → Exibe top-3 oportunidades inline

PROMOVER A PROJETO:
  Detalhe → [Transformar]
  → detailsJson: is_idea=false, idea_state='promoted'
  → Sheet fecha → card agora aparece como projeto real

VINCULAR A PROJETO EXISTENTE:
  Detalhe → [Vincular]
  → Picker de projetos reais
  → detailsJson: linked_project_id, idea_state='linked', status='completed'
  → Sheet fecha

FILTRAR:
  Filtro "IDEIAS" → exibe somente is_idea=true
  Filtro "PROJETOS" → exibe somente is_idea=false (ou sem is_idea)
  Filtro "TODOS" → exibe tudo

==================================================
8. ARQUIVOS MODIFICADOS
==================================================

  lib/data/models/project.dart
    + isIdea, ideaState, iveEvaluation getters
    + copyWith() aceita detailsJson

  lib/data/services/content_service.dart
    + upsertFromProject()

  lib/providers/project_provider.dart
    + import content_service.dart
    + create(): auto-index ideas
    + promoteToProject()
    + saveIveEvaluation()
    + linkIdeaToProject()

  lib/features/projects/screens/project_command_center_screen.dart
    + _isIdeaMode, _filter state
    + _showEntityChoice(), _buildFilterBar(), _buildFilteredEmpty()
    + _save() passes details_json
    + _buildProjectList() applies filter
    + _buildForm() adapts to idea mode
    + _buildEmpty() calls _showEntityChoice()
    + _ProjectCard: isIdea visual differentiation
    + _ProjectDetailSheet: badge, evaluation section, decision buttons
    + _evaluateIdea(), _promoteToProject(), _showProjectLinker()

  docs/roadmap/PROJECT_IDEA_LIFECYCLE_REPORT.md
    + Este relatório

==================================================
9. MIGRATIONS NECESSÁRIAS
==================================================

NENHUMA.
  Toda a funcionalidade usa details_json (JSONB existente, migration 013).
  Nenhuma coluna nova, nenhuma tabela nova.

==================================================
10. EDGE FUNCTIONS NECESSÁRIAS
==================================================

NENHUMA NOVA.
  Avaliação de ideia usa generate-project-opportunities (já deployada).
  Indexação usa content_items (Supabase direto, sem função).

==================================================
11. TESTES E2E A VALIDAR EM DISPOSITIVO
==================================================

  E2E-5 CRIAR IDEIA:
    + → "Somente uma Ideia" → preencher → Salvar
    Esperado: card com 💡, badge roxa "SOMENTE IDEIA"
    Filtro "IDEIAS" exibe a ideia criada.

  E2E-6 AVALIAR COM IVE:
    Ideia → Detalhe → AVALIAR IDEIA COM IVE
    Esperado: spinner → top-3 oportunidades exibidas inline
    idea_state = 'evaluated' (verificar no Supabase)

  E2E-7 PROMOVER:
    Ideia → Detalhe → [Transformar]
    Esperado: sheet fecha, card agora aparece em "PROJETOS"
    is_idea = false em details_json (verificar no Supabase)

  E2E-8 VINCULAR:
    Ideia → Detalhe → [Vincular] → selecionar projeto
    Esperado: sheet fecha, ideia aparece em "CONCLUÍDOS"
    linked_project_id definido em details_json

  E2E-9 FILTROS:
    Criar 1 projeto real + 1 ideia
    Filtro "PROJETOS" → apenas projeto real
    Filtro "IDEIAS" → apenas ideia
    Filtro "TODOS" → ambos

==================================================
12. VEREDICTO
==================================================

CÓDIGO: GO — sem migration, sem edge function nova.
  Toda a funcionalidade é retrocompatível:
    - Projetos existentes sem 'is_idea' = projetos reais
    - isIdea == false por padrão
  Aguarda APK release para validação em dispositivo físico.
