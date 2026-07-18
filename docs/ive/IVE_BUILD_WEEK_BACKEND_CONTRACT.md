# IVE Build Week — Contrato de Backend

**Versão:** 2.0.0  
**Sprint:** Build Week — Claude 01  
**Edge Function:** `context-copilot`  
**Prompt Version:** `2.0.0`  

---

## 1. Endpoint

```
POST https://<SUPABASE_PROJECT_REF>.supabase.co/functions/v1/context-copilot
```

O `SUPABASE_PROJECT_REF` está disponível em `AppConstants` ou nas variáveis de ambiente do projeto.

---

## 2. Headers Obrigatórios

```http
Authorization: Bearer <SUPABASE_JWT_TOKEN>
Content-Type: application/json
apikey: <SUPABASE_ANON_KEY>
```

O Supabase Flutter SDK injeta `Authorization` e `apikey` automaticamente quando você usa:
```dart
_client.functions.invoke('context-copilot', body: {...})
```

**Não passe `userId` no body.** O servidor extrai o usuário do JWT.

---

## 3. Autenticação

- **Obrigatória:** qualquer requisição sem `Authorization: Bearer <token>` recebe `401`
- **JWT validado** pelo servidor via `client.auth.getUser()`
- **Sessão expirada** retorna `401` com código `UNAUTHORIZED`
- **`userId` do cliente é ignorado** — o servidor usa exclusivamente o uid do JWT
- **`project_id` é validado** — o servidor confirma que pertence ao usuário antes de processar

---

## 4. Request Schema

```typescript
interface ContextCopilotRequest {
  // Obrigatório
  message: string;                    // máx 2.000 chars

  // Identificação de tela (um dos dois)
  screen_name?: string;               // ex: "opportunity_lab"
  route?: string;                     // ex: "/projects/abc/opportunities"

  // Projeto ativo (validado server-side)
  project_id?: string;                // UUID — servidor valida ownership

  // Entidade selecionada na tela (opcional)
  selected_entity_type?: string;      // ex: "opportunity", "action"
  selected_entity_id?: string;        // UUID da entidade selecionada

  // Versão do contrato (para futuras migrações)
  context_version?: string;           // ex: "2.0"

  // Hints do cliente (scores calculados localmente, não validados)
  context?: {
    scores?: {
      ecosystem: number;
      opportunity: number;
      strategic_fit: number;
      roi: number;
      momentum: number;
      market: number;
      execution: number;
      recommendation: string;
    };
    market?: {
      niche: string;
      competition: string;
      growth: number;
      market_score: number;
    };
    personas?: Array<{ name: string; niche: string; learningScore: number }>;
    revenue?: { monthly_moderate: number; annual_moderate: number };
    // IMPORTANTE: project, opportunities, actions NÃO são confiados do cliente
    // O servidor busca esses dados diretamente no banco
  };

  // Histórico da conversa (últimas N mensagens)
  history?: Array<{
    role: 'user' | 'assistant';
    content: string;                  // máx 800 chars por mensagem
  }>;                                 // máx 10 itens (excedente cortado)

  // Perguntas recentes da memória da IVE
  recent_questions?: string[];

  // ID de correlação do cliente (retornado na resposta)
  client_correlation_id?: string;
}
```

### Limites

| Campo | Limite |
|---|---|
| Payload total | 64 KB |
| `message` | 2.000 chars |
| `history` items | 10 (mais antigos cortados) |
| `history[].content` | 800 chars (truncado) |
| `project_id` | UUID v4 válido |

---

## 5. Response Schema

```typescript
interface ContextCopilotResponse {
  // ── Campos backward-compatible (provider atual) ─────────────────────────
  answer:             string;       // texto da resposta (sem o bloco JSON)
  sources:            string[];     // fontes usadas (nomes, não IDs)
  confidence:         number;       // 30–95 (calculado server-side)
  entities:           string[];     // entidades mencionadas
  action_suggestion:  ActionSuggestionLegacy | null;
  timestamp:          string;       // ISO 8601

  // ── Campos novos (IVE v2 / Codex) ───────────────────────────────────────
  response_id:        string;       // UUID único desta resposta
  correlation_id:     string;       // = client_correlation_id ou gerado
  intent:             string;       // 'create' | 'explain' | 'simulate' | 'recommend' | 'query'
  project_id:         string | null; // projeto validado server-side
  evidence:           Evidence[];
  limitations:        string[];     // fontes indisponíveis
  proposed_action:    ProposedAction | null;  // schema fechado
  prompt_version:     string;       // ex: "2.0.0"
  model:              string;       // ex: "llama-3.3-70b-versatile"
  server_timestamp:   string;       // ISO 8601
}
```

