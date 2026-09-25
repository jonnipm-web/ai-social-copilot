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
  `public.impact_rate_limit_hit(p_bucket, p_window_seconds)`:
  `SECURITY DEFINER`, `SET search_path = ''`, identity from `auth.uid()`
  only (never a parameter), bucket and window validated (10..3600 s).
- One statement: `INSERT … ON CONFLICT DO UPDATE SET hit_count = hit_count + 1
  RETURNING` — concurrent requests serialize on the row lock; no lost
  update (proved by `impact_rate_limit_race_test.sh` and EF-14: 12 parallel
  requests with limit 5 → exactly 5 admitted).
- Privileges: EXECUTE only for `authenticated` (revoked from PUBLIC, anon,
  service_role). Table: RLS on, SELECT own rows only; no INSERT/UPDATE/DELETE
  grant to anyone. SERVICE_ROLE_TRUST_GATE = LAB_ONLY is unchanged: the
  impact-lab function calls the RPC with the **caller's** session client.
- Housekeeping: each call deletes the caller's own windows older than 1 day.

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

`impact_rate_limit_test.sql` (R5-01..19: privileges, RLS, identity,
validation, windows, housekeeping), `impact_rate_limit_race_test.sh`,
`impact-lab/index_test.ts` EF-13 / EF-14. All in CI
(`disposable-db-rls-ci`, Edge Function Tests).

## Rollback (Lab)

`DROP FUNCTION public.impact_rate_limit_hit(text, integer); DROP TABLE public.impact_rate_limits;`
