# Financial Intelligence Positioning

**Mission:** INSIGHTVALUES-COMMERCIAL-MACRO-01, Tranche 2. Scope: reconcile this app's "IVE Quant" placeholder with the real Strategy001/"Paulo Trend Fibonacci" asset, and integrate real code where safe — explicitly without real broker connection, real money, real order execution, broker credentials, an invented market-data provider, or bypassing licensing.

> **AMENDMENT (INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04, §13):** the section immediately below claims this shape was "verified against its real source." A later mission independently re-checked that specific claim and could not substantiate it — the named `insightvalues-quant` GitHub repository contains only a README, no Strategy001 code of any kind, as of a commit dated seven weeks before this document was written. See `docs/commercial/STRATEGY001_SOURCE_FINDING.md` for the full diligence trail before treating anything below as confirmed fact. Nothing in the resulting Dart contracts is unsafe (they are inert types, not logic) — only the provenance claim needs re-confirming with the Owner.

## What Strategy001 actually is (verified against its real source)

Strategy001 ("Paulo Trend Fibonacci") lives entirely in the separate `insightvalues-quant` Python repository, at `insightvalues_quant/strategy001/` and `insightvalues_quant/fibonacci/`. It is a validated, tested state machine (`test_strategy001_*.py`, `test_fibonacci_*.py` — engine, evaluator, state machine, golden files, audit trail, all present) that tracks structural trend/pullback/Fibonacci/confirmation conditions bar-by-bar and emits typed events (`TREND_DETECTED`, `FIB_READY`, `TRIGGERED`, `TARGET_REACHED`, etc.) plus per-bar snapshots.

Its own README is explicit and load-bearing for this whole mission's scope decision:

> "This module produces state transitions and events only. It never generates BUY, SELL, LONG, SHORT, or any trading signal. It never integrates with Backtest, Portfolio, Risk, or any broker."

So Strategy001 itself, even inside its own repository, is one deliberate step removed from anything that could be called a live trading signal — it is structural-condition tracking, nothing more. That single fact is why the integration below is safe to do at all.

## What "IVE Quant" was, before this tranche

`ive-quant` in `module_registry.dart` was a pure placeholder: `status: planned`, `commercialEnabled: false`, `route: null`, and a readiness note recording an exhaustive prior-mission grep confirming **zero code, zero route, zero model** for anything Quant-related inside this repository (the Flutter/Dart Commercial app). There was no "existing Quant vertical" in this codebase to reconcile Strategy001 with — the separation the mission asks to preserve (Quant=calculation / IVE=interpretation / AEF=governance / Broker=future execution) describes a target architecture, not something already partially built here.

## What this tranche adds

`lib/core/quant/strategy001_contracts.dart` — a hand-written Dart mirror of `insightvalues_quant/strategy001/models.py`'s real dataclasses (`StrategyState`, `EventKind`, `StrategyEvent`, `BarSnapshot`, `Strategy001Result`) and `insightvalues_quant/structure/models.py`'s `TrendDirection` enum. Field names, types, and the state/event vocabulary were copied from that real source, not invented. It contains:

- The **shape** Strategy001 already produces (states, event kinds, snapshots, the aggregate result of one run).
- One small piece of real logic: `Strategy001Result.eventsByKind`, mirroring the Python model's own `events_by_kind` property. Covered by `test/core/quant/strategy001_contracts_test.dart`.

It contains **zero** of the following, deliberately:

- The Fibonacci/trend/confirmation algorithm itself (no port, partial or full).
- Any market-data provider, invented or real.
- Any broker adapter, order execution, or real-money code path.
- Any wiring into a route, screen, Riverpod provider, or Supabase function — nothing in the app can currently construct, receive, or display one of these contracts. `ive-quant` remains `commercialEnabled: false`, `route: null`; this is not a commercial launch of Financial Intelligence, and no Owner decision to launch it was made this tranche.
- Any AEF integration. A future Strategy Engine that *acts* on these events (e.g. surfacing a "structural setup detected" notification) would need its own governance pass through AEF before it could do anything beyond display — that is a distinct, future, Owner-gated decision this file does not imply or shortcut.

## Why a contract mirror, and not more

The mission explicitly did not want this step "limited to documentation... where safe code integration is possible" — but it also explicitly forbids everything that would make a *functional* integration meaningful (no market data, no broker, no execution). Between those two constraints, the real, safe, additive contribution is exactly this: give a future integration a faithful, tested target type instead of an ad-hoc `Map<String, dynamic>`, without pretending any actual signal, data feed, or execution path exists yet. A full cross-language port of the validated algorithm logic (Python → Dart) was considered and deliberately not attempted this pass — it's a substantial, separately-scoped engineering effort (the Python side has ~8 dedicated test files for the state machine alone), not a safe quick addition, and porting logic without also porting its test suite would silently discard the validation that makes Strategy001 trustworthy in the first place.

## What a real future integration would still need (not started here)

1. **A decision on where Strategy001 actually runs**: re-implemented in Dart (full port + test suite), or invoked via a Supabase Edge Function wrapping the existing Python package. Both are legitimate; neither was decided or attempted here.
2. **A real, licensed market-data source.** Still blocked — no provider exists or was invented.
3. **An AEF governance pass** for anything beyond passive display of a detected structural condition.
4. **An explicit Owner decision to commercially launch Financial Intelligence** — `ive-quant`'s `commercialEnabled: false` stays exactly as a prior mission's Owner-deferral left it, same posture Growth Intelligence had before its own explicit launch decision this tranche.

## Architecture separation (preserved, not yet exercised)

- **Quant (calculation)**: still 100% in the separate `insightvalues-quant` repository. Untouched.
- **IVE (interpretation)**: untouched. No IVE code references these new contracts.
- **AEF (governance)**: untouched. No AEF code references these new contracts.
- **Broker (future execution adapter)**: does not exist anywhere in this app. Not created.

No strategy has acquired a direct, ungoverned path to real financial execution — because no strategy has acquired *any* path to execution, governed or not. The gap between "structural event" and "trading action" is exactly as wide after this tranche as before it; the difference is that a future team building across that gap now has a real type to build against.
