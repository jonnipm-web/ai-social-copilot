# IVE Tool Registry — V1 Blueprint

> Status: BLUEPRINT ONLY — Nenhuma implementação realizada.  
> Data: 2026-07-21  
> Fase alvo: Phase 1B

---

## Conceito

O Tool Registry define o conjunto de operações que o LLM pode invocar durante o loop do agente. Cada ferramenta:

1. Tem um `tool_name` único e imutável (usado no contrato de resposta do LLM)
2. Só pode operar sobre dados do `user_id` derivado do JWT (nunca do payload do cliente)
3. Declara o schema de entrada esperado (validado antes da execução)
4. Retorna um resultado estruturado que vai para o contexto do próximo turno do LLM
5. Tem permissão declarada: `read` ou `write`

---

## Ferramentas V1

### `action.create` (write)

**Já implementado** — `ServiceBackedIveActionExecutor` + `IveActionProposal`.

```json
{
  "tool_name": "action.create",
  "description": "Cria uma ação na fila de execução do projeto ativo. Requer confirmação explícita do usuário antes de persistir.",
  "permission": "write",
  "requires_user_confirmation": true,
  "input_schema": {
    "project_id":    { "type": "string", "format": "uuid", "required": true },
    "title":         { "type": "string", "maxLength": 200, "required": true },
    "description":   { "type": "string", "maxLength": 1000 },
    "priority":      { "type": "string", "enum": ["low", "medium", "high", "critical"], "required": true },
    "impact":        { "type": "string", "enum": ["low", "medium", "high"], "required": true },
    "effort":        { "type": "string", "enum": ["low", "medium", "high"], "required": true },
    "due_date":      { "type": "string", "format": "date-time" },
    "rationale":     { "type": "string", "maxLength": 500 },
    "evidence_ids":  { "type": "array", "items": { "type": "string", "format": "uuid" } },
    "opportunity_id":{ "type": "string", "format": "uuid" }
  },
  "security": {
    "user_id_source": "JWT only",
    "project_ownership": "verified server-side via projects table",
    "idempotency": "persistenceMarker = ive_proposal:<proposalId> em sources[]"
  }
}
```

**Implementação existente:**
- `IveProposedAction.tryParse()` — validação de campos
- `IveActionProposal.fromProposedAction()` — montagem com TTL
- `ServiceBackedIveActionExecutor.execute()` — persistência com deduplicação
- Invalidação pós-execução: `actionQueueByProjectProvider`, `actionQueueProvider`, `pendingActionsProvider`, `ecosystemScoresProvider`, `iveContextDataProvider`

---

### `action.list` (read)

**Backing existente:** `actionQueueByProjectProvider(projectId)` / `ActionQueueService`

```json
{
  "tool_name": "action.list",
  "description": "Lista ações do projeto ativo, com filtro opcional por status e limite de retorno.",
  "permission": "read",
  "requires_user_confirmation": false,
  "input_schema": {
    "project_id": { "type": "string", "format": "uuid", "required": true },
    "status":     { "type": "string", "enum": ["pending", "in_progress", "completed", "cancelled"] },
    "limit":      { "type": "integer", "default": 10, "maximum": 25 }
  },
  "output_schema": {
    "actions": [
      {
        "id":           "uuid",
        "title":        "string",
        "status":       "string",
        "priority":     "integer (0-100)",
        "impact_score": "integer (0-100)",
        "effort_score": "integer (0-100)",
        "roi_score":    "integer (0-100)",
        "origin":       "string"
      }
    ]
  },
  "security": {
    "user_id_source": "JWT only",
    "rls": "action_queue.user_id = auth.uid()"
  }
}
```

---

### `opportunity.list` (read)

**Backing existente:** `opportunityLabByProjectProvider(projectId)` / `OpportunityLabService`

```json
{
  "tool_name": "opportunity.list",
  "description": "Lista oportunidades avaliadas do projeto ativo, ordenadas por final_score.",
  "permission": "read",
  "requires_user_confirmation": false,
  "input_schema": {
    "project_id": { "type": "string", "format": "uuid", "required": true },
    "status":     { "type": "string", "enum": ["pending", "approved", "rejected"] },
    "limit":      { "type": "integer", "default": 10, "maximum": 25 }
  },
  "output_schema": {
    "opportunities": [
      {
        "id":               "uuid",
        "title":            "string",
        "description":      "string",
        "final_score":      "integer (0-100)",
        "market_score":     "integer",
        "revenue_score":    "integer",
        "competition_score":"integer",
        "strategic_fit":    "integer",
        "synergy_score":    "integer",
        "opportunity_type": "string",
        "status":           "string",
        "confidence":       "string"
      }
    ]
  },
  "security": {
    "user_id_source": "JWT only",
    "rls": "opportunity_lab.user_id = auth.uid()"
  }
}
```

