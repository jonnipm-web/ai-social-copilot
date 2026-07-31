# IVE Avatar — Current Integration Map
**Fase 11F Audit | Branch:** `claude/ive-avatar-v2-production-integration`

## Ponto único de render (produção)

| Arquivo | Linha | Widget | Posição | Condição | Ação ao toque | Risco | Decisão |
|---------|-------|--------|---------|----------|---------------|-------|---------|
| `lib/app.dart` | 404 | `IveOverlay` | `Stack` global, `Positioned` draggável | Sempre renderizado (visibilidade controlada internamente) | Bubble dismiss ou `showCopilotChat` | Aparece em rotas de auth se rota não filtrada | → **Substituir por `IveAvatarResolver`** |

## Widget de overlay legado

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `lib/shared/widgets/ive_overlay.dart` | Definição + lógica | `IveOverlay` — draggável, escuta `iveRouteNotifier`, renderiza `IveAvatar` + speech bubble. Abre `showCopilotChat` ao toque. |
| `lib/shared/widgets/ive_overlay.dart:151` | Uso interno | `IveAvatar(size: compact, showStatusRing: true, interactive: false)` — avatar legado dentro do overlay |

## Avatar legado (V1)

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `lib/features/ive/visual/ive_avatar.dart` | Definição | Widget principal legado — Rive ou `IveVisualFallback`. Lê `iveProvider`. |
| `lib/features/ive/visual/ive_visual_fallback.dart` | Definição | Fallback geométrico com anel pulsante e badge de debug (kDebugMode). |
| `lib/shared/widgets/ive_avatar.dart` | Re-export deprecated | Aponta para `lib/features/ive/visual/ive_avatar.dart` |

## Avatar V2 (isolado — somente showcase)

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `lib/shared/ive_avatar/widgets/ive_avatar_v2.dart` | Definição | Widget V2 completo — usa `iveAvatarV2StateProvider`. |
| `lib/shared/ive_avatar/widgets/ive_avatar_compact.dart` | Definição | Variante compacta V2 |
| `lib/shared/ive_avatar/widgets/ive_avatar_card.dart` | Definição | Variante card V2 |
| `lib/shared/ive_avatar/widgets/ive_avatar_assistant_button.dart` | Definição | Botão flutuante V2 (showcase apenas) |
| `lib/shared/ive_avatar/showcase/ive_avatar_showcase_page.dart` | Uso | Única tela de produção que usa V2 — rota `/debug/ive-avatar-v2`, guard `kDebugMode` |

## Feature flag

| Arquivo | Linha | Descrição |
|---------|-------|-----------|
| `lib/data/models/feature_flag.dart:28` | Constante | `iveAvatarV2Enabled = 'ive_avatar_v2_enabled'` |
| `lib/providers/feature_flag_provider.dart:29` | Accessor | `FlagMapX.iveAvatarV2Enabled` — default `false` |
| `lib/shared/ive_avatar/providers/ive_avatar_provider_v2.dart:14` | Provider | `iveAvatarV2EnabledProvider = Provider<bool>((_) => false)` — ainda não conectado ao Supabase |

## `showCopilotChat` — pontos de chamada

| Arquivo | Linha | Contexto |
|---------|-------|---------|
| `lib/shared/widgets/ive_overlay.dart` | 168 | Toque no avatar ou link do bubble |
| `lib/shared/widgets/ive_explain_button.dart` | 63 | Botão "Explicar" em widgets de insight |
| `lib/shared/widgets/ive_detail_sheet.dart` | 263 | Ação no detalhe sheet |
| `lib/features/dashboard/screens/executive_dashboard_screen.dart` | 96 | AppBar IconButton |
| `lib/features/ecosystem/screens/executive_decision_center_screen.dart` | 372, 558, 1108 | Cards de opportunity, score e recommendation |
| `lib/features/projects/screens/project_command_center_screen.dart` | 1205 | Dialog de intelligence profile |

## Riscos de sobreposição identificados

| Risco | Local | Impacto | Decisão |
|-------|-------|---------|---------|
| Avatar flutuante sobre FAB | Screens com FAB: opportunity_lab, knowledge_vault, etc. | Cobre botão de ação primária | Resolver respeita SafeArea e não intercepta gestos fora da área |
| Avatar em rotas de auth | Rota `/` e `/login` | Confunde usuário não autenticado | `IveAvatarVisibilityService` já filtra — ampliar lista |
| Avatar dentro de modal de chat | Ao abrir `showCopilotChat` | Duplicidade visual | Resolver oculta quando modal aberto |
| Badge "RIVE ASSET PENDING" em produção | `IveVisualFallback` com `kDebugMode` | Texto técnico visível em build debug | Mover para apenas showcase em debug |

## Duplicidades a eliminar

- `IveOverlay` renderiza `IveAvatar` que renderiza `IveVisualFallback` — cadeia única, sem duplicidade atual.
- Não há dois avatares simultâneos no widget tree atualmente.
- Risco futuro: se `IveAvatarResolver` não substituir `IveOverlay` mas somar-se a ele, haverá duplicidade.
- **Decisão: `IveAvatarResolver` substitui `IveOverlay` no `app.dart` — não coexistem.**
