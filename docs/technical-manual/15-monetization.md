# 15 — Monetization Architecture

Four layers must never be conflated: **implemented entitlement**, **commercial pricing**,
**billing infrastructure**, **production activation**.

## 1. Tiers

| Tier | DB value (`profiles.role`) | Implemented entitlement (E-MAIN) | Quota value | Commercial pricing | Billing path |
|---|---|---|---|---|---|
| Free | `free` | Default at signup; all commercial V1 modules (`minimumPlan: free`) | 5 AI units/month (DB default, webhook FREE limit) | UI copy "R$ 0" (`lib/l10n/*.arb` `planFreePrice`) | — |
| Pro | `pro` | `Profile.isPro`; `ModulePlan.pro` route gate (no Pro-only module is commercially enabled on E-MAIN) | **`CONFLICTING_EVIDENCE`**: 300 when set by `stripe-webhook` (`PRO_ROLE_LIMIT`), 100 when set by an admin (`AppConstants.planLimits`) | UI copy "R$ 29 / mês" (`planProPriceAmount`) — display string only; charged amount is whatever Stripe price `STRIPE_PRICE_ID_PRO` holds (`UNKNOWN`) | Stripe Checkout (TEST mode) |
| Premium | `premium` | `Profile.isPremium`; no `ModulePlan.premium` on E-MAIN (added on E-INT02, unused) | 1000 (admin-assigned only) | none | none (no Stripe product) |
| Beta | `beta_tester` | `Profile.isBetaTester`; no module uses it on E-MAIN | 50 (admin-assigned only) | none | none |
| Admin | `admin` | Bypasses route policy; admin RLS policies | 99999 (admin-assigned) | n/a | n/a |

Prices: this manual records UI copy only. No authoritative price list exists in code or config;
final pricing is an explicit Owner non-decision (E-INT02 `docs/commercial/MONETIZATION_ARCHITECTURE.md`).

## 2. Quota (server-enforced) vs commercial quota vs safety limits

| Limit | Kind | Where |
|---|---|---|
| Monthly AI units per user | Commercial quota, server-enforced | `try_reserve_ai_quota` reads `profiles.monthly_limit`; counter `ai_usage` per calendar month |
| Idempotent reservation | Safety (double-charge prevention) | `ai_quota_reservations` |
| Request envelope caps (message 4000, history 20, context 50 000 chars, grounding 8000) | Safety / cost | `context-copilot/index.ts` |
| File size caps (8 MB base64, 5 MB DOCX XML) | Safety | `process-file/index.ts` |
| Fetch caps (2 MB, 10 s, 3 redirects) | Safety | `_shared/safe_fetch.ts` |
| Per-endpoint rate limits | Safety | `NOT_IMPLEMENTED` on E-MAIN (Quant/Impact/AEF rate limits exist on E-INT02) |

## 3. Billing infrastructure

```mermaid
sequenceDiagram
  participant U as User (Upgrade screen)
  participant C as create-checkout-session
  participant S as Stripe (TEST)
  participant W as stripe-webhook
  participant DB as Postgres
  U->>C: invoke (user JWT)
  C->>DB: subscriptions upsert (service_role) if no customer
  C->>S: create Checkout Session (price = STRIPE_PRICE_ID_PRO)
  C-->>U: checkout URL (url_launcher)
  S->>W: event + Stripe-Signature
  W->>W: HMAC verify, dedupe processed_webhook_events
  W->>S: retrieve subscription (current state)
  W->>DB: apply_stripe_subscription_state (ordered by event.created)
  Note over DB: active/trialing → role=pro, limit 300; otherwise role=free, limit 5
  U->>U: app resume → re-read profile (+1 bounded re-check after 5 s)
```

| Layer | Status |
|---|---|
| Implemented entitlement (role → quota) | `IMPLEMENTED`, `TESTED` |
| Module entitlement enforced server-side | E-MAIN `NOT_IMPLEMENTED`; E-INT02 `IMPLEMENTED` (unmerged) |
| Billing code | `IMPLEMENTED`, `TESTED` (webhook 17, checkout 5, stripe helper 10 static tests) |
| Stripe mode | TEST mode (migration header, registry readiness note) |
| Production activation (live keys, live price) | `NOT_IMPLEMENTED` per E-INT02 docs ("Stripe live activation: not performed, HOLD"); live env state `UNKNOWN` |
| Real subscription lifecycle proof | "pending the owner's test credentials" (registry) → `UNKNOWN` |

## 4. Capabilities that support monetization

Quota ledger, role-based limits, Stripe webhook ordering/idempotency, route-level upsell
(`redirectUpgrade`), Upgrade/Account screens, paid-state refresh on app resume. Missing for
commercial scale: server-side module entitlements on `main`, live billing, invoices/tax, Premium
product, per-seat/enterprise model, usage analytics beyond `ai_usage`.
