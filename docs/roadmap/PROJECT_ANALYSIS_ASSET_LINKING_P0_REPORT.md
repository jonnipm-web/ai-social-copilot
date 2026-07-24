# Relatório P0 — Project Analysis + Asset Linking
# AI Social Copilot

**Data:** 2026-07-24
**Versão:** 1.0.0
**Branch:** claude/access-social-copilot-wJ6B5

---

## VEREDICTO: GO COM RESSALVA

Todas as Missões de código foram entregues. Ressalva única:
o teste real do MENTE ACELERADA™ requer dispositivo físico com
sessão autenticada (não pode ser validado neste ambiente CI).

---

## 1. ROOT CAUSE — DIAGNÓSTICO

PROJETO MENTE ACELERADA™ mostrava:
- Eco Score = 0, todas as dimensões = 0
- Recomendação "ANÁLISE INCOMPLETA"
- Ações 0/0

CAUSA RAIZ CONFIRMADA:
- `_hasEnoughData()` em `ecosystem_intelligence_service.dart` retorna
  `false` quando `analysis == null && plan == null && lab.isEmpty && actions.isEmpty`.
  Projetos novos (sem análise de mercado, sem plano de receita, sem lab,
  sem ações) sempre entram nesse estado.
- `_ScoreRow` exibia "0" para todas as dimensões menos ROI — ao invés
  de "—" (ausência de dados) — porque `showDash` só era passado para ROI.

CAUSA SECUNDÁRIA:
- Não existia nenhum botão "Analisar Projeto" ou fluxo explícito para
  disparar análise.
- Não existia seção de vínculo Cofre → Projeto na UI do detalhe do
  projeto.

---

## 2. ARQUIVOS MODIFICADOS

MODIFICADO  lib/features/projects/screens/project_command_center_screen.dart

---

## 3. MISSÕES ENTREGUES

MISSAO 1 — ROOT CAUSE IDENTIFICADO
  Confirmado via leitura de ecosystem_intelligence_service.dart.
  _hasEnoughData() retorna false -> recommendation = 'ANALISE INCOMPLETA'
  -> todos os scores zerados mas mostrados como "0" na UI.

MISSAO 2 — PROJECT-ASSET LINKING (Cofre → Projeto)
  Implementado em _ProjectDetailSheet (agora ConsumerStatefulWidget):
  - Seção "CONHECIMENTO VINCULADO" com lista de itens vinculados.
  - Botão "+ ADICIONAR" → _KnowledgeSelectorSheet (selector de itens
    com projectId == null).
  - Ao selecionar: KnowledgeService.update(id, {project_id: projectId})
    + ref.invalidate(knowledgeItemsByProjectProvider).
  - "remover" por item: KnowledgeService.update(id, {project_id: null})
    + ref.invalidate(knowledgeItemsByProjectProvider).
  Usa migration 013 (APLICADA). Sem novas migrations necessárias.

MISSAO 3 — UX MINIMA ATIVOS
  Implementado:
  - Lista de itens vinculados com ícone + título + link "remover".
  - Botão "ADICIONAR" inline na header da seção.
  - Sheet seletor com lista scrollável, item com ícone de link.

MISSAO 4 — KNOWLEDGE CONTEXT NO IVE
  IveProjectAskButton recebe knowledgeItems (List<KnowledgeItem>).
  Os 3 primeiros itens são incluídos em CopilotContextData.project como
  knowledge_context com title + excerpt (200 chars).

MISSAO 5 — FLUXO ANALISAR / REANALISAR
  Implementado _analyzeProject() em _ProjectDetailSheetState:
  1. Busca itens vinculados ao projeto via knowledgeItemsByProjectProvider.
  2. Chama edge function generate-project-opportunities com:
     project_name, project_description, project_type, documents (Cofre), market_context.
  3. Salva cada oportunidade retornada via opportunityLabNotifierProvider.add().
  4. ref.invalidate(ecosystemScoresProvider) → sheet atualiza reativamente.

  Label do botão varia por estado:
  - s == null             → "ANALISAR PROJETO"
  - !s.hasEnoughData      → "COMPLETAR ANALISE"
  - s.hasEnoughData       → "REANALISAR"

  Loading state: CircularProgressIndicator + "Analisando com IA..."

MISSAO 6 — NULL NAO CONFUNDIDO COM ZERO
  _ScoreRow recebe showDash: !s.hasEnoughData para TODAS as 7 dimensões
  (antes, apenas ROI recebia showDash).
  Eco score badge no header só aparece quando s.hasEnoughData == true.

MISSAO 7 — DATA COMPLETENESS UI
  Container amarelo (Color(0xFFFFD93D)) com aviso visível quando
  noData == true, instrui o usuário a vincular itens e clicar em
  "Analisar Projeto".

MISSAO 8 — BACKFILL
  Não requer migration — o fluxo de análise é disparado manualmente
  pelo usuário para cada projeto. O Product Owner pode abrir
  "MENTE ACELERADA™", adicionar itens do Cofre, e clicar em
  "ANALISAR PROJETO".

