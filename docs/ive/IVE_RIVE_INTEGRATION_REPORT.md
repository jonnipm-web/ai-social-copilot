# IVE™ Visual Runtime — Integration Report

**Data:** 2026-07-16  
**Branch:** `claude/access-social-copilot-wJ6B5`  
**Status:** ✅ Implementado — aguardando asset `.riv`

---

## Resumo executivo

O sistema visual da IVE™ foi completamente reescrito. A implementação anterior (`_IveExecutivePainter`) — um CustomPainter com rosto cartoon, 3 AnimationControllers simultâneos e apenas 5 expressões — foi substituída por uma arquitetura Rive-first com fallback automático baseado na imagem de referência oficial aprovada.

---

## Arquitetura implementada

```
lib/features/ive/
  visual/
    ive_avatar.dart              ← widget principal (ConsumerStatefulWidget)
    ive_avatar_controller.dart   ← ChangeNotifier: bridge entre IveProvider e Rive
    ive_avatar_state.dart        ← IveVisualState (10 estados) + config + mapper
    ive_rive_runtime.dart        ← implementação Rive (State Machine)
    ive_visual_runtime.dart      ← interface abstrata IveVisualRuntime
    ive_visual_config.dart       ← constantes: asset paths, inputs Rive, IveAvatarSize
    ive_visual_fallback.dart     ← imagem de referência + anel (enquanto .riv ausente)
    ive_status_ring.dart         ← CustomPainter exclusivo do anel externo
    ive_speech_anchor.dart       ← posicionamento do speech bubble
  domain/
    ive_visual_event.dart        ← IveVisualTrigger enum (8 triggers)
  providers/
    ive_visual_provider.dart     ← iveVisualTriggerProvider + overrideProvider

assets/ive/
  reference/ive_character_reference.png  ← identidade aprovada (em uso no fallback)
  rive/ive_executive_v1.riv              ← PENDENTE (ver spec)

lib/shared/widgets/
  ive_avatar.dart   ← re-exporta features/ive/visual/ive_avatar.dart (backward compat)
  ive_overlay.dart  ← usa IveAvatar (substituiu IveAvatarWidget)
```

---

## Estados visuais (IveVisualState)

| Index | Estado | Animação Rive base | Descrição |
|---|---|---|---|
| 0 | `idle` | `idle_loop` | Postura neutra, respiração suave |
| 1 | `attentive` | `attentive_focus` → `idle_loop` | Inclinação leve de cabeça |
| 2 | `listening` | `listening_loop` | Receptiva, movimentos sutis |
| 3 | `thinking` | `thinking_loop` | Olhar desviado, sobrancelha franzida |
| 4 | `speaking` | `speaking_loop` | Movimento sutil de lábios |
| 5 | `success` | `success_reaction` → `idle_loop` | Sorriso discreto |
| 6 | `warning` | `warning_reaction` → `idle_loop` | Expressão cautelosa |
| 7 | `error` | `error_reaction` → `idle_loop` | Expressão séria, contato direto |
| 8 | `opportunity` | `opportunity_reaction` → `idle_loop` | Leve sorriso, gesto de apresentação |
| 9 | `executive` | `executive_recommendation` → `idle_loop` | Postura firme, expressão confiante |

---

## Mapeamento IveExpression → IveVisualState

| IveExpression (legado) | IveVisualState | Condição |
|---|---|---|
| `happy` | `idle` | — |
| `thinking` | `thinking` | — |
| `excited` | `success` | — |
| `neutral` | `attentive` | — |
| `winking` | `opportunity` | — |
| _(qualquer)_ | `error` | `activeIssue.severity` = critical/error |
| _(qualquer)_ | `warning` | `activeIssue.severity` = warning |
| _(qualquer)_ | `attentive` | `activeIssue.severity` = info |

---

## Inputs da State Machine Rive

### Booleanos (5)
`isListening`, `isThinking`, `isSpeaking`, `isVisible`, `hasUnreadInsight`

### Numéricos (4)
`stateIndex` (0–9), `attentionLevel` (0.0–1.0), `expressionIntensity` (0.0–1.0), `speechActivity` (0.0–1.0)

### Triggers (8)
`wave`, `notify`, `success`, `warning`, `error`, `opportunity`, `focus`, `reset`

---

## Fallback (ativo enquanto .riv ausente)

`IveVisualFallback` exibe:
- Imagem de referência oficial com `ClipOval` circular
- Overlay de cor do estado (opacidade 20%)
- `IveStatusRing` com cor e glow correspondentes ao estado
- Badge "RIVE ASSET PENDING" em `kDebugMode`

Quando `assets/ive/rive/ive_executive_v1.riv` for adicionado, o fallback é substituído automaticamente — sem nenhuma alteração de código.

---

## Melhorias vs implementação anterior

| Métrica | Antes | Depois |
|---|---|---|
| AnimationControllers | 3 simultâneos (sempre ativos) | 1 no fallback / Rive nativo |
| Estados visuais | 5 | 10 |
| Renderização do rosto | CustomPainter cartoon | Rive (quando disponível) / PNG referência |
| Acessibilidade | Nenhuma | `Semantics(label: 'IVE, assistente executiva', button: true)` |
| Backward compatibility | — | `ive_avatar.dart` re-exporta novo sistema |
| Fallback quando asset ausente | Crash silencioso | `IveVisualFallback` automático |

---

## Cobertura de testes

Arquivo: `test/features/ive/ive_visual_runtime_test.dart`

| Grupo | Testes |
|---|---|
| `IveVisualState` | 10 valores distintos; stateIndex único por estado |
| `IveVisualStateMapper` | 5 mapeamentos de expressão → estado visual |
| `IveAvatarController` | idle inicial; applyVisualState; no-op em mesmo estado; notificação; isRiveReady; dispose seguro |
| `IveStatusRingPainter` | shouldRepaint true/false |
| `IveVisualStateConfig` | error=vermelho; success=verde; glowIntensity 0–1 para todos |
| `IveVisualFallback` | renderiza sem crash |
| `IveAvatar` | renderiza; onTap callback; semantics label |

---

## Próximo passo

1. Entregar `docs/ive/IVE_RIVE_ASSET_SPECIFICATION.md` ao motion designer.
2. Designer produz `ive_executive_v1.riv` seguindo a spec (artboards, State Machine, 14 animações, 17 inputs).
3. Colocar o arquivo em `assets/ive/rive/ive_executive_v1.riv`.
4. Badge "RIVE ASSET PENDING" desaparece automaticamente em builds release.
5. `IveVisualFallback` deixa de ser exibido — sem refatoração adicional.
