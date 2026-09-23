# InsightValues Quant — Roadmap (evidence-based, after Foundation)

The order below follows what the Foundation audit actually found; it is a
proposal for Agente Martins / Paulo, not a commitment.

## 1. Phases

| Phase | Scope | Depends on | Risk class |
|---|---|---|---|
| **Q0 Foundation** (this mission) | deterministic engine, contracts, CSV validation, provenance/freshness, partial risk, manual portfolio, IVE contract, tripwires | — | A (library) |
| **Q1 Data plane + first API** | module-split decision (§3); first entitlement-gated Quant Edge Function (analyze a validated CSV / fixture server-side); watchlist persistence + RLS; exchange calendar (sessions/holidays) for freshness and gaps; market-data vendor **audit** (license, delay terms, cost) — no purchase without owner | §3 decision; owner approval for any paid vendor | B/D (new EF = CLASS D review) |
| **Q2 Analytics + Lab surface** | multi-instrument comparison, period selection, minimal admin-only Lab screen (dataset import, period, metrics, risk summary, provenance) — no BUY/SELL/EXECUTE/CONNECT BROKER | Q1 | B |
| **Q3 Portfolio intelligence** | persisted manual portfolios (RLS, project-scoped option), FX conversion with FX provenance (source, rate, timestamp) | Q1 | B/D |
| **Q4 Risk intelligence** | portfolio volatility (explicit rebalancing model), historical VaR/CVaR, beta vs explicit benchmark, stress scenarios | Q3 | B |
| **Q5 Research / fundamentals** | fundamentals contract with point-in-time `filingDate`; statements/reports via Knowledge as untrusted evidence | Q1, Knowledge | B/D |
| **Q6 IVE Quant** | implement `QuantNarrator` on IVE Intelligence Core; grounding guard mandatory | IVE-INTELLIGENCE-CORE-01 PASS + integration gate | D (LLM boundary) |
| **Q7 Backtesting** | research/backtest tiers only; look-ahead, survivorship, costs, slippage, corporate actions, snooping controls | Q1 data quality, Q5 point-in-time | B |
| **Q8 Alerts / monitoring** | threshold/freshness alerts (informational only) | Q1 data plane, scheduler | B |
| **Q9 Broker read-only** | account/positions import via OAuth; read scopes only | legal review, CLASS D, credential vault design | D/E |
| **Q10 Controlled execution** | Action Intent → AEF → risk policy → Human Gate → broker adapter → receipt → reconciliation | AEF persistence (IV-AEF-PERSISTENCE-01), regulatory analysis, explicit owner authorization | C/E |

Observation: Q6 can run in parallel with Q2–Q4 once IVE Core passes,
because the explanation contract already exists; it does not need Q1.

## 2. Recommended next gate

**IV-QUANT-DATA-PLANE-AND-API-02** — Q1 above, preceded by the §3 decision.
Exit criteria: one Quant Edge Function behind `requireModuleAccess`, CLASS D
Codex review, CSV → analysis end-to-end on the server, watchlist table with
RLS + disposable-DB tests, calendar-aware freshness, vendor audit report
(no purchase).

## 3. RESOLVED (Owner + Agente Martins: Option A) — analytics vs execution module

```
CURRENT STATE: one server module 'ive-quant' = EXPERIMENTAL / CONSEQUENTIAL.
  MP-09 forbids any Edge Function for a CONSEQUENTIAL module while AEF
  persistence is unavailable, so no read-only Quant API can exist today.
PROBLEM: read-only analytics (class A) and real-money execution (class C)
  share one module id, so the class-C restriction blocks harmless analytics,
  and a future lowering of 'ive-quant' to READ_ONLY would silently
  un-protect execution.
OPTIONS:
  A. Split: new 'quant-analytics' (READ_ONLY, EXPERIMENTAL → later
     ALPHA/BETA) for analysis/watchlists/portfolios; 'ive-quant' stays
     CONSEQUENTIAL for anything that could ever execute (remains blocked).
  B. Keep one module, wait for AEF persistence before any Quant API.
  C. Lower 'ive-quant' to READ_ONLY now (NOT recommended: removes the
     class-C tripwire from the module that will own execution).
RECOMMENDATION: A.
RISKS: registry/drift-test/entitlement updates on both sides; must keep
  MP-03/MP-09 invariants and QB-10..12 (retargeted) green.
COST/IMPACT: small code change; no infra, no recurring cost.
```

