# Executive Event Catalog

Catálogo completo de todos os tipos de eventos na timeline executiva.

## Visão Geral

Os eventos são emitidos automaticamente pelas operações do usuário (criar projeto, concluir análise, etc.) e persistidos na tabela `project_events` com idempotência garantida.

---

## Tipos de Evento

| Tipo (DB) | Enum Dart | Emoji | filterGroup | Módulo Origem |
|-----------|-----------|-------|-------------|---------------|
| `project_created` | `projectCreated` | 🌱 | Projeto | projects |
| `stage_changed` | `stageChanged` | 📈 | Projeto | projects |
| `analysis_completed` | `analysisCompleted` | 🔬 | Análises | market_intelligence |
| `decision_taken` | `decisionTaken` | ✅ | Decisões | opportunity_lab |
| `opportunity_created` | `opportunityCreated` | 💡 | Oportunidades | opportunity_lab |
| `document_added` | `documentAdded` | 📄 | Conhecimento | knowledge_vault |
| `action_completed` | `actionCompleted` | ⚡ | Ações | action_engine |
| `check_in` | `checkIn` | 🔄 | Decisões | executive_intelligence |
| `interview_completed` | `interviewCompleted` | 🎤 | Conhecimento | projects |
| `relationship_detected` | `relationshipDetected` | 🔗 | Projeto | executive_intelligence |
| `health_changed` | `healthChanged` | ❤️ | Análises | executive_intelligence |
| `priority_changed` | `priorityChanged` | 🎯 | Análises | executive_intelligence |

---

## Fluxos de Emissão Automática

### `project_created`
**Trigger:** `ProjectsNotifier.create()` → `ExecutiveContextOrchestrator.onProjectCreated()`

**Metadata:** `{'project_name': String}`

**Idempotência:** Não aplicada (sem sourceEntityId)

---

### `stage_changed`
**Trigger:** `ProjectsNotifier.updateStatus()` → `ExecutiveContextOrchestrator.onStageChanged()`

**Metadata:** `{'status': String, 'project_name': String}`

**Idempotência:** Não aplicada

---

### `analysis_completed`
**Trigger:** `MarketAnalysisNotifier.analyze()` → `ExecutiveContextOrchestrator.onAnalysisCompleted()`

**Metadata:** `{'opportunity_score': int}`

**Idempotência:** `'${projectId}_analysisCompleted_${marketAnalysisId}'`

**Efeito adicional:** Atualiza `last_analysis_at` em `executive_contexts`

---

### `decision_taken`
**Trigger:** `OpportunityLabNotifier.approve()` → `ExecutiveContextOrchestrator.onDecisionTaken()`

**Metadata:** `{'opportunity_title': String}`

**Idempotência:** `'${projectId}_decisionTaken_${opportunityId}'`

---

### `opportunity_created`
**Trigger:** `OpportunityLabNotifier.add()` → `ExecutiveContextOrchestrator.onOpportunityCreated()`

**Metadata:** `{'opportunity_title': String}`

**Idempotência:** Via auto-geração: `'${projectId}_opportunityCreated_${opportunityId}'`

---

### `document_added`
**Trigger:** `KnowledgeItemNotifier.create()` → `ExecutiveContextOrchestrator.onDocumentAdded()`

**Metadata:** `{'title': String}`

**Idempotência:** `'${projectId}_documentAdded_${knowledgeItemId}'`

---

### `action_completed`
**Trigger:** `ActionQueueNotifier.complete()` → `ExecutiveContextOrchestrator.onActionCompleted()`

**Metadata:** `{'action_title': String}`

**Idempotência:** `'${projectId}_actionCompleted_${actionId}'`

---

### `check_in`
**Trigger:** Banner de check-in no `_ProjectDetailSheet` → callback → `ExecutiveContextOrchestrator.onCheckInCompleted()`

**Metadata:** `{'project_name': String}`

**Efeito adicional:** `ExecutiveContextService.markCheckInCompleted()` define `check_in_due = false`

---

### `interview_completed`
**Trigger:** `IdeaInterviewDialog._saveAsKnowledge()` → `ProjectEventNotifier.emit()`

**Metadata:** (vazio — detalhes no KnowledgeItem)

---

## Mecanismo de Idempotência

1. Chave gerada: `'${projectId}_${type.name}_${sourceEntityId}'`
2. Persistida em `idempotency_key` (NULL-safe unique index)
3. Colisão capturada: `PostgrestException` code `'23505'` → silenciada, log apenas
4. NULLs não colidem entre si no PostgreSQL (partial index)

---

## Filtros da Timeline UI

| filterGroup | Tipos de Evento |
|-------------|-----------------|
| Análises | `analysisCompleted`, `healthChanged`, `priorityChanged` |
| Conhecimento | `documentAdded`, `interviewCompleted` |
| Decisões | `decisionTaken`, `checkIn` |
| Oportunidades | `opportunityCreated` |
| Ações | `actionCompleted` |
| Projeto | `projectCreated`, `stageChanged`, `relationshipDetected` |