MISSAO 9 — MENTE ACELERADA™ COMO CASO DE TESTE
  BEFORE: Eco Score = 0, todas as dimensões = "0", "ANALISE INCOMPLETA"
  AFTER (steps):
  1. Abrir projeto MENTE ACELERADA™.
  2. Seção "CONHECIMENTO VINCULADO" → ADICIONAR → selecionar itens
     do Cofre relacionados.
  3. Tocar "ANALISAR PROJETO" → aguardar IA.
  4. Sheet atualiza: scores reais, eco badge visível, "ANALISE INCOMPLETA"
     substituída por recomendação da IA.
  Validação requer dispositivo físico com sessão autenticada.

MISSAO 10 — FLOWS E2E VERIFICADOS (LOGIC REVIEW)
  FLOW 1 — Projeto sem dados:
    Abrir projeto → ver aviso amarelo + "ANALISAR PROJETO" + scores "—"
    IMPLEMENTADO

  FLOW 2 — Vincular Cofre → Projeto:
    ADICIONAR → _KnowledgeSelectorSheet → selecionar → update project_id
    IMPLEMENTADO

  FLOW 3 — Analisar projeto:
    "ANALISAR PROJETO" → edge function → save opportunities →
    invalidate provider → scores atualizados na sheet
    IMPLEMENTADO

  FLOW 4 — Remover vínculo:
    Tap "remover" → update project_id = null → lista atualiza
    IMPLEMENTADO

  FLOW 5 — IVE com contexto de knowledge:
    "Perguntar à IVE" → contextData inclui knowledge_context com
    title + excerpt dos 3 primeiros itens vinculados
    IMPLEMENTADO

MISSAO 11 — MIGRATIONS 022/023/024
  DECISAO: NAO NECESSARIAS para este fix.
  A tabela assets NAO EXISTE em producao. Usar knowledge_items
  (migration 013, APLICADA) como "ativos vinculados" é suficiente
  para o caso de uso do Product Owner.
  Migrations 022/023/024 permanecem como PROPOSTA, sem deploy.

MISSAO 12 — IVE-AGENT-RUNNER
  DECISAO: NAO NECESSARIO.
  Scoring é calculado in-memory pelo EcosystemIntelligenceService (Dart).
  Edge function generate-project-opportunities usa GROQ API (já deployada).
  Nenhum novo deploy é necessário.

---

## 4. ARQUITETURA DO FIX

_ProjectDetailSheet:
  ANTES: StatelessWidget, aceita ecosystemScore como parâmetro
  DEPOIS: ConsumerStatefulWidget
    - Assiste ecosystemScoresProvider reativamente (sheet atualiza
      após _analyzeProject sem precisar ser reaberta)
    - Assiste knowledgeItemsByProjectProvider para lista vinculada
    - Não aceita mais ecosystemScore como parâmetro

Novos widgets:
  _KnowledgeItemTile   — exibe item vinculado + botão "remover"
  _KnowledgeSelectorSheet — sheet seletor de itens não vinculados

IveProjectAskButton:
  Novo parâmetro opcional: knowledgeItems (default [])
  Top 3 items incluídos como knowledge_context no contextData

---

## 5. SEGURANÇA

CONSTRAINTS MANTIDAS:
  - NÃO expõe INTERNAL_TESTER_IDS
  - NÃO hardcoda UID — sempre derivado da sessão autenticada
  - NÃO ativa agent mode globalmente
  - NÃO cria bypass baseado em email/client payload
  - NÃO altera migrations 022/023/024
  - NÃO configura OPENAI_API_KEY real
  - NÃO faz deploy ive-agent-runner
  - NÃO ativa flag global ive_agent_mode
  - NÃO quebra fluxo de Google Drive
  - NÃO remove context-copilot
  - NÃO inicia novas fases ou Update Packs

---

## 6. O QUE NAO FOI FEITO (E POR QUE)

- Backfill automático de projetos existentes: o spec requer
  que seja um fluxo explícito (botão), não automático. Correto.
- Testes unitários: fora do escopo do P0.
- Nova migration: desnecessária (migration 013 existente cobre o caso).

---

## 7. PROXIMOS PASSOS RECOMENDADOS

1. Testar em dispositivo físico com projeto MENTE ACELERADA™:
   - Abrir projeto → ver aviso + "ANALISAR PROJETO"
   - Vincular ≥1 item do Cofre
   - Tocar "ANALISAR PROJETO" → aguardar IA
   - Confirmar que scores aparecem e "ANÁLISE INCOMPLETA" some
2. Revisar se o seletor de Cofre carrega items corretamente
   (depende de items existentes com projectId == null)
3. Opcionalmente criar migration 022-024 se "assets" tipados forem
   necessários no futuro (não P0)

---

VEREDICTO FINAL: GO COM RESSALVA
Código completo, sem credenciais expostas, sem migration, sem impacto em P0.
Validação final em dispositivo físico pelo Product Owner.
