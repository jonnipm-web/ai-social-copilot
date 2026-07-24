RELATÓRIO — UNIFIED KNOWLEDGE + IVE IDEA INTAKE
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
1. ROOT CAUSE — BOTÃO ADICIONAR
==================================================

SINTOMA:
  "+ ADICIONAR" não respondeu em testes em dispositivo S25 Ultra.

CAUSA 1 — TAP TARGET MINÚSCULO:
  TextButton.icon com tapTargetSize: MaterialTapTargetSize.shrinkWrap
  e minimumSize: Size.zero reduzia a área tocável ao tamanho exato
  do texto (~80 x 20 dp). Em dispositivo físico com toque de dedo,
  essa área é praticamente intocável.

CAUSA 2 — FILTRO MUITO RESTRITIVO:
  Filtro original: i.projectId == null
  Excluía itens já vinculados a OUTROS projetos.
  Se todos os itens do Cofre estivessem vinculados a qualquer projeto
  (não necessariamente ao atual), a lista ficava vazia e um SnackBar
  aparecia ATRÁS do bottom sheet modal — invisível ao usuário.

FIX APLICADO:
  - Substituído TextButton por InkWell com padding: EdgeInsets.symmetric(
    horizontal: 12, vertical: 10) — área de toque ~100x44 dp.
  - Filtro alterado para: !linkedIds.contains(i.id)
    → exibe TODOS os itens não vinculados A ESTE projeto.
    Itens de outros projetos são exibidos com aviso "Será movido".
  - Erros exibidos INLINE no sheet (não como SnackBar).

==================================================
2. ROOT CAUSE — COMPLETAR ANÁLISE
==================================================

SINTOMA:
  Botão presente mas sem resposta visual percebida em dispositivo real.

CAUSA:
  O botão FUNCIONAVA (setState _analyzing=true disparava o spinner),
  mas a edge function generate-project-opportunities pode falhar
  imediatamente por timeout, auth ou CORS.
  O erro era enviado para ScaffoldMessenger.showSnackBar() que aparece
  ATRÁS do bottom sheet modal — invisível ao usuário.
  O spinner aparecia por <500ms e sumia sem feedback visível.

FIX APLICADO:
  _analyzeProject() não usa mais SnackBar.
  Estados adicionados: _analysisError (String?) e _analysisSuccess (String?).
  Sucesso: texto verde inline — "N oportunidade(s) gerada(s)."
  Erro: container vermelho inline com mensagem + botão fechar.
  O erro permanece visível até o usuário fechar ou tentar novamente.

==================================================
3. ROOT CAUSE — BIOMETRIA SAMSUNG S25 ULTRA
==================================================

SINTOMA:
  "Não foi possível ativar. Tente novamente mais tarde."

CAUSA CONFIRMADA:
  CI gera android/ via "flutter create --platforms android".
  O flutter create padrão gera MainActivity.kt estendendo FlutterActivity.
  O pacote local_auth REQUER FlutterFragmentActivity.
  Sem isso, qualquer chamada a LocalAuthentication() lança:
    PlatformException(code: 'no_fragment_activity', ...)
  Esse código caía no default: → BiometricStatus.failed
  → "Não foi possível ativar."

FIX APLICADO (3 partes):

  PARTE A — CI (build-android.yml e build-apk.yml):
    Novo step "Patch MainActivity — FlutterFragmentActivity (local_auth)"
    executado APÓS flutter create, ANTES de flutter pub get:
      sed -i 's/FlutterActivity/FlutterFragmentActivity/g' MainActivity.kt
    O step localiza o arquivo automaticamente via find.

  PARTE B — BiometricAuthService._map():
    Caso 'no_fragment_activity' → BiometricStatus.noHardware
    (antes: caía em default → BiometricStatus.failed)
    Campo lastErrorCode: String? adicionado à classe para diagnóstico.

  PARTE C — BiometricEnrollmentSheet:
    Caso noHardware → mensagem específica com código.
    Default → mensagem com código real (e.code) para diagnóstico.
    Exemplo: "Código: no_fragment_activity" permite ao PO identificar
    se o APK foi gerado com ou sem o patch.

==================================================
4. MODELO DE DADOS REAL
==================================================

