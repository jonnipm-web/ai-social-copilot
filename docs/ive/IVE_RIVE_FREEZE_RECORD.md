# IVE™ Avatar — Rive Freeze Record

**Mission:** IVE-AVATAR-COMMERCIAL-FALLBACK-04
**Date:** 2026-09-15
**Authority:** Agente Martins (architecture) · Paulo (owner)
**Branch of record:** `claude/ive-avatar-rive-runtime-03b6` (HEAD `5b47083` at mission start)

---

## 01. Status

```
IVE AVATAR RIVE STATUS: FROZEN
COMMERCIAL AVATAR:      IveVisualFallback (reference image + status ring)
DIAGNOSTIC CHAIN:       03B6D → 03B6O — CLOSED
RIVE PRODUCTION MIGRATION: NO-GO
```

No further Rive diagnostic mission (no "03B6P") may be opened without explicit authorization from Agente Martins/Paulo.

## 02. Reason

The canonical production canary (`assets/ive/rive/ive_executive_03b6_canary.riv`, SHA-256 `eabbfd3658479efe3c90cdef571f04c3fe2129d218146ef466176bc62ac2cd1f`) **initializes without error under `rive 0.14.11` / `rive_native 0.1.11`** — artboard `IVE_AVATAR_COMPACT` and state machine `IVE_EXECUTIVE_STATE_MACHINE` are found by name, all three live inputs (`stateIndex`, `isThinking`, `isSpeaking`) resolve, the full 12-transition state matrix runs with zero exceptions, the embedded portrait bytes are extracted and hash-match the canonical portrait, and `decode()` returns `true` — **yet it renders zero pixels in both supported renderer factories** (`Factory.rive` with the default CDN host, with a self-hosted host, and in a release build; `Factory.flutter` after explicit `RiveNative.init()`). In the same page, same harness and same WASM runtime, an official positive-control asset from the package's own examples (`rocket.riv`) renders correctly (40 000 / 40 000 non-transparent pixels, visible in a real Chrome screenshot). The failure is therefore asset-specific and **silent**: no exception, no console error, no CSP violation.

Under the currently shipped runtime (`rive ^0.13.12` → 0.13.20) the same canary fails differently but equally fatally: `initialize()` succeeds and the first frame throws `AnimationResetFactory` / `TypeError: LinearAnimation is not a subtype of TransformComponentBase` (root cause documented in 03B6J: a `KeyedObject.objectId` reference-domain mismatch between the Rive CLI 1.0.2 exporter and the legacy Dart importer). Both paths end in a blank Avatar for the user.

Three-Pillar decision recorded by 03B6O: AUTOMATION CONDITIONAL PASS · MONETIZATION FAIL (for Rive migration now) · SECURITY PASS WITH CONDITIONS. Final classification **D — PORTRAIT RENDERING BLOCKER REMAINS; FREEZE RIVE**.

## 03. What this mission changed (fallback-only, reversible)

| Change | File | Purpose |
|---|---|---|
| `IveRiveFeatureGate.enabled = false` (literal compile-time constant — no build flag or environment variable can flip it) | `lib/features/ive/visual/ive_visual_config.dart` | Rive disabled by configuration; re-enabling requires a reviewed code change. |
| Early return in `IveAvatarController.initializeRive()` when the gate is off | `lib/features/ive/visual/ive_avatar_controller.dart` | The fallback is selected **before** any `IveRiveRuntime`, asset load or native runtime exists — not by waiting for a failure, because 03B6O proved the failure can be silent. |
| Header comment | `lib/features/ive/visual/ive_visual_fallback.dart` | Declares the fallback as the commercial Avatar. |
| Tests | `test/features/ive/ive_visual_runtime_test.dart` | Gate determinism at controller level; `IveAvatar` always renders `IveVisualFallback` and never a `Rive` widget. |

No `.riv`, RML, package version, Rive source, auth, RLS, Supabase, JWT or Edge Function was touched. The 03B6C canary pointer in `IveAssetPaths.riveAsset` is left in place (inert behind the gate) so a future re-entry starts from the verified baseline.

To re-enable Rive for an authorized experiment: change `IveRiveFeatureGate.enabled` to `true` in a reviewed, non-commercial branch (it was deliberately NOT made a `--dart-define`, so that no CI or developer invocation can enable the frozen path by accident — Codex FALLBACK-04 finding P1). Never merge that change to a commercial branch.

