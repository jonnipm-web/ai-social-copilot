# AI Social Copilot — Arquitetura

**Data:** 2026-08-02  
**Versão do documento:** Phase 10 Stabilization

---

## Visão Geral

```
┌─────────────────────────────────────────────────┐
│                Flutter App (Android)             │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Features │  │ Providers│  │ Shared/      │  │
│  │ (24 mods)│◄─│(Riverpod)│  │ Widgets      │  │
│  └────┬─────┘  └────┬─────┘  └──────────────┘  │
│       │             │                           │
│  ┌────▼─────────────▼────────────────────────┐  │
│  │          Data Services (28)               │  │
│  └────────────────┬──────────────────────────┘  │
└───────────────────┼─────────────────────────────┘
                    │ HTTPS / Realtime
         ┌──────────▼──────────────┐
         │       Supabase           │
         │  ┌───────┐ ┌──────────┐ │
         │  │  DB   │ │  Edge    │ │
         │  │(PostgreSQL)│ Functions│ │
         │  │       │ │  (17 fns)│ │
         │  └───────┘ └──────────┘ │
         │  ┌───────┐              │
         │  │  Auth │              │
         │  │(Google│              │
         │  │ OAuth)│              │
         │  └───────┘              │
         └─────────────────────────┘
```

---

## Camadas

### 1. Features (`lib/features/`)

Cada feature é um módulo independente com estrutura:
```
features/<nome>/
  screens/    # Widgets de tela (ConsumerStatefulWidget)
  widgets/    # Componentes locais da feature
  domain/     # Modelos e eventos específicos (se houver)
```

Princípio: features não importam umas às outras — comunicação via providers e `IveEventBus`.

### 2. State Management — Riverpod (`lib/providers/`)

- **`AsyncNotifierProvider`** — para dados assíncronos com ciclo de vida (fetchAll/create/update/delete)
- **`FutureProvider`** — para dados read-only carregados uma vez
- **`StateNotifierProvider`** — para estado local com mutações

Padrão de reatividade:
```
Ação do usuário
  → notifier.method()
  → service.call() (Supabase)
  → state update (ref.state = ...)
  → IveEventBus.emit()
  → outros providers invalidados
  → UI rebuild
```

### 3. Data Services (`lib/data/services/`)

Responsáveis pela comunicação com Supabase. Todos implementam uma interface (`*Interface`) para facilitar mock em testes.

Regra de query:
```dart
// CORRETO: filtros antes de order()
var query = table.select();
query = query.eq('field', value);      // PostgrestFilterBuilder
final rows = await query.order(...);   // PostgrestTransformBuilder (terminal)
```

### 4. Edge Functions (`supabase/functions/`)

Funções Deno/TypeScript. Padrão de resposta:
- `400` — payload inválido
- `405` — método não permitido
- `422` — entidade não processável
- `500` — erro interno
- `502` — erro upstream (Groq/OpenAI)

> **Observabilidade:** 10/17 funções sem `console.error/warn`. Nenhuma usa `error_code` semântico. Melhoria pendente.

### 5. IveEventBus (`lib/core/services/ive_event_bus.dart`)

Barramento de eventos global (singleton). Usado para comunicação entre providers desacoplados.

Eventos definidos em `lib/data/models/ive_event.dart`:
- `projectCreated`, `projectUpdated`, `projectStatusChanged`, `projectDeleted`
- Outros eventos de domínio

### 6. IVE Avatar System

#### V1 (Produção)
- `IveOverlay` — widget de sobreposição com estado gerenciado por `iveProvider`
- Integrado em `main.dart` via `MaterialApp` overlay

#### V2 (Isolado — não em produção)
- Localização: `lib/shared/ive_avatar/`
- Feature flag: `iveAvatarV2Enabled = false`
- Componentes: `IveAvatarV2`, `IveAvatarCompact`, `IveAvatarAssistantButton`, `IveAvatarCard`
- Runtime Rive: aguardando asset `.riv` em `assets/ive/rive/`
- **NÃO referenciado em `main.dart` — completamente isolado**

---

## Padrão de Testes

```
test/
  features/ive/         # Testes unitários/widget do sistema IVE
  integration/          # Testes de cadeia reativa (provider → event bus)
  providers/            # Testes unitários dos providers
  features/projects/    # Testes de lógica de tela
```

Dependências de teste:
- `mocktail` — mocks de interfaces de serviço
- `ProviderContainer` — container isolado por teste (sem `WidgetTester` quando desnecessário)
- `IveEventBus.instance.stream` — captura de eventos emitidos

---

## Autenticação

- **Supabase Auth** — gerenciamento de sessão
- **Google Sign-In** (`google_sign_in: ^6.2.1`) — OAuth via `google-services.json`
- **Google Drive** — integração para importação de documentos

> **Problema conhecido:** `certificate_hash` vazio em `google-services.json` — Drive OAuth não funciona (ver KNOWN_ISSUES.md).
