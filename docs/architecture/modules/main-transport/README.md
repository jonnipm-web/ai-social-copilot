# Patches ready for `main` (not applied)

Mission: `INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02`. This mission
may not write to `main` or to the commercial branch. These patches are the
exact, reviewed changes to carry over **through the commercial/main gate**
(Agente Martins + Paulo). Both patches were checked with
`git apply --cached --check` against `origin/main` = `ff8ef34`. No file in
this directory contains a credential literal.

| Patch | Finding | Why `main` needs it |
|---|---|---|
| `0001-aef-fix-clock-dependent-validator-tests.patch` | MPA-F07 | Two AEF validator tests (F-08, N-04) have failed deterministically since 2026-09-18T13:00Z: they rely on the real clock but reused a fixed expiry. CI on `main` is red for any PR touching `aef/`, `contracts/aef/` or `supabase/functions/`. Test-only; the validator is unchanged. |
| `0002-ci-disable-legacy-keystore-workflows.patch` | MPA-F01 | `ccb065c` for `build-android.yml` and `build-apk.yml`. On `main`, `build-android.yml` still runs on every push to `main` with the `KEYSTORE_*` secrets (91 successful runs, last 2026-09-18) and `build-apk.yml` remains dispatchable. |
| `0003-generate-keystore.yml.replacement` | MPA-F01 | Full replacement for `.github/workflows/generate-keystore.yml` (the disabled `ccb065c` version). Shipped as a whole file, not a diff, because any diff of that file must reproduce the removed hardcoded password (Codex Final CXF-01). One literal in its incident comment is redacted. |

Apply (on a branch cut from `main`, by whoever the gate authorizes):

```bash
git switch -c fix/main-transport origin/main
git apply docs/architecture/modules/main-transport/0001-aef-fix-clock-dependent-validator-tests.patch
git apply docs/architecture/modules/main-transport/0002-ci-disable-legacy-keystore-workflows.patch
cp docs/architecture/modules/main-transport/0003-generate-keystore.yml.replacement .github/workflows/generate-keystore.yml
deno test --allow-read contracts/aef/validators_test.ts   # expect all green
```

## Keystore evidence (corrects the `ccb065c` narrative)

Metadata only: no GitHub secret value was read, printed or downloaded. The
historical hardcoded workflow passwords are already public in git history;
they were compared by hash only and are not reproduced anywhere in this
directory.

- `KEYSTORE_BASE64`, `KEYSTORE_KEY_ALIAS`, `KEYSTORE_KEY_PASSWORD`,
  `KEYSTORE_STORE_PASSWORD` were created on **2026-07-14**, the same day as
  `fd8e0fb` ("usar keystore fixo para assinatura release permanente"), which
  replaced a per-build ephemeral `keytool` keystore with a fixed CI keystore
  to stabilise the SHA-1 registered for Google Sign-In.
- `generate-keystore.yml` (hardcoded password, prints base64) was added on
  **2026-07-28**, **has zero runs**, and instructs secrets with different
  names, none of which exist. The `KEYSTORE_*` secrets therefore did **not**
  come from it; its hardcoded password is not evidence about their values.
- The removed ephemeral `keytool` step in `fd8e0fb` also hardcoded a
  password (different from `generate-keystore.yml`'s, compared by hash
  only). Whether the fixed keystore reused it cannot be verified without
  reading the secret.

Classification: **STALE** — a legacy CI signing key for the pre-commercial
build, still consumed by `build-android.yml` on `main`, provenance
unverifiable, and **not** the Play upload key (`com.insightvalues.app`
release signing uses `android/key.properties`, owner-held, see
`android/OWNER_KEYSTORE_RECOVERY_CHECKLIST.md`).

Owner action: never use `KEYSTORE_*` as the Play upload key; delete the four
secrets once no Google Cloud OAuth Android client depends on SHA-1
`20:EB:49:1E:…:E2:1D` (deleting them also neutralises the three workflows on
`main` immediately, without touching `main`).
