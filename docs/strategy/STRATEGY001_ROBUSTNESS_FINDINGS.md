# Strategy #001 (Paulo Trend Fibonacci V10) — Robustness Findings

INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 §22.

Real run against the real WIN1! dataset (`win1-5min-qt01c3`, hash
`5220e7cc9f46987b8dcf6cb9`, 2026-03-30 to 2026-08-11), through the actual
product code path (`runV10ViaBridge` -> `buildCanonicalBacktestResult` ->
`analyzeCostSensitivity`/`analyzeBacktestResult`), not a synthetic fixture.

## Result

| Methodology | Trades | Net P&L | Profit factor | Expectancy |
|---|---|---|---|---|
| Zero-cost research | 75 | **-57.00** | 0.93 | -0.76 |
| Cost-adjusted (Run B: realistic B3 day-trade fees) | 75 | **-270.75** | 0.93 | -3.61 |

`analyzeCostSensitivity` flags the cost-adjusted delta as **materially**
different from the zero-cost result (INFERENCE claim, real threshold
crossed, not a fabricated confidence number).

## Honest reading

This is a **negative finding**, and it is reported as one rather than
omitted or reframed:

- Strategy #001, on this dataset/period/configuration, was **not
  historically profitable** — not zero-cost, and materially worse once
  realistic transaction costs are applied.
- Sample size (75 trades) is above the platform's own
  `SMALL_SAMPLE_THRESHOLD` (30), so this is not simply "too little data" —
  it is a real, moderately-sized sample showing a losing result.
- 19 of 75 trades (25%) executed at an ambiguous price source
  (`BAR_OPEN_GAP`), a known, already-disclosed limitation of running on
  5-minute bars instead of real 1-minute execution data (Macro-05 §12,
  preserved unchanged — no fake 1-minute data was synthesized to work
  around this).
- Costs alone turned an already-losing zero-cost result roughly 4.75x
  more negative — the strategy, as configured, is **highly cost-sensitive**.

## What this does NOT mean

Per §18/§35 of the mission brief, this finding is not evidence that no
profitable configuration exists, and it is not used to declare any
"best"/"guaranteed" outcome. It is exactly one measured data point: this
specific configuration, this specific dataset, this specific period. The
platform's own `UNKNOWN` claim ("Future profitability cannot be estimated
from this historical result alone") applies here as it does to every
other result.

## Reproduction

```
1. Copy tools/backtest_bridge/bridge_config.example.json to
   bridge_config.json and fill in real local paths.
2. python tools/backtest_bridge/backtest_service.py
3. Run a script that calls runV10ViaBridge() twice (costConfig: null, then
   the Run B cost config from fixtures_win.py) against dataset_id
   'win1-5min-qt01c3' using v10_reference.ts's buildV10ReferenceSpecification(),
   builds each into a CanonicalBacktestResult, and calls
   analyzeCostSensitivity(zeroCostResult, costAdjustedResult).
```

No fixture, no synthetic data, no fabricated numbers -- every value above
came directly out of the real Python V10 orchestrator run against the
real WIN1! CSV on 2026-09-28.