---

## 6. Tipos Detalhados

### ActionSuggestionLegacy (campo `action_suggestion`)
Mantido para compatibilidade com `context_copilot_provider.dart`:

```typescript
interface ActionSuggestionLegacy {
  type:  'create_action';           // único tipo desta sprint
  label: string;                    // "Criar ação: <título>"
  data: {
    title:          string;
    description?:   string;
    action_type:    'tarefa';
    priority:       number;         // 50 (medium) ou 80 (high/critical)
    project_id:     string;
    rationale?:     string;
    evidence_ids:   string[];       // apenas IDs reais do servidor
    opportunity_id?: string;
    // Campos do schema fechado (prefixo _)
    _tool:          'action.create';
    _impact:        string;
    _effort:        string;
    _due_date?:     string;
  };
}
```

### ProposedAction (campo `proposed_action`)
Schema fechado — para consumo direto pelo Codex:

```typescript
interface ProposedAction {
  tool_name:      'action.create';  // único valor permitido
  project_id:     string;           // sempre o projeto validado pelo servidor
  title:          string;           // máx 200 chars
  description?:   string;           // máx 1.000 chars
  priority:       'low' | 'medium' | 'high' | 'critical';
  impact:         'low' | 'medium' | 'high';
  effort:         'low' | 'medium' | 'high';
  due_date?:      string;           // ISO 8601 se presente
  rationale?:     string;           // máx 500 chars
  evidence_ids:   string[];         // apenas IDs reais recuperados server-side
  opportunity_id?: string;
}
```

### Evidence

```typescript
interface Evidence {
  source_type:      'project' | 'opportunity' | 'action' | 'kb_item';
  source_id:        string;         // UUID real do banco
  title:            string;
  structured_value?: Record<string, unknown>;   // campos resumidos
  excerpt?:         string;         // texto truncado seguro
  project_id:       string | null;
  timestamp:        string | null;  // ISO 8601
  relevance:        number;         // 0.0 – 1.0
}
```

---

## 7. Enums

### `intent`
`create` | `explain` | `simulate` | `recommend` | `query`

### `priority` (ProposedAction)
`low` | `medium` | `high` | `critical`

### `impact`, `effort` (ProposedAction)
`low` | `medium` | `high`

### `source_type` (Evidence)
`project` | `opportunity` | `action` | `kb_item`

### `sources[]` (campo backward-compat)
Apenas nomes de fontes válidas:
`Projeto` | `Oportunidades` | `Ações` | `Base de Conhecimento` | `Scores` | `Mercado` | `Histórico`

---

## 8. Códigos de Erro

```typescript
interface ErrorResponse {
  error: {
    code:           string;
    message:        string;
    correlation_id: string | null;
  };
}
```

| HTTP | `code` | Significado |
|---|---|---|
| 400 | `BAD_REQUEST` | Payload inválido, campo obrigatório ausente, UUID mal formado |
| 401 | `UNAUTHORIZED` | JWT ausente, inválido ou expirado |
| 404 | `NOT_FOUND` | `project_id` não encontrado ou não pertence ao usuário |
| 405 | `METHOD_NOT_ALLOWED` | Apenas POST aceito |
| 413 | `PAYLOAD_TOO_LARGE` | Payload > 64 KB |
| 502 | `MODEL_ERROR` | Erro na chamada ao modelo Groq |
| 504 | `TIMEOUT` | Modelo não respondeu em 25 s |
| 500 | `SERVER_ERROR` | Configuração do servidor incompleta |

---

## 9. Exemplo de Requisição

