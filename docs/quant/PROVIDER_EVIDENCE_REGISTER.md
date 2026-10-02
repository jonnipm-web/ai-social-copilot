# Provider Evidence Register — IV Quant Lab
# Mission: IV-QUANT-LICENSED-PROVIDER-PILOT-04 (§24)
# Access Date: 2026-10-03
# Policy: Every external claim about a provider must have an entry here.

---

## How to Use This Register

Every entry: `EV-{PROVIDER}-{SEQ}` with URL, access date, document/page, and the
specific claim being registered. Claims here are RAW observations — they do not
constitute legal advice. Owner must verify current terms before any commercial commitment.

---

## Databento

### EV-DB-01 — DBEQ.BASIC Deprecated January 13 2025

| Field | Value |
|---|---|
| Evidence ID | EV-DB-01 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://databento.com/blog/upcoming-changes-to-pricing-plans-in-january-2025 |
| Document | "Upcoming changes to pricing plans in January 2025" |
| Claim | DBEQ.BASIC (Databento Equities Basic) was deprecated on January 13, 2025; IEX TOPS live data replaced by EQUS.MINI on February 1, 2025 |
| Criticality | CRITICAL — drives adapter migration decision |

### EV-DB-02 — EQUS.SUMMARY is the Current EOD OHLCV Dataset

| Field | Value |
|---|---|
| Evidence ID | EV-DB-02 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://databento.com/blog/introducing-databento-us-equities |
| Document | "Introducing Databento US Equities" |
| Claim | EQUS.SUMMARY provides "100% intraday volume on a delayed basis and consolidated end-of-day prices (OHLCV) across all NMS exchanges and ATSs" |
| Criticality | CRITICAL — confirms replacement dataset |

### EV-DB-03 — Zero License Fees and Free Redistribution Rights

| Field | Value |
|---|---|
| Evidence ID | EV-DB-03 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://www.streetinsider.com/PRNewswire/Databento+Launches+the+Industrys+First+US+Equities+Bundle+with+Zero+License+Fees/22285216.html |
| Document | Databento press release: "Databento Launches the Industry's First US Equities Bundle with Zero License Fees" |
| Claim | "The only financial data provider to offer real-time stock data with zero license fees, free redistribution rights, and full exchange compliance" |
| Criticality | HIGH — GREEN rights claim for commercial display |

### EV-DB-04 — EQUS.MINI Permissive Distribution for Web Apps

| Field | Value |
|---|---|
| Evidence ID | EV-DB-04 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://databento.com/blog/databento-us-equities-mini-now-available |
| Document | "Databento US Equities Mini now available" |
| Claim | EQUS.MINI is "free to license for distribution, display, and non-display applications and is ideal for web apps, brokerages, systematic trading, and cloud-based environments" |
| Criticality | HIGH — confirms permissive display rights |

### EV-DB-05 — Pay-As-You-Go Historical Data Remains Available

| Field | Value |
|---|---|
| Evidence ID | EV-DB-05 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://docs.databento.com/knowledge-base/new-users/usage-based-pricing-and-data-credits |
| Document | "Usage-based pricing and credits" (Databento docs) |
| Claim | "Pay-as-you-go pricing for historical data will remain one of Databento's core features. Historical data is billed per byte consumed, and you pay only for the data that you've used with no monthly subscription fee." |
| Criticality | CRITICAL — confirms ~$0/month for pilot scale |

### EV-DB-06 — $125 Free Credits for New Accounts

| Field | Value |
|---|---|
| Evidence ID | EV-DB-06 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://docs.databento.com/knowledge-base/new-users/usage-based-pricing-and-data-credits |
| Document | "Usage-based pricing and credits" (Databento docs) |
| Claim | "All new users receive $125 in free credits upon signup, which can be used on historical data or towards the cost of the first month of a subscription plan; credits expire after 6 months." |
| Criticality | MEDIUM — extends free pilot window |

### EV-DB-07 — EQUS.SUMMARY Supports ohlcv-1d Schema

| Field | Value |
|---|---|
| Evidence ID | EV-DB-07 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://nautilustrader.io/docs/latest/tutorials/databento_overview/ |
| Document | NautilusTrader Databento integration docs (third-party, cross-reference) |
| Claim | EQUS.SUMMARY supports `ohlcv-1d` schema; the ohlcv-1d schema is standardized across Databento datasets |
| Criticality | HIGH — confirms adapter schema compatibility |

### EV-DB-08 — Standard Subscription Plan Pricing

| Field | Value |
|---|---|
| Evidence ID | EV-DB-08 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://databento.com/blog/updates-to-subscription-pricing |
| Document | "Updates to subscription pricing" |
| Claim | Standard plan available for $199/month (includes unlimited live data + historical); pay-as-you-go historical does not require a subscription |
| Criticality | MEDIUM — only relevant if live data or bulk history needed beyond PAYG |

### EV-DB-09 — EQUS.SUMMARY Covers All NMS Exchanges

| Field | Value |
|---|---|
| Evidence ID | EV-DB-09 |
| Provider | Databento |
| Access Date | 2026-10-03 |
| Source URL | https://databento.com/blog/introducing-databento-us-equities |
| Document | "Introducing Databento US Equities" |
| Claim | "Brings data from 15 US equities exchanges and 30 ATSs together under a single pricing plan" |
| Criticality | MEDIUM — confirms EQUS.SUMMARY coverage broader than DBEQ.BASIC |

---

## Twelve Data

### EV-TD-01 — Venture Plan Pricing and Display Rights

