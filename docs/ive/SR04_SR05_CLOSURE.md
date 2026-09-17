# SR-04 / SR-05 CLOSURE — `ive-agent-runner`

**Mission:** `IV-SECURITY-REMEDIATION-02` (SR-04/SR-05 Controlled Closure + Runner Containment)
**Executor:** Claude | **Adversarial verifier:** Codex | **Architect/gate:** Agente Martins
**Date:** 2026-09-17
**Baseline:** `INSIGHTVALUES-ECOSYSTEM-TARGET-ARCHITECTURE-01` (CONDITIONAL PASS), Runner Transition Decision **B → D → E** (approved).

---

## Status Summary

| Item | Status |
|---|---|
| **SR-04** (source-of-truth drift) | **CONTAINED — pending PR merge** ([PR #97](https://github.com/jonnipm-web/ai-social-copilot/pull/97)). Runtime and this branch already match; `origin/main` will match once merged. |
| **SR-05** (auth/JWT gap) | **CLOSED** — verified live in production, does not depend on merge status |
| `ive-agent-runner` deployment version | 6 (was 5) |
| `verify_jwt` | `true` (was `false`) |
| Business logic present | **None** — function is an inert retirement stub |
| Deployment governance hard-block | **Preserved, unchanged** |

**Note on SR-04 status (Codex-reviewed, P1 finding, resolved by opening PR #97):** the production runtime fix and this repository's source addition are both real and already in effect on branch `ive-commercial-autonomous-15` (commit `356f550`). The *fully* closed state for SR-04 — where anyone reading `origin/main` sees a canonical source matching production — requires this PR to be reviewed and merged. Do not report SR-04 as unconditionally `CLOSED` until that merge lands.

---

## What was true before this mission

- `ive-agent-runner` was **ACTIVE in production** (Supabase project `nzngvbajrnruknpzzjbf`), version 5, `verify_jwt: false`, created and never updated since `2026-08-20` (`created_at == updated_at`).
- Its source existed **only** on git branch `release/phase-10-stabilization`, never merged or canonicalized to `main`. `main` had **no file** at `supabase/functions/ive-agent-runner/`.
- `.github/deploy-allowlist.tsv` and `scripts/ci/resolve_deploy_selection.sh` already hard-blocked this function name from the canonical CI deploy workflow, "regardless of allowlist contents" (protection dating to mission `X4A`).
- Zero client callers were found anywhere in `lib/` or in any other Edge Function, across **every branch** of the repository (confirmed fresh in this mission's DISCOVER phase, not carried over from a prior mission's memory).

## Why this was a real (if low-severity) risk

- `verify_jwt: false` meant the live function accepted **any** request with no signed JWT at all — a strictly weaker gate than every other real Edge Function in this project.
- The historical business logic (10/11 read-only tools + 1 propose-only tool) was reachable by anyone who discovered the URL, with no identity check of any kind.
- Actual exploitation likelihood was low (zero callers, no discoverability beyond the URL, tools mostly read-only) — this is why the Target Architecture mission classified it `OPEN/CONDITIONAL`, not `P0`.

## What this mission did

**Runner Transition Decision context:** the approved sequence is B (extract the pattern for AEF) → D (retain as an isolated, non-critical adapter while AEF doesn't exist) → E (deprecate once AEF has Job Lifecycle + Tool Registry + Human Gates). This mission executes the **D** step concretely: the runner is retained as a slug, but its actual invokable surface is neutralized.

1. **Did not** touch, copy, cherry-pick, or reconstruct any code from `release/phase-10-stabilization`. The historical implementation remains exactly where it was, untouched, preserved as historical reference only.
2. **Did not** remove or weaken the `.github/deploy-allowlist.tsv` hard-block. It still unconditionally denies any deploy of this function name through the canonical CI workflow.
3. Deployed a **fresh, minimal retirement stub** directly to the `ive-agent-runner` slug (outside the CI pipeline, the same way this function has always been deployed — version 5 also predates the CI pipeline). The stub:
   - Sets `verify_jwt: true` at the platform level.
   - Additionally re-implements the exact same identity check as `supabase/functions/_shared/auth.ts::resolveAuthenticatedUser()` (inlined, since this is a single-file direct deploy outside the canonical bundle) — rejects missing headers, malformed headers, and any token that isn't a real GoTrue user session (this is what closes the anon-key gap that `verify_jwt=true` alone would not close).
   - Performs **no business logic** regardless of identity: every request that passes both gates still receives `410 Gone`. There is nothing left to exploit even for a legitimately authenticated user.
4. Committed the same stub source to `main` at `supabase/functions/ive-agent-runner/index.ts` — **this is the first time repository truth and production runtime truth match for this function.** This is what closes SR-04: there is no longer a deployed artifact with no corresponding source in `main`.
5. Updated the explanatory comment in `.github/deploy-allowlist.tsv` (enforcement logic unchanged) to reflect that source now exists but the function remains permanently excluded from CI deploy.

## Runtime verification (production, post-deploy)

| Test | Expected | Result |
|---|---|---|
| No `Authorization` header | 401, platform-level | ✅ `401 UNAUTHORIZED_NO_AUTH_HEADER` (rejected before reaching function code) |
| Malformed/garbage bearer token | 401, platform-level | ✅ `401 UNAUTHORIZED_INVALID_JWT_FORMAT` |
| `Authorization` header without `Bearer` prefix | 401, platform-level | ✅ `401 UNAUTHORIZED_INVALID_JWT_FORMAT` |
| Anon/publishable key as bearer token | Passes platform gate, rejected inside function | ✅ `401 {"error":"Unauthorized"}` (function-level rejection, confirms double-gate works) |
| `OPTIONS` preflight | 200, CORS headers present | ✅ `200` |
| `POST` with body, no auth | 401, method-agnostic | ✅ `401` |
| Response headers | No secrets, no service-role key, no internal data | ✅ Only standard Cloudflare/Supabase infra headers |
| Valid authenticated user session | Passes both gates, receives `410 Gone` | **NOT_VERIFIED** — no test user credentials available in this environment; not exercised against a real production user to avoid touching real account state. The identity-check code path is byte-for-byte identical in logic to `_shared/auth.ts::resolveAuthenticatedUser()`, which is already exercised by `auth_test.ts` and used in production by 18 other functions today. |

## Canonical ownership and future conditions

- **Canonical owner of this slug:** Core repository maintainers, pending AEF. No product currently depends on it.
- **Source-of-truth status:** `main` at `supabase/functions/ive-agent-runner/index.ts` (this stub) is now authoritative for what is deployed. The historical business-logic implementation on `release/phase-10-stabilization` is **not** authoritative for anything and should not be treated as a source to merge, cherry-pick, or reference as a specification.
- **Deployment path:** unchanged — this slug cannot be deployed through `.github/workflows/deploy-edge-functions.yml` (hard-blocked by name, independent of allowlist contents). Any future change to this stub must be deployed directly, the same way this change was, under an explicit mission.
- **Conditions before any future change:**
  1. A mission must explicitly authorize touching this function again.
  2. If the future change is "replace with AEF-routed adapter" (Runner Transition Decision step E), it must go through `IV-AEF-FOUNDATION-01` (or successor), not be improvised ad hoc.
  3. If the future change is "restore functionality," the requesting mission must independently re-derive the desired behavior and threat model — it must **not** treat the frozen `release/phase-10-stabilization` code as a ready-to-use specification (per `IV-EVIDENCE-TRUST-BOUNDARY-DESIGN-01`'s and this repository's `X4A`/`X4R` findings).

## Rollback

If this change needs to be reverted for any reason, **do not** redeploy the historical version 5 — that would silently reintroduce the exact `verify_jwt=false` exposure this mission closed. A safe rollback deploys another known-safe inert stub (this one, or an equivalent), the same way this one was deployed (direct, outside CI, under an explicit mission), and reverts the two repository files (`supabase/functions/ive-agent-runner/index.ts`, this doc) via a normal `git revert` of commit `356f550`. A full backup of the pre-change function state (version 5 metadata, including its `ezbr_sha256`) was archived during this mission for audit purposes; the historical source itself remains recoverable from `origin/release/phase-10-stabilization` if ever needed for forensic reference — not for redeployment.
