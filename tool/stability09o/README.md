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
built `main.dart.js.map` corresponds to the commit just built by reading
the REAL checked-out `lib/main.dart` from the same job and round-tripping
SEVERAL known lines, spread across the entire file (not just one), through
`generatedPositionFor` / `originalPositionFor` (see the script's own header
comment, including the two earlier approaches that didn't hold up under
Codex review, for exactly why). This is a strong multi-point freshness
check, not a byte-for-byte whole-file guarantee — Flutter/dart2js on this
version doesn't embed `sourcesContent`, so an exact content comparison
isn't available; see the script's header for the accepted residual
limitation. A failure fails the whole deploy job — a source map that
cannot be proven build-matched must not be trusted for a future crash.

```
node verify_build_sourcemap.mjs build/web/main.dart.js.map lib/main.dart
```

## `symbolicate.mjs` — manual symbolication of a real production crash

When a genuine STABILITY-09 recurrence is captured in `diagnostic_events`
(category `RUNTIME`, event `uncaught_error`):

1. Read the event's `session_id` → look up that session's `build_sha` in
   `diagnostic_sessions`.
2. Download the artifact named `sourcemap-<build_sha>` from that commit's
   `Deploy Web → GitHub Pages` Actions run (Actions tab → the run →
   Artifacts). This repository is **public**, so the encrypted blob itself
   is downloadable by anyone — it decrypts only with
   `SOURCEMAP_ENCRYPTION_KEY` (a repo secret; ask Paulo/Agente Martins for
   the value if you don't already have it — it cannot be re-read from
   GitHub's UI once set, only rotated).
3. Decrypt and unpack it:
   ```
   openssl enc -d -aes-256-cbc -pbkdf2 -in sourcemap.tar.gz.enc -out sourcemap.tar.gz -k "<SOURCEMAP_ENCRYPTION_KEY>"
   tar -xzf sourcemap.tar.gz
   ```
4. Parse the event's `error_stack` for a `main.dart.js:LINE:COLUMN`
   reference.
5. Run:

```
node symbolicate.mjs <path-to-main.dart.js.map> <line> <column>
```

6. Both `resolved_LUB` and `resolved_GLB` resolving to `null` is the known
   signature of a **build_sha mismatch** (confirmed in STABILITY-09R against
   historical pre-09O crashes) — re-check step 1/2 before concluding
   anything else about the crash itself.

## Rotating or losing `SOURCEMAP_ENCRYPTION_KEY`

GitHub Actions secrets are write-only — nobody, including Paulo, can read
the value back after it's set. If it's lost, generate a new one and set it
(`gh secret set SOURCEMAP_ENCRYPTION_KEY`); this only affects FUTURE
deploys' source-map artifacts — it does not touch the running app or any
already-uploaded artifact (those simply become permanently undecryptable,
same as if they'd expired).
