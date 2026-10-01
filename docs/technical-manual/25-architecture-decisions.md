# 25 — Architecture Decision Records (recovered)

Recovered from code comments, migration headers and mission reports. History is not rewritten:
each record cites where the decision is evidenced. Status: `CURRENT` (in force on E-MAIN),
`PROPOSED` (documented, not in force on E-MAIN), `SUPERSEDED`.

| ID | Decision | Rationale (as recorded) | Evidence | Status |
|---|---|---|---|---|
| ADR-001 | IVE is the intelligence/assistant core; it may request, never authorize | "IVE MAY REQUEST. IVE MUST NOT AUTHORIZE." | `contracts/aef/README.md`; display-only chip in `context_copilot_widget.dart` | `CURRENT` |
| ADR-002 | AEF is the only future path for consequential execution; fail-closed, deterministic policy, no LLM in policy | Architecture chain IVE → AEF → domain/tool | `aef/README.md`, `aef/policy_evaluator.ts` | `CURRENT` (library); runtime `PROPOSED` |
| ADR-003 | No broker / live trading; Quant live tiers hard-denied even with Human Gate | No safe execution path exists | `aef/action_classification.ts` | `CURRENT` |
| ADR-004 | Commercial LLM = Groq (server-side key); Gemini/ADK confined to the hackathon agent | Cost/auth control; hackathon track requirement | 16 EFs; E-AGENT README; E-INT02 IVE state doc §4 | `CURRENT` |
| ADR-005 | Projects + Knowledge are the operational center; every IVE interaction is project-scoped | Grounding on the project on screen, not the top-scored project | `docs/commercial/PROJECT_CONTEXT_CONTRACT.md`, `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §1 | `CURRENT` (partially implemented) |
| ADR-006 | Quant and Impact are domain intelligence verticals, built in isolated labs, admin-only until a Promotion Gate | Regulated / reputational domains | E-INT02 `MODULE_PROMOTION_GATE.md`, `MODULE_PORTFOLIO.md` | `PROPOSED` (unmerged) |
| ADR-007 | Separation: Quant = calculation, IVE = interpretation, AEF = governance, Broker = nonexistent | Avoid LLM-generated financial numbers | E-INT02 `FINANCIAL_INTELLIGENCE_POSITIONING.md` | `PROPOSED` |
| ADR-008 | Strategy001 emits state transitions/events only, never BUY/SELL signals | Keep research engine one step from trading | E-QUANT strategy001 README (quoted in E-INT02 doc) | `CURRENT` (E-QUANT) |
| ADR-009 | Mobile (Android) and Web are both first-class from one Flutter codebase | Single product surface | workflows `deploy-web.yml`, `build-apk.yml` | `CURRENT` |
| ADR-010 | Human authority over consequential decisions; confirmation before any quota-consuming AI call | Monetization + trust | `ai_execution_confirmation.dart`, `IVE_INTERACTION_AND_QUOTA_CONTRACT.md` | `CURRENT` |
| ADR-011 | Real identity boundary is `resolveAuthenticatedUser()`, not `verify_jwt` | Anon key passes `verify_jwt` | `_shared/auth.ts`, allowlist header (AUTH-01) | `CURRENT` |
| ADR-012 | Merge ≠ deploy for Edge Functions; one function per manual run; allowlist is single source of JWT policy | Prior bulk deploy flipped JWT policy | `deploy-edge-functions.yml` header (X4R-DG1/DG2) | `CURRENT` |
| ADR-013 | Canonical migration baseline captured from live production; legacy migrations archived, never replayed | Legacy files diverged from production | `20260907120000_baseline_production_pre_x4r.sql`, `docs/legacy-migrations-archive/README.md` | `CURRENT` |
| ADR-014 | Plan/quota source of truth = `profiles.role` + `monthly_limit`, tamper-proof via trigger; usage counted in `ai_usage` via DEFINER RPCs | Reuse audited schema | migrations `20260910190000`, 022 | `CURRENT` |
| ADR-015 | Stripe state is written only by the signed webhook (service_role), atomically and ordered by `event.created` | Stripe does not guarantee order/once | billing migrations 0101/0201/0301 | `CURRENT` |
| ADR-016 | Rive avatar frozen; deterministic Flutter fallback is the commercial avatar; gate is a compile-time constant | Silent zero-pixel rendering | `docs/ive/IVE_RIVE_FREEZE_RECORD.md` | `CURRENT` (`FROZEN`) |
| ADR-017 | `ive-agent-runner` retired to a 410 stub, permanently excluded from CI deploy | SR-04/SR-05 | `docs/ive/SR04_SR05_CLOSURE.md` | `CURRENT` |
| ADR-018 | Module registry is single metadata source; commercial availability checked before plan | Prevent Pro unlocking unreleased modules | `route_policy.dart` | `CURRENT` |
| ADR-019 | Showcase: temporary in-repo (Option A) → separate repo + SDK (B/D) | IP protection, release independence | `docs/showcase/SHOW_00_REPOSITORY_BOUNDARY_DECISION.md` | `PROPOSED` (never executed; no Showcase repo exists) |
| ADR-020 | Market Intelligence child tables hold one current row per analysis; superseded rows archived, not deleted | 406 duplicate bug; preserve distinct LLM output | `20260916000000_market_intelligence_current_state.sql` | `CURRENT` |
| ADR-021 | Source maps never public; encrypted artifact only | Public repository | `deploy-web.yml` STABILITY-09O steps | `CURRENT` |
| ADR-022 | Quant history: legacy signal-based `backtest/`, `portfolio/`, `strategy/base.py` discontinued in favour of the official pipeline | ADR-028/ADR-035 in E-QUANT | E-QUANT README | `CURRENT` (E-QUANT) |

E-QUANT carries its own ADR series (ADR-016 … ADR-060) under `docs/adr/`; they are referenced,
not duplicated, here.
