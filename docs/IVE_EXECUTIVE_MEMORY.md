# IVE EXECUTIVE MEMORY
## InsightValues Business OS — Memória Executiva da IVE
### Data: 2026-07-29 | FASE 11

---

## OBJETIVO

Garantir que a IVE nunca perca o contexto de um projeto quando o usuário retornar.
Cada projeto possui um `ExecutiveContext` persistente que agrega automaticamente:
- Perfil do projeto
- Estágio de maturidade
- Decisões-chave
- Riscos abertos
- Sinergias com outros projetos
- Histórico de análises
- Próximo Check-In agendado

---

## ARQUITETURA

### Modelo: `ExecutiveContext`

```dart
class ExecutiveContext {
  final String   projectId;
  final String   userId;
  final String   executiveSummary;
  final List<String> keyDecisions;    // decisões tomadas
  final List<String> openRisks;       // riscos ainda ativos
  final List<String> synergies;       // sinergias detectadas
  final String   currentStage;        // 'ideia' | 'validando' | 'crescendo' | 'maduro'
  final DateTime? lastAnalysisAt;
  final DateTime? lastCheckInAt;
  final DateTime? checkInDueAt;       // quando a IVE deve pedir check-in
  final int      priorityScore;       // 0-100, dinâmico
  final Map<String, dynamic> metadata;
  final DateTime updatedAt;
}
```

### Tabela Supabase: `executive_contexts`

```sql
create table executive_contexts (
  id                 uuid primary key default gen_random_uuid(),
  project_id         uuid not null references projects(id) on delete cascade,
  user_id            uuid not null references auth.users(id),
  executive_summary  text default '',
  key_decisions      jsonb default '[]',
  open_risks         jsonb default '[]',
  synergies          jsonb default '[]',
  current_stage      text default 'ideia',
  last_analysis_at   timestamptz,
  last_check_in_at   timestamptz,
  check_in_due_at    timestamptz,
  priority_score     integer default 0,
  metadata           jsonb default '{}',
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);
```

---

## FLUXO DE ATUALIZAÇÃO AUTOMÁTICA

```
Evento ocorre (análise, decisão, documento, ação)
    ↓
IveEventBus.emit(event)
    ↓
ExecutiveContextService.updateFromEvent(projectId, event)
    ↓
Atualiza: executiveSummary, lastAnalysisAt, openRisks, synergies
    ↓
Agenda próximo checkInDueAt (+21 dias)
    ↓
Persiste no Supabase
```

---

## CONTEXTO VIVO (SESSÃO)

O `IveMemoryNotifier` é extendido para incluir:

```dart
// Campos adicionados à IveMemory (sessão)
final Map<String, int>     projectHealthScores;   // projectId → health
final Map<String, String>  projectStages;         // projectId → stage
final List<String>         checkInDueProjects;    // projetos que precisam de check-in
```

---

## INTEGRAÇÃO COM COPILOT CHAT

Quando o usuário abre o Copilot Chat em um projeto:

```dart
showCopilotChat(
  context,
  screenName:     'Projetos',
  initialMessage: '[contexto do ExecutiveContext do projeto]',
)
```

O contexto é injetado automaticamente no prompt do Copilot via `IveContextDataProvider`.

---

## REGRAS DE QUALIDADE

| Regra | Implementação |
|-------|--------------|
| Nunca começar do zero | ExecutiveContext é lido na abertura do projeto |
| Resumo sempre atualizado | Re-gerado a cada análise ou decisão |
| Check-in automático | Agendado +21 dias após última atividade |
| Riscos expiram | Removidos automaticamente quando mitigados |
| Prioridade dinâmica | Recalculada a cada mudança de status |
