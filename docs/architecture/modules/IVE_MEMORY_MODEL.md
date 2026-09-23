# IVE Memory Model

Mission: `IVE-INTELLIGENCE-CORE-01` · policy `supabase/functions/_shared/ive/memory_policy.ts` ·
write path `ive-memory` · storage `public.business_memory` (migration `20260924000000`, Module Lab, not applied).

## 1. Levels (only what the architecture justifies — no new table)

| Level | Where | Written by | Read by |
|---|---|---|---|
| SESSION | visible chat transcript (client memory, `(screen, project)` key) | never persisted by the core | sent back as `conversation`, enveloped as untrusted data, budget-trimmed |
| PROJECT | `business_memory`, `scope = 'project'`, `project_id` owned | promote path | core, for that project only |
| USER | `business_memory`, `scope = 'user'`, `project_id` null | promote path | core, for every project of the owner |

Transcript ≠ durable memory: a chat message never becomes memory
automatically. The core returns **candidates** (only explicit statements:
"lembre que…", "nossa meta é…", "decidimos…", "prefiro…", "não podemos…"
and EN equivalents); persistence requires the explicit `promote` call, which
re-runs the policy server-side.

The device-local IVE memory (SharedPreferences) is now bound to its owner
and wiped on sign-out/user change; it is not sent by the core path.

## 2. What may be persisted

Categories: `preference`, `decision`, `goal`, `constraint`,
`context_summary`. Size 12–500 chars. Rejected: anything matching secret
patterns (labelled credentials, JWT, provider keys, bearer values, card-like
digit runs, unlabeled high-entropy tokens), checked on the raw and the
canonical (NFKC, invisible-stripped, homoglyph-folded) text.

## 3. Provenance and scope columns

`scope`, `origin` (`user_authored | ive_derived | system_derived |
external_agent_derived`), `status` (`active | superseded | expired`),
`dedup_key`, `superseded_by`, `updated_at`, `expires_at`, plus existing
`user_id`, `project_id`, `memory_type`, `source`, `created_at`. No
"confidence" is invented for new memories.

## 4. Authority

| Writer | Origin | How |
|---|---|---|
| IVE core (promote) | `ive_derived` | user JWT, policy + ownership checked server-side |
| user / app | `user_authored` | user JWT (default) |
| external agent (legacy writer) | backfilled `external_agent_derived`; new rows default `user_authored` (debt) | user JWT |
| operators / system jobs | `system_derived` | service_role only (RLS forbids it for authenticated) |

Origin is provenance, not privilege: every memory is injected as untrusted
data and cannot grant a capability, plan or role.

RLS: select/delete own; insert/update own **and** project_id null or owned
(fixes IVE-F06); anon none. Tests: `supabase/tests/ive_memory_rls_test.sql`
(owner, non-owner, anon, cross-user, cross-project, re-point, system origin,
dedup, size), mutation-checked.

## 5. Consolidation

- Dedup: `sha256(category|scope|project|normalized text)`; one ACTIVE row
  per key per user (unique partial index) — concurrent promotes resolve to
  `DEDUPLICATED`.
- Supersession: `promote` with `supersedes_id` (same owner, same scope and
  project) marks the old row `superseded`; reported only if exactly one row
  changed.
- Expiry: `forget` sets `status = expired` (soft, auditable); rows with a
  past `expires_at` are never read.
- Reads: active only, newest first, ≤ 10 items, ≤ 1500 chars.

## 6. Rollout / rollback

Migration before deploying the core (the memory read selects the new
columns; if missing, memory degrades — never leaks). Rollback: drop the four
new policies and recreate `business_memory_user`; columns/index/trigger may
stay (additive). Legacy upgrade proven on dirty data
(`ive_memory_legacy_upgrade_test.sql`).
