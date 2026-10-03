# Bootstrap Provider Decision — IV Quant Lab
# Mission: IV-QUANT-LICENSED-PROVIDER-PILOT-04 (§25–§27)
# Decision Date: 2026-10-03
# Authority: Agente Martins + Paulo

---

## 1. Decision Summary

| Role | Selected | Dataset | Rights | Bootstrap Cost |
|---|---|---|---|---|
| PRIMARY_BOOTSTRAP | **Databento EQUS.SUMMARY** | EQUS.SUMMARY | **YELLOW/NOT_VERIFIED** (see §2.2) | ~$0/month (PAYG historical) |
| SECONDARY_FUTURE | Tiingo Redistribution | EOD + IEX | YELLOW → confirm | $250/month (Phase 2) |
| FUNDAMENTALS_FUTURE | FMP Enterprise | Market + Fundamentals | YELLOW → negotiate | Phase 2/3 |
| UK/XLON Phase 1 | **NONE** | — | BLOCKED | — |

---

## 2. Why Databento EQUS.SUMMARY

### 2.1 Correctness of Premise

The previous mission selected DBEQ.BASIC based on documented commercial rights.
That dataset was deprecated January 13, 2025 (evidence: EV-DB-01).

EQUS.SUMMARY is the current replacement:
- Same endpoint: `hist.databento.com`
- Same authentication: HTTP Basic auth, `DATABENTO_API_KEY`
- Same schema: `ohlcv-1d` (confirmed, EV-DB-07)
- Same encoding: NDJSON with `pretty_px=true` and `pretty_ts=true`

### 2.2 Rights

| Right | DBEQ.BASIC (deprecated) | EQUS.SUMMARY |
|---|---|---|
| Commercial display | GREEN (documented) | **YELLOW — NOT_VERIFIED** |
| Redistribution | GREEN | **YELLOW — NOT_VERIFIED** |
| Web application | GREEN | **YELLOW — NOT_VERIFIED** |
| Zero exchange fees | YES | **YES — "zero license fees" (EV-DB-03)** |
| SaaS use | GREEN | **YELLOW — NOT_VERIFIED** |

Evidence: EV-DB-03 (PRNewswire press release — third-party), EV-DB-04 (describes EQUS.MINI live, not EQUS.SUMMARY historical)

**RIGHTS CLASSIFICATION: YELLOW/NOT_VERIFIED — Codex VND-01 (2026-10-03)**

EV-DB-03 is a PRNewswire article, not a Databento contractual document.
EV-DB-04 explicitly describes EQUS.MINI (live data), not EQUS.SUMMARY (historical).
Written confirmation from Databento is required before commercial production.
Rights for SaaS display, caching, derived analytics, AI processing, and raw retention are unverified.
Action required: Owner sends `DATABENTO_RIGHTS_CONFIRMATION_REQUEST.md` to support@databento.com
and receives written reply. Until then, classification remains YELLOW/NOT_VERIFIED.

### 2.3 Cost Model

| Scenario | Cost | Notes |
|---|---|---|
| Pilot (3 symbols × 2 years) | < $0.01 | pay-as-you-go, tiny bytes |
| Bootstrap (100 symbols × 5 years) | < $1.00 | PAYG, well within $125 credits |
| Phase 2 (1,000 symbols daily) | < $5/month | PAYG historical |
| Live data (if needed) | $199/month | Standard subscription required |
| Free credits | $125 | New account, expires 6 months |

All historical data is PAYG — no subscription required. No financial commitment for pilot.
Evidence: EV-DB-05, EV-DB-06

### 2.4 Technical Fit

- Existing adapter already built, Codex-reviewed (P0=0, P1=0 post-fix)
- Migration: change ONE constant (`DBEQ.BASIC` → `EQUS.SUMMARY`) + adapter ID
- Same API, same auth, same NDJSON parsing, same `ohlcv-1d` schema
- Lowest migration risk of all alternatives

### 2.5 Score

| Dimension | Score | Rationale |
|---|---|---|
| RIGHTS | 6/10 | YELLOW/NOT_VERIFIED — Codex VND-01; EV-DB-03 third-party press release; written Databento confirmation required |
| LOW COST | 10/10 | ~$0/month PAYG for pilot |
| HISTORICAL DATA | 10/10 | Full history available |
| TECHNICAL FIT | 10/10 | Minimal adapter change |
| SCALE PATH | 9/10 | Subscription tier available for live |
| COVERAGE | 8/10 | US equities all NMS; no UK/FX/fundamentals |

