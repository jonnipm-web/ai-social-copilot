# 07 — Financial Intelligence

Financial Intelligence is **one vertical**, not the center of the ecosystem. On the merged
product (E-MAIN) it does not exist beyond a registry placeholder and AEF policy boundaries.

## 1. Where each piece lives

| Component (mission vocabulary) | Evidence found | Status |
|---|---|---|
| `ive-quant` module | `lib/core/modules/module_registry.dart` — `status: planned`, `commercialEnabled: false`, `route: null`, readiness note "NÃO EXISTE neste repositório" | E-MAIN: `PLANNED` |
| AEF Quant boundary | `quant_execution_tier` enum; live tiers require `human_gate_ref` in the contract and are **hard-denied** by the v0 kernel even with approval | E-MAIN: `IMPLEMENTED`, `TESTED` |
| Quant Lab analytics engine (TypeScript) | E-INT02 `supabase/functions/_shared/quant/`, EFs `quant-analyze` (READ_ONLY/INTERNAL), `quant-watchlists` (REVERSIBLE/INTERNAL), migrations `20260924000000_quant_watchlists.sql`, `20260924000100_quant_rate_limits.sql`, admin-only `/quant-lab` | `EXPERIMENTAL`, unmerged, not deployed, no market-data vendor, no real key (E-DOC `docs/quant/QUANT_CURRENT_STATE.md`) |
| Strategy001 Dart contracts | E-INT02 `lib/core/quant/strategy001_contracts.dart` — mirror of the Python dataclasses; zero logic except `eventsByKind`; reachable from no route/provider | `IMPLEMENTED` (unmerged), inert |
| Strategy001 engine (Python) | E-QUANT `insightvalues_quant/strategy001/`, `fibonacci/`, `structure/` | `IMPLEMENTED`, `TESTED` (research) |
| Historical backtest / financial P&L model | E-QUANT `historical_backtest/`, `historical_data/`, `costs/`, `instruments/`, `position_management/`, `risk_management/`; ADR-048…060 | `IMPLEMENTED` (research) |
| Strategy fidelity packages (Paulo Trend Fibonacci V2, V3, V4 hierarchical) | E-QUANT `strategy_fidelity/`, `docs/strategy/paulo-trend-fibonacci-v3-fidelity.md`, `…-v4-hierarchical-fidelity.md` | `IMPLEMENTED` (research) |
| Dataset certification / instrument registry | E-QUANT `docs/architecture/dataset-certification.md`, `instrument-registry.md` | `IMPLEMENTED` (research, per docs) |
| Robot Builder | none | `ENVIRONMENT_BLOCKED` |
| Strategy Specification | none (closest: E-QUANT strategy config hashes) | `ENVIRONMENT_BLOCKED` |
| Validation Engine | none | `ENVIRONMENT_BLOCKED` |
| Strategy Lab | none | `ENVIRONMENT_BLOCKED` |
| Backtest Engine (as a product surface) | E-QUANT research orchestrator only | `ENVIRONMENT_BLOCKED` for the Macro-09 version |
| Dataset registry / engine registry | none | `ENVIRONMENT_BLOCKED` |
| Quant metrics | E-QUANT `risk/` (Sharpe, drawdown, Calmar); E-INT02 TS analytics (SMA, crossover, Sharpe) | `IMPLEMENTED` (research / Lab) |
| Robustness, holdout, contamination tracking, experiments, parameter sensitivity | none located | `ENVIRONMENT_BLOCKED` |
| IVE Strategy Analyst | none | `ENVIRONMENT_BLOCKED` |
| User decision / governed simulation | AEF contract tiers `research/backtest/paper` exist; no runtime | `PLANNED` |
| Broker / order execution | none; AEF hard-denies live tiers | `NOT_IMPLEMENTED` |

The owner-described Macro-09 components could not be verified in any accessible repository
(four repos, 90+ branches searched). They must be documented from Macro-09's own evidence
when that workspace is available. Nothing in this chapter should be read as confirming them.

## 2. Strategy naming (canonical, per owner definition)

| Term | Meaning | Evidence status |
|---|---|---|
| **Strategy001** | Historical strategy-engine / state-machine architecture (Python `insightvalues_quant/strategy001/`: states `WAIT_TREND … RESET`, events `TREND_DETECTED … STRATEGY_INVALIDATED`). Emits state transitions and events only — never BUY/SELL signals (its README). | `VERIFIED` in E-QUANT; Dart mirror in E-INT02 |
| **Paulo Trend Fibonacci V10** | Current verified reference strategy implementation (owner definition) | `ENVIRONMENT_BLOCKED` — latest version found in any repo is **V4** (`codex/qt01c36-hierarchical-fibonacci-structural-fidelity`, 2026-08-13) |
| **Strategy #001** | Product identifier for the V10 reference strategy (owner definition) | `ENVIRONMENT_BLOCKED` |

Do not collapse these terms. `lib/core/quant/strategy001_contracts.dart` (E-INT02) mirrors
**Strategy001** (the engine architecture), not V10.

## 3. Research status — historical negative evidence (E-QUANT, `HISTORICAL_EVIDENCE_ONLY`)

| Artifact | Recorded result |
|---|---|
| `E-QUANT:docs/research/baselines/paulo_trend_fibonacci_v2_real_validated_v1.json` | `BASELINE_REAL_VALIDATED_V1`: strategy `PAULO_TREND_FIBONACCI_V2_FIDELITY`, instrument WIN (B3 mini-index), 5-min, 10 354 bars, 92 sessions, 2026-03-30 → 2026-08-10 |
| `E-QUANT:docs/research/qt01research01-diagnostico-completo-v2.md` | "VEREDITO FINAL: +R$1.967,40 é REAL na aritmética mas NÃO VERIFICÁVEL na premissa"; conservative scenario R$765 gross; 1-minute scenario −83 % vs baseline; "n=19/29 por direção são amostras insuficientes" |
| `E-QUANT:docs/research/qt01c36-v4-backtest-comparison.md` | "No version or target scenario is selected by P&L. V4 performance is negative on this sample and robustness is insufficient." |

No strategy in the accessible evidence has a verified positive edge. This manual does not
optimize, re-run or re-interpret these results.

## 4. Financial Intelligence flow (target, not current)

```mermaid
flowchart LR
  DATA[Licensed market data: NONE] -.-> QE[Quant engine: deterministic calculation]
  QE --> EV[Evidence: metrics, events, hashes]
  EV --> IVE[IVE: interpretation only]
  IVE --> U[User decision]
  U --> AEF[AEF: research / backtest / paper tiers]
  AEF -.hard DENY.-> LIVE[controlled_live / expanded_live]
  LIVE -.-> BROKER[Broker adapter: NOT_IMPLEMENTED]
```

Separation principle recorded in E-INT02 `docs/commercial/FINANCIAL_INTELLIGENCE_POSITIONING.md`:
**Quant = calculation, IVE = interpretation, AEF = governance, Broker = nonexistent.**

## 5. Blockers

Market-data licensing (no vendor selected, E-INT02 `QUANT_VENDOR_LICENSING_DOSSIER.md`),
legal review for regulated domain (Promotion Gate class C), AEF persistence not applied,
Macro-09 evidence not accessible.
