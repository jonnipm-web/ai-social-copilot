# IVE™ Rive Asset Specification

**Arquivo destino:** `assets/ive/rive/ive_executive_v1.riv`  
**Versão do Rive Editor:** 0.8.x ou superior  
**Referência visual:** `assets/ive/reference/ive_character_reference.png`

---

## Identidade da Personagem

A IVE™ é uma Chief AI Strategy Advisor com aparência feminina adulta (28–35 anos), cabelo escuro curto e assimétrico, olhos expressivos escuros, roupa tecnológica escura (blazer ou jaqueta), acabamento semirrealista premium com iluminação violeta e azul. Expressão séria, elegante e confiável.

**Nunca:** emoji, bitmoji, cartoon, avatar genérico, personagem infantil.

---

## A. Artboards

| Nome | Uso | Dimensões sugeridas |
|---|---|---|
| `IVE_AVATAR_COMPACT` | Overlay flutuante (56–72dp) | 200×200 |
| `IVE_AVATAR_CHAT` | Cabeçalho do chat (96–128dp) | 300×300 |
| `IVE_HALF_BODY` | Telas de análise | 300×500 |
| `IVE_FULL_REFERENCE` | Referência completa | 400×700 |

O artboard `IVE_AVATAR_COMPACT` é o padrão. Todos devem compartilhar a mesma State Machine.

---

## B. Camadas Visuais (em ordem de renderização)

```
background_glow       — gradiente radial violeta/azul escuro
hair_back             — cabelo atrás do rosto
neck                  — pescoço
face_base             — rosto (semirrealista, tom neutro frio)
ears                  — orelhas sutis
nose                  — nariz minimalista
eyebrows              — sobrancelhas expressivas, finas
eye_white_left        — esclerótica esquerda
eye_white_right       — esclerótica direita
iris_left             — íris esquerda (olho escuro)
iris_right            — íris direita
pupil_left            — pupila esquerda
pupil_right           — pupila direita
upper_eyelid_left     — pálpebra superior esquerda (piscar)
upper_eyelid_right    — pálpebra superior direita
lower_eyelid_left     — pálpebra inferior esquerda
lower_eyelid_right    — pálpebra inferior direita
lips                  — lábios (mínimos — não exagerados)
jaw_shadow            — sombra do queixo
hair_front            — cabelo na frente (assimétrico, elegante)
torso                 — busto
jacket                — blazer/jaqueta tecnológica escura
collar                — gola
ive_insignia          — marca sutil no blazer (opcional)
left_arm              — braço esquerdo
right_arm             — braço direito
left_hand             — mão esquerda
right_hand            — mão direita
```

---

## C. Bones / Controls

```
bone_head             — controle principal da cabeça (rotação X, Y, Z)
bone_neck             — pescoço
bone_torso            — tronco
ctrl_eye_target_left  — direção do olhar esquerdo
ctrl_eye_target_right — direção do olhar direito
ctrl_eyebrow_left     — curvatura da sobrancelha esquerda
ctrl_eyebrow_right    — curvatura da sobrancelha direita
ctrl_upper_lip        — lábio superior
ctrl_lower_lip        — lábio inferior
ctrl_jaw              — abertura da mandíbula (mínima)
bone_shoulder_left    — ombro esquerdo
bone_shoulder_right   — ombro direito
bone_forearm_left     — antebraço esquerdo
bone_forearm_right    — antebraço direito
bone_hand_left        — mão esquerda
bone_hand_right       — mão direita
```

---

## D. Animações (Timeline)

| Nome | Duração | Tipo | Descrição |
|---|---|---|---|
| `idle_loop` | 4s | Loop | Respiração suave, postura neutra, piscar natural integrado |
| `natural_blink` | 0.25s | One-shot | Piscar realista (acionado aleatoriamente pelo idle) |
| `attentive_focus` | 0.5s | One-shot | Leve inclinação da cabeça, olhar direcionado |
| `listening_loop` | 3s | Loop | Expressão receptiva, sutis movimentos de cabeça |
| `thinking_loop` | 2.5s | Loop | Olhar levemente desviado, sobrancelha levemente franzida |
| `speaking_loop` | 1.5s | Loop | Movimento sutil dos lábios, microgestos de mão |
| `success_reaction` | 0.8s | One-shot | Sorriso discreto, postura positiva |
| `warning_reaction` | 0.6s | One-shot | Expressão cautelosa, leve contração das sobrancelhas |
| `error_reaction` | 0.5s | One-shot | Expressão séria, contato visual direto |
| `opportunity_reaction` | 0.9s | One-shot | Leve sorriso, leve gesto de apresentação |
| `executive_recommendation` | 1.2s | One-shot | Postura firme, expressão confiante |
| `discreet_wave` | 0.7s | One-shot | Aceno discreto com a mão (não infantil) |
| `enter_soft` | 0.6s | One-shot | Entrada suave do avatar (scale + fade) |
| `exit_soft` | 0.4s | One-shot | Saída suave |

