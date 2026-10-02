# Databento — Rights Confirmation Request
# IV-QUANT-LICENSED-PROVIDER-PILOT-04

**Prepared:** 2026-10-02  
**Prepared by:** InsightValues / Claude Code (IV-QUANT-LICENSED-PROVIDER-PILOT-04)  
**Status:** READY TO SEND — Owner must review and send to Databento support  
**Send to:** support@databento.com or via https://databento.com/support

---

## Purpose

InsightValues is a multi-tenant SaaS platform (web + Android) delivering
quantitative financial analysis to end users. We intend to use **Databento
DBEQ.BASIC** (US equities composite, OHLCV-1d historical) as a data source.

Before entering commercial operation we require **written confirmation** of
the following rights. Your public documentation at https://databento.com/blog/dbeq-basic
indicates that commercial redistribution and display are permitted under
your derived-use license with participating NMS exchanges, and we want
formal confirmation for our compliance records.

---

## Questions Requiring Written Confirmation

### 1. SaaS Commercial Use
May we use DBEQ.BASIC data within a multi-tenant SaaS application that
charges subscription fees to end users?

### 2. Web Display
May we display derived analytics (OHLCV charts, return metrics, volatility,
Sharpe ratio, moving averages) computed from DBEQ.BASIC data to users
via a web browser interface?

### 3. Mobile Display (Android)
May we display the same derived analytics via a native Android application?

### 4. Free-Tier Users
May we provide analytics to users on a free (no-cost) tier of our platform,
where such users see results computed from DBEQ.BASIC data?

### 5. Paying Users
Same question for paying subscribers.

### 6. Derived Analytics
May we compute and display derived statistics (e.g. volatility, Sharpe ratio,
maximum drawdown, correlation matrices, custom indicators) from DBEQ.BASIC
raw OHLCV data without displaying the raw OHLCV values themselves?

### 7. AI / ML Processing
May we use DBEQ.BASIC data as input to AI/ML models and display the model
outputs (e.g. risk summaries, narrative explanations of statistical results)
to end users? We do not redistribute raw data; outputs are derived analytics.

### 8. Server-Side Caching
May we cache DBEQ.BASIC historical OHLCV bars on our servers for up to
[X] days to reduce API calls and latency? What is the maximum permitted
cache duration?

### 9. Long-Term Raw Data Retention
May we retain raw DBEQ.BASIC OHLCV bars in our server-side database
indefinitely, or is there a maximum retention period for raw (unadjusted)
price data?

### 10. Attribution Requirements
Must we display attribution to Databento and/or the underlying exchanges
when showing analytics to end users? If so:
  a. What attribution text or logo is required?
  b. On which screens must it appear?
  c. Is attribution required for derived analytics that do not display raw prices?

### 11. Redistribution Restrictions
May end users export or download raw OHLCV data from our platform? If not,
we understand this is prohibited and will implement technical controls.

### 12. Exchange-Reporting Obligations
Under the DBEQ.BASIC derived-use license with NMS exchanges, are there any
reporting obligations (e.g. subscriber counts, usage reports) that we must
fulfil directly with exchanges, or does Databento handle all exchange
obligations on our behalf?

---

## Our Platform Profile

- **Type:** Multi-tenant SaaS (web + Android)
- **Data usage:** Historical EOD (OHLCV-1d), US equities only (pilot phase)
- **User scope:** Individual retail investors and financial professionals
- **Raw data display:** We do NOT display raw tick-level or intraday data;
  only daily OHLCV is used for computation
- **Redistribution:** We do NOT redistribute raw OHLCV to third parties;
  only derived analytics are shown to our own subscribers
- **Data volume (pilot):** < 100 symbols × 5 years history = < 25 MB

---

## Classification of Each Item (Internal)

| Item | Pilot Required | Commercial Required | Notes |
|------|---------------|--------------------|----|
| SaaS commercial use (Q1) | YES | YES | Core license question |
| Web display (Q2) | YES | YES | Core display question |
| Android display (Q3) | YES | YES | Core display question |
| Free-tier users (Q4) | YES | YES | Affects tier model |
| Paying users (Q5) | YES | YES | Core commercial question |
| Derived analytics (Q6) | YES | YES | Primary use case |
| AI/ML processing (Q7) | NO | YES | IVE integration (future) |
| Server-side caching (Q8) | YES | YES | Architecture requirement |
| Long-term raw retention (Q9) | NO | YES | Post-pilot scope |
| Attribution requirements (Q10) | YES | YES | Compliance |
| Redistribution restrictions (Q11) | NO | YES | Product boundary |
| Exchange-reporting (Q12) | NO | YES | Compliance |

---

## Next Step

1. Owner reviews this message
2. Owner sends to Databento support
3. Owner forwards written confirmation to Claude Code / Agente Martins
4. Upon confirmation, remove PILOT_RIGHTS_UNCONFIRMED gate from the
   commercial launch checklist

---

*This document was prepared as part of IV-QUANT-LICENSED-PROVIDER-PILOT-04.*
*Do not send without Owner review.*
