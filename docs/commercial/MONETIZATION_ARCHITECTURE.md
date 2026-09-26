# Monetization Architecture

**Mission:** INSIGHTVALUES-COMMERCIAL-MACRO-01 (Section 17). Architecture only — no final pricing, no Stripe changes. Billing integration itself (`create-checkout-session`, `stripe-webhook`) already exists in TEST MODE from a prior mission and is untouched here.

## What already exists (verified against current code, not assumed)

- **Entitlement model**: `ModulePlan` enum (`free` / `pro` / `admin`) on every `ModuleDefinition.minimumPlan`, enforced server-adjacent by `route_policy.dart`'s `decideForModule`/`evaluateRouteAccess`, wired into GoRouter's `redirect` — a route with `minimumPlan: pro` on a `free` user resolves to `redirectUpgrade`, not just a hidden nav item. This is a real gate, not a UI suggestion.
- **Quota model**: `AppConstants.planLimits` (`admin: 99999, premium: 1000, pro: 100, beta_tester: 50, free: 5`) — note `premium` already exists as a distinct tier constant in code, even though no `ModulePlan.premium` enum value exists yet (only `free`/`pro`/`admin`). This is a real gap between the quota model (4+ tiers) and the entitlement model (3 tiers) — flagged here, not resolved, since introducing a new `ModulePlan.premium` value would touch every `route_policy.dart` call site and is exactly the kind of change that deserves its own scoped pass, not a silent addition inside a larger macro mission.
- **Billing**: real Stripe Checkout, TEST MODE only, single `PRO` product/price, `subscriptions` + `processed_webhook_events` tables, atomic webhook application (3 migrations hardening this). No live credentials used. **Untouched by this mission.**

## Capability family → tier mapping (architecture, not final pricing)

| Family | Free | Pro | Premium (quota constant exists, no enum yet) |
|---|---|---|---|
| Project & Knowledge (Projects, Knowledge Vault, file/Drive import) | Core, uncapped by plan (AI-quota capped) | — | — |
| IVE (Context Copilot, avatar, memory) | Core, AI-quota capped | — | — |
| Market & Opportunity Intelligence (Market Intelligence hub + 6 sub-modules, Opportunity Lab) | Core, AI-quota capped | — | — |
| Action Engine | Core | — | — |
| Growth Intelligence (Improve Post, Personas, Content, Calendar, Campaigns, Performance, ROI) | — (currently hidden from all tiers, `commercialEnabled: false`; see note below) | Natural home once launched | — |
| Financial Intelligence (Quant) | — | — | Natural home once licensing clears (`ive-quant`, currently `externalPlanned`) |
| Evidence/Impact Intelligence | — | — | Separate product line, not tier-gated the same way (own admin-only surface today) |

**Growth Intelligence is deliberately left un-toggled by this mission.** The module registry already carries an explicit note from a prior mission that hiding these (previously Pro-visible) was itself a deliberate change pending Owner review — flipping `commercialEnabled` for a revenue-facing capability family is a monetization decision with real business consequences, not a pure architecture task, so it stays exactly as the prior mission left it. The architecture (entitlement gate, quota system) is already fully ready to enable this the moment the Owner decides — no code change would be required beyond flipping the flag.

## What this mission adds (architecture only)

Nothing new was built into the billing/entitlement code paths — the existing `ModulePlan`/`route_policy.dart`/quota system already provides a coherent foundation for tiered commercial enforcement, confirmed by direct re-inspection this mission. The gap worth flagging for a future scoped mission: reconcile the quota system's 4-tier constant set (`admin`/`premium`/`pro`/`beta_tester`/`free`) with the entitlement enum's 3 values (`free`/`pro`/`admin`) before any real Premium-tier feature is gated on `minimumPlan` — today a "Premium" capability would have nothing to check against in `ModulePlan`.

## Explicit non-decisions (Owner Gate, per mission Section 17/28)

- Final pricing: not set.
- Stripe live activation: not performed, HOLD per mission boundary.
- `ModulePlan.premium` enum introduction: not performed (scoping note above).
- Growth Intelligence commercial enablement: not performed (Owner's own prior deferral preserved).
