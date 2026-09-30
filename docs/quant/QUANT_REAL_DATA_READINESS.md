# InsightValues Quant — Real-Data Readiness (IV-QUANT-REAL-DATA-READINESS-03)

Status date: 2026-09-25. **No paid vendor, no real API key, no production
market data, no redistribution, no promotion beyond INTERNAL.** This mission
makes the platform *ready* to receive a licensed provider; it does not
connect one.

## 1. Three pillars

| Pillar | State |
|---|---|
| Technical | Provider adapter + runtime, provenance cache, rate limits, multi-series, watchlist → analysis: implemented and tested with synthetic data |
| Licensing | No vendor licensed. Dossier with 22 questions × 4 vendors; owner e-mails drafted, **not sent** (QUANT_VENDOR_LICENSING_DOSSIER.md) |
| Physical | Validated on a Samsung S25 Ultra (Android) — §7 |

## 2. Synthetic market data (dev/test only)

`synthetic_market.ts` generates deterministic, vendor-shaped payloads
(FNV-1a seed + mulberry32, log-normal walk) on the **real** XNYS/XNAS/XLON
sessions, so freshness/calendar/alignment logic is exercised realistically.
No real price, symbol history or vendor dataset is copied. Provenance:
`providerKind FIXTURE`, `trust SYNTHETIC_FIXTURE` → evidence **WEAK**; the
UI states "SYNTHETIC data" wherever the watchlist analysis is shown.

## 3. Provider adapter and runtime

* `provider_adapter.ts` — `AdapterSpec`: id, kind, trust, **exact host
  allowlist**, secret env name + header, max response bytes, timeout,
  `buildRequest`, `parseResponse` (identity echo checks on symbol, exchange,
  currency, interval, adjustment; every bar inside the requested window — no
  bar after `toT` (look-ahead), none before `fromT` beyond one day of date
  granularity; `as_of` never after retrieval — else `PROVIDER_MALFORMED`,
  never an empty success; PC-08, Codex Gate 2).
* `quant_provider_runtime.ts` — `HttpAdapterProvider`: only network path;
  `safeFetch` (SSRF-validated, bounded) with `allowedHosts` re-checked on
  **every redirect hop**, and credential headers dropped whenever a redirect
  changes origin (Codex Gate 1); credential only from a server secret, sent as a
  header, never in a URL (`key=`/`token=` refused), never logged; errors
  normalized to `PROVIDER_TIMEOUT / PROVIDER_RATE_LIMITED / PROVIDER_UNAVAILABLE / PROVIDER_MALFORMED`.
* No real vendor base URL or key exists anywhere in the repository.
* Contract tests PC-01..07 (fake fetch; no network).

## 4. Provenance cache

QUANT_CACHE_POLICY.md — provider responses only; original provenance
preserved; stale copy served only when the provider fails, flagged
`STALE_FALLBACK` + `CACHE_STALE`; USER_UPLOAD never cached.

## 5. Rate limiting

QUANT_RATE_LIMIT_POLICY.md — Postgres-enforced fixed window per user and
bucket; 429 + `Retry-After`; store failure fails closed (503).

## 6. File-type policy (client; the server re-parses everything anyway)

Decided on the file **name and its leading bytes** (a renamed binary is
still refused). CSV remains the canonical format.

| Type | Policy | Physical result (S25, SAF picker) |
|---|---|---|
| CSV (UTF-8, BOM ok) | SUPPORTED | ✅ loaded + analyzed (Downloads and Google Drive) |
| TXT holding CSV text | SUPPORTED | ✅ loaded |
| JSON | NOT_IMPLEMENTED | ✅ "not supported yet — export as CSV" |
| XLS / XLSX / ODS | NOT_IMPLEMENTED | ✅ same message (by extension and by ZIP/OLE signature) |
| PDF (also renamed to .csv) | REJECTED | ✅ "file type not supported" |
| Image (PNG/JPEG/GIF/WebP) | REJECTED | ✅ PNG refused |
| Other (XML, DOCX, ZIP, binary) | REJECTED | ✅ XML and DOCX refused |
| Non-UTF-8 text (latin-1) | REJECTED (unreadable) | ✅ "unreadable CSV (use UTF-8)" |
| > 5 MiB | REJECTED | unit test |

