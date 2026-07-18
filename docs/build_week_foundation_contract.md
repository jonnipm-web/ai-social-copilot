# Contrato da Fundação — Build Week

**Status:** CONGELADA após aprovação da Fase 1C  
**Branch de referência:** `claude/access-social-copilot-wJ6B5`  
**Data de congelamento:** 2026-07-18

---

## 1. Arquitetura da Fundação

```
Flutter App
├── Providers (Riverpod)          ← lógica de negócio, estado reativo
│   ├── selectedProjectProvider   ← projeto ativo global
│   ├── projectsNotifierProvider  ← lista de projetos do usuário
│   ├── currentProfileProvider    ← perfil/role do usuário logado
│   └── [módulo]Provider          ← um por módulo de dados
├── Services (data layer)         ← acesso ao Supabase
│   └── _requireUid() em TODOS   ← guard de autenticação obrigatório
└── Models                        ← imutáveis, DateParser em todos os DateTime
```

---

## 2. Fonte do Usuário Autenticado

**Única fonte confiável:**
```dart
Supabase.instance.client.auth.currentUser?.id
```

**Regra:** NUNCA confiar em userId vindo do payload do cliente ou do model.  
**Implementação:** todos os services têm `_requireUid()` que lança `Exception('Não autenticado')` antes de qualquer query.

---

## 3. Fonte do Projeto Ativo

**Provider:** `selectedProjectProvider` (StateNotifierProvider)  
**Arquivo:** `lib/providers/selected_project_provider.dart`

**Contrato:**
- Persiste apenas o `id` em `SharedPreferences` (chave: `selected_project_id`)
- Restaura na inicialização validando `project.userId == uid da sessão`
- Auto-limpa no logout via `onAuthStateChange(signedOut)`
- Restaura no login via `onAuthStateChange(signedIn | tokenRefreshed)`
- `select(project)` valida ownership antes de aceitar
- `refresh()` é no-op seguro se não há projeto ativo

**Como consumir na IVE:**
```dart
final project = ref.watch(selectedProjectProvider);
// project pode ser null — sempre verificar antes de usar
```

---

## 4. Services Disponíveis

Todos os services abaixo têm `_requireUid()` implementado.

| Service | Arquivo | Tabela Principal |
|---|---|---|
| `ProjectService` | `data/services/project_service.dart` | `projects` |
| `KnowledgeService` | `data/services/knowledge_service.dart` | `knowledge_items` |
| `OpportunityLabService` | `data/services/opportunity_lab_service.dart` | `opportunity_lab` |
| `ActionQueueService` | `data/services/action_queue_service.dart` | `action_queue` |
| `ContentService` | `data/services/content_service.dart` | `content_items` |
| `CalendarService` | `data/services/calendar_service.dart` | `calendar_items` |
| `PostService` | `data/services/post_service.dart` | `post_generations` |
| `CampaignService` | `data/services/campaign_service.dart` | `campaigns` |
| `PerformanceService` | `data/services/performance_service.dart` | `performance_metrics` |
| `RoiMetricService` | `data/services/roi_metric_service.dart` | `roi_metrics` |
| `BusinessMemoryService` | `data/services/business_memory_service.dart` | `business_memory` |
| `CopilotService` | `data/services/copilot_service.dart` | `copilot_sessions` |
| `PersonaTrainingService` | `data/services/persona_training_service.dart` | `persona_training` |
| `WebsiteAnalyzerService` | `data/services/website_analyzer_service.dart` | `website_analyses` |
| `MarketAnalysisService` | `data/services/market_analysis_service.dart` | `market_analyses` |
| `ProfileService` | `data/services/profile_service.dart` | `profiles` |

---

## 5. Contratos por Módulo

### Knowledge Base
```dart
// Buscar itens do projeto ativo
KnowledgeService().fetchAll(projectId: project?.id)

// Criar item (userId injetado do token, não do model)
KnowledgeService().create(knowledgeItem)

// Campos obrigatórios do KnowledgeItem:
//   id, userId, title, content, createdAt, updatedAt
```

### Opportunity Lab
```dart
OpportunityLabService().fetchAll(projectId: project?.id)
OpportunityLabService().create(item)  // userId injetado da sessão

// OpportunityLabItem campos principais:
//   id, userId, title, description, opportunityScore, status
```

### Action Engine (Fila de Tarefas)
```dart
ActionQueueService().fetchAll(projectId: project?.id, status: 'pending')
ActionQueueService().create(item)
ActionQueueService().update(id, data)

// ActionQueueItem campos principais:
//   id, userId, projectId, title, status, priority, opportunityScore
```

### Library (Content Items)
```dart
ContentService().fetchAll(projectId: project?.id, type: 'artigo')
ContentService().create(item)  // userId injetado da sessão

// Tipos válidos: 'artigo', 'video', 'podcast', 'infografico', 'email'
```