TABELAS CANÔNICAS (já existem, sem migration):

  knowledge_items
    id, user_id, project_id (FK → projects, nullable),
    title, source_type, source_url, file_name, content,
    niche, target_audience, language, persona_id, status,
    opportunity_score, created_at, updated_at

  knowledge_analysis
    id, knowledge_item_id (UNIQUE FK), user_id, project_id,
    summary, keywords_*, entities, topics, content_pillars,
    audience_pain_points, audience_desires, commercial_angles,
    ctas, campaign_ideas, post_ideas, article_ideas,
    seo_opportunities, score_* (seo/adsense/amazon/linkedin/
    social/opportunity/hotmart/shopify), score_details, created_at

  content_items (Biblioteca)
    id, user_id, project_id, persona_id, title, type,
    description, base_text, niche, target_audience,
    knowledge_item_id (FK → knowledge_items), keywords,
    opportunity_score, auto_generated, created_at

  opportunity_lab
    id, user_id, project_id, title, description,
    opportunity_type, scores (market/revenue/competition/
    synergy/strategic_fit/final), status, origin, created_at

==================================================
5. COFRE × BIBLIOTECA × PROJETO — RELAÇÃO REAL
==================================================

COFRE (knowledge_items):
  - Armazenamento e gestão de ativos brutos.
  - Um item tem: source (manual/url/file), content, metadata.
  - Pode ou não estar vinculado a um projeto (project_id nullable).

BIBLIOTECA (content_items):
  - Índice inteligente — NÃO é um armazenamento separado.
  - Auto-populada por KnowledgeService.analyzeItem() via
    ContentService.upsertFromKnowledge().
  - Cada content_item aponta para knowledge_item_id de origem.
  - Contém: title, type, description, keywords, opportunity_score.

PROJETO (projects + knowledge_items.project_id):
  - Consome referências (vínculos) de knowledge_items.
  - Um item pode ser vinculado a um projeto via UPDATE project_id.
  - Análise do projeto: usa itens vinculados como "documentos".

IVE:
  - Camada de inteligência que lê os três acima.
  - Novo: IVE Idea Intake analisa ideias brutas e sugere roteamento.

==================================================
6. MODELO CANÔNICO DE CONHECIMENTO
==================================================

UM ATIVO ENTRA UMA VEZ:

  INGESTÃO (KnowledgeVaultScreen / projeto / IVE)
        ↓
  knowledge_items (COFRE) — identidade canônica
        ↓
  KnowledgeService.analyzeItem()
        ↓
  knowledge_analysis — extração AI (keywords, topics, scores)
        ↓
  ContentService.upsertFromKnowledge()
        ↓
  content_items (BIBLIOTECA) — indexação automática
        ↓
  knowledge_items.project_id = project_id (se vinculado)
        ↓
  Disponível em: Cofre + Biblioteca + Projeto + IVE

SEM DUPLICAÇÃO:
  - knowledge_items.id = chave canônica
  - content_items.knowledge_item_id = referência, não cópia
  - opportunity_lab.project_id = referência ao projeto

==================================================
7. CLASSIFICAÇÃO AUTOMÁTICA
==================================================

Implementada em KnowledgeService.analyzeItem() via edge fn
extract-knowledge (GROQ/Llama). Detecta automaticamente:

  detected_type     → ContentItem.type
  detected_title    → ContentItem.title
  detected_niche    → ContentItem.niche
  detected_audience → ContentItem.targetAudience
  keywords_primary  → ContentItem.keywords
  score_opportunity → KnowledgeItem.opportunityScore

Status de review:
  knowledge_items.status = 'pending' → 'processing' → 'analyzed'
  Em caso de falha: status = 'error'

==================================================
8. INDEXAÇÃO AUTOMÁTICA (BIBLIOTECA)
==================================================

Cascade: qualquer item analisado no Cofre aparece automaticamente
na Biblioteca via ContentService.upsertFromKnowledge().

  upsert por: knowledge_item_id (UNIQUE)
  NÃO cria duplicatas.
  Atualiza scores se o item for re-analisado.

==================================================
9. PROJECT LINKING — FLUXO CORRIGIDO
==================================================

VINCULAR EXISTENTE (corrigido):
  Projeto → ADICIONAR (InkWell, 44dp tap target)
        ↓
  _showKnowledgeSelector: carrega TODOS os itens do usuário
  Filtra: !linkedIds.contains(i.id)
  Exibe itens de outros projetos com aviso "Será movido"
        ↓
  _KnowledgeSelectorSheet (DraggableScrollableSheet scrollável)
        ↓
  onSelect → KnowledgeService.update(id, {project_id: widget.project.id})
        ↓
  ref.invalidate(knowledgeItemsByProjectProvider) → lista atualiza

