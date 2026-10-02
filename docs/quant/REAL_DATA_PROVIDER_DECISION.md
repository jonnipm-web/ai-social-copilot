# InsightValues Quant — Real Data Provider Decision Record
# IV-QUANT-LICENSED-PROVIDER-PILOT-04

**Date:** 2026-10-02  
**Author:** Claude Code (executor)  
**Reviewed by:** Pending Codex adversarial review  
**Owner approval required:** See §7 (BLOCKED_OWNER items)

---

## 0. Intended Use (preserved from Mission 03)

InsightValues is a SaaS with web + Android clients. The Quant engine is a
server-side analytical engine (not a trading robot). Target use:

- Server-side retrieval (Supabase Edge Function)
- Server-side cache (in-memory; future shared store)
- Deterministic analytics (returns, volatility, drawdown, Sharpe, SMA, correlation)
- **Display** of raw prices and derived analytics to authenticated end users
- US equities (XNYS, XNAS) and UK equities (XLON) — daily bars first, intraday later
- Multi-tenant SaaS (free and paying users)
- No raw data resale / API redistribution to third parties intended

---

## 1. Provider Evaluation Matrix

| Provider | Markets | Rights (commercial display) | Cost entry | Status |
|---|---|---|---|---|
| Databento DBEQ.BASIC | US equities XNYS/XNAS | **GREEN** — see §2 | $125 credit (usage-based after) | **RECOMMENDED PILOT** |
| Databento DBEQ.MINI | US equities (composite) | **GREEN** — explicit redistribution/display | $125 credit (usage-based after) | Alternative to BASIC |
| Twelve Data Business | US+FX+UK | YELLOW — "commercial display" on Business plans but UK/exchange fees unclear | Not public (Business tier) | BLOCKED_PENDING_WRITTEN_RIGHTS |
| EODHD Enterprise | US+UK | YELLOW — Internal Use explicitly forbids external display; Enterprise/Custom required | £2,499+/mo | BLOCKED_PENDING_WRITTEN_RIGHTS |
| Massive/Polygon Business | US only | YELLOW — Individual plans only; Business terms not confirmed for display | $2,499+/mo | BLOCKED_PENDING_WRITTEN_RIGHTS |
| Tiingo Commercial | US+FX+Crypto | YELLOW — internal commercial use only; no redistribution without special agreement | Contact sales | BLOCKED_PENDING_WRITTEN_RIGHTS |
| Financial Modeling Prep | US+global | YELLOW — personal tier non-commercial; commercial requires separate agreement | Contact sales | BLOCKED_PENDING_WRITTEN_RIGHTS |
| Alpha Vantage | US+FX+Crypto | YELLOW — commercial requires separate written agreement | Contact sales | BLOCKED_PENDING_WRITTEN_RIGHTS |
| Sharadar / Nasdaq Data Link | US equities (EOD) | YELLOW/RED — distribution licence required for display | Not public | Research use only |
| Yahoo Finance | US+global | RED — no commercial use permitted | Free | REJECTED |
| Stooq | US+EU+Global | UNKNOWN — no commercial terms found publicly | Free | UNKNOWN — do not use |

---

## 2. Databento DBEQ.BASIC — GREEN Classification Evidence

### 2.1 Rights Sources

| Claim | Source | Date verified |
|---|---|---|
| "supports commercial applications — external redistribution and non-display trading — without licensing restrictions" | https://databento.com/blog/databento-us-equities-mini-now-available | 2026-10-02 |
| "display platforms, redistribution, brokerages, and analytics tools … without incurring additional licensing costs" | Same source (DBEQ.MINI context; DBEQ.BASIC is the broader sibling) | 2026-10-02 |
| "Databento has a derived use license in place with venues … end users are allowed to use and redistribute the feed without further licensing or exchange fee requirements" | https://databento.com/blog/dbeq-basic | 2026-10-02 |
| "Zero license fees on distribution; does not require exchange reporting; instantly approved once you subscribe" | Same source | 2026-10-02 |
| Usage-based pricing, $125 free credits for new accounts, no subscription commitment required | https://databento.com/pricing + https://databento.com/docs/knowledge-base/new-users/usage-based-pricing-and-data-credits | 2026-10-02 |

