# Monetization Architecture

**Mission:** INSIGHTVALUES-COMMERCIAL-MACRO-01. Tranche 1 (Section 17) documented the pre-existing model architecture-only, no pricing/Stripe changes. Tranche 2 executed two of that tranche's own flagged items under explicit Owner authorization: Growth Intelligence commercial launch, and the `ModulePlan.premium` entitlement gap closure. Billing integration itself (`create-checkout-session`, `stripe-webhook`) remains TEST MODE only and untouched by either tranche.

## What already exists (verified against current code, not assumed)

- **Entitlement model**: `ModulePlan` enum (`free` / `pro` / `premium`) on every `ModuleDefinition.minimumPlan`, enforced server-adjacent by `route_policy.dart`'s `decideForModule`/`evaluateRouteAccess`, wired into GoRouter's `redirect` — a route with `minimumPlan: pro` on a `free` user resolves to `redirectUpgrade`, not just a hidden nav item. This is a real gate, not a UI suggestion. (`ModulePlan.admin` existed in this tranche's own history but was removed during INSIGHTVALUES-INTEGRATION-MACRO-02's reconciliation with a newer `ModuleLifecycle`-based architecture that expresses admin-only access without a fake "plan" — see module_definition.dart. Codex INTEGRATION-MACRO-02 audit, P3-01.)
- **Quota model**: `AppConstants.planLimits` (`admin: 99999, premium: 1000, pro: 100, beta_tester: 50, free: 5`), mirrored at the profile layer by `Profile.isPremium`/`QuotaInfo.isPremium` (`role == 'premium'`), which already existed and already distinguished Premium from Pro for quota purposes before Tranche 2.
- **Billing**: real Stripe Checkout, TEST MODE only, single `PRO` product/price, `subscriptions` + `processed_webhook_events` tables, atomic webhook application (3 migrations hardening this). No live credentials used. **Untouched by either tranche.**

## Tranche 2: `ModulePlan.premium` gap closure

Tranche 1 flagged a gap between the quota model (4+ tiers, including `premium`) and the entitlement enum (3 values, no `premium`). On inspection, the gap was narrower than described: `Profile.isPremium`/`QuotaInfo.isPremium` already existed — only `ModulePlan` itself and the code paths that consult it (`ModuleDefinition.visibleFor`, `decideForModule`, `evaluateRouteAccess`, `visibleDrawerModules`) had no way to express or check a Premium-exclusive module. Closed by:

- Adding `ModulePlan.premium` to the enum (`module_definition.dart`).
- Threading an `isPremium` parameter (optional, defaults to `false` — no existing call site's behavior changes) through `visibleFor`, `decideForModule`, `evaluateRouteAccess`, and `visibleDrawerModules`.
- Wiring the real value from `Profile.isPremium` into the one production call site (`app.dart`'s route redirect and the drawer's visibility computation).
- Adding a `ModulePlan.premium` branch to `decideForModule`'s switch: same shape as `pro` (not-yet-premium is `redirectUpgrade`, an upsell target, never `redirectDenied`; unreleased still wins over any plan).

**No module in the registry uses `minimumPlan: premium` yet.** This closes the structural gap so a future Owner decision (e.g. gating Financial Intelligence once Quant licensing clears) requires zero further plumbing — it is a real, tested, functioning gate with no current behavioral effect, not a documentation promise.

## Tranche 2: Growth Intelligence commercial launch

Per explicit Owner authorization ("Growth Intelligence FAZ PARTE do produto comercial InsightValues"), `improve-post`, `personas`, `content-library`, `calendar`, `campaigns`, `performance`, and `roi-tracker` moved from `commercialEnabled: false` to `true`, standardized at `minimumPlan: ModulePlan.pro`. This supersedes the "deliberately left un-toggled" note from Tranche 1 below.

## Capability family → tier mapping (architecture, current state)

| Family | Free | Pro | Premium |
|---|---|---|---|
| Project & Knowledge (Projects, Knowledge Vault, file/Drive import) | Core, uncapped by plan (AI-quota capped) | — | — |
| IVE (Context Copilot, avatar, memory) | Core, AI-quota capped | — | — |
| Market & Opportunity Intelligence (Market Intelligence hub + 6 sub-modules, Opportunity Lab) | Core, AI-quota capped | — | — |
| Action Engine | Core | — | — |
| Growth Intelligence (Improve Post, Personas, Content, Calendar, Campaigns, Performance, ROI) | — | Launched commercially, Tranche 2 | — |
| Financial Intelligence (Quant) | — | — | `ModulePlan.premium` now exists to gate this; not yet used — natural home once licensing clears (`ive-quant`, currently `externalPlanned`) |
| Evidence/Impact Intelligence | — | — | Separate product line, not tier-gated the same way (own admin-only surface today) |

## INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §20-21: Premium differentiation beyond quota

Owner-authorized: "Premium has materially larger quota but no exclusive modules. This is insufficient as long-term product differentiation... define and implement safe Premium differentiation using EXISTING or newly integrated mature capability... Do NOT fabricate Premium-only value."

Rather than gate a whole module at `minimumPlan: premium` (still not done — see below, unchanged), this mission added a real, non-fabricated *attribute-level* differentiation on top of Result → Learning (§7-9, this mission): **governed-action memory retention**. Free/Pro's AEF-derived `business_memory` entries (`origin: 'system_derived'`, written only from a real terminal AEF receipt) get a provisional 90-day `expires_at`; Premium's never expire. This is a genuine difference in what the product remembers about a user's own governed actions over time — not a quota number, not an arbitrary lock on existing functionality (Free/Pro's learning is fully functional, just time-limited, the same category of tier differentiator as message/history retention in many SaaS products). Implementation: `supabase/functions/_shared/result_learning.ts`'s `expiresAtForPlan`/`RESULT_LEARNING_RETENTION_DAYS`; a plan-lookup failure fails closed to the *shortest* retention, never to Premium's "never expires" (tested, RL-10). The 90-day number is provisional — no Owner decision on the exact retention window exists yet, same as pricing itself; it is a one-constant change when one is made.

