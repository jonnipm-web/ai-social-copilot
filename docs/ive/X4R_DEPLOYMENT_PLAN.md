# IVE-X4R Deployment Plan — P0 (migration 022) and X4C (SSRF)

**STOP FOR OWNER APPROVAL.** Nothing in this document has been executed
against production. Every command below is prepared, reviewed, and
ready — none has been run.

## P0 — migration 022

**Target project:** `nzngvbajrnruknpzzjbf` (production).
**Migration to apply:** `supabase/migrations/022_x4b_search_path_and_role_protection.sql`
at commit `1bf8970` (the X4R-corrected version — NOT the original X4
version at `52d9884`, which had the INSERT-bypass gap).
**Apply only this migration.** No later migration exists in this branch
beyond it; do not apply anything from `main` that postdates 022 without
separate review.

### Expected schema/object changes

- `public.is_admin_user()` — body unchanged, `SET search_path = 'public'` added.
- `public.handle_new_user()` — body unchanged, `SET search_path = 'public'` added.
- `public.set_updated_at()` — body unchanged, `SET search_path = 'public'` added.
- `public.update_project_events_updated_at()` — body unchanged, `SET search_path = 'public'` added.
- `public.update_executive_contexts_updated_at()` — body unchanged, `SET search_path = 'public'` added.
- **New function:** `public.prevent_self_privilege_escalation()` — `SECURITY INVOKER`, `SET search_path = 'public'`.
- **New trigger:** `trg_prevent_self_privilege_escalation` on `public.profiles`, `BEFORE INSERT OR UPDATE FOR EACH ROW`.
- No table, column, index, RLS policy, or grant is created, dropped, or altered.

### Preflight (read-only, safe to run any time before applying)

```sql
-- 1. Confirm the trigger does not already exist (idempotency safety).
SELECT tgname FROM pg_trigger
WHERE tgrelid = 'public.profiles'::regclass AND NOT tgisinternal;
-- expected: 0 rows

-- 2. Snapshot current function bodies, to diff against postflight.
SELECT proname, pg_get_functiondef(oid) FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('is_admin_user','handle_new_user','set_updated_at',
                   'update_project_events_updated_at',
                   'update_executive_contexts_updated_at');

-- 3. Snapshot current admin count and profile row count as a baseline.
SELECT count(*) FILTER (WHERE role = 'admin') AS admin_count, count(*) AS total
FROM public.profiles;
```

### Apply (requires explicit owner authorization — not run by this session)

```
supabase db push --project-ref nzngvbajrnruknpzzjbf
```
(or the equivalent single-migration apply mechanism the owner prefers —
this session has no `supabase` CLI available locally to even test the
command syntax; verify before running).

### Postflight (read-only, run immediately after applying)

```sql
-- 1. Confirm the trigger exists with the correct timing/events.
SELECT tgname, tgtype, pg_get_triggerdef(oid) FROM pg_trigger
WHERE tgrelid = 'public.profiles'::regclass AND NOT tgisinternal;
-- expected: trg_prevent_self_privilege_escalation, BEFORE INSERT OR UPDATE

-- 2. Confirm the trigger function is SECURITY INVOKER, not DEFINER.
SELECT proname, prosecdef FROM pg_proc
WHERE pronamespace='public'::regnamespace AND proname='prevent_self_privilege_escalation';
-- expected: prosecdef = false

-- 3. Confirm search_path is now set on all 5 hardened functions.
SELECT proname, proconfig FROM pg_proc
WHERE pronamespace='public'::regnamespace
  AND proname IN ('is_admin_user','handle_new_user','set_updated_at',
                   'update_project_events_updated_at',
                   'update_executive_contexts_updated_at');
-- expected: proconfig contains 'search_path=public' for all 5

-- 4. Confirm no RLS policy changed (diff against the X4 snapshot).
SELECT policyname, cmd, qual, with_check FROM pg_policies
WHERE schemaname='public' AND tablename='profiles';
-- expected: identical to the X4/X4R audit findings -- 2 policies,
-- admin_all_profiles and users_own_profile, both unchanged.

-- 5. Confirm the admin count and total profile row count are unchanged.
SELECT count(*) FILTER (WHERE role = 'admin') AS admin_count, count(*) AS total
FROM public.profiles;
-- expected: identical to the preflight snapshot -- this migration must
-- not itself change any row's data.
```

