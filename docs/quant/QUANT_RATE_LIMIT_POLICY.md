# InsightValues Quant — Rate Limit Policy (IV-QUANT-REAL-DATA-READINESS-03)

Technical protection per authenticated user — **not** a commercial quota.

## 1. Limits (fixed 60-second window)

| Bucket | Limit / min | Applies to |
|---|---|---|
| `quant-analyze` | 30 | every `quant-analyze` call (v1, multi.v1, watchlist.v1) |
| `quant-watchlists-read` | 120 | `list` |
| `quant-watchlists-write` | 60 | create / rename / delete / add_item / remove_item |

Source of truth: `quant_rate_limit_hit()` in migration
`20260924000100_quant_rate_limits.sql`; mirrored in
`_shared/quant/rate_limit_policy.ts` (`RATE_LIMITS`). Drift test QB-17
compares both. An unknown bucket is **denied**.

## 2. Enforcement

* Order: authenticate → entitlement → method → **rate limit** → body read
  (`quant-analyze`: before the up-to-6 MiB body is read) → work.
  `quant-watchlists` limits after parsing, because the bucket depends on the
  action.
* Identity: `auth.uid()` inside a SECURITY DEFINER function called with the
  caller's JWT. The user id is never taken from the body (RL-02).
* Counter table `quant_rate_limits`: RLS enabled, no policies, all
  privileges revoked from `anon`/`authenticated` — reachable only through the
  function. Atomic `INSERT … ON CONFLICT DO UPDATE` per (user, bucket, window).
* Concurrency: 50 simultaneous calls from 10 real Postgres sessions →
  exactly 30 allowed / 20 denied (evidence in the mission report); unit
  test RL-04 does 45 → 30/15 in process.

## 3. Responses

* Over the limit → `429 RATE_LIMITED`, `Retry-After: <seconds>`, body
  `{error, correlation_id, details: {limit, retry_after_seconds}}`.
* Counter store unavailable → `503 RATE_LIMIT_UNAVAILABLE` (**fails closed**,
  RL-03). Unauthenticated / non-entitled callers are rejected before the
  limiter is touched (RL-05).

## 4. Not covered (known limits)

* Fixed window allows up to 2× the limit across a window boundary. Accepted
  for INTERNAL; a sliding window is a promotion-time decision.
* Rows are not garbage-collected by a job yet (one row per user/bucket/minute;
  a cleanup job is required before any external exposure).
* The local dev server (`tool/quant_lab_dev_server.ts`) uses the in-memory
  limiter with the same numbers.
