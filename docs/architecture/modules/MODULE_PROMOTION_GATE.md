# Module Lifecycle & Promotion Gate

Mission: `INSIGHTVALUES-MODULE-PORTFOLIO-ARCHITECTURE-01`
Status: DEFINED. Since MODULE-FOUNDATION-AND-ENTITLEMENT-02 the two hard
blockers and the entitlement invariants are **enforced by CI**
(`edge-function-tests.yml` job `entitlement-core-ci` + `flutter test`);
the remaining dimensions are enforced by mission review + Codex.
Gate owner: Agente Martins (technical) · Paulo (commercial promotion)

## 1. Lifecycle

```
EXPERIMENTAL → INTERNAL → ALPHA → BETA → RELEASE_CANDIDATE → COMMERCIAL → DEPRECATED
```

| State | Who can reach it | Registry today (`ModuleStatus` / flags) | Lives on |
|---|---|---|---|
| EXPERIMENTAL | developers only; may not compile into release | not registered, or `planned`/`inDevelopment`, `adminClickable: false` | Module Lab branch only |
| INTERNAL | admin (server: `ADMIN_ROLE`, audited) | derived for every unreleased module not planned/in development; `commercialEnabled: false` | Module Lab |
| ALPHA | admin + beta_tester role (on its own plan) | explicit `lifecycleOverride` | Module Lab |
| BETA | admin + beta_tester role (on its own plan) | explicit `lifecycleOverride` | Module Lab → may be synced to commercial dark |
| RELEASE_CANDIDATE | same as BETA, frozen scope | `beta` | commercial branch, flag-off |
| COMMERCIAL | plan-entitled users | `active`, `commercialEnabled: true` | commercial / main |
| DEPRECATED | nobody new; data retained | `disabled`, `commercialEnabled: false` | any |

The existing `ModuleStatus` enum maps onto this lifecycle without a code
change; the proposed `lifecycle` field (MODULE_ARCHITECTURE.md §9) would
make the mapping explicit. A module never skips a state, and never moves
to COMMERCIAL because it compiles.

## 2. Gate dimensions

Each dimension is PASS / N/A (with reason) / FAIL. "N/A" needs a written reason.

| # | Dimension | Minimum evidence |
|---|---|---|
| G1 | FUNCTIONAL | acceptance criteria met; physical Android run for mobile surfaces |
| G2 | SECURITY | RLS on every new table (disposable-DB test like `supabase/tests/entitlement_subject_roles_rls_test.sql`); every new EF classified in `module_policy.ts` and, if MODULE-kind, gated by `requireModuleAccess` (CI: MP-04/MP-06/GH-*); SSRF via `safe_fetch` for any outbound fetch; injection delimiter for user/web content in prompts; Codex adversarial review for CLASS D triggers |
| G3 | AUTOMATION | structured inputs/outputs documented; IVE can invoke it through `IveInteractionRequest`/`context-copilot`; any write path is AEF-compatible |
| G4 | MONETIZATION | who pays, target plan, usage unit, cost per unit, API dependency |
| G5 | IVE INTEGRATION | Ask-IVE entry points; context contribution; exclusion regions for any new floating UI |
| G6 | AEF COMPATIBILITY | write actions classified by risk; destructive/external actions require Human Gate; no direct execution path |
| G7 | OBSERVABILITY | diagnostic events namespaced; failures surface as `IveIssue`; quota events auditable |
| G8 | TESTS | unit + widget tests; EF Deno tests; no fixtures that expire against the wall clock; every new route classified (enforced by the source-derived test in `route_policy_test.dart`) |
| G9 | MOBILE | Android layout sweep (narrow widths, text-scale, back button) |
| G10 | WEB | builds for web; no platform-only API without fallback |
| G11 | ACCESSIBILITY | semantics labels, contrast, touch targets |
| G12 | PT/EN | all strings in both ARB files; LLM output language honored |
| G13 | COST | per-call AI cost, quota consumption, worst case per user/month |
| G14 | ROLLBACK | flag-off path proven; migrations reversible or additive-only; no data loss on disable; **production-data preflight** recorded for any migration that adds constraints/triggers (e.g. the project-ownership triggers can leave pre-existing mismatched rows readable but un-updatable) |

## 3. Gate per transition

| Transition | Required dimensions |
|---|---|
| EXPERIMENTAL → INTERNAL | G2 (for anything touching data), G8 baseline |
| INTERNAL → ALPHA | + G1, G14 |
| ALPHA → BETA | + G3, G5, G6, G7, G9, G12 |
| BETA → RELEASE_CANDIDATE | all G1–G14; Codex review PASS or PASS_WITH_FINDINGS with no P0/P1 |
| BETA → RELEASE_CANDIDATE (hard blocker, CI-enforced) | every Edge Function is classified (MP-04) and every MODULE-kind function calls `requireModuleAccess` after auth and before quota (MP-06 static + GH-* executed denial tests: 401/503/403 with zero quota RPC and zero outbound fetch); server manifest and Flutter registry agree (drift test); client and server satisfy the shared decision vectors; no CONSEQUENTIAL (class C) module at RC/COMMERCIAL while `AEF_PERSISTENCE_AVAILABLE = false` (MP-03) |
| RELEASE_CANDIDATE → COMMERCIAL | **P0 = 0 · P1 = 0 · Codex = PASS · security = PASS · entitlement defined (plan + usage unit) · telemetry defined · rollback proven** · Owner approval (Paulo) |
| any → DEPRECATED | data-retention decision, route removal plan, registry entry kept (never deleted — registry rule) |

## 4. Risk class shortcuts

| Risk class | Definition | Extra requirement |
|---|---|---|
| A | read-only, own data | none |
| B | writes own tenant data | G6 idempotency; audit of automated writes |
| C | external side effects (posting, payments, orders, emails), financial or reputational claims | Human Gate mandatory; AEF persistence (IV-AEF-PERSISTENCE-01) must exist first; CLASS D Codex review; legal review for Quant/Impact |

Social posting, Quant execution and Impact risk signals are all class C.
None can pass BETA → RELEASE_CANDIDATE until AEF has persistent Human Gate
records and receipts.

## 5. Sync rule between lines

- Commercial → Module Lab: merge at explicit sync points (after each
  commercial gate), never cherry-picked silently.
- Module Lab → Commercial: only a module at RELEASE_CANDIDATE, shipped with
  `commercialEnabled: false`, through a dedicated promotion mission.
- Core changes made in Module Lab (e.g. server-side entitlements) are
  themselves promoted as a Core capability through the same gate.