The file is never read whole before the 5 MiB check: declared size is
refused first, then the byte stream is cut as soon as it passes the cap
(`readBoundedBytes`, Codex Gate 3).

Android picker: `FileType.any` + content decision (extension filters hide
valid CSVs on some SAF providers because of inconsistent MIME types). No
proprietary Dropbox/OneDrive integration: any installed Document Provider
works through SAF.

## 7. Physical Android validation (S25 Ultra, SM-S938B)

Setup: side-by-side debug build `com.insightvalues.app.quantlab` (commercial
app untouched); Owner logged in himself (e-mail/password — Google native
sign-in does not work for the side-by-side package because the OAuth client
is bound to the production package + signing certificate); the app talked to
a local Quant dev server (`tool/quant_lab_dev_server.ts`: real handlers, real
Supabase Auth and entitlement read, in-memory watchlists) through `adb
reverse`. **Nothing was written to the production database and nothing was
deployed.** The `QUANT_API_BASE_URL` override is honored only in debug builds
and only for loopback http.

| Area | Result |
|---|---|
| Cold start | 1.25 s; session persisted |
| Drawer / navigation | OK; Quant reached via Admin Panel → Modules → Open module (fix F1) |
| CSV import (Downloads, Google Drive) | OK (277 rows; 60 rows from Drive) |
| Analysis / freshness / provenance / metrics / warnings | OK; metrics equal an independent recomputation |
| Watchlist create / add (US + UK) / analyze | OK; 3 calendars, mixed currency, alignment warnings |
| PT / EN | OK (all Quant strings localized) |
| Text scale 1.0 / 1.3 / 2.0 | 0 overflow/exception lines in logcat on every Quant surface |
| Landscape | state preserved, no overflow |
| Back navigation / keyboard | OK |

Physical findings — each root-caused, fixed structurally, regression-tested
and re-verified on the device:

| # | Finding | Root cause | Fix |
|---|---|---|---|
| F1 | Quant Lab unreachable on Android | drawer hides non-commercial modules by design; admin module sheet was metadata-only | "Open module" in the admin sheet (route guard + server entitlement stay the authority) |
| F2 | Returning from the file picker flashed a blank screen and lost scroll/state | app re-fetches the profile on resume; the lab treated a refresh as "no data" and unmounted | spinner only before the first value; a refresh that returns non-admin still denies |
| F3 | Old file error stayed on screen after a valid import | error cleared only on analyze | cleared on successful import and on sample load |
| F4 | `.docx` reported as "spreadsheet" | ZIP signature mapped to spreadsheet regardless of name | container bytes only suggest a spreadsheet for csv/txt/nameless/spreadsheet names |
| F5 | Correlation labelled "XNAS × XNYS" | client parsed the instrument key with a guessed layout (masked by a wrong test fixture) | labels from the series' own instrument; fixture corrected |
| F6 | IVE avatar covered delete-watchlist, remove-item and a metric value | essential Quant elements not declared to the placement engine | `IveExclusionRegion` (Owner-approved contract) on primary actions and key metrics |

Not Quant (recorded): Admin Panel/Home not translated in EN; the IVE avatar
can still rest on non-essential text; Google Sign-In for side-by-side debug
packages.

## 8. What is still required before real data

1. Owner decision on a vendor after **written** licensing answers (dossier).
2. A licensed adapter (`AdapterSpec`) + server secret; a total request
   deadline for per-instrument provider calls.
3. Re-measure on the real Edge runtime (PLATFORM_RUNTIME_NOT_MEASURED; v1
   50 000-row heap peak ~153 MB is the tightest margin).
4. Rate-limit row cleanup job; persistent/shared cache decision (tied to
   licence storage terms).
5. Promotion Gate (ALPHA_PROMOTION_AUTHORIZED: NO).

## 9. Codex gate hardening (client)

* Explicit sign-out closes the Lab immediately and discards any displayed or
  in-flight result (the server remains authoritative).
* Watchlist results are cleared on any mutation or selection change.
* Malformed multi responses (duplicate series keys, correlation cells that
  reference unknown series, non-hex/short content hashes) are rejected as
  `MALFORMED_RESPONSE` instead of rendering misleading labels or crashing.
* All technical labels are localized (PT/EN).
