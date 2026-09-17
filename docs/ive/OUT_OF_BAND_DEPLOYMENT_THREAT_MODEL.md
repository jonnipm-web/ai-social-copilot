# OUT-OF-BAND DEPLOYMENT THREAT MODEL

**Mission:** `IV-SECURITY-REMEDIATION-03` | **Trigger:** the `ive-agent-runner` retirement stub (`IV-SECURITY-REMEDIATION-02`) was deployed directly via the Supabase MCP tool, entirely outside `.github/workflows/deploy-edge-functions.yml`. This is a real, confirmed capability of this environment, not a hypothetical — this document records exactly what it can and cannot do, so nobody later mistakes "the canonical CI path is well-governed" for "this project's only deployment path is well-governed."

---

## 1. Deployment paths that exist today

| Path | Enforcement | Evidence left | Actor identity |
|---|---|---|---|
| **Canonical CI** — `.github/workflows/deploy-edge-functions.yml` (`workflow_dispatch`) → `scripts/ci/resolve_deploy_selection.sh` → `.github/deploy-allowlist.tsv` → `scripts/ci/check_deploy_governance.sh` (self-test on relevant pushes) | **Full** — name allowlist, JWT-policy allowlist, explicit hard-blocks (`ive-agent-runner`), no-bulk/no-wildcard, allowlist/config.toml cross-check (this mission) | GitHub Actions run history, tied to a commit SHA and the GitHub identity that triggered `workflow_dispatch` | GitHub identity, logged |
| **Supabase MCP `deploy_edge_function`** (used in `IV-SECURITY-REMEDIATION-02` to deploy the retirement stub) | **None at the platform level.** The tool takes `verify_jwt` as a plain parameter with no allowlist check; nothing stops it from deploying any function name, including `ive-agent-runner`, with any `verify_jwt` value | Supabase's own function metadata: `version` increments, `updated_at` changes, `ezbr_sha256` changes | Whoever holds Supabase project access via this MCP connection — no separate identity per call |
| **Supabase Dashboard** (manual paste-and-deploy in the browser) | **None** | Same as above (version/updated_at/hash) | Whichever human is logged into the dashboard |
| **Supabase CLI** (`supabase functions deploy <name>`, run locally by anyone with the project's access token) | **None** | Same as above | Whoever holds the local CLI session/token |
| **Supabase Management API** (direct HTTP calls with a personal/service access token) | **None** | Same as above | Whoever holds the token |

**Conclusion:** exactly one deployment path has technical enforcement. Every other path is gated **only by who holds Supabase project credentials** — not by anything in this repository. This was already implicitly true before this mission (nothing changed it); this mission is the first to write it down explicitly and test the one governed path's own invariants (Sections 4-6 above).

## 2. Can an out-of-band deploy be detected after the fact?

**Partially, and only manually today.** Supabase's `list_edge_functions` response includes `version`, `updated_at`, and `ezbr_sha256` per function. These change on every deploy regardless of path. In principle, someone who knows what the *expected* version/hash should be (from git history + a record of when each deploy happened) can compare it against the live value and notice a mismatch. In practice:

- **Nothing does this comparison automatically today.** No CI job, script, or scheduled check cross-references live Supabase state against git.
- **`ezbr_sha256` does not correspond to a git blob or commit SHA.** It is Supabase's own hash of the bundled artifact. There is no built-in mapping from "this hash" to "this commit."
- The only reason `IV-SECURITY-REMEDIATION-02`'s out-of-band deploy is traceable at all is that the mission **manually and deliberately** recorded the pre-change state (`sr04_sr05_backup/ive-agent-runner_v5_PRE-CHANGE_BACKUP.json`) and the post-change state (`docs/ive/SR04_SR05_CLOSURE.md`, listing version 6 and its hash) as an explicit mission artifact — not because any system enforced or automated that record.
- If someone deployed a change via the Dashboard/CLI/API **and did not also write a corresponding doc or commit**, there would be **silent drift** between what `main` claims is deployed and what is actually running, with no alert of any kind. This is the same class of problem SR-04 itself was.

## 3. What data would let someone correlate runtime with source, if they went looking?

Today: `version` (an incrementing integer, no external meaning), `updated_at` (a timestamp, useful only if cross-referenced by hand against commit timestamps or mission reports), and `ezbr_sha256` (opaque, only useful as an equality check against a *previously recorded* value from a prior manual audit — never against a git SHA directly). None of these are sufficient on their own; all require a human-maintained bridge document (exactly what `docs/ive/SR04_SR05_CLOSURE.md` is, for this one function).

## 4. Is this a new problem introduced by this mission chain?

No. This capability (direct MCP/Dashboard/CLI/API deploy, fully out-of-band) has existed since the Supabase project was created — `IV-SECURITY-REMEDIATION-02` did not create it, it *used* it (under explicit mission authorization, for a narrow, low-risk, fully-tested change) and, in doing so, made the gap concrete and visible for the first time in this mission chain. `INSIGHTVALUES-ECOSYSTEM-TARGET-ARCHITECTURE-01` (the architecture mission two missions ago) had already flagged "Deployment/Runtime Truth" as an unimplemented capability in the abstract; this document is the same gap, now described from the specific angle of "what happens if someone uses the side door," with concrete evidence instead of a hypothesis.

## 5. Residual risk classification

**P2 — not a new exposure, but an existing one now documented.** Nothing this mission did increases exposure (no new access was granted to anyone; the MCP tool already existed and was already usable this way before this mission). The risk is that this gap could be used **accidentally** (someone fixing something via the Dashboard without realizing the repo needs a matching commit) more than **maliciously** (anyone who already has Supabase project credentials already has far more direct capability than "deploy a function" — e.g., direct database access). Recommended handling: keep as a documented, tracked gap; do not attempt to lock it down by restricting Supabase access in this mission (out of scope, and would affect legitimate administrative work); close it properly only as part of the Deployment/Runtime Truth extension below, which is itself explicitly deferred to a future mission per the architecture mission's own sequencing.

---

## 6. Deployment / Runtime Truth — minimal incremental extension

Full target chain (from `INSIGHTVALUES-ECOSYSTEM-TARGET-ARCHITECTURE-01`, Section 14):

```
Repository → Canonical Branch → Commit SHA → Source Hash → Deployment Manifest →
Deployment Actor/Path → Production Version → Runtime Hash → Runtime Verification → Drift Detection
```

| Link | Status | Evidence |
|---|---|---|
| Repository → Canonical Branch → Commit SHA | **IMPLEMENTED NOW** | Standard git; nothing to add |
| Source Hash | **IMPLEMENTED NOW** | `ezbr_sha256` (Supabase's own artifact hash), already returned by `list_edge_functions`/`deploy_edge_function` |
| Deployment Manifest | **IMPLEMENTED NOW, for the canonical path only** | `.github/deploy-allowlist.tsv` + `supabase/config.toml`, now cross-checked against each other (this mission) |
| Deployment Actor/Path | **IMPLEMENTED NOW for canonical CI (GitHub identity + run log); NOT IMPLEMENTED for any out-of-band path** | Section 1 above |
| Production Version | **IMPLEMENTED NOW** | `version`/`updated_at` from `list_edge_functions` |
| Runtime Hash | **IMPLEMENTED NOW** | `ezbr_sha256`, live |
| Runtime Verification | **IMPLEMENTED NOW, manual only** | This mission and `IV-SECURITY-REMEDIATION-02` both did this by hand (curl tests, `list_edge_functions` calls) |
| Drift Detection | **PROPOSED FUTURE — not implemented** | No automated comparison exists between "what git says should be deployed" and "what Supabase says is deployed," for any function |

**Minimal, low-risk increment proposed for a future mission (not built here, per Section 9's explicit "no new platform/service/daemon" constraint):** a plain script (no new service, no database, no daemon) that a human runs on demand — not a scheduled job — which (a) reads `.github/deploy-allowlist.tsv` for the list of governed functions, (b) calls `list_edge_functions` for their current `version`/`ezbr_sha256`, and (c) compares that against a small, git-committed manifest file (e.g., `docs/ive/DEPLOYED_VERSIONS.md` or similar) that each mission touching a function's deployment is required to update in the same commit — exactly the discipline `docs/ive/SR04_SR05_CLOSURE.md` already follows for `ive-agent-runner` alone, generalized to every function instead of one. This closes "Drift Detection" for the functions that opt in, without building any new infrastructure. **Not implemented in this mission** — it would touch a broader convention than SR-04/SR-05's scope, and Section 9 explicitly reserves "qualquer sistema novo... FORA DE ESCOPO," which this manifest-file proposal deliberately stays under by being a plain committed file plus a plain script, run by a human, not a system.
