# Impact — Registry Source Dossier (I2)

Assessment of real registries for InsightValues Impact. **Public access is not
an unrestricted right to reuse; a public API is not a redistribution right.**
Nothing here is legal advice; every "REQUIRES_CONFIRMATION" is an Owner /
legal action before any enablement. No service was contracted, no credential
created, nothing bypassed. Status values: CONFIRMED · REQUIRES_CONFIRMATION ·
NOT_SUPPORTED · UNKNOWN.

Assessment date: 2026-09-23. Sources: the official developer / dataset pages
(read-only). Adapters: `supabase/functions/_shared/impact_registry/`.
**Enabled in the Lab: none** (`catalog.ts`, test CAT-01).

## 1. UK — Companies House (`gb-companies-house`)

| Item | Status | Notes |
|---|---|---|
| Official? | CONFIRMED | Statutory register of UK companies (Crown). |
| API? | CONFIRMED | Public Data API, `api.company-information.service.gov.uk`. |
| Authentication | CONFIRMED | "Access to API services requires authentication … API key" (developer site). **Owner credential required — none configured.** |
| Download? | REQUIRES_CONFIRMATION | A bulk "basic company data" product exists; not assessed in detail. |
| Terms / licence | REQUIRES_CONFIRMATION | Crown copyright page; reuse terms (OGL / developer guidelines) to be confirmed by the Owner. |
| Commercial use / display / redistribution / cache | REQUIRES_CONFIRMATION | Depends on the terms above. |
| Attribution | REQUIRES_CONFIRMATION | |
| Rate limits | REQUIRES_CONFIRMATION | Developer guidelines reference limits; commonly cited as 600 requests / 5 min — adapter spaces requests ≥ 500 ms and never retries. |
| PII concerns | CONFIRMED (handled) | Officers, persons with significant control and addresses contain personal data → **never requested** (only `/company/{n}` and `/search/companies`), never parsed, never stored. |
| Technical status | Adapter written, offline-tested (CH-01..04); **not enabled**. |

## 2. UK — Charity Commission for England and Wales (`gb-charity-commission`)

| Item | Status | Notes |
|---|---|---|
| Official? | CONFIRMED | Regulator and register of charities (England & Wales). |
| API? | CONFIRMED | Register of Charities API (API portal, `api.charitycommission.gov.uk`). |
| Authentication | REQUIRES_CONFIRMATION | API-management portal with subscription key (`Ocp-Apim-Subscription-Key`). **Owner credential required.** |
| Download? | REQUIRES_CONFIRMATION | A full register extract is published; not assessed in detail. |
| Terms / licence | CONFIRMED (portal statement) + REQUIRES_CONFIRMATION (API terms) | Portal: "All content is available under the Open Government Licence v3.0, except where otherwise stated"; the API's own terms of use still to be read by the Owner. |
| Commercial use / display / redistribution / cache | REQUIRES_CONFIRMATION | OGL generally permits reuse with attribution; confirm for API data and exceptions. |
| Attribution | REQUIRES_CONFIRMATION | OGL attribution statement expected. |
| Rate limits | UNKNOWN | None found; adapter uses 1 request/s, no retry. |
| PII concerns | CONFIRMED (handled) | Trustee names, contact e-mail/phone and addresses → never requested / parsed / stored (CC-01). |
| Field mapping | REQUIRES_CONFIRMATION | Written from the published data definitions; must be confirmed against live responses once a key exists. |
| Technical status | Adapter written, offline-tested; **not enabled**. |

## 3. US — IRS Exempt Organizations Business Master File (`us-irs-eo-bmf`)

| Item | Status | Notes |
|---|---|---|
| Official? | CONFIRMED | IRS (TE/GE) extract of organizations currently recognized as tax-exempt. |
| API? | NOT_SUPPORTED | No official lookup API; the IRS "Tax Exempt Organization Search" is a web tool (not scraped — no scraping by design). |
| Download? | CONFIRMED | Per-state CSV at `https://www.irs.gov/pub/irs-soi/eo_{state}.csv`; ≈1.96 M records, updated monthly (page last updated 2026-09-08). |
| Authentication | CONFIRMED | None. |
| Terms / licence | REQUIRES_CONFIRMATION | US Government works are generally not subject to copyright; the page carries a "disclaimer of endorsement". IRS-specific reuse / display terms to be confirmed. |
| Commercial use / display / redistribution / cache | REQUIRES_CONFIRMATION | |
| Attribution | REQUIRES_CONFIRMATION | Non-endorsement wording must be respected. |
| Rate limits | UNKNOWN | Static files; adapter: one file per 5 s, 8 MB cap. |
| PII concerns | CONFIRMED (handled) | `ICO` ("in care of") is a **person's name** → dropped; street, city, ZIP and financial amounts dropped. |
| Semantics | CONFIRMED | Lists recognized exemption — NOT an incorporation register (source type GOVERNMENT_RECORD, authority class TAX_AUTHORITY). **Absence proves nothing** (small organizations, churches, group members may be missing). |
| Scale | NOT_SUPPORTED in the Lab | Large states exceed the Lab size cap → fail closed; production needs a scheduled bulk-ingestion pipeline (future gate). |
| Technical status | Adapter written, offline-tested (IRS-01/02); **controlled real smoke executed** (Wyoming extract, counts only, nothing stored — layout matched); **not enabled**. |

## 4. Not assessed / out of scope

US state registries (50 states — explicitly not attempted), UK Scottish
(OSCR) and Northern Ireland charity regulators, EU registries, Brazilian
registries (CNPJ/Receita), commercial aggregators. News/media APIs belong to
a later gate (no news crawler here).

## 5. Real-data policy applied

Real public data was used only for the controlled smoke (§3): official,
documented, no credential, no bypass, minimal (one small file), not selected
by suspicion of any organization, no organization named or persisted, results
Lab-only. All deterministic tests use synthetic fixtures (XA/XB).

## 6. Enablement checklist (per provider, Owner decision)

1. Owner confirms terms/licence rows above (display, cache, redistribution,
   attribution, commercial use).
2. Owner creates the credential and it is stored as an Edge Function secret
   (never in code or logs).
3. The provider is composed into the Lab registry **and** added to
   `public.impact_trusted_provider` in a migration (drift test PD-01).
4. Service-role gate re-evaluated (options A/B) if data leaves the Lab.
