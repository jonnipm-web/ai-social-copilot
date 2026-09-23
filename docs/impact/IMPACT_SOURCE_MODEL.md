# Impact — Source Model

Code: `types.ts` (`Source`), `source_authority.ts`, `provenance.ts`, `provider.ts`.

## 1. Source

type · publisher · publisherOrganizationId (makes it self-reported for that
org) · uri (reference only) · retrievedAt · publishedAt · jurisdiction ·
newsGenre (NEWS) · status (ACTIVE / UPDATED / RETRACTED / UNAVAILABLE) ·
retention · contentHash (SHA-256) · userSubmitted.

Types: OFFICIAL_REGISTRY, ORGANIZATION_WEBSITE, GOVERNMENT_RECORD,
FINANCIAL_REPORT, AUDITED_REPORT, COURT_RECORD, REGULATOR, NEWS, ACADEMIC,
NGO_DATABASE, SOCIAL_MEDIA, USER_DOCUMENT, OTHER.

## 2. Source ≠ truth

A source can be authoritative for legal registration and have no authority
over real-world impact. An organization's website proves that the
organization **made** a claim, not that it is true. A social-media post
proves "this account published this".

## 3. Authority table (`impact-source-authority/1`)

Decision order: user-submitted → USER_SUBMITTED; publisher is the claim's
subject → SELF_REPORTED (whatever the type); social media → ATTRIBUTION_ONLY;
news → only REPORTING can corroborate; else table.

| Source | Registration / regulatory | Outputs / outcomes / beneficiaries | Financial | Other |
|---|---|---|---|---|
| OFFICIAL_REGISTRY | AUTHORITATIVE | NONE (excluded) | CONTEXTUAL (filed by the org) | governance/history INDEPENDENT |
| REGULATOR | AUTHORITATIVE | NONE | CONTEXTUAL | governance INDEPENDENT |
| COURT_RECORD | REGULATORY_STATUS AUTHORITATIVE (exact stage) | NONE | CONTEXTUAL | CONTEXTUAL |
| GOVERNMENT_RECORD | INDEPENDENT | INDEPENDENT | INDEPENDENT | CONTEXTUAL |
| AUDITED_REPORT | CONTEXTUAL | CONTEXTUAL | INDEPENDENT | CONTEXTUAL |
| ACADEMIC | CONTEXTUAL | INDEPENDENT | CONTEXTUAL | CONTEXTUAL |
| NEWS (REPORTING) | CONTEXTUAL | INDEPENDENT | CONTEXTUAL | INDEPENDENT (history, affiliation, governance) |
| NEWS (OPINION/ALLEGATION/CORRECTION) | CONTEXTUAL | CONTEXTUAL | CONTEXTUAL | CONTEXTUAL |
| FINANCIAL_REPORT, NGO_DATABASE, third-party website, OTHER | CONTEXTUAL | CONTEXTUAL | CONTEXTUAL | CONTEXTUAL |
| SOCIAL_MEDIA | ATTRIBUTION_ONLY | | | |
| USER_DOCUMENT / userSubmitted | USER_SUBMITTED | | | |

Only AUTHORITATIVE and INDEPENDENT items can move a claim off UNVERIFIED.
Changing the table is a policy change (bump the version).

## 4. Retention / snapshot policy

| Mode | Kept | Max for |
|---|---|---|
| SNAPSHOT | full copy + hash | OFFICIAL_REGISTRY, GOVERNMENT_RECORD, REGULATOR (public records whose later change matters) |
| EXCERPT_AND_HASH | ≤ 2,000-char extract + hash of full content | news, academic, reports, websites, court records (may name individuals) |
| HASH_ONLY | fingerprint only | SOCIAL_MEDIA, USER_DOCUMENT (Vault stores the file) |
| REFERENCE_ONLY | URI + metadata | OTHER |

Callers may choose more restrictive, never less (`validateSource`). Pages are
never copied wholesale. Excerpts must match their SHA-256 (tamper check).
Conceptual retention periods: `RETENTION_POLICY` in `provenance.ts`
(enforced when persistence exists).

## 5. Changing / deleted sources

Status UPDATED → evidence excluded (`SOURCE_CHANGED`) until re-extracted;
RETRACTED → excluded (`SOURCE_RETRACTED`). `Investigation.updateSourceStatus`
lists affected claims and logs `REVERIFICATION_REQUIRED`. History keeps the
previous results.

## 6. Providers

`ImpactSourceProvider { descriptor; searchOrganization?(); fetchRegistryRecord?() }`
with `ProviderDescriptor` = id, sourceType, capabilities, jurisdictions,
authorityScope, freshnessDays, retrievalMethod. Undeclared capability →
`CAPABILITY_NOT_SUPPORTED`; offline registry → `REGISTRY_UNAVAILABLE` (never
"not registered"). Only `FixtureProvider` exists. RAW records are never
mutated; canonical records keep `rawRecordHash`; malformed/forged/
out-of-jurisdiction records are rejected whole.

Future adapters (not integrated): UK Charity Commission, Companies House,
US IRS exempt-org data, Brazilian registries, regulators/courts, reputable
news/search APIs — each a separate gate, via `safe_fetch.ts`, respecting
robots/terms/authentication, no aggressive scraping.

## 7. News and social media

NEWS genres: REPORTING (can corroborate outputs/history), OPINION,
ALLEGATION, CORRECTION (context only). No aggregator. Social media: not
integrated; modelled as ATTRIBUTION_ONLY.
