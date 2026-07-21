# IVE Permission Model — Blueprint v1.0

> Status: BLUEPRINT ONLY — Nenhuma implementação realizada.  
> Data: 2026-07-21

---

## Princípios Fundamentais

### P1: User_id vem exclusivamente do JWT

Nenhum dado de user_id ou project_id recebido no payload do cliente é confiável para operações de autorização. O servidor sempre deriva `user_id` de:

```typescript
const { data: { user }, error } = await supabaseClient.auth.getUser();
// user.id é a única fonte de verdade para user_id
```

O campo `project_id` enviado no `IveCopilotRequest.toMap()` é usado apenas para **localização** do projeto — a propriedade é verificada server-side via query no banco:

```sql
SELECT id FROM projects WHERE id = $project_id AND user_id = $uid LIMIT 1;
-- Se retornar vazio → 404 (IveProjectMismatchException / clearsSelectedProject=true)
```

### P2: RLS é a última linha de defesa

Mesmo que o Agent Runner ou qualquer camada intermediária contenha bugs de autorização, o RLS do Supabase garante que uma query só retorna dados do `auth.uid()` corrente:

```sql
-- Política existente em todas as tabelas relevantes:
CREATE POLICY "Users can only access their own data"
  ON action_queue FOR ALL
  USING (auth.uid() = user_id);
```

Isso vale para: `projects`, `action_queue`, `opportunity_lab`, `knowledge_items`, `ecosystem_scores`, `assets`, `asset_resources`.

### P3: ENTITY_ISOLATION no Edge Function

O Edge Function atual implementa isolamento pós-query:

```typescript
// supabase/functions/context-copilot/index.ts
// Após carregar oportunidades do banco (já filtradas por user_id):
const projectOpps = opportunities.filter(o => o.project_id === projectId);
// → Dados de outros projetos do mesmo usuário são descartados
```

O Agent Runner deve manter esse padrão para cada tool call.

### P4: Escrita requer confirmação explícita do usuário

Tools com `permission: "write"` nunca são executados automaticamente pelo Agent Runner. O fluxo obrigatório é:

```
LLM propõe tool_call action.create
    │
    ▼
Agent Runner detecta write tool → retorna IveActionProposal (sem executar)
    │
    ▼
ContextCopilotNotifier.state.pendingProposal != null → UI exibe card de confirmação
    │
    ▼
Usuário confirma → ContextCopilotNotifier.confirmProposal()
    │
    ▼
IveActionExecutor.execute() → Supabase INSERT
```

Nunca executar `action.create` sem que o usuário tenha explicitamente aprovado.

---

## Matriz de Permissões

| Tool | Tipo | Requer confirmação | Permite sem projeto | Fonte do user_id |
|---|---|---|---|---|
| `action.create` | write | SIM | NÃO | JWT |
| `action.list` | read | NÃO | NÃO | JWT |
| `opportunity.list` | read | NÃO | NÃO | JWT |
| `kb.search` | read | NÃO | NÃO | JWT |
| `score.get` | read | NÃO | NÃO | JWT |

---

## Validações por Camada

### Camada 1: Cliente Flutter (ContextCopilotNotifier.send)

```dart
// providers/context_copilot_provider.dart
final uid = _currentUserId();
if (uid == null || uid != scope.userId) {
  // → CopilotState.unauthorized — limpa histórico
}
if (scope.projectId.isEmpty || context.projectId != scope.projectId) {
  // → error: "Selecione um projeto antes de conversar com a IVE."
}
```

### Camada 2: Gateway (SupabaseIveCopilotGateway)

- Usa `supabase-flutter` que injeta automaticamente o token JWT do usuário logado
- Timeout de 45s client-side (Edge Function tem 25s)
- Erros HTTP mapeados para `IveCopilotHttpException` com semântica:
  - 401 → `clearsSensitiveState=true` → limpa sessão
  - 404 → `clearsSelectedProject=true` → remove projeto selecionado

### Camada 3: Edge Function (context-copilot / ive-agent-runner)