| Field | Value |
|---|---|
| Evidence ID | EV-TD-01 |
| Provider | Twelve Data |
| Access Date | 2026-10-03 |
| Source URL | https://twelvedata.com/pricing-business |
| Document | Business Pricing page |
| Claim | Venture plan at $499/month ($414/month annual) includes "external display data access" for 70+ markets including US, EU, AU |
| Criticality | MEDIUM — documents Phase 2 option |

### EV-TD-02 — March 2026 Plan Updates

| Field | Value |
|---|---|
| Evidence ID | EV-TD-02 |
| Provider | Twelve Data |
| Access Date | 2026-10-03 |
| Source URL | https://twelvedata.com/news/march-2026-updates |
| Document | "March 2026 updates" |
| Claim | Plans restructured in March 2026 for better LLM tool integration |
| Criticality | LOW — confirms docs are current as of 2026 |

---

## Intrinio

### EV-IN-01 — Startup Plan with Commercial Display Rights

| Field | Value |
|---|---|
| Evidence ID | EV-IN-01 |
| Provider | Intrinio |
| Access Date | 2026-10-03 |
| Source URL | https://intrinio.com/pricing |
| Document | Intrinio Pricing page |
| Claim | Startup plan from $333/month (6 months) → $666/month → $999/month; includes "commercial use and display rights with a business-wide license" and "unlimited number of external users" |
| Criticality | MEDIUM — expensive for bootstrap; documents Phase 2 option |

---

## Financial Modeling Prep (FMP)

### EV-FMP-01 — Commercial Display Requires Negotiation

| Field | Value |
|---|---|
| Evidence ID | EV-FMP-01 |
| Provider | Financial Modeling Prep |
| Access Date | 2026-10-03 |
| Source URL | https://site.financialmodelingprep.com/pricing-plans |
| Document | FMP Pricing Plans |
| Claim | Standard plans are not licensed for commercial display or redistribution; Enterprise plan required for "data display, redistribution, custom rate limits, and negotiated licensing" — specific pricing not published, requires direct negotiation |
| Criticality | MEDIUM — YELLOW status; Phase 2 fundamentals option |

---

## Massive (formerly Polygon.io)

### EV-MA-01 — Rebrand and Business Pricing

| Field | Value |
|---|---|
| Evidence ID | EV-MA-01 |
| Provider | Massive (ex-Polygon.io) |
| Access Date | 2026-10-03 |
| Source URL | https://qveris.ai/guides/polygon-pricing-optimized/ |
| Document | "Polygon.io Pricing 2026 (Massive): Plans & Limits" |
| Claim | Polygon.io rebranded to Massive on October 30, 2025. Business/commercial SaaS pricing starts at $2,000/month. api.polygon.io continues to work. |
| Criticality | MEDIUM — documents provider status and prohibitive cost for bootstrap |

---

## Tiingo

### EV-TI-01 — Redistribution Pricing for Startups

| Field | Value |
|---|---|
| Evidence ID | EV-TI-01 |
| Provider | Tiingo |
| Access Date | 2026-10-03 |
| Source URL | https://www.tiingo.com/about/pricing |
| Document | Tiingo Pricing page |
| Claim | Display redistribution (SaaS, web app) starts at $250/month for startups (EOD + IEX). Internal commercial use: $50/month (no redistribution). Basic/Power plans: internal/personal only. |
| Criticality | MEDIUM — cheapest confirmed redistribution option after Databento |

---

## Alpha Vantage

### EV-AV-01 — Commercial Display Unclear

| Field | Value |
|---|---|
| Evidence ID | EV-AV-01 |
| Provider | Alpha Vantage |
| Access Date | 2026-10-03 |
| Source URL | https://www.alphavantage.co/ |
| Document | Alpha Vantage pricing page and related searches |
| Claim | Paid plans from $49.99/month (75 req/min) to $249.99/month (1200 req/min). Commercial SaaS display rights: "commercial use needs separate licensing" — terms not clearly published for SaaS display |
| Criticality | LOW — YELLOW status; not selected |

---

## Alpaca

### EV-AL-01 — Not Suitable for Multi-User SaaS Display

| Field | Value |
|---|---|
| Evidence ID | EV-AL-01 |
| Provider | Alpaca |
| Access Date | 2026-10-03 |
| Source URL | https://docs.alpaca.markets/us/docs/about-market-data-api |
| Document | Alpaca Market Data API docs |
| Claim | Business plan: $99/device/month (internal business use only). Broker API for multi-user platforms requires custom bespoke pricing. Not structured for SaaS external display at fixed predictable cost. |
| Criticality | LOW — RED status for Phase 1 |

---

## EODHD

### EV-EO-01 — Commercial Plans Pricing

| Field | Value |
|---|---|
| Evidence ID | EV-EO-01 |
| Provider | EODHD |
| Access Date | 2026-10-03 |
| Source URL | https://eodhd.com/commercial-pricing |
| Document | EODHD Commercial Pricing |
| Claim | Personal plans ($19.99–$99.99/month) are for personal use ONLY. Commercial Internal: $399/month. Commercial Enterprise: $2,499/month. |
| Criticality | LOW — too expensive for bootstrap |

---

## Register Maintenance

- Add a new entry whenever a new external claim about a provider is relied upon
- Update `CURRENT?` and `DEPRECATED?` columns in CURRENT_PROVIDER_MARKET_2026-10.md
- Record next revalidation date (90 days or before production promotion)
- Do NOT remove old entries — mark them SUPERSEDED with the new EV ID

**Next full revalidation: 2027-01-03** (90 days from 2026-10-03)
