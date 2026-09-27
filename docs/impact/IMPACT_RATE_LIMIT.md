# Impact — Dossier Rate Limit (IV-IMPACT-I5, closes Codex I4G3-04)

**Status: EXPERIMENTAL, Lab only. Migration `20260928010000_impact_product_rate_limit.sql`
is NOT applied to production.**

## What is limited

| Bucket | Actions | Default |
|---|---|---|
| `dossier_build` | `get_dossier` | 30 / 60 s per caller |
| `dossier_export` | `export_dossier` | 10 / 60 s per caller |
| `dossier_verify` | `verify_dossier` | 30 / 60 s per caller |

Overridable (Lab) with `IMPACT_RL_DOSSIER_{BUILD|EXPORT|VERIFY}_PER_MIN`
(1..1000; anything else → default). Other actions are not rate limited by
this mechanism (they keep the I1–I4 size/count limits).

## Why server-side and atomic

- The counter lives in `public.impact_rate_limits` (PK
  `user_id, bucket, window_start`), written **only** by
  `public.impact_rate_limit_hit(p_bucket)`: `SECURITY DEFINER`,
  `SET search_path = ''`, identity from `auth.uid()` only (never a
  parameter), bucket validated. The **window is fixed at 60 s inside the
  function** — never a caller argument (Codex I5G2-01: a caller-chosen window
  let a direct RPC caller create unbounded rows).
- One statement: `INSERT … ON CONFLICT DO UPDATE SET hit_count = hit_count + 1
  RETURNING` — concurrent requests serialize on the row lock; no lost
  update (proved by `impact_rate_limit_race_test.sh` and EF-14: 12 parallel
  requests with limit 5 → exactly 5 admitted).
- Privileges: EXECUTE only for `authenticated` (revoked from PUBLIC, anon,
  service_role). Table: RLS on, SELECT own rows only; no INSERT/UPDATE/DELETE
  grant to anyone. SERVICE_ROLE_TRUST_GATE = LAB_ONLY is unchanged: the
  impact-lab function calls the RPC with the **caller's** session client.
- Bounded growth: each call deletes **all** of the caller's past windows, so
  a caller holds at most one row per bucket (3 rows) however it calls the RPC
  (R5-20..22). Rows of callers who stop calling stay bounded at 3 each and go
  with the user (FK `ON DELETE CASCADE`).
- Schema-drift guard (Codex I5G2-03): if `impact_rate_limits` already exists
  with another column set or primary key, the migration stops with
  `IMPACT_RATE_LIMIT_SCHEMA_DRIFT` (tested by the CI runner).
- Calling the RPC directly gains nothing: it only increments the caller's
  own counter; the limit itself is enforced by impact-lab.

## Where it runs in impact-lab

After authentication, admin entitlement and request parsing — **before**
the store and the ownership check. Consequences:

- No cross-user oracle: a foreign id and a missing id both consume the
  caller's own budget and both answer 404 (EF-13); a 429 carries nothing
  about any investigation.
- Buckets are per caller; one user cannot exhaust another's budget.
- Fail closed: if the limiter errors, the request is refused with
  500 `INTERNAL_ERROR` (never admitted unlimited).

## Response

`429 {ok:false, error:"RATE_LIMITED", message, retry_after, correlation_id}`
plus `Retry-After: <seconds>` (seconds until the fixed window ends). The UI
shows "try again in N s" and never retries automatically.

## Tests

`impact_rate_limit_test.sql` (R5-01..23: privileges, RLS, identity,
validation, fixed window, bounded growth, single signature),
`impact_rate_limit_race_test.sh`, the drift guard in
`scripts/ci/run_disposable_db_tests.sh`, `impact-lab/index_test.ts`
EF-13 / EF-14. All in CI (`disposable-db-rls-ci`, Edge Function Tests).

## Rollback (Lab only)

The counters are disposable (no other object references them; losing them
only resets budgets). On a Lab database, after confirming the target is not
production:
`DROP FUNCTION IF EXISTS public.impact_rate_limit_hit(text); DROP TABLE IF EXISTS public.impact_rate_limits;`
