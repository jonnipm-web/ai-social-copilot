# IVE™ Rive Runtime Contract — V1 (Frozen)

**Mission:** IVE-AVATAR-RIVE-RUNTIME-03A
**Status:** Specification only — no `.riv` file exists yet, none is added by this document.
**Supersedes (reconciles, does not replace):** `IVE_RIVE_ASSET_SPECIFICATION.md`, `IVE_RIVE_INTEGRATION_REPORT.md`, `IVE_VISUAL_RUNTIME_AUDIT.md` (all dated 2026-07-16/2026-08-15). Those documents remain accurate for character identity, layers, bones and animation timeline — this document is the one to trust for the **exact, current, code-verified** runtime contract (inputs, priority, dead vs. live surface), because it was produced by reading `main` at commit `3abde7a` line by line, not by re-describing intent.

---

## 01. Purpose

Freeze the exact contract between Flutter app state and the Rive runtime **as it exists in code today**, so a motion designer can build `assets/ive/rive/ive_executive_v1.riv` without guessing, and so a future integration mission (03B) has an unambiguous acceptance bar. This document creates no code, no asset, and changes no behavior.

## 02. Canonical Architecture

```
IveState (lib/data/models/ive_state.dart)
   — screenName, message, expression, bubbleVisible, activeIssue, interaction
        ↓
IveVisualStateMapper.fromIveState()  (lib/features/ive/visual/ive_avatar_state.dart:139-172)
   — pure function, single translation point, business rules live ONLY here
        ↓
IveVisualState  (10-value enum)
        ↓
IveAvatarController  (lib/features/ive/visual/ive_avatar_controller.dart)
   — bridges IveAvatar widget ↔ IveRiveRuntime; owns dead granular-input API
        ↓
IveRiveRuntime implements IveVisualRuntime  (lib/features/ive/visual/ive_rive_runtime.dart)
   — wraps a Rive StateMachineController; throws on load failure
        ↓
Rive State Machine `IVE_EXECUTIVE_STATE_MACHINE` inside the `.riv` file
        ↓ (on any failure at any layer above)
IveVisualFallback  (lib/features/ive/visual/ive_visual_fallback.dart)
   — reference PNG + IveStatusRingPainter, always available, no Rive dependency
```

Single mount point in the **production widget tree**: `IveOverlay` (`lib/shared/widgets/ive_overlay.dart:150`) instantiates exactly one `IveAvatar(size: IveAvatarSize.compact, ...)`. No other production screen creates an `IveAvatar`. This is unchanged by this mission and remains true. (`test/features/ive/ive_visual_runtime_test.dart` constructs additional standalone `IveAvatar` instances for unit testing at four separate `testWidgets` call sites — expected and correct test scaffolding, not a second production mount point; "single mount point" throughout this document refers to the app users actually run.)

## 03. Flutter Authority Model

**Flutter is the sole source of truth for which visual state is active.** `IveVisualStateMapper.fromIveState()` is a pure, total function with an explicit, hard-coded priority order (§09). Rive receives only the *result* of that decision (`stateIndex` + three derived booleans) — it never decides state on its own, and no future `.riv` may introduce internal logic that picks a different state than the one Flutter sends. A Rive trigger (§08) is cosmetic flourish layered on top of whatever state Flutter already chose; it is not an alternate state authority.

This was true before mission 02 and remains true after it: mission 02 added exactly one new state carrier (`IveState.interaction`), and it is checked *first* inside the same single mapper function, not through a second competing path (`iveVisualTriggerProvider`/`iveVisualStateOverrideProvider` remain deliberately unwired — `lib/features/ive/providers/ive_visual_provider.dart:10-20`).

## 04. Artboard Contract

| Name (declared in `ive_visual_config.dart:14-17`) | Declared use | Declared size | **Actually requested by app code today** |
|---|---|---|---|
| `IVE_AVATAR_COMPACT` | Floating overlay (56–72dp) | 200×200 | **YES — the only one.** `IveAvatarController.initializeRive()` is called with no `artboardName` argument anywhere in the codebase (verified: `grep -rn "initializeRive(" lib/` → exactly one call site, `ive_avatar.dart:73`, no arguments), so `IveRiveRuntime`'s default (`artboardCompact`) is always used. |
| `IVE_AVATAR_CHAT` | Chat header (96–128dp) | 300×300 | NO — declared, never requested. |
| `IVE_HALF_BODY` | Analysis screens | 300×500 | NO — declared, never requested. |
| `IVE_FULL_REFERENCE` | Full reference | 400×700 | NO — declared, never requested. |

Additional runtime detail not previously documented: `IveRiveRuntime.initialize()` does `file.artboardByName(artboardName) ?? file.mainArtboard` (`ive_rive_runtime.dart:85`) — if `IVE_AVATAR_COMPACT` is missing from the `.riv`, Rive's own "main artboard" is used silently instead of failing. **Acceptance requirement:** the `.riv`'s main artboard should itself be `IVE_AVATAR_COMPACT`, so this silent fallback and the explicit lookup agree.

