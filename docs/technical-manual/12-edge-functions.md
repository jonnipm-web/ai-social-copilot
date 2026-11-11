# 12 — Edge Functions

Baseline E-MAIN, `supabase/functions/` — **20 functions** + `_shared/`. Static facts below were
`VERIFIED` by script on 2026-09-28 at `ff8ef34` (grep for `resolveAuthenticatedUser`,
`reserveQuota(`, `api.groq.com`, `safeFetch(`, `Deno.test(`, allowlist membership).

Common properties of the 16 AI functions: `verify_jwt=true` + `resolveAuthenticatedUser()`
before any work → body validation → `reserveQuota(req, …, idempotency_key, '<own name>')` →
Groq `openai/gpt-oss-120b` → `refundQuota` on provider failure. **They do not write to the
database**; the Flutter client persists results under RLS. CORS `Access-Control-Allow-Origin: *`.

## 1. Inventory

| Function | Purpose / module | Auth | Quota | External deps | Persistence | Tests (static) | Deploy allowlist | Deployment evidence |
|---|---|---|---|---|---|---|---|---|
| `context-copilot` | IVE chat (Context Copilot) | JWT + real user | yes | Groq | none | 47 | yes | `HISTORICAL_EVIDENCE_ONLY` (mission reports) |
| `analyze-website` | Website Analyzer | JWT + user | yes | Groq, `safeFetch` (user URL) | none | 5 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `extract-knowledge` | Knowledge analysis / URL extraction | JWT + user | yes | Groq, `safeFetch` ×3 | none | 5 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `process-file` | File text extraction (txt/pdf/docx) | JWT + user | no (no AI) | none | none | 10 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `generate-strategy` | Knowledge → strategy | JWT + user | yes | Groq | none | 5 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `improve-post` | Growth: improve post | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `generate-campaign` | Growth: campaigns | JWT + user | yes | Groq | none | 5 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `market-analysis` | Market Intelligence hub | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `competitor-discovery` | MI sub-module | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `gap-analysis` | MI sub-module | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `niche-discovery` | MI sub-module | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `opportunity-discovery` | MI sub-module | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `content-cluster` | MI sub-module | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `revenue-planner` | MI sub-module / bootstrap | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `generate-project-opportunities` | Opportunity Lab / bootstrap | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `generate-project-actions` | Action Engine / bootstrap | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `decision-simulator` | Decision simulation (no UI on E-MAIN; admin-plan registry entry) | JWT + user | yes | Groq | none | 0 | yes | `HISTORICAL_EVIDENCE_ONLY` |
| `create-checkout-session` | Billing: Stripe Checkout (TEST) | JWT + user | no | Stripe API | `subscriptions` upsert (service_role) | 5 | yes | Registry: "implemented and deployed" (TEST) — `HISTORICAL_EVIDENCE_ONLY` |
| `stripe-webhook` | Billing: webhook | **no JWT** (reviewed exception); manual HMAC-SHA256 `Stripe-Signature` check before parsing | no | Stripe API (retrieve subscription) | `processed_webhook_events`, `subscriptions`, `profiles` via `apply_stripe_subscription_state` (service_role) | 17 | yes, `--no-verify-jwt` | `HISTORICAL_EVIDENCE_ONLY` |
| `ive-agent-runner` | Retired stub: always `410 Gone` after auth | `verify_jwt=true` (per report) + inlined user check | no | none | none | 0 | **hard-blocked** | `DEPLOYED` version 6 on 2026-09-17 per `docs/ive/SR04_SR05_CLOSURE.md` (`HISTORICAL_EVIDENCE_ONLY`) |

Unmerged functions (E-INT02 only): `module-access`, `ive-intelligence`, `ive-memory`,
`quant-analyze`, `quant-watchlists`, `impact-lab`, `aef-runtime` (hard-blocked from deploy).

## 2. Shared modules (`supabase/functions/_shared/`)

| Module | Role | Tests (static) |
|---|---|---|
| `auth.ts` | `resolveAuthenticatedUser()`, `unauthorizedResponse()` | 11 |
| `quota.ts` | `reserveQuota()` / `refundQuota()` / `quotaBlockedResponse()`; idempotency key must be UUID; `operationType` is a server literal, never client-supplied; replays never refund; structured stdout audit events (ids/enums only) | 25 (+9 real-DB) |
| `safe_fetch.ts` | SSRF guard: http/https only; blocks loopback, RFC1918, CGNAT, link-local/metadata, IPv6 ULA/link-local, IPv4-mapped/NAT64, multicast/reserved; re-validates each redirect (max 3); DNS resolution check; 10 s timeout; 2 MB cap. Residual: DNS-rebinding window (documented in file header). | 31 |
| `stripe.ts` | Stripe REST calls + signature verification | 10 |
| `service_client.ts` | `createServiceClient()` with `SUPABASE_SERVICE_ROLE_KEY` (billing only) | — |
| `language.ts` | Language helpers | 6 |
| `project_ownership_realdb_test.ts` | Real-DB ownership tests (need a database) | 14 |

## 3. Environment variable names (values never documented)

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `GROQ_API_KEY`,
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID_PRO`, `APP_CHECKOUT_SUCCESS_URL`,
`APP_CHECKOUT_CANCEL_URL`, `DENO_TESTING` (test switch).
`create-checkout-session` falls back to a hardcoded GitHub Pages URL when the success/cancel
URLs are unset.

## 4. Deployment rule

Deployment is via `.github/workflows/deploy-edge-functions.yml` only (manual, one function per
run, `confirm=DEPLOY`, allowlist + governance gate). Source existence ≠ deployment. No
automated record maps a deployed function version to a git SHA
(`docs/ive/OUT_OF_BAND_DEPLOYMENT_THREAT_MODEL.md` §2). See [19](19-environments-deployment.md).
