# IVE Avatar Resolver — Architecture
**Fase 11F | Branch:** `claude/ive-avatar-v2-production-integration`

## Visão geral

```
app.dart (Stack global)
  └── IveAvatarResolver            ← único ponto de render
        ├── effectiveIveAvatarVersionProvider
        │     ├── featureFlagsProvider (Supabase — async)
        │     ├── iveAvatarLocalOverrideProvider (SharedPreferences sync)
        │     ├── authStateProvider
        │     └── iveRouteNotifier (rota atual)
        │     → IveAvatarVersion { legacy | v2 | hidden }
        │
        ├── case legacy → IveOverlay()       (avatar legado, mantido)
        ├── case v2     → IveOverlayV2()     (novo wrapper V2)
        └── case hidden → SizedBox.shrink()
```

## Providers

### `effectiveIveAvatarVersionProvider` → `IveAvatarVersion`

```dart
enum IveAvatarVersion { legacy, v2, hidden }
```

Lógica de decisão (prioridade decrescente):

1. Usuário não autenticado → `hidden`
2. Rota protegida → `hidden`
3. Override local = `hidden` → `hidden`
4. Override local = `legacy` → `legacy`
5. Override local = `v2` → `v2`
6. Override local = `automatic` → segue flag Supabase
7. Flag Supabase `ive_avatar_v2_enabled` = true → `v2`
8. Padrão → `legacy`

### `iveAvatarLocalOverrideProvider` → `IveAvatarLocalOverride`

```dart
enum IveAvatarLocalOverride { automatic, legacy, v2, hidden }
```

- Persistido em `SharedPreferences` key `ive_avatar_override`
- Default: `automatic`
- Lido na inicialização, mutável em runtime
- Disponível apenas em `kDebugMode || isAdmin`

## IveAvatarResolver

- Widget `ConsumerStatefulWidget`
- Escuta `effectiveIveAvatarVersionProvider`
- Renderiza no máximo um avatar
- Registra telemetria ao mudar de versão

## IveOverlayV2

- Wrapper do `IveAvatarV2` com comportamento draggável igual ao `IveOverlay`
- Escuta `iveRouteNotifier` para ocultar em rotas protegidas
- Usa `IveAvatarVisibilityService` para decisão de visibilidade
- Conecta toque ao `IveOperationalStateService` para contexto

## Garantias

- Zero duplicidade: `IveOverlay` e `IveAvatarResolver` nunca coexistem no tree
- `IveOverlay` permanece no código mas não é montado pelo `app.dart`
- Rollback: alterar `effectiveIveAvatarVersionProvider` retorna para `legacy`
- Feature flag remota permanece `false` por padrão
