# InsightValues Quant — Vendor Licensing Dossier (IV-QUANT-REAL-DATA-READINESS-03)

Purpose: turn the vendor research into a **commercial checklist the Owner
can act on**. This document selects **no vendor**, signs nothing, buys
nothing, and sends nothing. API access is not a licence: a working key only
proves that the vendor answers, not that InsightValues may display, store or
redistribute the data (brief §06).

Public documentation re-read on **2026-09-24**. Prices and terms change; every
figure below is "as published on that date", not a quote.

Answer codes (brief §48):

| Code | Meaning |
|---|---|
| **CONFIRMED_PUBLIC_DOC** | stated in the vendor's current public page (source linked) |
| **REQUIRES_WRITTEN_CONFIRMATION** | public text is silent, conditional or ambiguous for our use — must be confirmed in writing |
| **NOT_SUPPORTED** | public text says it is not allowed / not offered on the plan named |
| **UNKNOWN** | nothing found; not inferred |

A commercial right is **never inferred** from silence.

## 0. Our intended use (what we must license)

InsightValues is a SaaS with web + Android clients. The target Quant use is:
server-side retrieval (Edge Function), server-side cache, deterministic
analytics, and **display** of raw prices and derived analytics to
authenticated end users (free and paying), with US (XNYS/XNAS) and UK
(XLON) equities, daily bars first; intraday later. No data resale / API
redistribution is intended. LLM features (IVE) may later *explain* derived
numbers — they never compute them.

## 1. Twelve Data — Business plans (baseline PRIMARY candidate)

