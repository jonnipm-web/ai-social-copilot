# IVE Agent Architecture — Blueprint v1.0

> Status: BLUEPRINT ONLY — Nenhuma implementação realizada.  
> Data: 2026-07-21  
> Branch: claude/access-social-copilot-wJ6B5

---

## 1. Arquitetura Atual (As-Is)

### Fluxo de dados hoje

```
Usuário
  │
  ▼
ContextCopilotWidget (Flutter UI)
  │  seleção de entidade, mensagem de texto
  ▼
ContextCopilotNotifier (StateNotifier)
  │  constrói IveCopilotRequest
  ▼
IveCopilotGateway (interface)
  │
  ▼  HTTP invoke via supabase-flutter
SupabaseIveCopilotGateway
  │
  ▼  Edge Function (Deno / Supabase)
context-copilot/index.ts
  │  JWT → auth.getUser() → uid
  │  4× DB queries (projects, actions, opportunities, kb_items)
  │  buildSystemPrompt()
  ▼
Groq API  (llama-3.3-70b-versatile, temp=0.35, max_tokens=900)
  │
  ▼
IveCopilotResponse.parse() — validação + isolamento de projeto
  │
  ▼
IveActionProposal  (opcional, TTL=15min)
  │
  ▼
IveActionExecutor → Supabase Insert (action_queue)
```

### Componentes principais

| Camada | Arquivo | Responsabilidade |
|---|---|---|
| UI | `shared/widgets/context_copilot_widget.dart` | Sheet flutuante, input, lista de turns |
| State | `providers/context_copilot_provider.dart` | `ContextCopilotNotifier`, `CopilotState`, `CopilotScope` |
| Context | `providers/ive_context_provider.dart` | `IveContextData`, `iveContextDataProvider` |
| Gateway | `features/ive/services/ive_copilot_gateway.dart` | `IveCopilotGateway` interface + `SupabaseIveCopilotGateway` |
| Contrato | `features/ive/domain/ive_copilot_contract.dart` | `IveCopilotRequest`, `IveCopilotResponse`, `IveEvidence`, `IveProposedAction` |
| Proposta | `features/ive/domain/ive_action_proposal.dart` | `IveActionProposal` (TTL, idempotência) |
| Executor | `features/ive/services/ive_action_executor.dart` | `ServiceBackedIveActionExecutor` (persistence marker) |
| Memória | `providers/ive_memory_provider.dart` | SharedPreferences, recentQuestions, clearSensitiveSession |
| Score | `data/services/ecosystem_intelligence_service.dart` | Fórmula pura: opp×25% + fit×25% + syn×20% + roi×20% + mom×10% |
| Edge Fn | `supabase/functions/context-copilot/index.ts` | Auth JWT, DB queries, prompt, Groq API, ENTITY_ISOLATION |

### Limitações da arquitetura atual

1. **LLM único, sem fallback** — Groq/llama-3.3-70b-versatile hardcoded no Edge Function. Qualquer degradação derruba toda a IVE.
2. **Sem roteamento de intent** — O cliente tenta detectar intent com regex local (`detectIntent`), mas o Edge Function não usa essa informação para decidir o caminho de execução.
3. **Única ferramenta disponível** — `action.create` é a única operação que o LLM pode propor. Não existe protocolo para múltiplas ferramentas.
4. **Contexto non-authoritative enviado 2×** — `IveContextData.toCopilotContext()` serializa dados do cliente como hints. O Edge Function depois re-busca os mesmos dados do DB. Duplicação sem benefício de segurança adicional.
5. **Sem streaming** — Resposta completa aguardada (até 45s client / 25s Edge Function). UX degradada em LLMs lentos.
6. **Sem memória de longo prazo** — `iveMemoryProvider` só persiste `recentQuestions` (SharedPreferences). Nenhum resumo de sessão anterior ou perfil de comportamento do usuário.
7. **Sem observabilidade estruturada** — correlation_id existe, mas não há logging centralizado nem rastreamento de tool calls.

---

## 2. Arquitetura Alvo (To-Be)

### Princípio central

> O LLM passa a ser o **orquestrador de ferramentas** (tool-calling agent), não apenas um gerador de texto com uma sugestão opcional de ação.

### Fluxo alvo

```
Usuário
  │
  ▼
ContextCopilotWidget  (sem mudança de UI)
  │
  ▼
ContextCopilotNotifier  (sem mudança de interface pública)
  │  IveCopilotRequest (mesmo contrato)
  ▼
IveCopilotGateway (interface — SEM MUDANÇA)
  │
  ├─── Fase atual ──► SupabaseIveCopilotGateway (mantido, sem alteração)
  │
  └─── Fase 1B ────► IveAgentGateway (nova implementação)
                        │
                        ▼
                      Agent Runner (Edge Function nova)
                        │  recebe IveCopilotRequest
                        │  executa loop: LLM → tool_call → resultado → LLM
                        ▼
                      Tool Registry
                        │
                        ├─ action.create
                        ├─ opportunity.list
                        ├─ action.list
                        ├─ kb.search
                        ├─ score.get
                        └─ [futuros]
                        │
                        ▼
                      Serviços Supabase existentes
                        (RLS aplicado em cada chamada)
```

### Camadas da arquitetura alvo

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter App (sem alteração de interface)                   │
│  ContextCopilotNotifier → IveCopilotGateway (interface)     │
└─────────────────────────────────────────────────────────────┘
                        │
           [Provider override por feature flag]
                        │
