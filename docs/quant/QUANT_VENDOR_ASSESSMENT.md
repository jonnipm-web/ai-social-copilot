# InsightValues Quant — Market-Data Vendor Assessment (documentary, no purchase)

Status date: 2026-09-23. **No account created, no card entered, no API key,
no integration.** Web research only; every claim is labelled:

* **FACT** — stated on the vendor's own page (source linked).
* **REPORTED** — from a third-party page; not confirmed on the vendor page → NOT_VERIFIED.
* **DOCUMENTED LIMITATION** — a restriction the vendor states.
* **UNKNOWN** — not found; must be asked before any decision.

Prices change; nothing here is a quote. Licensing/redistribution is treated
as an **architectural** criterion: the product displays data to end users,
which is *redistribution/display* in exchange terms (LSE: "Licensing is
required for … Redistribution, Derived Data, … Non-display use" —
[LSE Market Data Licensing](https://www.londonstockexchange.com/equities-trading/market-data/market-data-licensing)).

## 1. Requirements derived from the product

1. US **and** UK (XLON) equities/ETFs/indices, EOD first; intraday later.
2. Split/dividend-adjusted **and** raw prices (Foundation keeps both honest).
3. A licence that allows **displaying** derived analytics/prices to paying end users.
4. Timestamps + corporate-action metadata good enough to fill `sourceAsOf`/`adjustment`.
5. REST (Edge Function fetch through `safe_fetch`); no SDK required.
6. Free/dev tier usable for **internal** development without violating terms.

## 2. Candidates

### Massive (formerly Polygon.io)
* FACT/REPORTED: rebranded Polygon.io → Massive (Oct 2025); `api.polygon.io` keeps working; REST, WebSocket, S3 flat files; US stocks, options, indices, forex, crypto, futures ([api-evangelist/polygon](https://github.com/api-evangelist/polygon), [LSE Directory profile](https://www.londonstrategicedge.com/directory/fundamental-data/polygon-io-massive/)).
* REPORTED (NOT_VERIFIED): plans Basic free / Starter $29 / Developer $79 / Advanced $199 per month; **business contracts required for redistribution and exchange-licensed data** ([apis.io plan listing](https://apis.io/plans/polygon-io/polygon-io-plans-pricing/)).
* DOCUMENTED LIMITATION: coverage is **US-centric** — no evidence of London equities.
* UNKNOWN: display-licence price for a consumer app.

### Twelve Data
* FACT: Personal plans (Basic/Grow/Pro/Ultra) "do not permit" redistribution or "commercial display of data to third parties"; Business plans (Venture/Enterprise/Enterprise+) enable "commercial display" subject to exchange licensing; outside the US commercial use needs "additional approval"; redistribution requires a separate agreement ([Twelve Data — Commercial and personal usage](https://support.twelvedata.com/en/articles/5332349-commercial-and-personal-usage)).
* FACT: offers "Redistribution Rights Add-Ons" for real-time and delayed feeds ([US equities market data](https://support.twelvedata.com/en/articles/9935903-us-equities-market-data)).
* REPORTED: global coverage incl. LSE, stocks/ETF/indices/FX/crypto, REST + WebSocket.
* UNKNOWN: Business plan price; whether LSE display needs a direct LSE licence on top.

### EODHD (EOD Historical Data)
* FACT/REPORTED: EOD for 60+ exchanges **including LSE** (`.LSE` suffix); raw **and** adjusted prices; exchanges updated 2–3 h after close; 30+ years US history, 15–20 years most European markets ([EODHD historical API](https://eodhd.com/financial-apis/api-for-historical-data-and-volumes), [pricing](https://eodhd.com/pricing)).
* DOCUMENTED LIMITATION: personal self-serve plans do not permit commercial use ([commercial pricing](https://eodhd.com/commercial-pricing)).
* REPORTED (NOT_VERIFIED): B2B "Internal Use" from €399/month, Enterprise €2 499/month, custom from €399 ([commercial pricing](https://eodhd.com/commercial-pricing)).
* UNKNOWN: whether "Internal Use" allows end-user display (the name suggests not); redistribution terms.

### Tiingo
* FACT: Basic/Power accounts are "internal and personal use only"; Commercial accounts are "internal commercial usage" — **no redistribution in any form** without a special agreement ([Tiingo pricing](https://www.tiingo.com/about/pricing), [Terms](https://app.tiingo.com/tos/)).
* REPORTED (NOT_VERIFIED): display-redistribution tiers from $250/month (startup) / $500 (enterprise), flat-rate.
* DOCUMENTED LIMITATION: focus on US EOD + IEX; UK coverage UNKNOWN.

### Alpha Vantage
* FACT: free tier 25 requests/day; commercial use → contact premium@alphavantage.co; redistribution/exchange-licensed data need separate onboarding ([Terms of Service](https://www.alphavantage.co/terms_of_service/), [Premium](https://www.alphavantage.co/premium/)).
* Assessment: licence path opaque; free tier unusable beyond experiments.

### Finnhub
* FACT/REPORTED: free tier ~60 calls/min for personal non-commercial use; monetised apps or redistribution need a paid plan; data must be deleted at subscription end ([FAQ](https://finnhub.io/faq), [startup/enterprise pricing](https://finnhub.io/pricing-startups-and-enterprise)).
* Strength: fundamentals/estimates breadth (Q5). UK EOD depth UNKNOWN.

### Nasdaq Data Link (Sharadar)
* FACT/REPORTED: US EOD prices + point-in-time fundamentals since 1998; "may not offer … for … commercial redistribution"; professional/institutional licence required for professional use ([Sharadar SEP](https://data.nasdaq.com/databases/SEP), [SFA](https://data.nasdaq.com/databases/SFA)).
* Strength: survivorship-free, point-in-time data — the right source for **backtesting (Q7)** research, not for app display.

### Stooq
* FACT: free CSV downloads (daily/intraday) across many markets.
* UNKNOWN: **no terms of use found** permitting commercial use → **not usable** for the product; at most for private manual checks.

## 3. Verdict (evidence permits a ranking, not a choice)

| Role | Candidate | Why | Blocking unknowns |
|---|---|---|---|
| **PRIMARY** | **Twelve Data (Business plan)** | only candidate whose own docs state a plan tier that permits *commercial display*, with US + international coverage in one REST API | price; LSE display licence path; delay (real-time vs 15-min vs EOD) per venue |
| **SECONDARY** | **EODHD (B2B)** | strongest documented US+LSE EOD depth, raw + adjusted | whether B2B plans include end-user display; redistribution terms |
| **US-only alternative** | Massive / Polygon (business contract) | best US depth, flat files for bulk history | UK gap; business-contract price |
| **FALLBACK / DEVELOPMENT** | CSV uploads + FixtureProvider (today); Tiingo Power for **internal** dev only | zero licence risk; Tiingo terms clearly allow internal use | none for internal use — must never be shown to end users |
| **Research-only (Q7)** | Nasdaq Data Link / Sharadar | point-in-time, survivorship-aware US data | professional licence |

Not recommended for the product: Alpha Vantage free, Finnhub free,
Stooq (licence), any personal-tier plan (all forbid third-party display).

## 4. Recommendation (requires Owner approval — cost)

1. Ask Twelve Data and EODHD sales, in writing, for: end-user **display**
   rights for derived analytics on US + LSE EOD (and delayed intraday),
   exchange fees they pass through, data-retention clauses, attribution
   rules. Decide on the written answers, not on list prices.
2. Implement the first real provider only after (1), as a
   `MarketDataProvider` behind `safe_fetch` (QUANT_SECURITY_MODEL §4),
   `trust = PROVIDER_REPORTED`, `sourceAsOf`/`adjustment` from vendor metadata.
3. Keep FixtureProvider + CSV as the deterministic test path forever.