```typescript
// Ordem obrigatória de verificações:
// 1. Verificar Authorization header
const { data: { user } } = await supabaseClient.auth.getUser();
if (!user) return 401;

// 2. Verificar que project_id pertence ao user
const { data: project } = await supabase
  .from('projects')
  .select('id, name')
  .eq('id', projectId)
  .eq('user_id', user.id)  // ← obrigatório
  .single();
if (!project) return 404;

// 3. Todas as queries subsequentes usam user.id (nunca payload)
// 4. ENTITY_ISOLATION: filtrar por project_id após cada query
```

### Camada 4: RLS (Supabase Database)

- Automático — não requer código adicional
- Falha silenciosa: queries retornam vazio ao invés de erro para dados não autorizados
- Isso é intencional: impede enumeração de IDs

### Camada 5: Validação de Resposta (IveCopilotResponse.parse)

```dart
// features/ive/domain/ive_copilot_contract.dart
if ((isV2 && projectId != activeProjectId) ||
    (!isV2 && projectId != null && projectId != activeProjectId)) {
  throw IveProjectMismatchException(...);
  // → clearsSelectedProject=true via IveCopilotHttpException(status: 404)
}
```

### Camada 6: Validação de Proposta (IveProposedAction.tryParse)

```dart
if (map['tool_name'] != 'action.create' || map['project_id'] != activeProjectId) {
  return null;  // descarta silenciosamente
}
// Valida evidence_ids contra IDs de evidências desta sessão
// Valida opportunity_id contra IDs de oportunidades do projeto ativo
```

---

## Escopo da CopilotScope

`CopilotScope(userId, projectId, screenName)` é a chave do provider `contextCopilotProvider.family`. Isso garante que:

1. Cada combinação `(user, project, screen)` tem seu próprio `ContextCopilotNotifier` isolado
2. Trocar de projeto cria uma nova instância do notifier — histórico do projeto anterior não vaza
3. `autoDispose` garante que instâncias não utilizadas são destruídas

```dart
// providers/context_copilot_provider.dart
final contextCopilotProvider = StateNotifierProvider.autoDispose
    .family<ContextCopilotNotifier, CopilotState, CopilotScope>(
  (ref, scope) => ContextCopilotNotifier(ref, scope),
);
```

---

## Confirmação de Proposta: Guards em Cascata

```dart
// ContextCopilotNotifier.confirmProposal()

// Guard 1: Projeto ativo mudou desde que a proposta foi criada
if (proposal.projectId != scope.projectId) {
  invalidateProposalForProjectChange();
  return;
}

// Guard 2: TTL de 15 minutos expirou
if (proposal.isExpired) {
  state = state.copyWith(
    clearProposal: true,
    error: 'A proposta expirou. Solicite uma nova recomendação.',
  );
  return;
}

// Guard 3: Já está executando
if (state.executing) return;

// Só executa se todos os guards passaram
```

---

## O que o Agente NUNCA pode fazer (V1)

| Operação | Razão |
|---|---|
| Usar `user_id` do payload do cliente | user_id vem exclusivamente do JWT |
| Escrever para outro projeto do mesmo usuário | ENTITY_ISOLATION + verificação de `proposal.projectId == scope.projectId` |
| Criar múltiplas ações em uma sessão | `write_tools_per_session: 1` no Agent Loop V1 |
| Deletar dados | Não existe tool de deleção em V1 |
| Acessar dados de outro usuário | RLS bloqueia em nível de banco |
| Executar sem confirmação do usuário | Guards no `confirmProposal()` + UI obrigatória |
| Contornar TTL da proposta | `isExpired` verificado em `confirmProposal()` antes da execução |
| Referenciar evidências de outro projeto | `IveEvidence.tryParse()` valida `projectId == activeProjectId` |
| Referenciar oportunidades de outro projeto | `allowedOpportunityIds` construído a partir das oportunidades do projeto ativo |

---

## Autenticação: Ciclo de Vida

```
Login do usuário
    │
    ▼
supabase.auth.currentUser → uid disponível
    │
    ▼
CopilotScope(userId: uid, ...) criado
    │
    ▼
ContextCopilotNotifier escuta auth stream:
  onAuthStateChange → signedOut → clearHistory()
    │
    ▼
IveMemoryProvider.clearSensitiveSession() → limpa recentQuestions
    │
    ▼
selectedProjectProvider.clear() → limpa projeto selecionado
```

Nenhum dado de conversa ou proposta sobrevive ao logout.
