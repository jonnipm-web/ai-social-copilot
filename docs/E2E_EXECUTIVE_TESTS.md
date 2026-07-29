# E2E EXECUTIVE TESTS
## InsightValues Business OS — Testes de Ponta a Ponta — IVE Executive Intelligence
### Data: 2026-07-29 | FASE 11

---

## OBJETIVO

Validar o funcionamento integrado do Executive Intelligence Engine da IVE, cobrindo os principais
fluxos da Fase 11: entrevista de ideia, perfil vivo, saúde executiva, check-in, priorização,
relações entre projetos, recomendações, linha do tempo e geração de planos.

---

## CENÁRIOS DE TESTE

### T01 — Ideia sem contexto dispara entrevista

**Pré-condição:** Projeto com `coverage.score < 30`, `niche == 'Não definido'`, `targetAudience == 'Não definido'`

**Passos:**
1. Abrir Project Command Center
2. Tocar no card do projeto

**Resultado esperado:**
- `IdeaInterviewDialog` abre (não fecha ao tocar fora)
- Barra de progresso exibe `1/10`
- Botão "Pular entrevista" disponível

**Resultado NÃO esperado:**
- `_ProjectDetailSheet` abre diretamente sem entrevista

---

### T02 — Entrevista completa enriquece perfil

**Pré-condição:** T01 executado, dialog aberto

**Passos:**
1. Responder as 10 perguntas sequencialmente
2. Pressionar "Concluir" na pergunta 10

**Resultado esperado:**
- `KnowledgeItem` criado com `source: 'idea_interview'`
- `ProjectEvent(interviewCompleted)` registrado
- `projectIntelligenceProfilesProvider` invalidado
- `_ProjectDetailSheet` abre após conclusão

---

### T03 — Perfil vivo atualiza após nova análise

**Pré-condição:** Projeto com análise de mercado

**Passos:**
1. Executar nova análise de mercado no Market Intelligence Hub
2. Retornar ao Project Command Center

**Resultado esperado:**
- `executivePriorityScore` recalculado
- `ExecutiveHealth` recalculado com novos scores
- Ordenação no PCC reflete novo score dinâmico

---

### T04 — Comparação detecta projetos relacionados

**Pré-condição:** 2+ projetos com nicho similar (ex: "SaaS para RH") no portfólio

**Passos:**
1. Abrir qualquer um dos projetos com nicho compartilhado
2. Rolar até a seção "Relações do Portfólio"

**Resultado esperado:**
- Pelo menos 1 `ExecutiveRelationship` exibido
- Chip com tipo (🔗 Sinérgico / ⚠️ Conflitante / 🔴 Duplicata)
- Tap no chip → `IveDetailSheet` com evidências da relação

---

### T05 — Sugestão espontânea aparece quando score de oportunidade é alto

**Pré-condição:** Projeto com `opportunityScore >= 70` e nenhuma ação criada nos últimos 7 dias

**Passos:**
1. Abrir Decision Center (aba Recomendações)

**Resultado esperado:**
- Card de tipo `investProject` ou `executeOpportunity` exibido
- `priority == 'alta'` exibido em vermelho 🔴
- `costOfIgnoring` preenchido (não vazio)
- Botão "Criar Plano" visível

---

### T06 — Prioridade muda automaticamente após completar ação

**Pré-condição:** Projeto com 1 de 5 ações completadas

**Passos:**
1. Marcar mais 2 ações como concluídas no Action Engine
2. Retornar ao Project Command Center

**Resultado esperado:**
- `executivePriorityScore` aumenta (momentum de 20% → 60%)
- Posição do projeto na lista PCC sobe
- Score visível no card reflete novo valor

---

### T07 — Geração de plano a partir de recomendação

**Pré-condição:** Card de recomendação exibido no Decision Center (T05)

**Passos:**
1. Tocar em "Criar Plano" no card de recomendação

**Resultado esperado:**
- Action Engine abre pré-populado com contexto da recomendação
- OU `ActionQueueNotifier.addFromOpportunity()` é chamado
- Nova ação criada com título relacionado à recomendação

---

### T08 — Linha do tempo registra evento de análise

**Pré-condição:** Projeto sem análise prévia

**Passos:**
1. Executar análise de mercado
2. Consultar `project_events` via Supabase para o projeto

**Resultado esperado:**
- Registro com `event_type == 'analysisCompleted'` inserido
- `title` contendo "Análise" e `metadata` com `opportunityScore`
- `created_at` com timestamp atual

---

### T09 — Check-in executivo exibe banner após 21 dias sem atividade

**Pré-condição:** Projeto com `lastActivityAt` > 21 dias atrás (simular atualizando `updated_at` no Supabase)

**Passos:**
1. Abrir `_ProjectDetailSheet` do projeto

**Resultado esperado:**
- Banner `🔄 Check-in necessário` exibido no topo da sheet
- `checkInDue == true` no `ProjectIntelligenceProfile`
- `executivePriorityScore` tem -10 de penalidade aplicada

---

## COBERTURA DE COMPONENTES

| Componente | Coberto pelos cenários |
|-----------|----------------------|
| `IdeaInterviewDialog` | T01, T02 |
| `ProjectIntelligenceProfile.shouldInterview` | T01 |
| `ExecutiveHealthService` | T03 |
| `ExecutiveRelationshipService` | T04 |
| `priorityRecommendationsProvider` | T05, T07 |
| `_executivePriority()` | T03, T06 |
| `ActionQueueNotifier.addFromOpportunity()` | T07 |
| `ProjectEventService.emit()` | T02, T08 |
| `_isCheckInDue()` | T09 |
| `executivePriorityScore` penalidade | T09 |

---

## CRITÉRIOS DE ACEITAÇÃO DOS TESTES

- [ ] T01: entrevista disparada automaticamente
- [ ] T02: KnowledgeItem + ProjectEvent criados
- [ ] T03: score dinâmico recalculado após nova análise
- [ ] T04: relações exibidas para projetos com nicho compartilhado
- [ ] T05: recomendação com `costOfIgnoring` preenchido
- [ ] T06: score sobe ao completar ações
- [ ] T07: botão "Criar Plano" funcional
- [ ] T08: evento inserido no Supabase após análise
- [ ] T09: banner de check-in + penalidade no score