---

### `kb.search` (read)

**Backing existente:** `knowledgeItemsByProjectProvider(projectId)` / `KnowledgeService`

```json
{
  "tool_name": "kb.search",
  "description": "Busca itens na Knowledge Base do projeto ativo por título ou niche. Retorna apenas metadados.",
  "permission": "read",
  "requires_user_confirmation": false,
  "input_schema": {
    "project_id": { "type": "string", "format": "uuid", "required": true },
    "query":      { "type": "string", "maxLength": 200 },
    "limit":      { "type": "integer", "default": 5, "maximum": 10 }
  },
  "output_schema": {
    "items": [
      {
        "id":                "uuid",
        "title":             "string",
        "status":            "string",
        "opportunity_score": "integer (0-100)",
        "niche":             "string | null"
      }
    ],
    "limitation": "Apenas metadados retornados. Conteúdo integral dos documentos não está disponível."
  },
  "security": {
    "user_id_source": "JWT only",
    "rls": "knowledge_items.user_id = auth.uid()",
    "note": "Conteúdo dos documentos NÃO é retornado — apenas metadados e scores."
  }
}
```

---

### `score.get` (read)

**Backing existente:** `ecosystemScoresProvider` / `EcosystemIntelligenceService`

```json
{
  "tool_name": "score.get",
  "description": "Retorna os scores de ecossistema do projeto ativo calculados pelo EcosystemIntelligenceService.",
  "permission": "read",
  "requires_user_confirmation": false,
  "input_schema": {
    "project_id": { "type": "string", "format": "uuid", "required": true }
  },
  "output_schema": {
    "ecosystem_score":  "integer (0-100)",
    "execution_score":  "integer | null",
    "opportunity_score":"integer (0-100)",
    "market_score":     "integer (0-100)",
    "strategic_fit":    "integer (0-100)",
    "synergy_score":    "integer (0-100)",
    "roi_score":        "integer (0-100) | null",
    "has_roi_data":     "boolean",
    "momentum_score":   "integer (0-100)",
    "has_enough_data":  "boolean"
  },
  "security": {
    "user_id_source": "JWT only",
    "note": "EcosystemIntelligenceService é pure in-memory. Dados de entrada já foram filtrados por user_id."
  }
}
```

---

## Ferramentas Excluídas da V1

| Tool | Razão da exclusão |
|---|---|
| `action.update` | Requer lógica de merge e validação de estado atual — complexidade alta para V1 |
| `action.complete` / `action.cancel` | Mutações de estado — deixar para V2 após validação do loop básico |
| `opportunity.create` | OpportunityLabService tem lógica de scoring complexa — V2 |
| `opportunity.update` | Mesma razão |
| `kb.create` | Upload de documento envolve storage — fora do escopo de V1 |
| `project.update` | Mutação de dados core do usuário — risco alto, V2+ |
| `report.generate` | Dependência de múltiplos tools + formatação — V2 |

---

## Protocolo de Tool Call (LLM → Agent Runner)

O LLM deve retornar, quando quiser usar uma ferramenta, um objeto `tool_call` no formato:

```json
{
  "tool_name": "action.list",
  "tool_input": {
    "project_id": "<uuid do projeto ativo>",
    "status": "pending",
    "limit": 5
  }
}
```

O Agent Runner:
1. Valida `tool_name` contra o registry
2. Valida `tool_input` contra o schema declarado
3. **Substitui `project_id` pelo project_id verificado server-side** (nunca usa o do payload)
4. Executa o tool com `user_id` do JWT
5. Retorna resultado como próxima mensagem de contexto para o LLM
6. Repete até o LLM retornar uma resposta final (sem `tool_call`) ou `max_turns` atingido

---

## Limites do Agent Loop

```
max_turns:          5   — número máximo de iterações tool_call → resultado
max_tools_per_turn: 1   — uma ferramenta por iteração (sem parallel tool calls em V1)
timeout_total:      25s — igual ao contexto atual do Edge Function
write_tools_per_session: 1 — só uma operação de escrita por conversa (V1)
```

---

## Sequência de Evolução

```
V1 (Phase 1B):    action.create + action.list + opportunity.list + kb.search + score.get
V2:               action.update/complete/cancel + opportunity.create
V3:               project tools + report generation
V4+:              tools de integração externa (calendário, CRM, etc.)
```
