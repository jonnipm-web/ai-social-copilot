# InsightValues Quant — Real Data Cost Model
# IV-QUANT-LICENSED-PROVIDER-PILOT-04

**Date:** 2026-10-03 (updated from 2026-10-02)  
**Scope:** Databento EQUS.SUMMARY (replaces deprecated DBEQ.BASIC — EV-DB-01); usage-based pricing as of 2026-10-03.  
**All figures are estimates only — not quotes. Verify at https://databento.com/pricing.**

---

## 1. Databento Pricing Model

Databento uses **usage-based pricing ($/GB consumed)**:
- No monthly subscription fee for historical data
- New accounts receive **$125 in free credits** (shared across team; expires 6 months after signup)
- Real-time data requires a subscription plan (not used in this pilot)
- Batch historical downloads: billed once per request; re-download free for 30 days

---

## 2. Data Size Estimates

All figures are classified as MEASURED, ESTIMATED, or ASSUMED:

| Label | Meaning |
|---|---|
| MEASURED | Confirmed by actual API call or official documentation |
| ESTIMATED | Derived from known parameters (bar count × byte size) |
| ASSUMED | Hypothesis based on industry patterns; no confirmation |

### Daily OHLCV bar (JSON)
- One bar: ~200 bytes (with pretty_ts + pretty_px, NDJSON format) — **ESTIMATED**
  (based on sample ndjsonBar() in test helper: actual byte size of typical bar)
- 252 trading days/year × 200 bytes ≈ **~50 KB per symbol per year** — **ESTIMATED**

### Pilot dataset (3 symbols × 2 years)
- 3 × 2 × 50 KB = **~300 KB** → effectively $0.00 at any $/GB rate — **ESTIMATED**
- NOTE: actual bytes will be MEASURED in the post-owner-gate E2E test.

### Production: 1,000 symbols × 5 years daily history (initial load)
- 1,000 × 5 × 50 KB = **250 MB** ≈ $0.25–$2.50 at $1–$10/GB — **ESTIMATED**
  ($/GB rate from Databento pricing page; not a binding quote)
- Daily incremental (1,000 symbols × 1 day): 200 KB → $0.0002 — **ESTIMATED**

---

## 3. Per-User Cost Estimate (LAB PROJECTION ONLY)

The following uses today's Databento $125 credit baseline to project at scale.
**This is not an actual cost until the owner converts to a paid plan.**

### Assumptions (all ASSUMED until post-owner-gate measurement)
- 1 Quant Lab user = 1 watchlist = ~10 symbols — **ASSUMED**
- Initial load: 2 years history = 2 × 252 × 10 × 200 bytes = ~1 MB — **ESTIMATED**
- Daily incremental: 10 symbols × 200 bytes = 2 KB — **ESTIMATED**
- Cache hit rate: 90% after warm-up → 10% miss rate — **ASSUMED**
  (based on typical CDN/cache patterns; not measured for this adapter)
- $/GB rate: $5/GB — **ASSUMED** (Databento pricing ranges by plan/volume; verify at databento.com/pricing)

### Monthly cost per user (after initial load)
- Daily calls: 10 symbols × (1 − 0.90 cache hit) × 30 days = 30 provider calls — **ESTIMATED**
- Data fetched: 30 × ~4 KB (single day) = 120 KB/month — **ESTIMATED**
- At $5/GB estimate: $0.0006/user/month — **ASSUMED** ($/GB not verified by measurement)

### At 1,000 active users
- $0.60/month for Databento data — **ASSUMED** (extrapolation, not measurement)
- Dominant cost: Supabase compute, not data — **ASSUMED**

### Tier model draft (data cost component only)

| Tier | Quant usage | Estimated Databento cost/month | Suggested price anchor |
|---|---|---|---|
| FREE | 3 symbols × 6 months history | < $0.01 | $0 |
| PRO | 20 symbols × 5 years history | < $0.05 | $9.99 |
| ADVANCED | 100 symbols × 10 years history | < $0.50 | $29.99 |

**Note:** These are data-only estimates. Compute, storage, and Edge Function costs are separate.

---

## 4. Pilot Phase (No Financial Commitment)

Phase: account creation → free credits → pilot test

| Step | Cost |
|---|---|
| Account creation | $0 (free credits: $125) |
| Pilot (3 symbols × 2 years) | < $0.01 (well within $125 credit) |
| Pilot (10 symbols × 5 years) | < $0.05 (well within credit) |
| Real-time subscription | NOT in this pilot |

**Decision required before credit exhaustion:** Whether to move to paid plan.
At the data volumes above, the $125 credit will last years for daily OHLCV only.

---

## 5. Cost Observability Instrumentation

The adapter emits the following metadata for cost tracking (no billing in this mission):

- `provider: 'databento-equs-summary-v1'`
- `cache_outcome: 'HIT' | 'MISS' | 'STALE_FALLBACK'`
- `rows_returned: number`
- `response_bytes: number` (approximated from body.length)

See `observability.ts` for the log contract.

---

## 6. Recommendation

Databento EQUS.SUMMARY is the **most cost-effective YELLOW/NOT_VERIFIED provider** for the pilot:
- Zero financial commitment at pilot scale
- No per-user or per-display fees
- Cost scales linearly with data volume; daily OHLCV is very small

For UK/XLON coverage (future): EODHD or Twelve Data pricing must be confirmed.
Expected to be significantly higher (£399–£2,499+/mo based on public plans).