Decision authority: Agente Martins + Paulo. Not implemented in Q0.

## 4. Monetization architecture (hypothesis — no prices, no tiers activated)

| Tier | Candidate capability | Enforcement point |
|---|---|---|
| Free | watchlist, delayed/EOD data, basic returns/volatility on user CSV | `requireModuleAccess('quant-analytics')`, quota |
| Pro | multi-series comparison, manual portfolio analytics, correlation, drawdown history | plan rank `pro` |
| Premium | risk intelligence (VaR/CVaR/beta/scenarios), research/fundamentals, IVE Quant narratives | plan rank `premium` + quota for LLM |
| Enterprise / API | programmatic access, org workspaces | needs Enterprise tenancy (MODULE_PORTFOLIO V5) |
| Quant-specific entitlement | a separately purchasable vertical (`SEPARATE_PRODUCT` recommendation in the registry) | would need a product/entitlement dimension beyond plan — architectural decision |

Constraints: market-data licensing may forbid redistribution of real-time
data on lower tiers; real-time data cost is the main recurring cost driver.
Billing is untouched by this mission.

## 5. Three pillars (Foundation assessment)

| Pillar | Status | Evidence |
|---|---|---|
| Automation | PARTIAL | ingestion (CSV/fixture), normalization, calculation, structured results and safe log events are automatable and deterministic; no scheduler, alerts or live ingestion yet |
| Monetization | PARTIAL | entitlement hook exists (`ive-quant` admin-only), tier matrix drafted; no tier activated, no API to meter |
| Security | PASS (Foundation scope) | no surface, tripwires, entitlement deny, AEF deny, no secrets, allowlisted logs, untrusted-content boundary |

## 6. Re-evaluation after IV-QUANT-DATA-PLANE-AND-API-02

| Phase | Status | Evidence / next need |
|---|---|---|
| Q0 Foundation | **PASS** (closed in mission 02) | remote CI green, Codex recheck 0 P0/P1 |
| Q1 Data plane / API | **DONE (Lab)** except a real provider | quant-analyze, quant-watchlists, RLS, calendars; real vendor blocked on licence answers (QUANT_VENDOR_ASSESSMENT §4) |
| Q2 Analytics + Lab | **Lab surface done** (admin-only); multi-instrument comparison not started | next: comparison + correlation over several uploaded series |
| Q3 Portfolio intelligence | not started — do **not** start before Q1 provider + FX provenance | engine functions exist (Foundation) |
| Q4 Risk | not started | needs Q3 |
| Q5 Fundamentals | not started | vendor decision |
| Q6 IVE Quant | contract only | IVE-INTELLIGENCE-CORE PASS + integration gate; resolve CXR-01 residual there |
| Q7 Backtesting | not started | point-in-time data (Sharadar-class) |
| Q8 Alerts | not started | needs provider + scheduler + rate limits |
| Q9 Broker read-only | not started | legal + CLASS D |
| Q10 Controlled execution | blocked by design | AEF persistence + Human Gate + regulatory analysis |

Order change vs mission 01: vendor licensing is now the critical path for
Q1→Q2 value; Q6 can proceed in parallel once IVE Core passes.

## 7. Recommended next Quant gate

**IV-QUANT-PROVIDER-AND-PROMOTION-READINESS-03**:
1. Owner obtains written licence answers from the PRIMARY/SECONDARY vendors
   (display rights, US + LSE, delay, fees) — Owner decision + cost approval.
2. First real `MarketDataProvider` behind `safe_fetch` with recorded
   fixtures; provider cache keyed with provenance.
3. Per-user rate limit (429) for Quant APIs.
4. Multi-series analytics in the Lab (comparison, correlation matrix).
5. Physical Android run + web build of `/quant-lab` (G1/G9/G10 evidence).
6. Promotion Gate review of `quant-analytics` INTERNAL → ALPHA (beta
   testers): requires a new `quant_watchlists_access_allowed()` migration
   (QB-16) and CLASS D review.
