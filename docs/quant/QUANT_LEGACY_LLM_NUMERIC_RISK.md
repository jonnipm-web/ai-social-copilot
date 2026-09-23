# LEGACY_LLM_NUMERIC_RISK (technical record — not fixed in Quant)

Recorded by IV-QUANT-DATA-PLANE-AND-API-02. **Out of Quant scope; no code
changed.** These commercial (Business ROI) Edge Functions ask an LLM to
*produce* financial-looking numbers, the opposite of the Quant rule
"the engine calculates, the LLM explains".

| Function | Module (lifecycle) | LLM-generated numeric fields (from the prompt schema) |
|---|---|---|
| `market-analysis` | market-intelligence (COMMERCIAL) | `opportunity_score`, `investment_score`, `investment_recommendation`, `revenue_monthly_min/max`, `months_to_revenue`, `revenue_confidence`, `score_*`, `roi_expected` — `supabase/functions/market-analysis/index.ts:15-60` |
| `revenue-planner` | revenue-planner (COMMERCIAL) | `monthly_conservative/moderate/aggressive`, `annual_*`, `revenue_sources[].percentage` — `supabase/functions/revenue-planner/index.ts:15-60` |
| `decision-simulator` | decision-simulator (EXPERIMENTAL) | `health_delta`, `execution_delta`, `opportunity_delta`, `roi_estimate`, `confidence`, `timeline_weeks` — `supabase/functions/decision-simulator/index.ts:75-90` |

## Risk

* Numbers are not reproducible (same input → different output), have no
  formula, no provenance and no stated assumptions.
* Presented next to real metrics, users may read them as computed facts
  ("investment_score: 80", "R$ 8.000/mês").
* Regulatory: an LLM-generated "investment recommendation" is exactly the
  kind of output QUANT_SECURITY_MODEL §5 keeps out of Quant.

## Recommendation (future, separate mission — Business ROI, not Quant)

1. Label every such figure in the UI as **"estimativa gerada por IA"**, with
   the inputs it was based on — immediate, low cost.
2. Move arithmetic that has inputs (percentages summing to 100, annual =
   12 × monthly, deltas) into deterministic server code; keep the LLM for
   qualitative narrative.
3. Never import these outputs into Quant (`UntrustedDocumentEvidence` rule).
4. Do **not** merge Business ROI with the Quant financial engine without an
   explicit architecture decision — different domains (business estimates
   vs market data).