Sources: [Commercial and personal usage](https://support.twelvedata.com/en/articles/5332349-commercial-and-personal-usage),
[Pricing](https://twelvedata.com/pricing), [API docs](https://twelvedata.com/docs),
[US equities market data](https://support.twelvedata.com/en/articles/9935903-us-equities-market-data).

| # | Question | Answer | Evidence / note |
|---|---|---|---|
| 1 | SaaS commercial use | **CONFIRMED_PUBLIC_DOC** (Business plans only) | Business plans "allow the use of data for commercial display and internal usage"; Individual plans do **not** (NOT_SUPPORTED on Basic/Grow/Pro/Ultra). |
| 2 | Web display | REQUIRES_WRITTEN_CONFIRMATION | "commercial display" is granted generically; channel scope not stated. |
| 3 | Android/mobile display | REQUIRES_WRITTEN_CONFIRMATION | same as #2. |
| 4 | Display to paying users | REQUIRES_WRITTEN_CONFIRMATION | implied by "commercial display" but user-count / pricing tiers not stated. |
| 5 | Display to free users | REQUIRES_WRITTEN_CONFIRMATION | not addressed. |
| 6 | Show derived analytics | UNKNOWN | derived data not addressed. |
| 7 | Store derived analytics | UNKNOWN | not addressed. |
| 8 | Store raw data | UNKNOWN | storage not addressed. |
| 9 | Redistribute raw data | **NOT_SUPPORTED** without separate agreement | "Any redistribution of data requires a separate agreement"; redistribution add-ons exist. |
| 10 | Display historical data | REQUIRES_WRITTEN_CONFIRMATION | covered by "commercial display"? not explicit. |
| 11 | Intraday display | REQUIRES_WRITTEN_CONFIRMATION | real-time/intraday display subject to exchange licensing. |
| 12 | Attribution required | UNKNOWN | not found in docs. |
| 13 | Extra exchange fees | **CONFIRMED_PUBLIC_DOC** (that they may apply) | "subject to exchange licensing requirements"; amounts UNKNOWN. |
| 14 | US equities | **CONFIRMED_PUBLIC_DOC** | pricing lists real-time US equities/ETFs. |
| 15 | UK/LSE | REQUIRES_WRITTEN_CONFIRMATION | "outside the United States requires additional approval for commercial use"; LSE not named in docs read. |
| 16 | FX | **CONFIRMED_PUBLIC_DOC** (data offered) | `/forex_pairs`, `/currencies/exchange-rate`; commercial display rights for FX not separately stated. |
| 17 | Corporate actions | **CONFIRMED_PUBLIC_DOC** | Dividends, Splits (+ calendars) endpoints. |
| 18 | Adjusted / unadjusted | **CONFIRMED_PUBLIC_DOC** | `/time_series` `adjust`: all, splits, dividends, none (default splits). |
| 19 | Backend/server API use | REQUIRES_WRITTEN_CONFIRMATION | not restricted in text read; confirm server-side fan-out to many users is covered. |
| 20 | Cache allowed / duration | UNKNOWN | not addressed. |
| 21 | Enterprise/API redistribution | **NOT_SUPPORTED** on standard plans | separate agreement / add-on. |
| 22 | AI/ML restrictions | UNKNOWN | not addressed. |

## 2. EODHD — B2B / commercial plans (baseline SECONDARY)

Sources: [Commercial pricing](https://eodhd.com/commercial-pricing),
[EOD historical API](https://eodhd.com/financial-apis/api-for-historical-data-and-volumes), [Pricing](https://eodhd.com/pricing).

| # | Question | Answer | Evidence / note |
|---|---|---|---|
| 1 | SaaS commercial use | REQUIRES_WRITTEN_CONFIRMATION | "Internal Use" plan: "restricted to being used solely within your company"; display to outsiders **NOT_SUPPORTED** on that plan. Enterprise/Custom terms not public. Personal plans: no commercial use. |
| 2 | Web display | REQUIRES_WRITTEN_CONFIRMATION (Enterprise/Custom) · NOT_SUPPORTED (Internal Use) | "Displaying the data … outside your company is not permissible." |
| 3 | Android/mobile display | same as #2 | |
| 4 | Paying users | REQUIRES_WRITTEN_CONFIRMATION | |
| 5 | Free users | REQUIRES_WRITTEN_CONFIRMATION | |
| 6 | Show derived analytics | UNKNOWN | |
| 7 | Store derived analytics | UNKNOWN | |
| 8 | Store raw data | UNKNOWN | page says contact sales for storage terms. |
| 9 | Redistribute raw data | NOT_SUPPORTED on public plans | Custom plan FAQ mentions clients "partially download the data" → REQUIRES_WRITTEN_CONFIRMATION for any such right. |
| 10 | Historical display | REQUIRES_WRITTEN_CONFIRMATION | |
| 11 | Intraday display | REQUIRES_WRITTEN_CONFIRMATION | intraday is a separate API. |
| 12 | Attribution | UNKNOWN | |
| 13 | Exchange fees | UNKNOWN | not stated on the commercial page. |
| 14 | US equities | **CONFIRMED_PUBLIC_DOC** | `.US` suffix, all US venues; data from Nasdaq Cloud API. |
| 15 | UK/LSE | **CONFIRMED_PUBLIC_DOC** (coverage) | `BP.LSE`; "LSE for UK data". Display rights: REQUIRES_WRITTEN_CONFIRMATION. |
| 16 | FX | **CONFIRMED_PUBLIC_DOC** (data offered) | `EURUSD.FOREX`. |
| 17 | Corporate actions | **CONFIRMED_PUBLIC_DOC** | splits/dividends reflected in `adjusted_close`. |
| 18 | Adjusted / unadjusted | **CONFIRMED_PUBLIC_DOC** | OHLC raw; `adjusted_close` for splits and dividends (recomputed retroactively — never a stable key). |
| 19 | Backend API use | REQUIRES_WRITTEN_CONFIRMATION | |
| 20 | Cache | UNKNOWN | |
| 21 | Enterprise redistribution | REQUIRES_WRITTEN_CONFIRMATION | Custom only. |
| 22 | AI/ML | UNKNOWN | |

## 3. Massive (formerly Polygon.io) — Business (baseline US SPECIALIST)

Sources: [Pricing](https://massive.com/pricing), [Business pricing](https://massive.com/business).

| # | Question | Answer | Evidence / note |
|---|---|---|---|
| 1 | SaaS commercial use | REQUIRES_WRITTEN_CONFIRMATION | Individual plans (Basic/Starter/Developer/Advanced) are "Individual use only" → NOT_SUPPORTED. "Stocks Business" exists; display/redistribution terms not on the page. |
| 2 | Web display | REQUIRES_WRITTEN_CONFIRMATION | |
| 3 | Android/mobile display | REQUIRES_WRITTEN_CONFIRMATION | |
| 4 | Paying users | REQUIRES_WRITTEN_CONFIRMATION | |
| 5 | Free users | REQUIRES_WRITTEN_CONFIRMATION | |
| 6 | Show derived analytics | UNKNOWN | |
| 7 | Store derived analytics | UNKNOWN | |
| 8 | Store raw data | UNKNOWN | |
| 9 | Redistribute raw data | UNKNOWN | |
| 10 | Historical display | REQUIRES_WRITTEN_CONFIRMATION | Business: "20+ years historical". |
| 11 | Intraday display | REQUIRES_WRITTEN_CONFIRMATION | real-time feeds are separate paid expansions (Nasdaq Basic, Cboe EDGX, Full Market). |
| 12 | Attribution | UNKNOWN | |
| 13 | Exchange fees | **CONFIRMED_PUBLIC_DOC** (feed add-ons priced) | e.g. "Full Market Delayed" $499/mo, "Nasdaq Basic" $1,999/mo; exchange-direct fees beyond these UNKNOWN. |
| 14 | US equities | **CONFIRMED_PUBLIC_DOC** | "US coverage". |
| 15 | UK/LSE | **NOT_SUPPORTED** (per public stock plans) | stock plans are US-only; partner data (e.g. TMX) "contact for pricing"; no LSE listed. |
| 16 | FX | UNKNOWN (not re-verified this pass) | |
| 17 | Corporate actions | **CONFIRMED_PUBLIC_DOC** | Business plan lists corporate actions. |
| 18 | Adjusted / unadjusted | UNKNOWN (not re-verified this pass) | |
| 19 | Backend API use | REQUIRES_WRITTEN_CONFIRMATION | |
| 20 | Cache | UNKNOWN | |
| 21 | Enterprise redistribution | REQUIRES_WRITTEN_CONFIRMATION | Enterprise "custom", multi-team licensing. |
| 22 | AI/ML | UNKNOWN | |

## 4. Sharadar (Nasdaq Data Link) — baseline RESEARCH

Sources: [sharadar.com](https://sharadar.com/), [SEP on Nasdaq Data Link](https://data.nasdaq.com/databases/SEP) (page did not render its body on 2026-09-24; terms below from the vendor's public descriptions), [QuantRocket Sharadar](https://www.quantrocket.com/sharadar/).

| # | Question | Answer | Evidence / note |
|---|---|---|---|
| 1 | SaaS commercial use | **NOT_SUPPORTED** on individual licence; REQUIRES_WRITTEN_CONFIRMATION for institutional | non-professional vs professional licensing; sharing within/outside the organization requires "the appropriate institutional or distribution license". |
| 2–5 | Display (web / mobile / paid / free) | REQUIRES_WRITTEN_CONFIRMATION | distribution licence required. |
| 6–7 | Derived analytics (show / store) | UNKNOWN | |
| 8 | Store raw data | UNKNOWN | bulk download offered; retention terms not found. |
| 9 | Redistribute | **NOT_SUPPORTED** without distribution licence | |
| 10 | Historical display | REQUIRES_WRITTEN_CONFIRMATION | |
| 11 | Intraday | **NOT_SUPPORTED** | end-of-day product. |
| 12 | Attribution | UNKNOWN | |
| 13 | Exchange fees | UNKNOWN | |
| 14 | US equities | **CONFIRMED_PUBLIC_DOC** | US exchanges, EOD. |
| 15 | UK/LSE | **NOT_SUPPORTED** | US-only product. |
| 16 | FX | **NOT_SUPPORTED** | not in the bundle. |
| 17 | Corporate actions | **CONFIRMED_PUBLIC_DOC** | corporate actions table. |
| 18 | Adjusted / unadjusted | REQUIRES_WRITTEN_CONFIRMATION | not re-verified this pass. |
| 19 | Backend API use | REQUIRES_WRITTEN_CONFIRMATION | |
| 20 | Cache | UNKNOWN | |
| 21 | Enterprise redistribution | REQUIRES_WRITTEN_CONFIRMATION | distribution licence. |
| 22 | AI/ML | UNKNOWN | |

Role: point-in-time **research/backtest** data, not an end-user display
source, unless a distribution licence is obtained.

## 5. DEV — CSV upload / synthetic fixtures

User CSV (USER_UPLOAD, USER_SUPPLIED, evidence WEAK) and the in-process
`SYNTHETIC_PROVIDER` (FIXTURE, SYNTHETIC_FIXTURE) need no licence: no third
party data. They remain the only data sources wired today.

## 6. Cost model (public prices, 2026-09-24 — not quotes)

| Vendor | Lowest plan with *commercial display* in public text | Published price | Also needed | Unknown |
|---|---|---|---|---|
| Twelve Data | Business (Venture/Enterprise tiers, per support article) | not shown on the individual pricing page read | exchange licences; non-US approval; redistribution add-on if ever needed | Business price, exchange fees, UK approval terms |
| EODHD | none public (Internal Use forbids external display) | Internal Use £399/mo; Enterprise £2,499/mo; Custom on request | written display right (likely Custom) | Custom price, exchange fees |
| Massive | Stocks Business (terms to confirm) | $2,499/mo + feed expansions ($399–$1,999/mo each) | UK source elsewhere (no LSE) | display/redistribution terms |
| Sharadar | distribution licence (not public) | not public | UK/FX source elsewhere | licence price |

Individual/personal plans (Twelve Data Basic–Ultra, EODHD All-In-One,
Massive Basic–Advanced, Sharadar individual) are **excluded**: their own
terms forbid our use. Price alone must not decide — licence scope, exchange
fees, UK+US coverage, history depth, request volume and display rights all
weigh in.

## 7. Status (brief §51 — no winner)

| Vendor | TECHNICAL PREFERENCE | LICENSING PREFERENCE | COST | Status |
|---|---|---|---|---|
| Twelve Data Business | high (US + FX + corporate actions + explicit `adjust`; UK to confirm) | highest (only one whose public text grants commercial display on a plan) | COST UNKNOWN | **BLOCKED_PENDING_WRITTEN_RIGHTS** |
| EODHD | high (US + LSE confirmed, raw+adjusted) | medium (external display not in public plans) | Internal £399 / Enterprise £2,499 public; display plan COST UNKNOWN | **BLOCKED_PENDING_WRITTEN_RIGHTS** |
| Massive Business | medium (US only) | medium | $2,499/mo + feeds | **BLOCKED_PENDING_WRITTEN_RIGHTS** |
| Sharadar | research only | low for display | COST UNKNOWN | research use only |

The commercial decision belongs to the Owner (Paulo) with Agente Martins.

## 8. Owner contact package — DRAFTS, NOT SENT

Send only after Owner review. No negotiation, no volume promise, no
acceptance of terms. Replace `[…]` before sending.

### 8.1 Twelve Data

> **Subject:** Licensing questions — Business plan for a SaaS analytics app (web + Android)
>
> Hello Twelve Data team,
>
> I run InsightValues, a SaaS with web and Android clients. We are evaluating
> a Business plan to show end-of-day (later intraday) prices and analytics
> derived from them (returns, volatility, drawdown, correlation) to
> authenticated users. We do not intend to resell or redistribute raw data.
> Before choosing a plan, could you confirm in writing:
>
> 1. Which Business tier covers display of raw prices and derived analytics
>    to end users on web **and** mobile apps, including both free and paying users?
> 2. Whether commercial display of **London Stock Exchange** data is
>    available, and what the "additional approval" for non-US data involves.
> 3. Exchange licensing fees that would apply to US (NYSE/Nasdaq) and LSE
>    data for delayed/end-of-day display, and who contracts them.
> 4. Whether we may store raw data and derived analytics server-side, and
>    for how long (including after the subscription ends); any caching limits.
> 5. Whether attribution is required and in what form.
> 6. Whether server-side (backend) API calls serving many end users are permitted under one account.
> 7. Any restriction on processing the data with AI/ML models (e.g. an
>    assistant explaining analytics the system computed).
>
> This is an information request only; we are not committing to a purchase at this stage.
>
> Kind regards, [Owner name] — InsightValues — [contact]

### 8.2 EODHD

> **Subject:** Licensing for external display in a SaaS app (US + LSE end-of-day)
>
> Hello EODHD team,
>
> We are evaluating EODHD for InsightValues, a SaaS with web and Android
> apps. Your Internal Use plan excludes display outside the company. We would
> need to show end-of-day prices (US and LSE) and analytics derived from them
> to authenticated end users (free and paying), without redistributing raw data. Could you confirm in writing:
>
> 1. Which plan (Enterprise or Custom) permits that display on web and mobile, and its price basis.
> 2. Exchange fees applicable for US and LSE end-of-day display.
> 3. Rules for storing raw data and derived analytics server-side, cache duration, and retention after termination.
> 4. Attribution requirements.
> 5. Any restriction on AI/ML processing of the data.
>
> Information request only — no commitment at this stage.
>
> Kind regards, [Owner name] — InsightValues — [contact]

### 8.3 Massive

> **Subject:** Stocks Business — display rights for a SaaS app
>
> Hello Massive team,
>
> We are evaluating Stocks Business for InsightValues (web + Android SaaS).
> We would display US equity end-of-day/delayed prices and derived analytics
> to authenticated end users, without redistributing raw data. Could you confirm in writing:
>
> 1. Whether Stocks Business permits that display to free and paying end users on web and mobile.
> 2. Which feed expansions / exchange fees are required for delayed or end-of-day display.
> 3. Storage and caching rules for raw data and derived analytics, and retention after termination.
> 4. Attribution requirements and any AI/ML processing restrictions.
> 5. Whether the startup programme applies and its conditions (information only).
>
> Information request only — no commitment at this stage.
>
> Kind regards, [Owner name] — InsightValues — [contact]

### 8.4 Sharadar / Nasdaq Data Link

> **Subject:** Distribution licence scope — derived analytics in a SaaS app
>
> Hello,
>
> We are considering Sharadar US equity prices and fundamentals for
> InsightValues. Could you describe the licence required to (a) use the
> data internally for research and (b) show analytics **derived** from it
> (not raw data) to end users of a web/mobile SaaS, plus storage/retention
> terms and any AI/ML restrictions?
>
> Information request only.
>
> Kind regards, [Owner name] — InsightValues — [contact]