ADICIONAR NOVO (fluxo existente via KnowledgeVaultScreen):
  Cofre → Novo Item → salvar com project_id = null
  Depois vincular via Projeto → ADICIONAR

DESVINCULAR:
  "remover" (InkWell) → KnowledgeService.update(id, {project_id: null})
  Erro exibido inline se falhar.

==================================================
10. PROJECT ANALYSIS — FLUXO CORRIGIDO
==================================================

COMPLETAR ANÁLISE / REANALISAR:
  Projeto → botão
        ↓
  _analyzeProject()
  setState: _analyzing=true, _analysisError=null
        ↓
  Busca items vinculados ao projeto
  Chama generate-project-opportunities (GROQ)
  Salva oportunidades em opportunity_lab
  ref.invalidate(ecosystemScoresProvider)
        ↓
  SUCESSO: _analysisSuccess = "N oportunidade(s) gerada(s)."
  ERRO: _analysisError = mensagem real (inline, visível ao usuário)
  SEMPRE: _analyzing = false

==================================================
11. IVE CONTEXT
==================================================

IveProjectAskButton inclui top-3 itens vinculados como
knowledge_context no CopilotContextData.project:

  'knowledge_context': [
    {'title': ..., 'excerpt': content[:200]},
    ...
  ]

A IVE recebe contexto real de cada projeto.

==================================================
12. IDEA INTAKE ARCHITECTURE
==================================================

NOVO: _IdeaIntakeSheet (ConsumerStatefulWidget)

ACESSO: Projeto → "ANALISAR IDEIA COM IVE" (botão roxo)

FLUXO:
  1. Usuário digita ideia (TextField, 5 linhas)
  2. "Analisar com IVE" → generate-project-opportunities
     com idea como project_description
  3. IVE retorna: oportunidades estruturadas (title, scores)
  4. Usuário vê lista de oportunidades detectadas

OPÇÕES PÓS-ANÁLISE:
  [Salvar como Ideia] → cria KnowledgeItem(sourceType='manual',
    projectId=project.id, content=ideia)
    → disponível no Cofre e na Biblioteca
  [Vincular ao Projeto] → salva KnowledgeItem + salva oportunidades
    em opportunity_lab com origin='ia-idea-intake'
    → ref.invalidate(ecosystemScoresProvider) → scores atualizados

APROVAÇÃO HUMANA:
  A IVE NÃO age automaticamente.
  Usuário decide entre: Analisar / Salvar Ideia / Vincular ao Projeto.

MIGRATION NECESSÁRIA: NÃO.
  Usa tabelas existentes: knowledge_items + opportunity_lab.

==================================================
13. ARQUIVOS MODIFICADOS
==================================================

MODIFICADO  lib/features/projects/screens/project_command_center_screen.dart
  - _ProjectDetailSheetState: _analysisError, _analysisSuccess
  - _analyzeProject(): inline error/success (sem SnackBar)
  - _showKnowledgeSelector(): filtro expandido, inline error
  - _unlinkItem(): inline error
  - _openIdeaIntake(): novo método
  - Build: InkWell para ADICIONAR (44dp tap), displays inline
  - _KnowledgeSelectorSheet: currentProjectId, DraggableScrollableSheet
  - NOVO _IdeaIntakeSheet: ConsumerStatefulWidget completo

MODIFICADO  lib/core/services/biometric_auth_service.dart
  - Campo lastErrorCode: String? (diagnóstico)
  - _map(): case 'no_fragment_activity' → noHardware
  - _map(): lastErrorCode = e.code antes do switch

MODIFICADO  lib/features/auth/widgets/biometric_enrollment_sheet.dart
  - case BiometricStatus.noHardware adicionado
  - default: exibe service.lastErrorCode real

MODIFICADO  .github/workflows/build-android.yml
  - Novo step "Patch MainActivity — FlutterFragmentActivity (local_auth)"
    após flutter create, antes de flutter pub get

MODIFICADO  .github/workflows/build-apk.yml
  - Mesmo step de patch

NOVO        docs/roadmap/UNIFIED_KNOWLEDGE_AND_IVE_IDEA_REPORT.md
  - Este relatório

==================================================
14. MIGRATIONS NECESSÁRIAS
==================================================

NENHUMA.
  Todas as funcionalidades usam tabelas existentes:
  knowledge_items (migration 013 — APLICADA)
  knowledge_analysis (existente)
  content_items (existente)
  opportunity_lab (existente)

