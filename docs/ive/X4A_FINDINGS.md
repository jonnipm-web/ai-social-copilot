# IVE-X4A Findings — Production Exposure & Deployment Closure

Audit only. No deploy, no traffic change, no IAM change, no Edge Function
deploy performed by this session. All findings below are from read-only
inspection: `gh api`, `git fetch`/`git show` (never checkout), the Supabase
MCP `list_edge_functions`/`execute_sql` (read-only queries only), and one
GET request to a documented, unauthenticated, side-effect-free `/health`
endpoint.

## 1. `ive-agent-runner` — NOT a scaffold. Deployed, gated, well-implemented.

Every prior mission (X1, X3, and this mission's own brief) treated
`ive-agent-runner` as unbuilt scaffolding. That was wrong, and this session
found out only by checking rather than repeating the assumption:

- **It is deployed and ACTIVE** in production Supabase (confirmed via
  `list_edge_functions`): `verify_jwt: false`, version 1, created and never
  updated since 2026-07-24T22:22:05Z.
- **The source does not exist on `main`** (confirmed: `find
  supabase/functions -iname "*ive-agent-runner*"` on `main` @ `7795421`
  returns nothing). It exists on branch **`release/phase-10-stabilization`**
  (commit `324bdf8`), which is where the one-time deploy must have come
  from — the deploy workflow's `workflow_dispatch` input accepts an
  arbitrary `deploy_ref`, and the file-existence check
  (`test -f supabase/functions/ive-agent-runner/index.ts`) would only pass
  against that ref, not `main`.
- **It is a substantial, multi-file implementation** ("Agent Runner v1.0 —
  IVE Agent Foundation Phase 1B"): `index.ts`, `agent_orchestrator.ts`,
  `ai_provider.ts`, `permission_engine.ts`, `score_engine.ts`,
  `tool_registry.ts`, `types.ts`, `index_test.ts`.

### Security posture (read from source, not assumed)

- **`--no-verify-jwt` at the gateway is real, but the function performs its
  own robust auth**: `createAuthenticatedClient` builds a Supabase client
  with the **anon key** (never service-role) carrying the caller's own
  `Authorization` header; `getAuthenticatedUid` calls `client.auth.getUser()`
  — a real round-trip validation against Supabase Auth, not a
  self-decoded/trusted claim. Every subsequent query runs under that
  client, so **RLS is fully enforced**, not bypassed.
- `project_id` ownership is explicitly re-verified
  (`.eq('id', projectId).eq('user_id', uid)`) before any context loads.
- `uid` is documented and confirmed to come exclusively from the validated
  JWT, never from the request payload.
- **10 of 11 tools are `permission: 'read'`; exactly one is `'propose'`.
  Zero occurrences of `.insert(`, `.update(`, or `.delete(` exist anywhere
  in the directory.** The agent cannot write to the database under any
  code path today — the one write-adjacent tool returns a proposed action
  object; an actual `action_queue` row is only created by the existing,
  separate, human-confirmed Flutter flow.
- Agent loop is bounded (`MAX_AGENT_TURNS = 5`), matching the frozen
  Python agent's own loop-guard discipline.
- **Access is gated closed for the general public today.** `feature_flags`
  has no `ive_agent_mode` row (confirmed via direct query) — the code's
  `isAgentModeEnabled` fails safe to `false` when the row is absent, so
  every caller except whoever is listed in the `INTERNAL_TESTER_IDS`
  secret gets a `503 AGENT_DISABLED` response. This session cannot see
  who is on that list.
- No API key is logged (grepped `ai_provider.ts` for key-logging patterns
  — none found); keys come only from `Deno.env.get(...)`.

### The real gap

`--no-verify-jwt` at the gateway does not let an unauthenticated caller do
anything (the app-level check rejects them with 401), but it does let an
unauthenticated caller's request reach billable function compute before
being rejected, instead of being rejected for free at Supabase's edge —
a cost-amplification / cheap-DoS surface, not an authorization bypass.

### Classification

Per the mission's taxonomy (ACTIVE / DORMANT / SCAFFOLD / DEPRECATED /
UNKNOWN): **ACTIVE**, not scaffold. Well-secured for what it currently
does (read + propose, never write), narrowly gated to an internal
allowlist, but **completely undocumented outside its own source comments,
invisible to three prior audit missions, and deployed from a branch that
was never merged or even referenced anywhere in this audit series.**

### What this session did NOT do

The mission's own instruction ("prepare the smallest safe change that
makes it DEPRECATED/NON-DEPLOYABLE") assumed this was dead scaffold. The
evidence contradicts that premise: this is a working, deliberately-gated,
reasonably-secured feature someone built with real engineering care
(explicit permission model, ownership re-verification, bounded loop, no
sensitive logging). **Unilaterally disabling a working, gated feature
without knowing who depends on it would be a worse mistake than leaving
it as-is pending owner review.** No code change was prepared for
`ive-agent-runner` itself. See the final report's recommendation for the
one safe, additive, non-breaking hardening this session does recommend
(re-enabling gateway `verify_jwt`) — prepared as a documented command, not
executed.

## 2. Frozen agent's Cloud Run service — LIVE, traffic > 0, confirmed

No `gcloud` CLI is available in this session (`which gcloud` → not found),
and the frozen repo never recorded its live URL in cleartext (checked
`FINAL_VIDEO_COMMANDS.md`, `H1B_CLOUD_RUN.md`, `H1C2_PRODUCTION_ACCEPTANCE.md`
— all use a `$SERVICE_URL` variable or an `XXXXX` placeholder). Cloud Run
URLs are deterministically derived from service name + GCP project number
+ region, all of which were already on record from IVE-X1's audit
(`ive-strategic-execution-agent`, project number `221504834589`,
`europe-west2`). Constructing the URL from these already-public facts and
issuing a single GET to the documented, unauthenticated, side-effect-free
`/health` endpoint (never `/run`, which is mutable and requires auth):

```
GET https://ive-strategic-execution-agent-221504834589.europe-west2.run.app/health
→ 200 OK
{"status":"ok","service":"ive-strategic-execution-agent"}
```

**FACT: the service is live and serving traffic.** Per the mission's own
rule (section 6): traffic > 0 → **X4A = BLOCKED_PENDING_OWNER_ACTION** for
this sub-item. No traffic change was attempted or is possible from this
session (no `gcloud` access). See the final report for the exact change,
impact, and rollback the owner would need to review to scale this to zero.