┌─────────────────────────────────────────────────────────────┐
│  IveAgentGateway (nova)                                      │
│  Envia request → recebe AgentResponse                        │
└─────────────────────────────────────────────────────────────┘
                        │
                     HTTP/JWT
                        │
┌─────────────────────────────────────────────────────────────┐
│  Edge Function: ive-agent-runner (nova)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Auth layer (JWT → uid, igual ao atual)               │   │
│  │ Context resolver (mesmas 4 queries, server-side)     │   │
│  │ Tool Registry (funções autorizadas por uid)          │   │
│  │ Agent Loop (LLM → tool_call → execute → LLM)        │   │
│  │ Permission Engine (uid validation por tool)          │   │
│  │ Response formatter (mesmo contrato de saída)         │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────────────────┐
│  Supabase DB (sem alteração de schema)                       │
│  RLS: auth.uid() = user_id em todas as tabelas               │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Componentes Reusáveis (Nenhuma alteração necessária)

Os seguintes componentes são **totalmente compatíveis** com a arquitetura alvo sem modificação:

| Componente | Por que pode ser reutilizado |
|---|---|
| `IveCopilotGateway` (interface) | É o ponto de extensão exato. `IveAgentGateway` implementa a mesma interface. |
| `IveCopilotRequest` | Contrato de entrada mantido. `toMap()` já serializa tudo que o agent runner precisa. |
| `IveCopilotResponse` | Contrato de saída mantido. Agent runner retorna o mesmo formato. |
| `IveEvidence` | Usado para expor fontes com validação de UUID e project_id. |
| `IveProposedAction` | Validação de campo, TTL, cross-project guard — todos reaproveitados. |
| `IveActionProposal` | Idempotência via `persistenceMarker`, status machine, `revised()`. |
| `IveActionExecutor` | Executor de persistência com deduplicação. Sem alteração. |
| `ContextCopilotNotifier` | Send/confirm/cancel/revise — interface pública inalterada. |
| `CopilotState` | Sem alteração. |
| `IveContextData.toCopilotContext()` | Hints opcionais — server sempre valida. |
| Todos os providers de dados | `actionQueueByProjectProvider`, `opportunityLabByProjectProvider`, `knowledgeItemsByProjectProvider`, `ecosystemScoresProvider` — servem como backing dos tools. |
| RLS + auth pattern | Todas as tabelas já têm `auth.uid() = user_id`. Tool Registry herda esse padrão. |

---

## 4. Ponto de Extensão Central

```dart
// lib/features/ive/services/ive_copilot_gateway.dart

abstract interface class IveCopilotGateway {
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request);
}

final iveCopilotGatewayProvider = Provider<IveCopilotGateway>((ref) {
  // FASE 1B: substituir por IveAgentGateway via override de provider
  // Exemplo com feature flag:
  // if (ref.watch(featureFlagProvider).agentEnabled) {
  //   return IveAgentGateway(Supabase.instance.client);
  // }
  return SupabaseIveCopilotGateway(Supabase.instance.client);
});
```

A troca de implementação **não requer alteração no ContextCopilotNotifier** nem em qualquer widget.

---

## 5. Mapeamento de Scores

Invariante crítica — nunca alterar sem atualizar os testes de Grupo 5:

```
IveContextData.healthScore  → toCopilotContext() → key 'ecosystem'  (NÃO 'health')
IveContextData.executionScore → key 'execution'
IveContextData.opportunityScore → key 'opportunity'
IveContextData.marketScore → key 'market'
IveContextData.strategicFit → key 'strategic_fit'
IveContextData.synergyScore → key 'synergy'
IveContextData.roiScore → key 'roi'  (só enviado se hasRoiData == true)
IveContextData.momentumScore → key 'momentum'
```

Fórmula EcosystemIntelligenceService (pura, sem I/O):
```
ecosystemScore = opportunity×25% + strategicFit×25% + synergy×20% + roi×20% + momentum×10%
```

---

## 6. Critérios de POC v1 (Phase 1B)

A implementação do agente só pode ser iniciada quando todos os critérios abaixo forem atendidos:

- [ ] `IveAgentGateway` implementa `IveCopilotGateway` e passa nos testes existentes sem modificação
- [ ] Edge Function `ive-agent-runner` passa pela mesma validação JWT que `context-copilot`
- [ ] Tool Registry executa cada tool com `user_id` derivado exclusivamente do JWT (nunca do payload)
- [ ] Agent loop tem limite de iterações (max_turns = 5) para prevenir loops infinitos
- [ ] `IveCopilotResponse.parse()` aceita resposta do agent runner sem modificação
- [ ] Nenhum dado de outro projeto aparece em evidências (ENTITY_ISOLATION mantido)
- [ ] `action.create` tool mantém deduplicação por `persistenceMarker`
- [ ] CI verde com todos os testes existentes passando

---

## 7. Decisões em Aberto

| ID | Decisão | Opções | Impacto |
|---|---|---|---|
| D1 | Provedor de LLM | Groq atual vs Claude API vs OpenAI | Alto — latência, custo, tool-calling nativo |
| D2 | Agent loop location | Edge Function vs cliente Flutter | Alto — latência offline, segurança |
| D3 | Streaming | Não / SSE / WebSocket | Médio — UX percebida |
| D4 | Feature flag de ativação | Provider override vs build flag vs remote config | Baixo — operacional |
| D5 | Memória longo prazo | Nenhuma / DB table / vector store | Alto — qualidade de resposta |

Estas decisões devem ser tomadas **antes** de iniciar Phase 1B.