### Read-only production verification of the fix (no mutation)

Do not attempt to self-promote using a real account. Instead:

```sql
-- Confirm the trigger is genuinely attached and would fire -- inspect its
-- definition text directly rather than exercising it.
SELECT pg_get_triggerdef(oid) FROM pg_trigger
WHERE tgname = 'trg_prevent_self_privilege_escalation';
```

If the owner has an explicitly authorized, isolated test account safe to
mutate, `x4b_authorization_tests.sql`'s test 4 (the self-promotion
attempt) can be proposed as a separate, narrowly-scoped follow-up — not
run by this session.

### Rollback

```sql
DROP TRIGGER IF EXISTS trg_prevent_self_privilege_escalation ON public.profiles;
DROP FUNCTION IF EXISTS public.prevent_self_privilege_escalation();
```
The 5 `search_path`-hardened functions are behavior-identical to their
pre-migration bodies; no rollback path is expected to be needed for
those specifically.

---

## X4C — analyze-website + extract-knowledge

**Only these two functions.** `ive-agent-runner` is explicitly excluded
per this mission's instruction (section 17) — not touched, not
redeployed, not altered in any way.

| Function | Current production version | verify_jwt | Source to deploy from |
|---|---|---|---|
| `analyze-website` | 2 | false (unchanged by this fix) | `claude/ive-x4-security-boundary-closure` @ `615b2eb` |
| `extract-knowledge` | 9 | false (unchanged by this fix) | `claude/ive-x4-security-boundary-closure` @ `615b2eb` |

This fix does not change either function's `verify_jwt` setting —
out of scope for X4C, unrelated to the SSRF fix.

### Config/secrets required

None new. Both functions already read only `GROQ_API_KEY` (unchanged).
`supabase/functions/_shared/safe_fetch.ts` has no environment/secret
dependency of its own.

### Could this deploy alter unrelated configuration?

Not if deployed via `supabase functions deploy <name>` for exactly
these two function names — that command does not touch any other
function's configuration. Do **not** use a bulk/all-functions deploy
command.

### Commands (requires explicit owner authorization — not run by this session)

```
supabase functions deploy analyze-website --project-ref nzngvbajrnruknpzzjbf
supabase functions deploy extract-knowledge --project-ref nzngvbajrnruknpzzjbf
```

### Rollback

```
git checkout 7795421 -- supabase/functions/analyze-website/index.ts supabase/functions/extract-knowledge/index.ts
supabase functions deploy analyze-website --project-ref nzngvbajrnruknpzzjbf
supabase functions deploy extract-knowledge --project-ref nzngvbajrnruknpzzjbf
```
(redeploys the exact pre-X4C code, dropping the `safe_fetch` import —
no schema/data involved, fully reversible).

### Post-deploy smoke tests (once authorized)

Permitted: a known-public benign URL (e.g. a stable, innocuous public
page) through each function's normal request shape, and an obviously
malformed URL (e.g. `not-a-url`) to confirm it's rejected before any
connection attempt. **Not permitted:** a real attempt against
`169.254.169.254`, `localhost`, or any internal/private target — rely on
the 31 automated tests for that coverage, per this mission's explicit
instruction.

Verify: the legitimate URL still returns real analysis (function is
still operational, not over-blocked — this is exactly what section 14
warns against); the unsafe-URL error message is the generic one (`"URL
não permitida..."`), not one that echoes back internal validation
reasoning; function logs show no secret material.
