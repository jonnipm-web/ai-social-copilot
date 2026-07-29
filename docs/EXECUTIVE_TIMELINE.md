# EXECUTIVE TIMELINE
## InsightValues Business OS — Linha do Tempo Executiva
### Data: 2026-07-29 | FASE 11

---

## OBJETIVO

Registrar automaticamente todos os eventos relevantes de um projeto em uma linha do tempo persistente no Supabase, explicável pela IVE.

---

## MODELO

```dart
enum ProjectEventType {
  projectCreated, stageChanged, analysisCompleted, decisionTaken,
  opportunityCreated, documentAdded, actionCompleted, checkIn,
  interviewCompleted, relationshipDetected, healthChanged, priorityChanged,
}

class ProjectEvent {
  final String id;
  final String projectId;
  final String userId;
  final ProjectEventType eventType;
  final String title;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
}
```

---

## TABELA SUPABASE: `project_events`

```sql
create table project_events (
  id           uuid primary key default gen_random_uuid(),
  project_id   uuid not null references projects(id) on delete cascade,
  user_id      uuid not null references auth.users(id),
  event_type   text not null,
  title        text not null default '',
  description  text default '',
  metadata     jsonb default '{}',
  created_at   timestamptz default now()
);

create index on project_events (project_id, created_at desc);
create index on project_events (user_id, created_at desc);
```

---

## EVENTOS POR EMOJI

| Tipo | Emoji | Quando emitir |
|------|-------|--------------|
| projectCreated | 🌱 | Ao criar projeto |
| stageChanged | 📈 | Mudança de status |
| analysisCompleted | 🔬 | Análise de MI concluída |
| decisionTaken | ✅ | Aprovação de oportunidade |
| opportunityCreated | 💡 | Nova oportunidade no Lab |
| documentAdded | 📄 | Knowledge item adicionado |
| actionCompleted | ⚡ | Ação marcada como completa |
| checkIn | 🔄 | Check-in executivo realizado |
| interviewCompleted | 🎤 | Entrevista de ideia concluída |
| relationshipDetected | 🔗 | Nova relação entre projetos |
| healthChanged | ❤️ | Score de saúde muda ±10 pontos |
| priorityChanged | 🎯 | Priority score muda ±15 pontos |

---

## PROVIDERS

```dart
// Eventos de um projeto
final projectEventsProvider = FutureProvider.autoDispose.family<List<ProjectEvent>, String>;

// Todos os eventos do usuário (timeline global)
final allProjectEventsProvider = FutureProvider.autoDispose<List<ProjectEvent>>;

// Notifier para adicionar eventos
final projectEventNotifierProvider = StateNotifierProvider.autoDispose.family<ProjectEventNotifier, AsyncValue<void>, String>;
```

---

## INTEGRAÇÃO — ONDE EMITIR

### Automático (a implementar em Fase 12)

| Serviço | Evento |
|---------|--------|
| `ProjectsNotifier.create()` | `projectCreated` |
| `ProjectsNotifier.updateStatus()` | `stageChanged` |
| `MarketAnalysisNotifier.analyze()` | `analysisCompleted` |
| `OpportunityLabNotifier.approve()` | `decisionTaken` |
| `OpportunityLabNotifier.add()` | `opportunityCreated` |
| `KnowledgeItemNotifier.create()` | `documentAdded` |
| `ActionQueueNotifier.complete()` | `actionCompleted` |

### Manual (disponível via IdeaInterviewDialog)

```dart
ref.read(projectEventNotifierProvider(projectId).notifier).emit(
  ProjectEventType.interviewCompleted,
  'Entrevista de Ideia concluída',
  description: '10 perguntas respondidas.',
);
```

---

## EXIBIÇÃO NA UI (Fase 12)

```
Timeline do Projeto:
🌱 [2026-07-01] Projeto criado
🔬 [2026-07-05] Análise de mercado concluída — Opportunity Score: 78
💡 [2026-07-10] 3 oportunidades geradas pelo Knowledge Engine
✅ [2026-07-15] Oportunidade "Expansão B2B" aprovada
🎤 [2026-07-20] Entrevista de Ideia concluída — perfil enriquecido
📈 [2026-07-25] Projeto promovido para estágio "Crescendo"
```

Cada evento: clicável → `IveDetailSheet` com contexto completo.