### 2.2 Rights Classification Detail

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | SaaS commercial use | **GREEN** | Explicitly stated: "commercial applications" |
| 2 | Web display | **GREEN** | "display platforms" explicitly listed as target use case |
| 3 | Android/mobile display | **GREEN** | Same; no platform restriction stated |
| 4 | Display to paying users | **GREEN** | No user-class restriction in public docs |
| 5 | Display to free users | **GREEN** | Same |
| 6 | Show derived analytics | **GREEN** | Derived data explicitly licensed; analytics is a downstream derived product |
| 7 | Store derived analytics server-side | **GREEN** (inferred) | Derived data rights include downstream computation; Databento does not restrict storage of derivatives |
| 8 | Store raw data | YELLOW | Caching is standard practice; Databento doesn't explicitly state a retention limit — confirm in writing for long-term storage |
| 9 | Redistribute raw data | **GREEN** | Explicitly permitted under derived use license |
| 10 | Historical OHLCV display | **GREEN** | Historical API provided with same rights |
| 11 | Intraday display | **GREEN** | Same license covers real-time and historical |
| 12 | Attribution required | UNKNOWN | Not stated in public docs — confirm in writing |
| 13 | Exchange fees | **GREEN** (zero) | "Zero license fees", "does not require exchange reporting" |
| 14 | US equities (XNYS/XNAS) | **CONFIRMED** | DBEQ.BASIC is a US equities product |
| 15 | UK/LSE | **NOT_SUPPORTED** | DBEQ.BASIC covers US equities only |
| 16 | FX | **NOT_SUPPORTED** | Equities-only product |
| 17 | Corporate actions | **NOT_SUPPORTED** in this adapter version | Separate corporate-actions API exists but not in DBEQ.BASIC OHLCV-1d |
| 18 | Adjustment (split/dividend) | **NOT_SUPPORTED** in DBEQ.BASIC OHLCV | Raw trade aggregates = UNADJUSTED |
| 19 | Backend/server API use | **GREEN** | Standard API usage; no client-only restriction |
| 20 | Cache | **GREEN** (inferred) | Standard server-side caching; not restricted in public docs |
| 21 | AI/ML processing | **GREEN** (inferred) | Derived data rights cover downstream ML; no AI restriction stated |
| 22 | Account registration | **REQUIRES_OWNER_ACTION** | Payment method required at signup (even for free-credit tier) |

### 2.3 Known Limitations

1. **US equities only** — XLON and FX not covered; fallback to uploaded CSV for UK data.
2. **UNADJUSTED prices only** — No split/dividend adjustment in OHLCV-1d schema.
3. **Identity not echoed in response** — Bar records do not include symbol; adapter validates instrument_id consistency.
4. **Account requires payment method** — Owner must create Databento account before API key can be configured.
5. **POST vs GET** — Adapter uses GET query params; if Databento requires POST for this endpoint, `SafeFetchOptions` must be extended with `method`/`body` fields.
6. **Attribution requirement** — Not confirmed in public docs; confirm with Databento support.

---

## 3. Technical Recommendation

**Recommended provider: Databento DBEQ.BASIC**

Rationale:
- Only provider found with explicit, unambiguous GREEN rights for commercial display, redistribution, and derived analytics without additional licensing
- Zero exchange fees (no per-user or per-display fees)
- Usage-based pricing means zero irreversible cost commitment at pilot stage
- $125 free credit covers extensive pilot testing
- Strong documentation; established compliance infrastructure (KYC, CTA, etc.)
- REST API compatible with existing `HttpAdapterProvider` architecture

Limitations vs YELLOW providers:
- US equities only (no XLON, no FX in this pilot)
- UNADJUSTED prices only (acceptable for analytics pilot)

For UK/XLON coverage: A YELLOW provider (Twelve Data Business or EODHD Enterprise)
remains necessary. Owner must obtain written rights confirmation before integration.

---

## 4. Commercial Recommendation

For the InsightValues PILOT phase:
- Use Databento DBEQ.BASIC (GREEN, zero commitment)
- Confirm attribution requirements with Databento support
- Defer long-term storage policy confirmation until post-pilot

For full commercial launch (both US + UK):
- US: Databento (already GREEN, may upgrade to paid plan for volume)
- UK/XLON: Contact Twelve Data or EODHD for written commercial display rights

---

## 5. Owner Gate Required

Before integrating Databento into production:

1. **Create Databento account** at https://databento.com (requires payment method)
2. **Obtain API key** from the portal
3. **Store raw API key** as Supabase secret `DATABENTO_API_KEY = "db-YOUR-KEY-HERE"` (adapter constructs Authorization header automatically)
4. **Confirm attribution** requirements in writing with Databento support
5. **Review long-term data storage** policy with Databento

No production deployment in this mission. Quant Lab remains LAB status.