---

## E. State Machine: `IVE_EXECUTIVE_STATE_MACHINE`

### Inputs

#### Booleanos
| Input | Tipo | Descrição |
|---|---|---|
| `isListening` | Boolean | Ativa `listening_loop` |
| `isThinking` | Boolean | Ativa `thinking_loop` |
| `isSpeaking` | Boolean | Ativa `speaking_loop` |
| `isVisible` | Boolean | Controla visibilidade geral |
| `hasUnreadInsight` | Boolean | Ativa indicador de novo insight |

#### Numéricos
| Input | Tipo | Range | Descrição |
|---|---|---|---|
| `stateIndex` | Number | 0–9 | Estado atual (ver mapeamento abaixo) |
| `attentionLevel` | Number | 0.0–1.0 | Intensidade de atenção |
| `expressionIntensity` | Number | 0.0–1.0 | Intensidade geral da expressão |
| `speechActivity` | Number | 0.0–1.0 | Atividade de fala (sincronização lábios) |

#### Triggers
| Input | Tipo | Animação acionada |
|---|---|---|
| `wave` | Trigger | `discreet_wave` |
| `notify` | Trigger | Aceno discreto + notificação |
| `success` | Trigger | `success_reaction` |
| `warning` | Trigger | `warning_reaction` |
| `error` | Trigger | `error_reaction` |
| `opportunity` | Trigger | `opportunity_reaction` |
| `focus` | Trigger | `attentive_focus` |
| `reset` | Trigger | Retorna a `idle_loop` |

### Mapeamento stateIndex

| Valor | IveVisualState | Animação base |
|---|---|---|
| 0 | idle | `idle_loop` |
| 1 | attentive | `attentive_focus` → `idle_loop` |
| 2 | listening | `listening_loop` |
| 3 | thinking | `thinking_loop` |
| 4 | speaking | `speaking_loop` |
| 5 | success | `success_reaction` → `idle_loop` |
| 6 | warning | `warning_reaction` → `idle_loop` |
| 7 | error | `error_reaction` → `idle_loop` |
| 8 | opportunity | `opportunity_reaction` → `idle_loop` |
| 9 | executive | `executive_recommendation` → `idle_loop` |

---

## F. Diretrizes de Qualidade

- **Movimentos pequenos** — nunca exagerados. A IVE é executiva, não mascote.
- **Transições suaves** — easing `ease-in-out` para todas as transições de estado.
- **Sem mudanças bruscas** — crossfade mínimo de 150ms entre estados.
- **Duração de reações** — 300ms (mínimo) a 900ms (máximo).
- **Loops lentos** — `idle_loop` e `breathing` devem ser quase imperceptíveis.
- **Suporte a Reduced Motion** — quando `accessibilityFeatures.disableAnimations` estiver ativo, o Flutter pausará o Rive automaticamente; garantir que o frame parado do `idle_loop` seja visualmente correto.
- **Iluminação** — tons frios: violeta `#7B5CF6`, azul `#4DA6FF`, ciano `#00C6FF`. Sem tons quentes de pele orange/caramelo.
- **Cabelo** — escuro (`#18100A` a `#2A1810`), curto, assimétrico, elegante. Sem volume exagerado.
- **Roupa** — blazer/jaqueta escuro `#0D0F1E`, sem detalhes coloridos excessivos.

---

## G. Exportação

1. Exportar como `.riv` (não `.rev`).
2. Verificar que todos os artboards têm a mesma State Machine linkada.
3. Testar no Rive Viewer antes de entregar.
4. Colocar em `assets/ive/rive/ive_executive_v1.riv`.
5. O Flutter substituirá automaticamente o fallback assim que o arquivo existir.