==================================================
15. DEPLOYS NECESSÁRIOS
==================================================

NENHUM novo deploy de Edge Function.
  generate-project-opportunities: já deployada (GROQ).
  extract-knowledge: já deployada.
  context-copilot: não alterada.

DEPLOY NECESSÁRIO — APK:
  Após este commit, disparar build-android.yml (workflow_dispatch)
  para gerar novo APK com:
  - FlutterFragmentActivity patch
  - Botões corrigidos
  - IVE Idea Intake

==================================================
16. TESTES
==================================================

UNIT TESTS NÃO ALTERADOS.
  ive_etapa3_hotfix_test.dart continua passando:
  - "showDash: !s.hasRoiData" ainda é substring do ROI _ScoreRow.

TESTS E2E A VALIDAR EM DISPOSITIVO:

  E2E-1 ADICIONAR ITEM:
    Abrir projeto → ADICIONAR → seletor abre com todos os itens
    Selecionar → item aparece em CONHECIMENTO VINCULADO
    PASS esperado após APK com fix.

  E2E-2 COMPLETAR ANÁLISE:
    Abrir projeto → COMPLETAR ANÁLISE → spinner aparece
    Resultado: oportunidades salvas + mensagem verde inline
    OU mensagem de erro vermelha inline (sem mais "botão mudo").
    PASS esperado após APK com fix.

  E2E-3 BIOMETRIA S25 ULTRA:
    Gaveta → Login biométrico → toggle
    App mostra BiometricEnrollmentSheet
    Android exibe prompt biométrico nativo
    Digital → ativar → sucesso
    Fechar → reabrir → tela biométrica automática
    PASS esperado após APK com patch FlutterFragmentActivity.

  E2E-4 IVE IDEA INTAKE:
    Abrir projeto → ANALISAR IDEIA COM IVE
    Digitar ideia → Analisar com IVE
    IVE retorna oportunidades estruturadas
    Usuário toca VINCULAR AO PROJETO
    Ideia aparece no Cofre + oportunidades no Opportunity Lab
    PASS esperado.

==================================================
17. E2E RESULTS (DEVICE TEST REQUIRED)
==================================================

TODOS OS E2E REQUEREM DISPOSITIVO FÍSICO COM APK RELEASE.
  Ambiente CI: sem acesso a dispositivo físico.
  Validação final: Product Owner com S25 Ultra + APK gerado
  pelo build-android.yml APÓS este commit.

==================================================
18. BLOCKERS REMANESCENTES
==================================================

BLOCKER 1 — APK COM PATCH:
  O APK atualmente instalado no S25 Ultra não tem o patch de
  FlutterFragmentActivity. Biometria continuará falhando até
  novo APK ser gerado e instalado.
  AÇÃO: Disparar build-android.yml → baixar artefato → instalar.

BLOCKER 2 — VALIDAÇÃO EDGE FUNCTION:
  Se generate-project-opportunities falhar no dispositivo real
  (CORS, auth, timeout), o erro agora fica visível inline.
  O PO poderá ver a mensagem de erro exata e reportar.
  AÇÃO: Verificar logs Supabase se botão mostrar erro vermelho.

BLOCKER 3 — ITENS NO COFRE:
  Se o usuário não tem itens no Cofre, ADICIONAR mostrará:
  "Nenhum item disponível. Adicione itens no Cofre primeiro."
  O PO precisa ter itens no Cofre para vincular ao projeto.
  AÇÃO: Criar ao menos um item no Cofre antes de vincular.

==================================================
19. COMMITS
==================================================

(A serem criados após este relatório)

==================================================
20. VEREDICTO FINAL
==================================================

CÓDIGO: GO COM RESSALVAS

RESSALVA 1 — APK PENDING:
  As correções de biometria (FlutterFragmentActivity) e botões
  estão no código mas requerem novo APK.
  O APK atual no dispositivo está DESATUALIZADO.

RESSALVA 2 — VALIDAÇÃO EM DISPOSITIVO:
  Botões (ADICIONAR, COMPLETAR ANÁLISE) requerem confirmação
  com o APK atualizado no S25 Ultra.

SISTEMA SÓ SERÁ FUNCIONAL QUANDO:
  1. APK gerado com patch FlutterFragmentActivity instalado.
  2. Cofre tem ao menos um item para vincular.
  3. Edge function generate-project-opportunities acessível.

PARA DEVICE TEST:
  GO para gerar novo APK.
  NO-GO para declarar P0 e P1 completos antes do novo APK.
