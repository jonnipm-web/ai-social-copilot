# Executive Context Orchestration

## Visão Geral

O `ExecutiveContextOrchestrator` é a camada central que coordena todos os eventos executivos: emite eventos na timeline persistida e mantém `last_activity_at` atualizado no `executive_contexts`.

## Arquitetura

```
Ação do Usuário
     │
     ▼
[Provider Notifier]
(ProjectsNotifier, MarketAnalysisNotifier, etc.)
     │
     ▼
ExecutiveContextOrchestrator
     │
     ├── ProjectEventService.emit()  ──► project_events (Supabase)
     │
     └── ExecutiveContextService.updateLastActivity()  ──► executive_contexts (Supabase)
```

## Classe Principal

```dart
class ExecutiveContextOrchestrator {
  Future<void> onProjectCreated({required String projectId, required String projectName})
  Future<void> onStageChanged({required String projectId, required String projectName, required String newStatus})
  Future<void> onAnalysisCompleted({required String projectId, required String? marketAnalysisId, required int opportunityScore})
  Future<void> onOpportunityCreated({required String projectId, required String opportunityId, required String opportunityTitle})
  Future<void> onDecisionTaken({required String projectId, required String opportunityId, required String opportunityTitle})
  Future<void> onDocumentAdded({required String projectId, required String knowledgeItemId, required String documentTitle})
  Future<void> onActionCompleted({required String projectId, required String actionId, required String actionTitle})
  Future<void> onCheckInCompleted({required String projectId, required String projectName})
}
```

## Providers

```dart
final executiveContextServiceProvider = Provider<ExecutiveContextService>(...);
final executiveContextOrchestratorProvider = Provider<ExecutiveContextOrchestrator>(...);
```

Localização: `lib/data/services/executive_context_orchestrator.dart`

## Uso nos Providers

### Com `ref` disponível (ConsumerNotifier / StateNotifier com Ref)
```dart
ref.read(executiveContextOrchestratorProvider).onProjectCreated(
  projectId: id, projectName: name,
);
```

### Sem `ref` (StateNotifier simples)
```dart
ExecutiveContextOrchestrator().onActionCompleted(...);
```

## Método `_emitAndUpdate`

Método privado central que:
1. Chama `ProjectEventService.emit()` com os parâmetros do evento
2. Chama `ExecutiveContextService.updateLastActivity()` para timestamp

Nunca lança exceções — falhas são logadas e ignoradas para não bloquear o fluxo principal.

## Responsabilidades fora do Orquestrador

- **Recalcular ExecutiveHealth**: feito pelo `ProjectIntelligenceService` ao ser invalidado
- **Detectar novas relações**: feito pelo `ExecutiveRelationshipService` via `projectRelationshipsProvider`
- **Atualizar UI**: providers são invalidados pelos notifiers após operações

## Fluxo de Check-In

```
Usuário clica "Marcar revisão concluída"
    │
    ▼
_ProjectDetailSheet.onCheckInCompleted callback
    │
    ▼
ExecutiveContextOrchestrator.onCheckInCompleted()
    │
    ├── ProjectEventService.emit(checkIn, ...)  ──► project_events
    ├── ExecutiveContextService.updateLastActivity()  ──► executive_contexts
    └── ExecutiveContextService.markCheckInCompleted()  ──► check_in_due = false
         │
         ▼
ref.invalidate(projectIntelligenceProfilesProvider)
ref.invalidate(projectEventsProvider)
    │
    ▼
UI reconstruída sem o banner
```