## Explicit non-decisions (Owner Gate, still standing)

- Final pricing: not set.
- Stripe live activation: not performed, HOLD per mission boundary.
- Actually gating a whole module at `minimumPlan: premium`: still not performed — the mechanism exists, no Owner decision has been made to use it on a real module yet. (The retention differentiation above is a different mechanism entirely — it does not use `minimumPlan`.)
- The exact 90-day Free/Pro retention window (`RESULT_LEARNING_RETENTION_DAYS`): provisional, not an Owner-confirmed number.
- Quant/broker/market-data licensing: unchanged, still blocked — see the Financial Intelligence section of the Tranche 2 final report, and this mission's own `docs/commercial/STRATEGY001_SOURCE_FINDING.md`.

## INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §45-46: Strategy Builder tier architecture (candidate, no pricing)

Owner brief §45 asked for candidate Free/Pro/Premium capability differentiation for the new Strategy Builder ("Robot Builder"), built around *capability, not promises of profit* (§45: "Do NOT promise profitability"). Nothing below is priced or activated — `strategy-builder` stays `EXPERIMENTAL`/admin-only (module_policy.ts), same posture as `ive-quant`. This is architecture-readiness, not a live tier gate.

| Capability | Free (candidate) | Pro (candidate) | Premium (candidate) |
|---|---|---|---|
| Strategy Specifications | Limited count | More strategies | Higher limits |
| Validation (`strategy_spec.ts`) | Full — safety controls are never paywalled (§36: risk constraints "must never be weakened because of subscription tier") | Same | Same |
| Backtest/dataset breadth | Limited datasets/history | Broader datasets | Largest available history |
| Strategy versioning & comparison | Basic (this macro's foundation) | Version comparison at scale | Advanced robustness/comparison tooling (§30, §22 — not yet built) |
| Result → Learning retention for strategy backtests | Same 90-day provisional default as §20-21 above | Same | Same "never expires" pattern as §20-21 above |
| Governed automation (future, once Owner-authorized) | — | — | "when mature" per §45 — no implementation exists yet |

**Cost control (§46):** the real variable-cost surfaces this macro actually built (Strategy Specification validation, spec/version storage) are all pure, in-process, and cheap — no external compute, no LLM call, no market-data fetch in the `strategy-builder` Edge Function itself. `strategies`/`strategy_versions`/`strategy_backtest_results` are size-bounded by ordinary Postgres row limits and RLS-scoped per user; no unbounded-compute surface (a full backtest engine invocation) has been wired to any user-triggered endpoint this macro, so the "prevent obviously unbounded compute" requirement has nothing new to bound yet. This is a candidate table for future Owner tier decisions, not a commitment.