---

## 6. Regras de userId

1. **Nunca leia userId do model para gravar no banco** — sempre use `_requireUid()`
2. **Filtre SEMPRE por userId nas queries de leitura** — `.eq('user_id', uid)`
3. **RLS no banco é a segunda camada** — o service é a primeira
4. **Sem sessão = Exception** — nunca retorne dados de fallback sem autenticação

---

## 7. Regras de projectId

1. **projectId é sempre opcional nas queries** — o service suporta `null` (retorna todos do usuário)
2. **selectedProjectProvider fornece o projectId** — não peça ao usuário
3. **Valide ownership antes de selecionar** — `select()` já faz isso
4. **Projeto removido** — `fetchById` retorna null → `selectedProjectProvider` limpa automaticamente

---

## 8. Tratamento de Erros

| Situação | Comportamento esperado |
|---|---|
| Sem sessão | `Exception('Não autenticado')` — **sempre** |
| Não é admin | `Exception('Operação reservada para administradores')` |
| Auto-promoção | `Exception('Administrador não pode alterar a própria role')` |
| Projeto alheio | `Exception('Projeto não pertence ao usuário')` |
| Projeto removido | `null` retornado, state limpo automaticamente |
| Supabase offline | Exception propagada — UI trata com `AsyncValue.error` |

**Padrão de logging:**
```dart
// Erros de segurança sempre logados (mesmo em release)
debugPrint('[Security] Acesso negado — uid=$uid role=$role');
```

---

## 9. Modelo de Permissões

**Roles disponíveis:** `free`, `pro`, `premium`, `beta_tester`, `admin`

**Limites mensais:**
```dart
AppConstants.planLimits = {
  'admin': 99999, 'premium': 1000, 'pro': 100,
  'beta_tester': 50, 'free': 5,
}
```

**Verificação no código:**
```dart
final profile = ref.watch(currentProfileProvider).valueOrNull;
final isAdmin = profile?.isAdmin ?? false;
final isPro = profile?.isPro ?? false;
```

**Operações admin** (verificação obrigatória via `_requireAdmin()` no service):
- `ProfileService.updateRole()`
- `ProfileService.setActive()`
- `ProfileService.fetchAllProfiles()`

---

## 10. Arquivos PROTEGIDOS — Não Modificar

Os seguintes arquivos NÃO devem ser modificados pelo Codex sem necessidade comprovada:

```
lib/core/utils/date_parser.dart              ← utilitário de DateTime seguro
lib/core/constants/app_constants.dart        ← constantes e limites de plan
lib/data/services/profile_service.dart       ← guards de admin
lib/providers/selected_project_provider.dart ← ciclo de vida de auth
lib/providers/project_provider.dart          ← fonte única de projetos

supabase/migrations/021_security_profile_admin_guards.sql ← RLS + trigger
supabase/migrations/006_phase9_tables.sql                 ← RLS sub-entidades

.github/workflows/build-apk.yml             ← CI: não reduzir cobertura
```

---

## 11. Pontos de Extensão para a IVE

A IVE Executive Assistant pode consumir os seguintes contratos sem modificar a fundação:

```dart
// 1. Projeto ativo (read-only para IVE)
final project = ref.watch(selectedProjectProvider);

// 2. Dados de todos os módulos (filtrados por projeto)
final knowledge = await KnowledgeService().fetchAll(projectId: project?.id);
final tasks = await ActionQueueService().fetchAll(projectId: project?.id);
final opportunities = await OpportunityLabService().fetchAll(projectId: project?.id);

// 3. Memória de negócio
final memory = await BusinessMemoryService().fetchAll(projectId: project?.id);

// 4. Perfil do usuário (para personalização)
final profile = ref.watch(currentProfileProvider).valueOrNull;

// 5. IveEventBus — reagir a eventos sem acoplar providers
IveEventBus.instance.stream.listen((event) {
  // IveEventType.projectCreated, projectDeleted, projectStatusChanged
});
```

**Regra de ouro para a IVE:** nunca modifique dados diretamente — use os services existentes ou crie novos seguindo o mesmo padrão (_requireUid + filter by userId).

---

## 12. Checklist de Conformidade para Novas Features

Antes de adicionar qualquer feature nova, verificar:

- [ ] Service tem `_requireUid()` em todos os métodos de leitura
- [ ] Service injeta uid da sessão (não do model) nos creates
- [ ] Novo model usa `DateParser.parse()` (nunca `DateTime.parse()`)
- [ ] Novo provider tem override via `Provider<Interface>` (para testes)
- [ ] Teste de auth guard criado (`throwsNotAuthenticated()`)
- [ ] Migração SQL tem RLS com `auth.uid() = user_id`
