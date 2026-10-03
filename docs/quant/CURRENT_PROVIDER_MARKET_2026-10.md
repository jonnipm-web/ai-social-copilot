# Current Provider Market — IV Quant Lab
# Reference Date: 2026-10-03
# Mission: IV-QUANT-LICENSED-PROVIDER-PILOT-04 (§6)
# Revalidation required: every 90 days or before production promotion.

**DO NOT USE THIS DOCUMENT WITHOUT CHECKING PROVIDER_EVIDENCE_REGISTER.md FIRST.**
All claims in this document are sourced and dated in the evidence register.

---

## Summary Decision

| Role | Provider | Dataset | Status |
|---|---|---|---|
| PRIMARY_BOOTSTRAP (US equities) | Databento | EQUS.SUMMARY | **GREEN** |
| SECONDARY_FUTURE (US + UK) | Tiingo | EOD + IEX | YELLOW ($250/mo) |
| FUNDAMENTALS_FUTURE | FMP | Enterprise | YELLOW (negotiation) |
| UK/XLON Phase 1 | — | — | **BLOCKED** (no GREEN ≤ $250) |

---

## Full Comparison Matrix

| Field | Databento EQUS.SUMMARY | Twelve Data | Intrinio | FMP | Massive (Polygon) | Tiingo | Alpaca |
|---|---|---|---|---|---|---|---|
| **PROVIDER** | Databento | Twelve Data | Intrinio | Financial Modeling Prep | Massive (ex-Polygon.io) | Tiingo | Alpaca |
| **PRODUCT** | US Equities Summary | API / Business | Startup / Enterprise | Enterprise | Stocks API | EOD + Redistribution | Market Data API |
| **CURRENT?** | YES | YES | YES | YES | YES (rebrand Oct 2025) | YES | YES |
| **DEPRECATED?** | NO (replaces DBEQ.BASIC Jan 2025) | NO | NO | NO | NO | NO | NO |
| **SUNSET_DATE** | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| **CURRENT_DATASET** | EQUS.SUMMARY | All-market API | Equities / Options | Market & Fundamentals | Stocks v3 | EOD data | SIP / IEX |
| **CURRENT_ENDPOINT** | hist.databento.com | api.twelvedata.com | api-v2.intrinio.com | financialmodelingprep.com | api.massive.com (or api.polygon.io) | api.tiingo.com | data.alpaca.markets |
| **LAST_DOC_UPDATE** | 2025-01 (EQUS launch) | 2026-03 | 2026-06 | 2026 | 2025-10 (rebrand) | 2026 | 2025 |
| **US** | YES — all 15 NMS + 30 ATSs | YES | YES | YES | YES | YES | YES |
| **UK** | NO | YES (£) | NO | YES | YES | NO | NO |
| **FX** | NO | YES | NO | YES | YES | YES | NO |
| **CRYPTO** | NO | YES | NO | YES | YES | NO | YES |
| **HISTORICAL** | YES — full history | YES | YES | YES | YES (10+ years) | YES | YES |
| **INTRADAY** | YES (EQUS.MINI, subscription) | YES | YES | YES | YES | YES | YES |
| **LIVE** | YES (EQUS.MINI, subscription) | YES | YES | YES | YES (SIP) | YES (IEX) | YES (SIP) |
| **OHLCV** | YES | YES | YES | YES | YES | YES | YES |
| **TRADES** | YES | NO | NO | NO | YES | NO | YES |
| **QUOTES** | YES (EQUS.MINI) | NO | NO | NO | YES | YES (IEX) | YES |
| **L1** | YES | YES | YES | YES | YES | YES | YES |
| **L2** | YES (subscription) | NO | NO | NO | YES | NO | NO |
| **L3** | YES (subscription) | NO | NO | NO | NO | NO | NO |
| **FUNDAMENTALS** | NO | YES | YES | YES (main strength) | YES | NO | NO |
| **CORPORATE_ACTIONS** | YES (separate) | YES | NO | YES | YES | YES | NO |
| **API_TYPE** | REST | REST | REST | REST | REST | REST | REST |
| **WEBSOCKET** | YES | YES | NO | NO | YES | YES | YES |
| **COMMERCIAL_DISPLAY** | **YES — explicit, zero fees** | YES (Venture $499/mo) | YES (Startup plan) | NEGOTIATION REQUIRED | NEGOTIATION REQUIRED | YES ($250/mo startup) | NOT_FOR_SAAS |
| **DERIVED_ANALYTICS** | YES (implied by redistribution terms) | YES | YES | YES | YES | UNKNOWN | UNKNOWN |
| **AI_PROCESSING** | ASSUMED (no restriction seen) | UNKNOWN | YES (mentioned) | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |
| **CACHE** | YES (no prohibition) | YES | YES | YES | YES | YES | UNKNOWN |
| **RAW_STORAGE** | YES (pay-as-you-go = download-based) | UNKNOWN | UNKNOWN | UNKNOWN | YES | YES | UNKNOWN |
| **ATTRIBUTION** | UNKNOWN (pending rights confirmation) | UNKNOWN | YES (required) | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |
| **REDISTRIBUTION** | YES — free redistribution, explicit | YES (Venture+) | YES (Startup+) | BLOCKED (negotiation) | BLOCKED (business tier) | YES ($250/mo) | NO |
| **MONTHLY_FIXED_COST** | $0 (historical, pay-as-you-go) | $499/mo (Venture) | $333/mo (Startup) | Unknown | $2,000+/mo (business) | $250/mo (redistribution) | $99/device/mo |
| **PAY_AS_YOU_GO** | YES (historical data) | NO | NO | NO | NO | NO | NO |
| **FREE_CREDIT** | $125 (new accounts, expires 6 mo) | NO | NO | NO | NO | NO | NO |
| **STARTUP_PROGRAM** | NO (credits only) | NO | YES (phased pricing) | YES (discount mentioned) | NO | NO | NO |
| **MINIMUM_COMMITMENT** | None (PAYG) | 1 month | 1 month | Unknown | Unknown | 1 month | 1 month |
| **OWNER_CONTRACT_REQUIRED** | NO (self-serve) | NO | NO | YES (commercial display) | YES (business tier) | NO | NO |
| **STATUS** | **GREEN** | YELLOW | YELLOW | YELLOW | RED (cost) | YELLOW | RED (SaaS) |
| **SOURCE_DATE** | 2026-10-03 | 2026-10-03 | 2026-10-03 | 2026-10-03 | 2026-10-03 | 2026-10-03 | 2026-10-03 |

