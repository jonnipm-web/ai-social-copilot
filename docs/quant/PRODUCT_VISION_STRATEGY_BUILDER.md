# InsightValues Quant — Product Vision: Strategy Builder
# Registered in IV-QUANT-LICENSED-PROVIDER-PILOT-04 (2026-10-02)

**Status:** ROADMAP ONLY — not implemented in any current mission  
**Authority:** This document records the Owner's stated product vision.  
**Decision authority for implementation:** Agente Martins + Paulo.

---

## 1. Core Principle

> The "robot" is NOT the product.
>
> InsightValues does not sell a trading algorithm.
> InsightValues sells a **Quantitative Strategy Builder** paired with an
> **IVE Financial Intelligence Copilot**.

The Owner's Reference Strategy is a _template_ — a demonstration of what
the platform can model, not a product in itself.

---

## 2. What the Product Is

### Quantitative Strategy Builder

The end user of InsightValues will be able to:

- Construct their own quantitative strategy
- Define entry and exit rules
- Combine technical indicators (SMA, EMA, RSI, Bollinger Bands, MACD, etc.)
- Configure risk parameters (stop-loss, position size, max drawdown)
- Configure capital allocation rules
- Test strategies against historical data (backtesting)
- Compare strategy versions side-by-side
- Evolve and refine strategies iteratively
- Receive qualitative analysis from IVE Financial Intelligence Copilot

### IVE Financial Intelligence Copilot

IVE will assist the user in the strategy-building process. IVE **may**:

- Help the user articulate and structure strategy rules in plain language
- Identify logical inconsistencies in the user's defined rules
- Explain what a metric means (Sharpe ratio, beta, VaR, drawdown)
- Compare two strategy versions and explain differences
- Point out gaps, edge cases, or missing risk controls
- Suggest tests the user has not run
- Organize and narrate backtest results
- Explain why a metric changed between periods

IVE **must NOT**:

- Invent financial results or fabricate performance numbers
- Invent or hallucinate market data
- Promise profitability or expected returns
- Transform a reference strategy template into a personal recommendation
- Execute real money or place orders without full AEF governance
- Bypass the deterministic engine with LLM-generated numbers

---

## 3. Architectural Implications

### The Strategy is User-Defined

```
User defines:
  - indicators (rule parameters)
  - entry/exit logic
  - risk controls

Engine computes:
  - deterministic backtest results
  - metrics (returns, Sharpe, drawdown, VaR, beta)

IVE narrates:
  - result explanation
  - consistency checks
  - comparison summaries
```

### What This Means for the Data Plane

- Real historical data (DBEQ.BASIC, future providers) serves as the
  backtest universe — NOT as recommendation input
- Raw prices are an input to the deterministic engine, not displayed
  directly as investment recommendations
- IVE explanations are grounded in engine output, not LLM-generated numbers
- The platform tracks provenance of every number shown to the user

### What This Means for the AEF Boundary

- The Strategy Builder is a RESEARCH / BACKTEST tier product
- Real-money execution (if ever implemented) must pass through:
  - AEF Human Gate
  - Risk policy check
  - Broker adapter
  - Reconciliation
- In the foreseeable roadmap, InsightValues is RESEARCH + PAPER only

---

## 4. Current AEF Boundary (Unchanged by This Vision)

```
BROKER_CONNECTION  = NONE
REAL_MONEY         = DISABLED
LIVE_ORDER         = DISABLED
```

No user-facing call-to-action for:
- BUY / SELL
- PLACE ORDER
- EXECUTE TRADE
- CONNECT BROKER (unless specifically gated)

---

## 5. Monetization Model (Hypothesis — No Prices Activated)

The Strategy Builder enables differentiated tiers by capability depth:

| Tier | Capabilities | Data depth |
|------|-------------|------------|
| FREE | Single strategy, 3 instruments, 1 year history, basic metrics | EOD historical |
| PRO | Multi-strategy comparison, 20 instruments, 5 years, correlation, drawdown | EOD historical |
| ADVANCED | Full backtesting, 100 instruments, 10 years, VaR/CVaR, custom indicators, IVE narration | EOD historical |
| ENTERPRISE | Organization workspaces, programmatic access, extended history | API access |

Data cost at all tiers is dominated by compute, not market data (see REAL_DATA_COST_MODEL.md).

---

## 6. Roadmap Dependencies

This vision requires, in order:

1. **Real data provider** — DBEQ.BASIC pilot (current mission)
2. **Backtesting engine** — Q7 in QUANT_ROADMAP.md (not started)
3. **Point-in-time data** — Sharadar-class provider for look-ahead-free backtesting
4. **Strategy definition format** — JSON schema for user-defined rules
5. **IVE Quant Narrator** — Q6 in QUANT_ROADMAP.md (contract exists, implementation blocked by IVE-INTELLIGENCE-CORE-01)
6. **Corporate actions** — Adjusted prices for meaningful long-term backtests
7. **AEF Paper execution** — Simulated portfolio with realistic fill modeling
8. **[Future only] AEF Controlled execution** — Gated by AEF persistence + Human Gate + regulatory

---

## 7. What Must NOT Be Built Without Authorization

- Live trading integration (requires CLASS D review + legal)
- Recommendation engine (requires regulatory analysis)
- Portfolio management as a service (regulatory scope)
- Automated rebalancing (AEF persistence + Human Gate first)

---

*This document records the strategic intent communicated by Owner (Paulo Martins)*
*during IV-QUANT-LICENSED-PROVIDER-PILOT-04 (2026-10-02).*
*Implementation decisions require Agente Martins + Paulo approval.*