```dart
// No context_copilot_provider.dart (não modificar)
final res = await _client.functions.invoke(
  'context-copilot',
  body: {
    'message':     'Qual é minha melhor oportunidade agora?',
    'screen_name': 'opportunity_lab',
    'project_id':  '550e8400-e29b-41d4-a716-446655440000',
    'context': {
      'scores': {
        'ecosystem': 72,
        'opportunity': 85,
        'roi': 60,
        'momentum': 45,
      },
    },
    'history': [
      {'role': 'user',      'content': 'Oi'},
      {'role': 'assistant', 'content': 'Olá! Como posso ajudar?'},
    ],
    'client_correlation_id': 'req-abc-123',
  },
);
```

---

## 10. Exemplo de Resposta

```json
{
  "answer": "Com base nos dados do servidor, sua melhor oportunidade agora é \"Artigo sobre SEO Local\" com score 87/100 e status pending. Ela tem alto impacto e esforço médio, tornando-a candidata prioritária para execução esta semana.",

  "sources": ["Oportunidades", "Projeto"],
  "confidence": 80,
  "entities": ["Artigo sobre SEO Local"],
  "action_suggestion": null,
  "timestamp": "2026-07-18T14:30:00.000Z",

  "response_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "correlation_id": "req-abc-123",
  "intent": "recommend",
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "evidence": [
    {
      "source_type": "opportunity",
      "source_id":   "opp-uuid-real",
      "title":       "Artigo sobre SEO Local",
      "structured_value": { "status": "pending", "score": 87 },
      "project_id":  "550e8400-e29b-41d4-a716-446655440000",
      "timestamp":   "2026-07-15T10:00:00.000Z",
      "relevance":   0.8
    }
  ],
  "limitations": [],
  "proposed_action": null,
  "prompt_version": "2.0.0",
  "model": "llama-3.3-70b-versatile",
  "server_timestamp": "2026-07-18T14:30:00.123Z"
}
```

---

## 11. Exemplo com action.create

```json
{
  "answer": "Recomendo criar uma ação para publicar o artigo sobre SEO Local ainda esta semana.",

  "action_suggestion": {
    "type":  "create_action",
    "label": "Criar ação: Publicar artigo SEO Local",
    "data": {
      "title":          "Publicar artigo SEO Local",
      "description":    "Escrever e publicar artigo otimizado para SEO local",
      "action_type":    "tarefa",
      "priority":       80,
      "project_id":     "550e8400-e29b-41d4-a716-446655440000",
      "rationale":      "Oportunidade com score 87 e alto potencial de tráfego orgânico",
      "evidence_ids":   ["opp-uuid-real"],
      "_tool":          "action.create",
      "_impact":        "high",
      "_effort":        "medium"
    }
  },

  "proposed_action": {
    "tool_name":    "action.create",
    "project_id":   "550e8400-e29b-41d4-a716-446655440000",
    "title":        "Publicar artigo SEO Local",
    "description":  "Escrever e publicar artigo otimizado para SEO local",
    "priority":     "high",
    "impact":       "high",
    "effort":       "medium",
    "rationale":    "Oportunidade com score 87 e alto potencial de tráfego orgânico",
    "evidence_ids": ["opp-uuid-real"],
    "opportunity_id": "opp-uuid-real"
  }
}
```

---

## 12. Confidence — Como é Calculada

O sistema calcula `confidence` **server-side** (nunca pelo modelo):

| Fator | Pontos |
|---|---|
| Base | +30 |
| Projeto validado presente | +20 |
| Oportunidades recuperadas | +15 |
| Ações recuperadas | +15 |
| KB items recuperados | +10 |
| Scores no contexto (client hint) | +10 |
| Nenhuma limitação de contexto | +5 |
| **Máximo** | **95** |

O modelo nunca retorna um `confidence` que seja usado diretamente. O valor que o Codex recebe é sempre calculado pelo servidor.

---

## 13. Timeout e Retry

| Parâmetro | Valor |
|---|---|
| Timeout do modelo | 25 s |
| Limite do Supabase Edge | 60 s |
| Retry recomendado (cliente) | 1x após 504 |
| Retry para 5xx | sim (backoff exponencial) |
| Retry para 4xx | não (erro do cliente) |
| Retry para 401 | renovar token, então retentar |

