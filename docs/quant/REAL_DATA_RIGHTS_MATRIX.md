# InsightValues Quant — Real Data Rights Matrix
# IV-QUANT-LICENSED-PROVIDER-PILOT-04

**Date:** 2026-10-02  
**Evidence cutoff:** 2026-10-02 — all sources re-read on this date. Terms change; re-verify before commercial launch.

Answer codes:

| Code | Meaning |
|---|---|
| **GREEN** | Confirmed in current public documentation |
| **YELLOW** | Requires written confirmation or specific plan |
| **RED** | Explicitly prohibited |
| **UNKNOWN** | Ambiguous or not found |

---

## Master Rights Matrix

| Right | Databento DBEQ.BASIC | Twelve Data Business | EODHD Enterprise | Polygon/Massive Business |
|---|---|---|---|---|
| SaaS commercial use | **GREEN** | YELLOW | YELLOW | YELLOW |
| Display to end users (web) | **GREEN** | YELLOW | YELLOW | YELLOW |
| Display to end users (mobile) | **GREEN** | YELLOW | YELLOW | YELLOW |
| Display to free users | **GREEN** | YELLOW | YELLOW | UNKNOWN |
| Display to paying users | **GREEN** | YELLOW | YELLOW | UNKNOWN |
| Derived analytics display | **GREEN** | UNKNOWN | UNKNOWN | UNKNOWN |
| Store raw data server-side | YELLOW | UNKNOWN | UNKNOWN | UNKNOWN |
| Store derived analytics | YELLOW (inferred) | UNKNOWN | UNKNOWN | UNKNOWN |
| Redistribute raw data | **GREEN** | RED (separate agreement) | RED (standard plans) | UNKNOWN |
| US equities (XNYS/XNAS) | **GREEN** | **GREEN** (confirmed) | **GREEN** (confirmed) | **GREEN** (US only) |
| UK equities (XLON) | **RED** (not in product) | YELLOW (extra approval) | YELLOW (Internal Use ≠ display) | **RED** (not offered) |
| FX | **RED** (not in product) | **GREEN** (data available) | **GREEN** (data available) | UNKNOWN |
| Historical OHLCV | **GREEN** | **GREEN** | **GREEN** | **GREEN** |
| Exchange fees | **GREEN** (zero) | UNKNOWN (extra fees apply) | UNKNOWN | YELLOW ($399–$1,999/mo per feed) |
| Attribution required | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |
| AI/ML processing | **GREEN** (inferred) | UNKNOWN | UNKNOWN | UNKNOWN |
| Caching | YELLOW | UNKNOWN | UNKNOWN | UNKNOWN |
| Account commitment | None (pay-as-you-go) | Business tier | Enterprise | $2,499+/mo |

---

## Rights Gate Decision

| Provider | Verdict | Action |
|---|---|---|
| Databento DBEQ.BASIC | **PILOT_APPROVED** | Adapter implemented; Owner creates account + key |
| Databento DBEQ.MINI | **PILOT_APPROVED** | Alternative; same rights, optimized for real-time |
| Twelve Data Business | **BLOCKED_PENDING_WRITTEN_RIGHTS** | Owner sends draft email (see Mission 03 dossier §8.1) |
| EODHD Enterprise | **BLOCKED_PENDING_WRITTEN_RIGHTS** | Owner sends draft email (see Mission 03 dossier §8.2) |
| Polygon/Massive Business | **BLOCKED_PENDING_WRITTEN_RIGHTS** | Owner sends draft email (see Mission 03 dossier §8.3) |
| Sharadar | **RESEARCH_ONLY** | Not for SaaS display |
| Yahoo Finance | **REJECTED** | No commercial use |
| Stooq | **REJECTED** (no public terms) | Do not use |

---

## Key Gaps for Full Commercial Launch

1. **UK/XLON coverage** — No GREEN provider covers UK equities without written agreement.
   Resolution: Obtain written rights from Twelve Data Business or EODHD Enterprise.

2. **Adjusted prices** — No provider in pilot covers split/dividend-adjusted OHLCV.
   Resolution: Databento has a separate corporate-actions API; integrate post-pilot.

3. **Attribution** — No provider's attribution requirement is confirmed in public docs.
   Resolution: Confirm in writing during commercial negotiation.

4. **Long-term data storage** — Cache TTL and post-termination retention unconfirmed.
   Resolution: Confirm in writing; implement retention policy at storage layer.