**Contract for 03B / asset delivery:** the `.riv` MUST contain `IVE_AVATAR_COMPACT` with the full state machine (the only artboard actually exercised by the app). The other three artboards MAY be included (per the original asset spec, for forward compatibility with screens that don't exist yet) but are not required for 03B's acceptance, since no app code will ever request them until a future mission wires a non-compact `IveAvatarSize`/screen. `IveAvatarSize` itself currently has `standard`/`large`/`chat`/`detail` values (`ive_visual_config.dart:45-54`) that are likewise declared but never instantiated anywhere (`grep -rn "IveAvatar(" lib/` → one call site, `ive_overlay.dart:150`, always `compact`).

## 05. State Machine Contract

- Name: `IVE_EXECUTIVE_STATE_MACHINE` (`ive_visual_config.dart:11`), looked up via `StateMachineController.fromArtboard(artboard, IveRiveInputs.stateMachine)` (`ive_rive_runtime.dart:87-98`). If not found on the loaded artboard, `initialize()` throws a `StateError` naming the missing state machine and pointing at this doc's predecessor — caught by `IveAvatarController.initializeRive()`'s try/catch (`ive_avatar_controller.dart:26-39`), triggering fallback.
- Exactly **one** state machine is referenced by the runtime. Per the original asset spec (§A, `IVE_RIVE_ASSET_SPECIFICATION.md`), all artboards should share it — this mission confirms nothing in code contradicts that, and reinforces it as a hard requirement: **do not design multiple parallel state machines.**

## 06. Inputs

All input names below are read verbatim from `lib/features/ive/visual/ive_visual_config.dart:19-40` and matched against their actual driver in `ive_rive_runtime.dart` and `ive_avatar_controller.dart`. **"Zero call sites" below means zero call sites in `lib/` (production code)** — `test/features/ive/ive_visual_runtime_test.dart` deliberately calls `initializeRive()` and exercises the mapper/controller directly as unit tests, which is correct, expected test behavior and not a production usage of these methods.

### 06.1 Boolean inputs

| Input | Declared meaning | Actual driver today | Persistent/transient | Status |
|---|---|---|---|---|
| `isListening` | Active during `listening_loop` | `IveRiveRuntime.setState()`: `_isListening.value = (state == IveVisualState.listening)` (`ive_rive_runtime.dart:133`) | Persistent while state holds | **Wired but functionally always false** — `IveVisualState.listening` is never produced by the mapper (§07); no app code path sets `IveState.expression`/`interaction` to reach it. The granular `IveAvatarController.setListening(bool)` method exists (`ive_avatar_controller.dart:63-65`) but has **zero call sites** (verified by repo-wide grep). |
| `isThinking` | Active during `thinking_loop` | Same mechanism, `state == IveVisualState.thinking` (`ive_rive_runtime.dart:134`) | Persistent | **LIVE.** Reachable via `IveExpression.thinking` (route-contextual messages) and via `IveInteractionState.thinking` (real chat request in flight, mission 02). Granular `setThinking(bool)` on the controller is separately dead (no call sites) — only the `setState()` path drives it. |
| `isSpeaking` | Active during `speaking_loop` | `state == IveVisualState.speaking` (`ive_rive_runtime.dart:135`) | Persistent | **LIVE.** Reachable only via `IveInteractionState.speaking` (chat response being presented, mission 02) — no `IveExpression` value maps to `speaking` directly. Granular `setSpeaking(bool)` dead, same as above. |
| `isVisible` | "Controla visibilidade geral" | Set to `true` exactly once, in `initialize()` (`ive_rive_runtime.dart:124`), immediately after load succeeds | Set-once | **Effectively a constant `true`.** `setVisible(bool)` exists on the `IveVisualRuntime` interface (`ive_visual_runtime.dart:26`) and on `IveRiveRuntime` (`ive_rive_runtime.dart:156`) — **note: unlike every other input in this table, `IveAvatarController` does NOT expose a corresponding `setVisible` wrapper** (its granular API stops at `setHasUnreadInsight`, `ive_avatar_controller.dart:63-89`), so there is no path to call it even indirectly. There is no app-level concept of hiding the avatar while keeping the Rive runtime alive — visibility is really "is the widget mounted at all," which is a Flutter-level concern (`IveOverlay` is always mounted; see §17). |
| `hasUnreadInsight` | "Ativa indicador de novo insight" | `setHasUnreadInsight(bool)` exists at both layers, never called | — | **Fully dead.** No app concept of "unread insight" currently reaches the avatar. |

### 06.2 Number inputs

| Input | Range (declared) | Actual driver today | Status |
|---|---|---|---|
| `stateIndex` | 0–9 | `IveRiveRuntime.setState()`: `_stateIndex.value = IveVisualStateConfig.forState(state).stateIndex.toDouble()` (`ive_rive_runtime.dart:132`) | **LIVE — the primary, and effectively only, continuously-driven number input.** Values 0–9 map 1:1 to `IveVisualState` per the table in §07; `stateIndex` is set on every `applyVisualState()` call where the state actually changed (`ive_avatar_controller.dart:44-54`, which no-ops if the state is unchanged). |
| `attentionLevel` | 0.0–1.0 | `setAttentionLevel(double)` at both layers, zero call sites | **Fully dead.** Never set, so a `.riv` reading it will only ever see its own Rive-editor default value. |
| `expressionIntensity` | 0.0–1.0 | `setExpressionIntensity(double)`, zero call sites | **Fully dead**, same as above. |
| `speechActivity` | 0.0–1.0 | `setSpeechActivity(double)`, zero call sites | **Fully dead.** There is no lip-sync/audio-amplitude signal in this app (no TTS/voice — confirmed in the prior reconciliation audit and unchanged since). |

**Normalization:** none of the number inputs are clamped or normalized by app code beyond `stateIndex`'s `.toDouble()` cast of an already-bounded `int` (0–9, one per enum value, uniqueness enforced by an existing test in `ive_visual_runtime_test.dart`: *"stateIndex is unique per state"*). The three dead 0.0–1.0 inputs have no normalization code because nothing ever writes to them.

### 06.3 Required vs. optional, for the asset

Because `_findBool`/`_findNumber`/`_findTrigger` (`ive_rive_runtime.dart:57-76`) return `null` for any input not found on the state machine (rather than throwing), **every input listed above is technically optional at load time** — a `.riv` missing any of them will load successfully and simply no-op that specific setter (`_isListening?.value = ...`). Only `stateMachine` name and `artboard` presence are hard-required (their absence throws, per §05). This is a real, code-verified fail-soft property, not an assumption.

**Explicit tiering for 03B (to remove any ambiguity between "loads without error" and "actually needs to work"):**

```
MUST (03B acceptance blockers — driven by real app logic today):
  stateIndex, isThinking, isSpeaking

SHOULD (recommended, low effort, matches existing loop/config work
        already speced in IVE_RIVE_ASSET_SPECIFICATION.md — but no
        app code drives them yet, so a designer may implement them
        minimally/statically without blocking 03B):
  isListening, isVisible, hasUnreadInsight, attentionLevel,
  expressionIntensity, speechActivity

RESERVED (forward-compatible scaffolding only — see §08; safe to
          implement as inert one-shots, not required for 03B):
  wave, notify, success, warning, error, opportunity, focus, reset
  (all 8 triggers)
```

## 07. States

`IveVisualState` (`ive_avatar_state.dart:8-19`), 10 values, `stateIndex` per `IveVisualStateConfig.forState()` (`ive_avatar_state.dart:40-133`):

| # | STATE | APP SOURCE (`IveVisualStateMapper.fromIveState`, priority order) | RIVE INPUT | EXPECTED VISUAL BEHAVIOR (per `IVE_RIVE_ASSET_SPECIFICATION.md §D/§E`) | CURRENTLY REACHABLE? |
|---|---|---|---|---|---|
| 0 | idle | `IveExpression.happy` (default state) | `stateIndex=0` | `idle_loop`, neutral breathing | **YES** — default/fallback expression |
| 1 | attentive | `IveExpression.neutral`, OR `activeIssue.severity == info` | `stateIndex=1` | `attentive_focus` → `idle_loop` | **YES** |
| 2 | listening | *(none — no code path produces this)* | `stateIndex=2`, `isListening=true` | `listening_loop` | **NO — dead state.** No voice/STT exists in this app (confirmed, unchanged). |
| 3 | thinking | `IveInteractionState.thinking` (priority 1, mission 02) OR `IveExpression.thinking` (priority 3, route-contextual) | `stateIndex=3`, `isThinking=true` | `thinking_loop` | **YES**, via two independent app-level triggers converging on the same enum value |
| 4 | speaking | `IveInteractionState.speaking` (priority 1, mission 02) only | `stateIndex=4`, `isSpeaking=true` | `speaking_loop` | **YES**, single trigger path |
| 5 | success | `IveExpression.excited` | `stateIndex=5` | `success_reaction` → `idle_loop` | **YES** |
| 6 | warning | `activeIssue.severity == warning` | `stateIndex=6` | `warning_reaction` → `idle_loop` | **YES** |
| 7 | error | `activeIssue.severity` ∈ {`error`, `critical`} | `stateIndex=7` | `error_reaction` → `idle_loop` | **YES** |
| 8 | opportunity | `IveExpression.winking` | `stateIndex=8` | `opportunity_reaction` → `idle_loop` | **YES** |
| 9 | executive | *(none — no code path produces this)* | `stateIndex=9` | `executive_recommendation` → `idle_loop` | **NO — dead state.** No caller ever sets an expression/issue/interaction that resolves here. |

Entry/exit conditions are governed entirely by the priority chain in §09 — there is no per-state timer or animation-driven auto-exit in Flutter (the *speaking* state's exit is timer-driven at the `IveNotifier` level, not the Rive level — see §09/§10).

**`thinking`/`speaking` are the two states this mission's predecessor (STATE-MACHINE-02) made real.** Both are exercised today with real CI-passing test coverage (`test/providers/ive_provider_interaction_test.dart`) — they are not speculative for the `.riv` asset; they are the highest-priority, most time-sensitive states a motion designer should get right first.

## 08. Triggers

`IveVisualTrigger` (`lib/features/ive/domain/ive_visual_event.dart:3-12`), 8 values, fired via `IveRiveRuntime.trigger()` (`ive_rive_runtime.dart:139-151`), reachable only through `IveAvatarController.triggerAnimation()` (`ive_avatar_controller.dart:56-59`).

| Trigger | Rive input name | Animation (per old spec) | **Real caller today** | Classification |
|---|---|---|---|---|
| `wave` | `wave` | `discreet_wave` | none | **FUTURE** — no "greeting" app event exists |
| `notify` | `notify` | discreet wave + notification | none | **FUTURE** — no distinct "new insight" event separate from the existing bubble-message mechanism |
| `success` | `success` | `success_reaction` | none | **REDUNDANT with `stateIndex`** — success is already fully represented by `stateIndex=5`; a one-shot flourish trigger adds nothing the state transition doesn't already convey given the app never distinguishes "entering success" from "already in success" |
| `warning` | `warning` | `warning_reaction` | none | **REDUNDANT**, same reasoning as `success` |
| `error` | `error` | `error_reaction` | none | **REDUNDANT**, same reasoning |
| `opportunity` | `opportunity` | `opportunity_reaction` | none | **REDUNDANT**, same reasoning |
| `focus` | `focus` | `attentive_focus` | none | **FUTURE** — could map to `attentive` state entry, but nothing currently distinguishes "just became attentive" from "already attentive" at the Flutter layer |
| `reset` | `reset` | returns to `idle_loop` | none | **FUTURE** — `stateIndex=0` (idle) already achieves this; a dedicated reset trigger would only matter if the state machine needs an explicit way to interrupt a stuck one-shot animation |

**`triggerAnimation()` has zero call sites in `lib/` (production code)** (verified by grep, confirmed identical to the finding in the prior reconciliation audit — unchanged by mission 02). No trigger is "SHOULD NOT EXIST" — all 8 are plausible future hooks — but **none should be wired in 03B** without a real corresponding app event, per this mission's own instruction and the precedent set by mission 02 (which deliberately left this exact provider unwired rather than fabricate motion). The asset should implement all 8 as no-op-safe one-shot animations (each can override `idle_loop`/current loop briefly and return), so a future mission can wire them without needing an asset revision.

## 09. Priority Model

Derived from reading `IveVisualStateMapper.fromIveState()` (`ive_avatar_state.dart:139-172`) top to bottom — this **is** the priority order, not an approximation of it:

```
1. state.interaction                        ← highest priority, short-lived chat overlay
   (thinking / speaking)
2. state.activeIssue                        ← business alert
   ONLY evaluated when activeIssue != null AND bubbleVisible == true
   (error/critical > warning > info)          — both conditions are required (ive_avatar_state.dart:150-161);
                                                 an issue that exists but whose bubble was dismissed does
                                                 NOT reach this branch, and falls through to expression (3) instead
3. state.expression                         ← fallback, always evaluated if 1 and 2 don't apply
   (thinking > excited=success > neutral=attentive > winking=opportunity > happy=idle)
```

Worked example from the mission brief — warning present, user sends a chat message:
```
warning (activeIssue.severity=warning, priority 2)
  → user sends message → IveNotifier.beginThinking() → interaction=thinking (priority 1, overrides)
  → response arrives → interaction=speaking (priority 1, still overrides)
  → speaking timer clears interaction (interaction=null)
  → mapper re-evaluates: activeIssue is still set (it was never touched) → warning (priority 2, restored)
```
This is exactly the behavior mission 02 built and tested (`test/providers/ive_provider_interaction_test.dart`, *"a business issue that arrives live during speaking is preserved and becomes authoritative once the interaction clears"*) — **not aspirational, already true in shipped code.**

**Hard constraint for the `.riv`:** the state machine must not introduce its own precedence between simultaneously-true booleans. Flutter never sends more than one "true" narrative at a time — it always resolves to a single `stateIndex` before calling Rive. The three booleans (`isListening`/`isThinking`/`isSpeaking`) are *derived, redundant* signals for animation blending convenience (e.g., a blend tree keyed on booleans instead of the index), not an independent decision input — the `.riv` should treat `stateIndex` as authoritative and the booleans as confirmation, never the reverse.

## 10. Transition Behavior

- **Interruptibility:** every state transition today is immediate at the Flutter layer — `applyVisualState()` writes the new `stateIndex` the instant the mapper's output changes (subject to the no-op-if-unchanged guard, `ive_avatar_controller.dart:46`). The `.riv`'s own crossfade/easing (per the old spec's §F: 150ms minimum crossfade, ease-in-out) is where "smoothness" should live — Flutter will not wait for an animation to finish before requesting the next state.
- **One-shot vs. loop — correction from Codex review (P1):** `idle/attentive/listening/thinking/speaking` are conceptually loops (per the old spec's animation table); `success/warning/error/opportunity/executive` are one-shot reactions whose animation table entry reads e.g. `success_reaction → idle_loop`. **This "→ idle_loop" is a Rive-internal state-machine transition, not something Flutter drives.** Flutter's own dismiss timers (`IveNotifier`'s 7s transient-message timer, 15s issue timer, `ive_provider.dart:268-273,194-196`) only clear `bubbleVisible` (transient messages) or `activeIssue`+`bubbleVisible` (issues) — **they do not reset `expression`**. Concretely: if `IveEventType.assetAnalysisCompleted` sets `expression = excited` (→ `stateIndex=5`, success) and the message bubble disappears 7s later, `stateIndex` stays at `5` indefinitely at the Flutter layer — nothing recomputes it until the *next* real event (a route change, a new message, a new issue, or a new interaction). The visual "return to idle" a user actually sees must therefore come from the `.riv`'s own internal transition graph: play the one-shot `success_reaction` once, then settle into an idle-*looking* resting sub-state while `stateIndex` input remains at `5` and unchanged. **Do not design the state machine assuming Flutter will send a fresh `stateIndex=0` after a reaction plays out — it will not, unless a genuinely new business event happens to produce `idle` next.**
- **Speaking's fixed duration is Flutter-side, not Rive-side:** the ~1.5s "speaking" window is a `Timer` inside `IveNotifier` (`ive_provider.dart:115`, `_kSpeakingDuration`), not an animation-length contract on the `.riv`. The `speaking_loop` animation should simply loop cleanly for however long `isSpeaking`/`stateIndex=4` remains true — it does not need to be exactly 1.5s, and must not assume a fixed presentation length (that constant may change in a future Flutter-side mission without any asset update).

## 11. Motion Behavior

This mission does not re-derive per-state motion-design language from scratch — `IVE_RIVE_ASSET_SPECIFICATION.md §D/§F` already specifies it (animation names, durations, easing, "small movements, never exaggerated," 150ms minimum crossfade, 300–900ms reaction duration) and this audit found nothing in the current runtime that contradicts it. Two additions specific to what mission 02 made real:

```
THINKING (now also chat-driven, not just business-context-driven)

Entry:  from any state — instantaneous priority override, so the entry
        transition must look natural even when the previous state was
        mid-loop (e.g., interrupting an idle breath).
Loop:   thinking_loop (per old spec) — same animation regardless of WHY
        the app is in this state (route context vs. real chat request).
        Do not design a "second thinking style" for chat — Flutter sends
        the same stateIndex=3 for both.
Exit:   either a newer interaction event (rare) or a business-state
        recompute once interaction clears — same visual exit as any
        other stateIndex change.
Must NOT: assume a minimum display duration — a very fast chat response
        could clear "thinking" in well under a second.

SPEAKING (chat-response presentation, mission 02)

Entry:  immediately follows thinking, always — never entered directly
        from another state without passing through thinking first
        (verified: `completeInteraction` always follows `beginThinking`
        in `ContextCopilotNotifier.send()`, `context_copilot_provider.dart:62-121`).
Loop:   speaking_loop, duration-agnostic (see §10) — must loop cleanly
        for an indeterminate span, not a fixed ~1.5s.
Exit:   returns to whatever business/context state is live underneath —
        must NOT hard-cut to idle_loop; the exit animation should be
        generic enough to blend into any of the 8 other possible next
        states, since Flutter decides that independently and Rive finds
        out only via the next stateIndex write.
Must NOT: imply spoken audio (no TTS exists) — "speaking" is a visual
        metaphor for "presenting a response," not lip-sync to real audio.
        speechActivity is a dead input today (§06.2) — do not require
        it to be non-zero for the animation to look correct.
```

## 12. Character Reference

- **Canonical reference:** `assets/ive/reference/ive_character_reference.png` (1536×1024 RGB PNG, 1.83MB, confirmed by both this audit and the independent prior showcase audit `docs/showcase/SHOW_00_CURRENT_STATE_MAP.md:223`). **No competing reference exists** — this is the only avatar/character image in the entire repository (verified: repo-wide search for image files with avatar/character/executive/ive in the name returns exactly this one file).
- **What IVE currently looks like** (from `IVE_RIVE_ASSET_SPECIFICATION.md`, unchanged, still the approved identity): adult female appearance (28–35), short asymmetric dark hair, expressive dark eyes, dark tech blazer/jacket, semi-realistic premium finish, cool violet/blue lighting, serious/elegant/confident expression. Explicitly **never**: emoji, bitmoji, cartoon, generic avatar, child character.
- **⚠️ Real production nuance not previously documented:** `ive_character_reference.png` is not an isolated character portrait — it is a **full annotated spec sheet** (title "IVE™ Chief AI Strategy Advisor," an 8-expression grid, a size-variant row, a color palette, typography samples, and an implementation file-structure panel — confirmed by directly viewing the file). `IveVisualFallback` (`ive_visual_fallback.dart:74-79`) renders this entire file through `Image.asset(..., fit: BoxFit.cover, alignment: Alignment.topCenter)` inside a small `ClipOval` — meaning **today's production fallback avatar is a cropped, cover-fit, top-center corner of an infographic**, not a purpose-cropped portrait. This currently "works" only because the portrait happens to sit roughly top-center in the sheet's layout; it is fragile and was never flagged in prior audits. **This is not something to fix in this read-only mission**, but the Rive asset (and any future fallback-image replacement) should be built from an isolated, purpose-cropped portrait, not a re-crop of this spec sheet.
- **Illustrated-state gap:** the reference sheet's own expression grid shows only 8 of the 10 `IveVisualState` values (idle, listening, thinking, speaking, success, warning, error, opportunity). **`attentive` and `executive` have no illustrated reference expression anywhere in the repository.** A motion designer will have to originate these two from the established style guide (§ color/lighting/never-list) rather than an existing illustration.
- No conflict found between this reference and any other project documentation (`docs/showcase/*` mentions the file only as an asset-inventory entry, makes no independent visual-identity claim).

## 13. Fallback Parity

| STATE | FALLBACK CURRENT FEEDBACK (`IveVisualFallback` + `IveStatusRingPainter`) | RIVE REQUIRED FEEDBACK | PARITY RULE |
|---|---|---|---|
| idle | Ring color `#6C63FF`, glow 0.35, overlay 0% | `idle_loop` | Rive may exceed fallback expressiveness; must not fall below it (i.e., must still read as "idle/neutral") |
| attentive | Ring `#9B8FFF`, glow 0.45, overlay 5% | `attentive_focus`→`idle_loop` | same rule |
| listening | Ring `#4DA6FF`, glow 0.55, overlay 5% | `listening_loop` | same rule (currently unreachable either way — §07) |
| thinking | Ring `#00C6FF`, glow 0.50, overlay 4% | `thinking_loop` | **Must be visually distinguishable from `speaking`** — both fallback and Rive already achieve this via distinct ring colors (cyan vs. violet); the `.riv` must preserve a similarly clear distinction |
| speaking | Ring `#7B5CF6`, glow 0.65, overlay 6% | `speaking_loop` | see above |
| success | Ring `#00E875`, glow 0.70, overlay 8% | `success_reaction`→`idle_loop` | same general rule |
| warning | Ring `#FFB020`, glow 0.65, overlay 7% | `warning_reaction`→`idle_loop` | same rule |
| error | Ring `#FF3D5A`, glow 0.75, overlay 10% | `error_reaction`→`idle_loop` | **Highest urgency** — Rive's error treatment must read as at least as urgent as the fallback's brightest/most saturated ring color |
| opportunity | Ring `#00FFD0`, glow 0.65, overlay 6% | `opportunity_reaction`→`idle_loop` | same general rule |
| executive | Ring `#D4AF37` (gold), glow 0.60, overlay 5% | `executive_recommendation`→`idle_loop` | same rule (currently unreachable either way — §07) |

**Ring ownership:** `IveStatusRingPainter` (`ive_status_ring.dart`) is explicitly documented in code as "the ONLY CustomPainter allowed — draws no face" and is reused identically by both the fallback and the Rive path (`_RiveAvatar` in `ive_avatar.dart:162-173` wraps the Rive widget in the *same* `IveStatusRingPainter`). **This means the ring is not something the `.riv` needs to draw at all** — Flutter already renders it as an overlay around whatever Rive produces. The `.riv`'s job is the character only; do not paint a competing ring/glow inside the artboard.

## 14. Failure Contract

All failure paths below are verified against actual code, not assumed:

| Failure | Where caught | Result |
|---|---|---|
| Asset missing | `rootBundle.load()` throws → `IveRiveRuntime.initialize()` propagates → `IveAvatarController.initializeRive()`'s try/catch (`ive_avatar_controller.dart:26-39`) | `_riveReady=false`, fallback renders. **This is the current, live, tested state of the app** (no `.riv` exists on `main` today). |
| Asset corrupt / unparsable | `RiveFile.import(bytes)` throws → same catch path | Same — fallback renders |
| Artboard missing | `file.artboardByName(...) ?? file.mainArtboard` — **never null-fails**; falls back to whatever Rive considers the main artboard (§04) | If the main artboard also lacks the state machine, fails at the next check below |
| State machine missing | `StateMachineController.fromArtboard(...)` returns `null` → explicit `throw StateError(...)` (`ive_rive_runtime.dart:92-98`) with a message naming the missing machine and the artboard, pointing at this doc | Caught by the same try/catch → fallback renders |
| Input missing (any bool/number/trigger) | `_findBool`/`_findNumber`/`_findTrigger` return `null`, no exception (`ive_rive_runtime.dart:57-76`) | That specific input's setter becomes a safe no-op (`_isListening?.value = v`) — **does not trigger fallback**, degrades gracefully input-by-input |
| Wrong input type (e.g. a `bool` where a `number` is expected) | Type-checked at lookup (`i is SMIBool` / `is SMINumber` / `is SMITrigger`) — a mismatched type is treated as "not found," not a cast error (this specifically avoids the `SMIBool`/`SMITrigger` cast collision the code comments call out at `ive_rive_runtime.dart:54-56`) | Same as "input missing" — safe no-op |
| Runtime exception during `initialize()` (any other cause) | Blanket `catch (_)` in `IveAvatarController.initializeRive()` | Fallback renders |
| Web load failure | No web-specific code path exists — same `rootBundle.load` mechanism used for all platforms | Same fallback behavior; not separately tested (see gap in §20) |
| Android load failure | Same as above | Same |

**No P0/P1 structural failure was found.** The runtime is fail-safe by construction: every failure mode this audit could identify degrades to the fallback (or, for missing individual inputs, degrades that one input silently) rather than crashing or leaving the avatar in an undefined state. This confirms and extends the same finding from the original `IVE_VISUAL_RUNTIME_AUDIT.md`.

## 15. Performance Budget

No prior numeric budget existed in the repository; the following is a proportional recommendation for an app whose current fallback assets are: one 1.83MB PNG spec sheet (§12 — itself oversized for what should ship as a small circular avatar), `rive: ^0.13.12` (`pubspec.yaml:37`), and an avatar rendered at a **single actually-used size of 56dp** (§04).

```
File size target:        150–400 KB for the .riv (compact artboard + shared
                          state machine). This is not a hard app-enforced
                          limit — no code checks .riv size — it is a
                          motion-design budget so the asset stays proportional
                          to an app that ships as a mobile APK.
Max acceptable size:      800 KB. Beyond this, reconsider vector complexity
                          or image-asset usage before shipping.
Artboard count:           1 required (IVE_AVATAR_COMPACT). Up to 4 total
                          (per §04) is acceptable but not required for 03B.
State machine count:      1 (IVE_EXECUTIVE_STATE_MACHINE), shared across
                          artboards per the original spec.
Image assets inside .riv: Prefer vector shapes. If raster fills are used
                          (e.g. skin/fabric texture), keep them small and
                          reused, not per-frame.
Vector complexity:        Proportional to a 56dp render target — avoid
                          sub-pixel detail that only matters at IVE_FULL_REFERENCE
                          scale (400×700) when the only artboard in active
                          use today renders at 56dp on screen.
Nested components:        Fine for reuse (e.g., shared eye/eyebrow rig
                          across artboards), but avoid deep nesting purely
                          for organization — Rive runtime cost scales with
                          active bone/constraint count, not file
                          organization.
Continuous animations:    idle_loop, listening_loop, thinking_loop,
                          speaking_loop are the only ones expected to run
                          for extended periods (per §07/§10 reachability —
                          listening_loop is currently dead but should still
                          be lightweight since it may become live later).
                          Keep loop animations cheap (few active bones/
                          shape morphs) since one instance runs for the
                          entire time the app is open (IveOverlay is always
                          mounted — §17 of the state-reconciliation audit).
CPU considerations:       The existing Flutter-side pulse ring
                          (AnimationController, ive_avatar.dart:62-68) and
                          any Rive-internal animation both run concurrently
                          whenever the avatar is visible (always). Budget
                          the .riv's continuous-loop cost accordingly — it
                          is additive to, not a replacement for, that
                          existing Flutter animation.
Mobile constraints:       Primary target is a 56dp render on Android/iOS
                          (this app is a Flutter mobile-first app; see
                          build-android.yml as the only currently-exercised
                          platform build).
Web constraints:          The app also has a Deploy Web → GitHub Pages
                          workflow (successfully exercised on main); Rive
                          web rendering (CanvasKit/Skia) should be assumed
                          reachable and budgeted for, though this mission
                          found no web-specific Rive test coverage (§20 gap).
```

## 16. Accessibility

- **Rive carries zero semantic responsibility today, by design.** `IveAvatar`'s `Semantics` wrapper (`ive_avatar.dart:125-134`) sets `excludeSemantics: true`, which explicitly suppresses any semantic nodes the child (Rive widget or fallback) might expose — confirming the existing architecture already enforces "Rive/fallback is decorative to the accessibility tree; Flutter's `Semantics` widget is authoritative," exactly as this mission requires. No change needed for this to remain true once a `.riv` exists.
- **Current label is static, not state-aware:** `Semantics(label: 'IVE, assistente executiva', button: true, ...)` is the same string regardless of whether the avatar is idle, thinking, speaking, or showing an error. This is a real, current limitation — a screen-reader user gets no announcement that IVE is "thinking" or "presenting a warning."
- **Forensic reference (V2, learning only, not adopted):** the abandoned `claude/ive-avatar-system-v2-yzjlvw` branch built `IveAvatarSemanticWrapper` (`lib/shared/ive_avatar/widgets/ive_avatar_semantic_wrapper.dart`) with a per-state `semanticLabel` and an explicit minimum touch-target `ConstrainedBox`. This is a **worthwhile idea for a future accessibility-focused mission**, not something this read-only mission adopts or cherry-picks.
- **Tap target:** the only size actually used today, `compact` = 56dp (§04), already exceeds common minimum touch-target guidance (typically 44–48dp) with no explicit enforcement needed at this size. No violation exists today; there is simply no safeguard if a future screen used a smaller custom size.
- **Conclusion for the `.riv` contract:** the asset itself needs no accessibility metadata — accessibility remains 100% a Flutter-layer responsibility, unaffected by which visual state Rive is rendering.

## 17. Responsiveness

- `IveAvatar` sizes itself via a fixed `SizedBox(width: size, height: size)` (`ive_avatar.dart:159-161`) where `size` comes from `IveAvatarSize.dp` (a `double`, not a hardcoded pixel value) — so the widget itself is already resolution/DPR-safe by construction (Flutter's logical-pixel system handles DPR scaling for both the `Rive` widget, via `useArtboardSize: false` + `BoxFit.contain`, `ive_avatar.dart:183-184`, and the fallback's `Image.asset`).
- `IveOverlay` (unchanged by mission 02, still governs actual on-screen placement) has explicit desktop/mobile branching: `_isDesktop = MediaQuery.of(context).size.width >= 1024` with different default corner offsets and drag-clamp bounds for each (`ive_overlay.dart:67-98`, from the prior reconciliation audit — re-confirmed unchanged in this pass). This means the *avatar's position* is responsive; the *avatar's own rendered size* is not currently varied by breakpoint (always `compact`, §04).
- Orientation change: no explicit handling exists or is needed beyond what `MediaQuery`-based repositioning already provides — `IveOverlay`'s `build()` recomputes `_defaultPosition`/clamp bounds from the current `MediaQuery.of(context).size` on every rebuild, which Flutter triggers on orientation change.
- **Contract for the `.riv`:** the artboard's own internal aspect ratio should be square or near-square (matching the declared 200×200 for `IVE_AVATAR_COMPACT`) so `BoxFit.contain` inside a square `SizedBox` never letterboxes. Do not hardcode non-square internal dimensions.
- **No dimension conflict found** — nothing in current code would break if a properly-square `.riv` artboard were dropped in today.

## 18. Reduced Motion

- **Flutter does provide a reduced-motion signal**, and the current app (`main`, post mission 02) does not read it anywhere (`grep -rn "disableAnimations" lib/` → zero matches, verified in this pass). The API is `MediaQuery.disableAnimationsOf(context)` (or `MediaQuery.of(context).disableAnimations` on older Flutter), which reflects the OS-level "reduce motion" accessibility setting.
- **Forensic reference (V2, learning only):** the abandoned branch built a small, self-contained `IveMotionPolicyResolver` (`lib/shared/ive_avatar/animations/ive_avatar_motion_policy.dart`) with exactly this API as its detection mechanism, plus helper functions to scale animation duration (×0.4, clamped 200–800ms) and intensity (×0.35) under reduced motion, and a `staticOnly` tier that zeroes both. This is a clean, minimal concept worth reusing as an idea in a future mission — **not adopted here**.
- **Recommendation for the future Rive integration (not implemented in this mission):**
  - Lower ambient/idle loop amplitude when reduced motion is signaled.
  - Fewer/no ambient micro-loops (e.g., skip `natural_blink` idle variety, hold a single clean idle frame) — the original asset spec already anticipated this: *"quando `accessibilityFeatures.disableAnimations` estiver ativo, o Flutter pausará o Rive automaticamente; garantir que o frame parado do `idle_loop` seja visualmente correto"* (`IVE_RIVE_ASSET_SPECIFICATION.md §F`). This audit confirms that guidance is still valid and still unimplemented.
  - No aggressive pulse — note the existing Flutter-side ring pulse (`_pulseCtrl`, 2.4s `repeat(reverse: true)`, `ive_avatar.dart:62-68`) **also** ignores reduced motion today; a future motion-reduction mission should treat the ring and the Rive character as one combined "is currently animating" surface, not fix one without the other.
  - Preserve semantic state regardless of motion level — reduced motion must never reduce *which* `stateIndex` is shown, only *how much it moves*.

## 19. Observability

No telemetry exists today for the visual runtime (confirmed: no analytics/logging call sites in `ive_rive_runtime.dart`, `ive_avatar_controller.dart`, or `ive_avatar.dart`). Specification only, for a future mission:

```
rive_load_success       — fired once, after IveRiveRuntime.initialize()
                           resolves and _riveReady becomes true. Payload:
                           artboard name actually loaded, whether it matched
                           the requested name or fell back to mainArtboard.
rive_load_failure        — fired once per failed initializeRive() call.
                           Payload: which stage failed (asset load / parse /
                           state-machine lookup) and, if a StateError, its
                           message.
missing_input            — fired the first time any of the 8 declared
                           inputs resolves to null via _findBool/_findNumber/
                           _findTrigger. One event per missing input name,
                           not per frame.
state_transition         — fired on every applyVisualState() call that
                           actually changes _currentState (the existing
                           no-op guard, ive_avatar_controller.dart:46,
                           is the natural dedupe point). Payload: from-state,
                           to-state, and whether the transition came from
                           business state or the interaction overlay.
trigger_fire              — fired on every triggerAnimation() call (today
                           zero, since nothing calls it — see §08).
fallback_activated        — fired whenever IveAvatar renders
                           IveVisualFallback instead of the Rive path
                           (i.e., whenever isRiveReady is false at build
                           time) — this event alone would have made the
                           "no .riv ships today" fact observable in
                           production without needing a code audit.
```

## 20. Test Matrix

Existing coverage (from `test/features/ive/ive_visual_runtime_test.dart` and `test/providers/ive_provider_interaction_test.dart`, both passing 114/114 in real CI as of mission 02G) already proves several rows below; rows marked **GAP** are not covered by any existing test and are proposed for mission 03B.

| Test | Status |
|---|---|
| Asset load (missing → fallback) | **COVERED** — `IveAvatarController` group, *"initializeRive returns false when .riv asset is absent"* |
| Correct artboard requested | **COVERED implicitly** — no test asserts the artboard *name* string itself; relies on `ive_visual_config.dart` constants |
| Correct state machine name | **GAP** — no test constructs a fake `.riv`/state machine to verify the exact string match; not testable without a real or synthetic asset |
| All required inputs found | **GAP** — no synthetic `.riv` exists to test against; will only be provable once a real asset ships (mission 03B) |
| Wrong/corrupt asset falls back | **COVERED by construction** — the "asset absent" test already exercises the same catch path a corrupt asset would hit (`rootBundle.load`/`RiveFile.import` both funnel into the same try/catch) |
| `thinking` maps correctly | **COVERED** — mapper tests (both expression-driven and interaction-driven, `ive_visual_runtime_test.dart` + `ive_provider_interaction_test.dart`) |
| `speaking` maps correctly | **COVERED** — same |
| `warning` priority | **COVERED** — *"speaking interaction overrides an active issue"*; *"a business issue that arrives live during speaking is preserved..."* |
| `error` priority | **COVERED implicitly** — same priority-switch code path as `warning`, exercised via the `activeIssue.severity` mapping tests |
| Business-state restore (recompute, not snapshot) | **COVERED** — the two tests named above are exactly this |
| Rapid interaction (stale token) | **COVERED** — two dedicated tests in `ive_provider_interaction_test.dart` |
| Route persistence | **COVERED indirectly** — `IveOverlay`'s single-instance-at-app-root architecture (state-reconciliation audit §10) plus existing `setRoute` tests in `ive_event_test.dart`'s sibling suite; no dedicated "survives 5 route changes" widget test exists |
| Web | **GAP** — no CI job runs `flutter test` against a web renderer; `flutter-validation.yml` runs the default (VM) test runner only |
| Android | Exercised only via the full app build (`build-android.yml`), not via a Rive-specific widget/integration test on a real device or emulator |

**03B acceptance should require, at minimum:** the two GAP rows that are actually testable once an asset exists (correct state machine name, all required inputs found) — these become straightforward once `assets/ive/rive/ive_executive_v1.riv` is real, by loading it in a test and asserting each `IveRiveInputs.*` constant resolves to a non-null input of the expected type.

## 21. Asset Acceptance Checklist

For the motion designer / for 03B's own gate, independent of this mission's own acceptance checklist (§27 of the mission brief). Items are marked **[MUST]** (03B blocker, per the §06.3 tiering) or **[SHOULD]** (recommended, not a blocker) to remove any ambiguity about what's actually required today:

```
[ ] [MUST]   File is .riv (not .rev), placed at assets/ive/rive/ive_executive_v1.riv
[ ] [MUST]   Main artboard resolves to IVE_AVATAR_COMPACT (or IS the main
             artboard — the app's fallback-to-mainArtboard behavior means
             this is safe either way, but they should agree, per §04)
[ ] [MUST]   A state machine named exactly IVE_EXECUTIVE_STATE_MACHINE exists
             on that artboard
[ ] [MUST]   The state machine's default/initial stateIndex is 0 (idle) —
             Flutter's initial applyVisualState() call can no-op if the
             controller's own default already matches (ive_avatar_controller.dart:13,
             44-50), so the .riv itself must not rely on Flutter to push an
             explicit "0" on load; it must already rest in the idle
             appearance before any input is set.
[ ] [MUST]   stateIndex (Number, 0-9) input exists and each value 0-9 produces
             a visually distinct, correctly-mapped state per §07's table
[ ] [MUST]   isThinking, isSpeaking (Booleans) exist and are wired to
             thinking_loop / speaking_loop respectively — these are the two
             states real users will see driven by live chat activity
[ ] [MUST]   thinking_loop and speaking_loop have no fixed/assumed duration
             baked in (§10) — they must loop cleanly for an indeterminate span
[ ] [MUST]   speaking_loop's exit blends acceptably into ANY of the other 9
             states, since Flutter decides the next state independently (§11)
[ ] [MUST]   Every one-shot reaction (success/warning/error/opportunity/
             executive) internally transitions back to an idle-looking
             resting sub-state on its own — per the corrected §10, Flutter
             will NOT send a fresh stateIndex just because time passed
[ ] [MUST]   Character matches the approved identity (§12) — cross-check
             against ive_character_reference.png's PORTRAIT region
             specifically, not reproduced from a re-crop of the full spec sheet
[ ] [MUST]   attentive and executive states are originated from the style
             guide (§12's illustrated-state gap) with the same visual
             language as the 8 already-illustrated states
[ ] [MUST]   File size within the budget in §15 (target 150-400KB, hard
             ceiling 800KB)
[ ] [MUST]   Square/near-square internal artboard dimensions (§17)
[ ] [MUST]   idle_loop has a visually-correct static first frame (§18,
             reduced-motion requirement already in the original asset spec)
[ ] [MUST]   Tested in Rive Viewer before delivery (per the original spec's §G)
[ ] [MUST]   Does not import, reference, or resemble the abandoned V2
             branch's asset work in any way that would misrepresent it as
             already-integrated
[ ] [SHOULD] isListening, isVisible, hasUnreadInsight, attentionLevel,
             expressionIntensity, speechActivity exist per §06.3's tiering —
             not required to be functionally meaningful since no app code
             drives them yet, but should not be absent-by-oversight
[ ] [SHOULD] All 8 triggers (§08) exist as safe one-shot animations, even
             though none are wired to a real event yet — recommended so a
             future mission can wire them without an asset revision, but
             NOT a 03B blocker
```

---

*This document was produced entirely by reading `main` at commit `3abde7a` (`git show`, direct file reads, and targeted `grep`) plus the abandoned V2 branch for forensic concept-extraction only. No code was modified to produce it. See the mission report (IVE-AVATAR-RIVE-RUNTIME-03A) for the Codex independent audit that reconciled against this document before it was finalized.*