---

## 14. Regras de Correlação

- Todo request deve incluir `client_correlation_id` (UUID ou string única)
- A resposta sempre retorna `correlation_id` (igual ao enviado, ou gerado)
- Logs do servidor usam `correlation_id` para rastreabilidade
- Em caso de erro, `correlation_id` está no body do erro

---

## 15. O Que o Cliente Deve Validar

- Verificar `res.data` é não-null antes de acessar campos
- Verificar `action_suggestion` não é null antes de mostrar UI de ação
- Usar `correlation_id` para rastreamento de erros em produção
- Exibir `limitations` ao usuário quando não vazio (contexto parcial)
- Nunca executar `proposed_action` diretamente — sempre confirmar com o usuário

## 16. O Que o Servidor Valida

- JWT válido e não expirado
- `project_id` UUID válido e pertencente ao usuário
- `message` presente e dentro do limite
- `history` truncado no servidor (sem erro)
- `evidence_ids` na `action_suggestion` existem de verdade
- `tool_name` é exclusivamente `action.create`
- `priority`, `impact`, `effort` pertencem a enums permitidos

---

## 17. Contexto Carregado Server-Side

O servidor **sempre** carrega diretamente do banco (com RLS):

| Dados | Tabela | Limite | Filtro |
|---|---|---|---|
| Projeto | `projects` | 1 | `user_id` + `project_id` |
| Oportunidades | `opportunity_lab` | 10 | `user_id` + `project_id` |
| Ações | `action_queue` | 10 | `user_id` + `project_id` |
| KB Items | `knowledge_items` | 10 | `user_id` + `project_id` |

O cliente pode enviar **hints** de `scores`, `market`, `personas`, `revenue` — esses dados são usados como complemento mas não são validados contra o banco.

---

## 18. Ações Ainda Não Disponíveis (Esta Sprint)

| Ação | Status | Motivo |
|---|---|---|
| `approve_opportunity` | ❌ não implementada | Próxima sprint |
| `create_project` | ❌ não implementada | Próxima sprint |
| `generate_roadmap` | ❌ não implementada | Próxima sprint |
| Execução de `action.create` | ❌ apenas proposta | A Edge Function não grava no banco |
| RAG completo (embeddings) | ❌ não implementado | Fase 2 |
| Streaming de resposta | ❌ não implementado | Fase 2 |

A Edge Function **nunca executa mutações**. `action.create` é uma proposta que o cliente deve confirmar e executar via `ActionQueueService.create()`.

---

## 19. Integração pelo Codex

Para consumir a proposta de ação no Flutter (depois da confirmação do usuário):

```dart
// 1. Usuário confirma a ação sugerida
// 2. Codex chama ActionQueueService com os dados do proposed_action
final proposal = response['proposed_action'] as Map<String, dynamic>?;
if (proposal != null) {
  final item = ActionQueueItem(
    id:          '',
    userId:      '',   // injetado pelo ActionQueueService._requireUid()
    projectId:   proposal['project_id'] as String?,
    title:       proposal['title'] as String,
    description: proposal['description'] as String?,
    priority:    _parsePriority(proposal['priority']),
    createdAt:   DateTime.now(),
  );
  await ActionQueueService().create(item);
}
```

**`ActionQueueService.create()` injeta o `userId` da sessão autenticada** — não confie no `userId` do payload da Edge Function.

---

## 20. Observações de Segurança para o Codex

1. **Nunca renderize `answer` como HTML** — use `Text()` do Flutter (proteção contra XSS)
2. **Nunca execute código do `answer`** — é texto livre de um LLM
3. **Valide `project_id` na resposta** antes de usar — deve corresponder ao projeto ativo
4. **`evidence_ids` são UUIDs reais** — podem ser usados para buscar detalhes via services
5. **`action_suggestion.data._tool = 'action.create'`** — confirme antes de executar qualquer ação
6. **Nunca modifique `context_copilot_provider.dart`** — a compatibilidade backward é contratual
