# InsightValues Quant — Domain Model (Foundation)

Only the contracts the Foundation needs are implemented. Everything else is
named here so later gates extend, rather than reinvent, the model.

## 1. Entities

| Entity | Foundation | Where |
|---|---|---|
| Instrument (identity) | IMPLEMENTED | `instrument.ts` |
| Market / Exchange | as `exchangeMic` + `exchangeTimezone` on Instrument | `instrument.ts` |
| Quote | `RawQuote` (provider contract) | `provider.ts` |
| PriceBar / TimeSeries | IMPLEMENTED (`PriceBar`, `PriceSeries`) | `timeseries.ts` |
| DataSource / DataSnapshot | `DataProvenance` + `dataSnapshot` (provenance, content hash, freshness) | `provenance.ts`, `analysis.ts` |
| Indicator | SMA (value), no standalone type | `metrics.ts` |
| Signal | IMPLEMENTED (descriptive only) | `signals.ts` |
| RiskMetric | `SeriesRiskOverview`, `Concentration`, `CorrelationEntry` | `risk.ts` |
| Portfolio / Position | IMPLEMENTED (manual/demo) | `portfolio.ts` |
| Analysis | `QuantAnalysisResult` | `analysis.ts` |
| Watchlist | contract + normalization, no persistence | `domain_future.ts` |
| FundamentalMetric | contract only | `domain_future.ts` |
| EconomicSeries | contract only (not an instrument) | `domain_future.ts` |
| ResearchArtifact | `UntrustedDocumentEvidence` contract | `domain_future.ts` |
| Scenario | NOT DEFINED (Q4) | — |
| Recommendation / Order / TradeIntent | **deliberately absent** | — |

## 2. Instrument identity

Canonical key: `assetClass : exchangeMic|UNSPECIFIED : symbol : currency`.
A ticker alone is never an identity ("AAPL" on XNAS/USD ≠ a same-named
symbol on another venue or currency ≠ an ETF with that symbol).

| Field | Rule |
|---|---|
| `assetClass` | one of the 8 tradable classes (§3) |
| `symbol` | venue symbol, uppercased, `[A-Z0-9][A-Z0-9.-=/]{0,31}` (e.g. `BRK.B`, `PETR4`) |
| `exchangeMic` | optional ISO 10383 MIC (`XNAS`, `BVMF`) |
| `currency` | **required** ISO 4217 |
| `exchangeTimezone` | optional IANA zone |
| `isin` | optional; ISO 6166 check digit verified |
| `figi` | optional; OpenFIGI check digit verified |
| `providerIds` | optional map provider → id (e.g. a vendor's `^GSPC`); never the key |

Nothing beyond symbol + currency + class is required, and identifiers that
do not exist are never demanded. One ISIN can map to many listings, which is
why ISIN is a cross-reference, not the key.

## 3. Asset classes

Declared: `EQUITY, ETF, INDEX, FX, CRYPTO, FIXED_INCOME, COMMODITY, FUND`.
Economic series are **not** an asset class: `EconomicSeriesIdentity` has
`kind: 'ECONOMIC_SERIES'` and cannot be a position.

Foundation analytics support **EQUITY, ETF, INDEX** only; the rest return
`UNSUPPORTED_ASSET_CLASS` because they break Foundation assumptions:

| Class | Why deferred |
|---|---|
| FX | pair semantics (base/quote), 24×5 calendar, no volume |
| CRYPTO | 24×7 calendar (annualization ≠ 252), venue fragmentation |
| FIXED_INCOME | price vs yield, clean vs dirty, accrued interest |
| COMMODITY | futures contracts, rolls, continuous-series construction |
| FUND | NAV frequency/lag, distributions |

## 4. Time series

`PriceBar {t, open, high, low, close, volume?, adjustedClose?}`, `t` in
epoch ms UTC. `PriceSeries {instrument, frequency, provenance, bars,
normalizationWarnings}`, frozen, strictly increasing `t`. See
QUANT_DATA_MODEL §5–§6.

## 5. Currency

A series' provenance currency must equal the instrument currency. Amounts
in different currencies are **never** summed; without an explicit FX
conversion the operation fails with `CURRENCY_MISMATCH`. A future FX
conversion must record FX source, rate and timestamp in provenance.

## 6. Portfolio

`ManualPortfolio {source: 'MANUAL'|'DEMO', baseCurrency, positions}`;
`PortfolioPosition {instrument, quantity > 0, costBasisPerUnit?}`. No broker,
no account import, no shorts, no cash, no transactions. Analyses:
allocation (market value, weights), concentration (HHI, effective holdings,
max weight), unrealized return vs cost basis, buy-and-hold return with
initial weights, return correlation matrix, per-holding price freshness.
Limit: 500 positions.

## 7. Watchlist

Name (1–80 chars), optional `projectId`, instruments deduplicated by
canonical key, max 200. Low-risk first capability for a UI; persistence and
RLS come with it in Q1 (owner-scoped, optional project FK validated by the
existing project-ownership pattern).

## 8. Indicator ≠ Signal ≠ Recommendation ≠ Order

| Concept | Meaning | Foundation |
|---|---|---|
| Indicator | number derived from data (SMA₂₀ = 104.3) | yes |
| Signal | factual observation about indicators ("SMA₂ crossed below SMA₃ at bar 7") | yes, `nature: 'DESCRIPTIVE'`, `isRecommendation: false` (literal types) |
| Recommendation | opinion about what someone should do | **not modeled** |
| Order | instruction to a broker | **not modeled; no path exists** |

A moving-average cross is never a buy/sell recommendation; the signal text
states so, and the IVE narrative rules forbid recommending.

## 9. Fundamentals (future Q5)

`FundamentalMetric {instrumentKey, metric, reportedValue, currency,
periodStart, periodEnd, fiscalPeriod, filingDate, isRestated, providerId}`.
`filingDate` is the only point-in-time key safe for backtests.

## 10. Economic series (future)

`EconomicSeriesIdentity {kind:'ECONOMIC_SERIES', concept, region, unit,
seasonallyAdjusted, providerSeriesId?}` — rates, inflation, employment, GDP.

## 11. Research artifacts

`UntrustedDocumentEvidence {trust:'UNTRUSTED_CONTENT', knowledgeItemId,
excerpt, claimedValue?}` — user documents are evidence to narrate, never
market-data authority.

## 12. Scenario (future Q4)

Stress/what-if over a portfolio (shock vectors, historical windows). Not
defined in the Foundation to avoid inventing a model before risk data exists.