**Overall: OPTIMAL BOOTSTRAP PROVIDER for Phase 1**

---

## 3. Why Not Others

| Provider | Reason Rejected for Phase 1 |
|---|---|
| DBEQ.BASIC | DEPRECATED January 2025 — cannot use |
| Twelve Data Venture | $499/month — too expensive pre-revenue |
| Intrinio Startup | $333-$999/month — too expensive pre-revenue |
| FMP Enterprise | Commercial display requires negotiation — YELLOW |
| Massive (Polygon) Business | $2,000+/month — prohibitive |
| Tiingo Redistribution | $250/month — secondary option; more expensive than Databento |
| Alpaca | Per-device pricing, not suitable for SaaS display |
| EODHD Commercial | $399-$2,499/month — too expensive |
| Alpha Vantage | Commercial display terms unclear — YELLOW |

---

## 4. UK/XLON Status

**BLOCKED for Phase 1 Bootstrap.**

All viable providers for UK equities with commercial display rights cost:
- Twelve Data Venture: $499/month (includes UK)
- Databento: No UK equities dataset currently

Decision: UK/XLON deferred to Phase 2 (Early Revenue) when $499/month is justifiable.
Owner must confirm budget before any UK integration begins.

---

## 5. Adapter Migration — COMPLETED (2026-10-03)

Migration from DBEQ.BASIC to EQUS.SUMMARY was completed in commit 874746e.
A subsequent Codex adversarial audit (commit c203723) applied security hardening.

Changes applied:
- `dataset`: `'DBEQ.BASIC'` → `'EQUS.SUMMARY'`
- Adapter ID: `'databento-dbeq-basic-v1'` → `'databento-equs-summary-v1'`
- Source label: `'Databento DBEQ.BASIC ohlcv-1d'` → `'Databento EQUS.SUMMARY ohlcv-1d'`
- OHLCV_1D_RTYPE: corrected from 32 (ohlcv-1h) to 35 (ohlcv-1d) per DBN spec
- MIC allowlist removed: EQUS.SUMMARY covers all US NMS — no hard allowlist needed
- Deprecation guard test added (DBEQ.BASIC guard + DBEQ.MINI guard)
- Contract guard tests added: rtype=32 (ohlcv-1h) and rtype=33 (ohlcv-1m) rejected
- Rights classification: GREEN → YELLOW/NOT_VERIFIED (Codex VND-01; see §2.2)

Rights: YELLOW/NOT_VERIFIED until written confirmation received from Databento.
Tests: 215/215 PASS (0 failed) as of 2026-10-03.

---

## 6. Phase 2 Candidates (after first revenue)

1. **Tiingo Redistribution** ($250/month) — if Databento availability changes
2. **Twelve Data Venture** ($499/month) — for UK/EU/FX coverage
3. **Intrinio Startup** ($333-$999/month) — for fundamentals + options
4. **FMP Enterprise** — for financial statements, ratios, filings

---

## 7. Owner Actions Required (after adapter migration)

1. Create Databento account at https://databento.com
2. Obtain API key (format: `db-xxxxxxxxxxxxxxxxxxxxxxxxxxxx`)
3. Store as `DATABENTO_API_KEY` in Supabase LAB secrets (server-side only)
4. Review and send `DATABENTO_RIGHTS_CONFIRMATION_REQUEST.md` to support@databento.com
   for written confirmation of commercial display, SaaS, derived analytics, caching rights
5. Keep within $125 free credits for pilot (no billing expected)

Do NOT take any of these actions until Codex adversarial audit completes and
Agente Martins reviews the final report.

---

## 8. Decision Register

| Field | Value |
|---|---|
| Decision | PRIMARY_BOOTSTRAP = Databento EQUS.SUMMARY |
| Date | 2026-10-03 |
| Authority | Agente Martins + Paulo |
| Evidence IDs | EV-DB-01, EV-DB-02, EV-DB-03, EV-DB-04, EV-DB-05, EV-DB-06, EV-DB-07 |
| Next Review | 2027-01-03 (90 days) or before production promotion |
| Revocation Triggers | EQUS.SUMMARY deprecated; rights terms changed; cost model breaks; better GREEN option at < $50/month |