---

## Phase Strategy

### Phase 1 — Bootstrap / Pre-Revenue

**Provider**: Databento EQUS.SUMMARY (pay-as-you-go historical)  
**Cost**: ~$0/month (within $125 free credits)  
**Coverage**: US equities, daily OHLCV  
**Rights**: GREEN — explicit "free redistribution rights, zero license fees"  
**Limitation**: UK/XLON blocked; no live data; no fundamentals

### Phase 2 — Early Revenue

**Add**: Tiingo Redistribution ($250/month) for broader US + possible UK EOD  
OR Databento Standard subscription ($199/month) if live data needed  
**Consider**: Twelve Data ($499/month Venture) for UK + FX  
**Fundamentals**: FMP Enterprise (negotiation)  

### Phase 3 — Scale

**Multi-provider**: US live + UK + FX + fundamentals  
**Consider**: Databento full subscription + specialized secondary  

---

## DBEQ.BASIC Deprecation Status

| Field | Value |
|---|---|
| Dataset | DBEQ.BASIC |
| Status | **DEPRECATED** |
| Deprecation Date | January 13, 2025 |
| Replaced By | EQUS.SUMMARY (EOD/historical), EQUS.MINI (live) |
| Adapter Action | MIGRATE: `dataset: 'EQUS.SUMMARY'` |
| Evidence | docs/quant/PROVIDER_EVIDENCE_REGISTER.md — EV-DB-01 |

---

*Next revalidation due: 2027-01-03 (90 days) or before production promotion.*
