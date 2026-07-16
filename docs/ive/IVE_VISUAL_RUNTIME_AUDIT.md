# IVE Visual Runtime Audit

## Arquivos encontrados (pré-migração)

| Arquivo | Papel | Destino |
|---|---|---|
| `lib/shared/widgets/ive_avatar.dart` | `IveAvatarWidget` + `_IveExecutivePainter` (CustomPainter cartoon) | **Substituído** — re-exporta novo sistema |
| `lib/shared/widgets/ive_overlay.dart` | Overlay flutuante + speech bubble | **Atualizado** — usa `IveAvatar` |
| `lib/shared/widgets/ive_detail_sheet.dart` | Modal explicativo | Preservado |
| `lib/shared/widgets/ive_explain_button.dart` | Botão "Explicar com IVE" | Preservado |
| `lib/data/models/ive_state.dart` | `IveExpression` enum + `IveState` | Preservado (backward compat) |
| `lib/data/models/ive_issue.dart` | `IveIssue` + `IveIssueSeverity` | Preservado |
| `lib/data/models/ive_event.dart` | `IveEvent` + `IveEventType` | Preservado |
| `lib/data/models/ive_memory.dart` | Persistência de sessão | Preservado |
| `lib/providers/ive_provider.dart` | `IveNotifier` (business logic) | Preservado |
| `lib/providers/ive_context_provider.dart` | `IveContextData` | Preservado |
| `lib/providers/ive_memory_provider.dart` | SharedPrefs | Preservado |
| `lib/core/services/ive_event_bus.dart` | Singleton broadcast stream | Preservado |

---

## Implementação visual anterior (removida)

### `_IveExecutivePainter` — Problemas identificados

1. **Rosto humano cartoon** — `_drawFace()` usava gradiente warm-tone `Color(0xFFEFBF89)` (pele).
2. **Cabelo animado** — `_drawHairBack()` + `_drawHairFront()` com beziers.
3. **Roupas desenhadas** — `_drawCollar()` com terninho escuro e blusa V-neck.
4. **Expressão "excited" com dentes** — `canvas.drawRect(teethRect)` visível na análise concluída.
5. **3 AnimationControllers simultâneos** — `_blinkCtrl`, `_floatCtrl`, `_entryCtrl` rodando mesmo quando avatar invisível.
6. **Tech ring decorativo** — 4 dots nos cantos sem significado funcional.
7. **5 expressões insuficientes** — `happy, thinking, excited, neutral, winking` não cobriam `error, warning, opportunity, executive`.

---

## Nova arquitetura

```
lib/features/ive/
  visual/
    ive_avatar.dart             ← widget principal (ConsumerStatefulWidget)
    ive_avatar_controller.dart  ← bridge entre IveProvider e Rive runtime
    ive_avatar_state.dart       ← IveVisualState enum + config + mapper
    ive_rive_runtime.dart       ← IveVisualRuntime via Rive State Machine
    ive_visual_runtime.dart     ← interface abstrata
    ive_visual_config.dart      ← constantes Rive + IveAvatarSize
    ive_visual_fallback.dart    ← imagem referência + anel (enquanto .riv ausente)
    ive_status_ring.dart        ← CustomPainter apenas para anel externo
    ive_speech_anchor.dart      ← posicionamento do speech bubble
  domain/
    ive_visual_event.dart       ← IveVisualTrigger enum
  providers/
    ive_visual_provider.dart    ← iveVisualTriggerProvider + override provider

assets/ive/
  reference/ive_character_reference.png  ← identidade oficial aprovada
  rive/ive_executive_v1.riv              ← PENDENTE (ver especificação)
```

---

## Acoplamentos removidos

- `IveAvatarWidget` com parâmetro `expression: IveExpression` → agora `IveAvatar` lê `iveProvider` diretamente.
- `IveStatusRing` agora é o ÚNICO CustomPainter permitido (não desenha rosto).
- `ive_overlay.dart` não mais importa `ive_avatar.dart` antigo direto.

## Pontos de acoplamento preservados

- `iveProvider` (StateNotifierProvider) → `IveAvatar` assiste via `ref.watch`.
- `IveState.expression` + `IveState.activeIssue` → `IveVisualStateMapper.fromIveState()`.
- `IveEventBus` → continua sendo consumido por `IveNotifier`, não pelo runtime visual.

## Risco de regressão

| Risco | Mitigação |
|---|---|
| `.riv` ausente | `IveVisualFallback` ativa automaticamente |
| Build quebrado por import | `ive_avatar.dart` antigo re-exporta o novo |
| Estado visual errado | `IveVisualStateMapper` com testes unitários |
| Performance em dispositivos médios | 1 `AnimationController` no fallback vs 3 anteriores |

## Plano de migração para .riv final

1. Motion designer recebe `IVE_RIVE_ASSET_SPECIFICATION.md`.
2. Designer produz `ive_executive_v1.riv` com artboards e State Machine nomeados conforme spec.
3. Arquivo colocado em `assets/ive/rive/ive_executive_v1.riv`.
4. `IveRiveRuntime.initialize()` passa a funcionar → `IveAvatar` troca automaticamente para Rive.
5. Badge "RIVE ASSET PENDING" some em builds de debug.
6. `IveVisualFallback` deixa de ser exibido — sem refatoração adicional necessária.
