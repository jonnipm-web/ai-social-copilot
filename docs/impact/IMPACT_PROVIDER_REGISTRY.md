# Impact — Server-side Provider Registry (I1, closes CF-06)

Code: `supabase/functions/_shared/impact/provider_registry.ts`
(`impact-provider-registry/1`).

## What changed

Foundation: the Verification Engine trusted whatever `trustedProviders` its
caller passed (CF-06, deferred). I1:

1. The trusted set is **composed in server code** from fixed descriptors
   (`registeredProviders()`, frozen map). `trustedProviderRefs()` is the only
   value the Lab ever hands to the engine. No request field, header or stored
   row can add, remove or re-scope a provider (`trusted_providers` in a request
   is an unknown field → `INVALID_REQUEST`).
2. `acquisition = PROVIDER` can only be produced by
   `ingestProviderRecord(providerId, recordId, ref)`: the server looks the
   provider up in the registry (Map lookup; prototype keys never resolve),
   the provider fetches the record, the server normalizes it and builds the
   Source (type, publisher, jurisdiction, content hash = raw record hash,
   retention SNAPSHOT) and stores the canonical snapshot.
3. Client-submitted sources are forced to `ANALYST_ENTRY` (or `USER_UPLOAD`),
   so they are at most CONTEXTUAL — whatever type/publisher they claim. After
   insertion, provenance fields are immutable in the database.
4. Subject identity for the engine comes only from ACTIVE provider snapshots
   of a registered provider of the matching type (entity resolution:
   CONFIRMED / PROBABLE / UNCERTAIN / UNRESOLVED).

## Descriptor

| field | value (Lab) |
|---|---|
| providerId | `fixture-xa-charity-registry` |
| sourceType | OFFICIAL_REGISTRY |
| capabilities | SEARCH_ORGANIZATION, FETCH_REGISTRY_RECORD |
| jurisdictions | XA (fictitious) |
| authorityScope | LEGAL_REGISTRATION, REGULATORY_STATUS, GOVERNANCE, OPERATING_HISTORY |
| freshnessDays | 7 |
| retrievalMethod | FIXTURE |
| network | NONE |

Fixture records: HopeBridge Foundation (XA-1234567), Northstar Relief
Initiative (XA-7654321) and a look-alike "Northstar Relief" (XA-9990001,
REMOVED) — all fictitious.

## Spoofing tests

LS-01 (frozen registry, prototype keys), LS-05 (client cannot declare
acquisition/provider/trust/authority/snapshot/SNAPSHOT retention), LS-06
(analyst "official registry" and self report labelled registry stay
non-authoritative), LS-07 (unknown / `constructor` provider → fail closed),
LS-08 (look-alike registry record never confirms identity), SQL S11/S12
(provenance cannot be upgraded later; PROVIDER needs a provider id).

## I2 (Registry Intelligence)

`impact-provider-registry/2`: `composeProviderRegistry()` (frozen, duplicate
ids and malformed descriptors fail closed), three SYNTHETIC registries
(`fixture-xa-charity-registry`, `fixture-xa-company-registry`,
`fixture-xb-charity-registry`), server-owned authority metadata (official,
authority class, primary publisher, data scope, adapter version, terms
status, synthetic). `trustedRefs()` now carries `primaryPublisher`.

Real adapters (Companies House, Charity Commission, IRS EO BMF) live in
`_shared/impact_registry/`, use `safe_fetch.ts` with a per-hop host allowlist,
and are NOT composed into the Lab registry (catalog CAT-01) until the Owner
confirms terms/credentials and adds them to `impact_trusted_provider` in the
same change (drift test PD-01 reads the latest migration's allowlist). See
IMPACT_REGISTRY_SOURCE_DOSSIER.md.