## 04. Preserved knowledge (do not implement — documented for re-entry)

1. **`rive 0.14.11` removes the fatal legacy crash.** The unmodified canary loads, runs the full state matrix and never throws `AnimationResetFactory` under `rive_native` (03B6N, confirmed 03B6O). The importer is a genuinely different C++ `CoreRegistry` model, not the legacy Dart `HashMap` path.
2. **Same-origin WASM architecture is validated and exact.** `rive_native` resolves its web runtime through `RIVE_NATIVE_WASM_HOST` (compile-time). Recipe: download `@rive-app/flutter-native-wasm@<wasmVersion>` from registry.npmjs.org (verify `dist.shasum`), pin SHA-256 of the four files (`wasm/rive_native.{js,wasm}`, `wasm_compatibility/rive_native.{js,wasm}`), serve them from `web/rive_native_self_host/`, build with `--dart-define=RIVE_NATIVE_WASM_HOST=/rive_native_self_host/` **from PowerShell, not Git Bash** (MSYS2 rewrites a leading `/` into `C:/Program Files/Git/...`). Verified: zero `cdn.jsdelivr.net` requests in a release build under a real CSP. The define fails **open** to jsdelivr if omitted — CI must enforce it. CSP needed `'unsafe-eval' 'wasm-unsafe-eval' blob:` (script) and `blob:` (worker); Flutter's default fonts additionally need `fonts.gstatic.com` or self-hosted fonts.
3. **Android debug build validated** (`app-debug.apk`, 177 537 451 B). `rive_native`'s Gradle task `runRiveNativeSetup` shells out to `dart` and requires it on PATH; it downloads native libraries at build time from `rive-flutter-artifacts.rive.app` (hash-checked) — pin/cache in CI. `rive_native` still applies the Kotlin Gradle Plugin, which Flutter warns will break in future versions. Never smoke-tested on a device.
4. **The classic 3-input contract still works** (`stateMachine.number('stateIndex')`, `.boolean('isThinking')`, `.boolean('isSpeaking')`), but the package marks classic Inputs as deprecated in favour of Data Binding — keep them isolated behind `ive_rive_runtime.dart`.
5. **Current canary renders zero pixels; positive-control `.riv` renders correctly** in the same harness (see §02). `Factory.flutter` works on web only after an explicit `await RiveNative.init()`; without it, `LateInitializationError: makeFlutterFactory` is an initialization-order artifact, not a platform limitation.
6. **99.94 % of the `.riv` is the embedded portrait** (1 678 024 of 1 679 076 bytes; 1 052 bytes of vectors/animation/structure). Any future 800 KB size mission is purely a portrait-compression task.
7. **Any future runtime integration must include visual-health detection** (first-painted-frame / timeout guard), because the failure mode is silent — exception-only fallback logic is insufficient.

Evidence is retained outside the canonical repo in the session scratchpad (`03b6n-disposable/probe_app` with the positive-control harness, APK, logs and release build; `03b6o-disposable` with the npm tarball, extraction and hashes) and in project memory.

## 05. Re-entry conditions

Rive may be reopened **only** if at least one of the following occurs:

- **A.** A newly authored / re-exported canonical Avatar `.riv` is available.
- **B.** Rive upstream provides a confirmed resolution or explanation for the current canary.
- **C.** Avatar animation becomes an explicitly approved commercial conversion / demo / retention requirement.
- **D.** Agente Martins / Paulo explicitly authorize reopening.

Otherwise **RIVE REMAINS FROZEN.** If reopened, the first step is outside the closed diagnostic chain: an upstream report to Rive (canary + `rocket.riv` positive control, already packaged) or a fresh authoring/export of the asset — not further importer forensics.

**Acceptance bar for any re-entry (minimum, before `IveRiveFeatureGate.enabled` may become `true` on a commercial branch):**

1. Visual proof from a **release** build (real screenshot + pixel evidence) that the artboard and portrait render — `decode() == true` is not sufficient.
2. A first-frame / visual-health guard that falls back to `IveVisualFallback` on **silent** failure (timeout or zero-paint detection), not only on exceptions.
3. Platform coverage: web release under the same-origin WASM recipe and CSP, plus an Android build **and** device/emulator smoke.
4. The gate stays a reviewed code constant; if it ever becomes a build flag, CI must fail closed on the enabling value.
5. Fresh Codex adversarial review of the re-entry change.
