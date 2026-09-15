# STABILITY-09O source-map tooling

Repository-committed (mission section 10 — must not depend solely on one
developer's local machine). Never used at app runtime; Node.js CLI tools
only, run from CI or a developer's machine.

## Setup

```
cd tool/stability09o
npm install
```

## `verify_build_sourcemap.mjs` — CI self-check

Run automatically by `.github/workflows/deploy-web.yml` right after
`flutter build web --release --source-maps`, before the private source-map
artifact is uploaded and before GitHub Pages publish. Proves the freshly
built `main.dart.js.map` actually corresponds to the commit just built, via
a source→generated→source round trip (see the script's own header comment
for why this is used instead of a fixed compiled offset). A failure fails
the whole deploy job — a source map that cannot be proven build-matched
must not be trusted for a future crash.

```
node verify_build_sourcemap.mjs build/web/main.dart.js.map
```

## `symbolicate.mjs` — manual symbolication of a real production crash

When a genuine STABILITY-09 recurrence is captured in `diagnostic_events`
(category `RUNTIME`, event `uncaught_error`):

1. Read the event's `session_id` → look up that session's `build_sha` in
   `diagnostic_sessions`.
2. Download the private source-map artifact named `sourcemap-<build_sha>`
   from that commit's `Deploy Web → GitHub Pages` Actions run (Actions tab
   → the run → Artifacts — never public, never on the deployed site).
3. Parse the event's `error_stack` for a `main.dart.js:LINE:COLUMN`
   reference.
4. Run:

```
node symbolicate.mjs <path-to-main.dart.js.map> <line> <column>
```

5. Both `resolved_LUB` and `resolved_GLB` resolving to `null` is the known
   signature of a **build_sha mismatch** (confirmed in STABILITY-09R against
   historical pre-09O crashes) — re-check step 1/2 before concluding
   anything else about the crash itself.
