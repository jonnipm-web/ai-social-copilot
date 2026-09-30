# Impact — Registry Intelligence (I2)

Mission IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01. Lab only: migration
`20260925010000` NOT applied to production, `impact-lab` NOT deployed, no real
registry enabled.

## 1. Pipeline

    organization candidate → identity resolution → registry lookup
    → source acquisition (snapshot) → provenance → lineage
    → independence classification → evidence candidate

Registry Intelligence improves IDENTITY, PROVENANCE, INDEPENDENCE and
TEMPORALITY. It never makes conclusions more aggressive: adapters provide
data, the deterministic engine decides status, and nothing about wrongdoing
is ever produced.

## 2. Layers

| Layer | Where | Network |
|---|---|---|
| Pure core (identity, lineage, registry statements, engine) | `_shared/impact/` | none (tripwire BT-1) |
| Server provider registry (composition, authority metadata) | `_shared/impact/provider_registry.ts` | none (fixtures) |
| Network adapters + transport | `_shared/impact_registry/` | only `safe_fetch` + host allowlist (tripwire BT-R1) |
| Lab API | `_shared/impact/lab_service.ts`, `impact-lab/` | via composed providers only |
| Persistence | migration `20260925010000` | — |

## 3. Adapter contract

`ImpactSourceProvider { descriptor; searchOrganization(q); fetchRegistryRecord(id) }`
(the mission's `searchOrganizations` / `getOrganization`; a registry
snapshot is the canonical record returned by `fetchRegistryRecord` →
`normalizeRegistryRecord`). The adapter owns query construction, network
acquisition, parsing, registry-specific semantics, retrieval timestamp and
error mapping; the engine never sees a provider format.

Server-owned descriptor metadata: provider id, source type, jurisdictions,
authority scope, authority class (STATUTORY_REGISTER / REGULATOR /
TAX_AUTHORITY), official, primary publisher, data scope, adapter version,
freshness, retrieval method, terms status, synthetic flag. A caller never
sets any of them.

## 4. Safe fetch

Exact host allowlist checked at every hop (new `allowedHosts` option of
`safe_fetch.ts`, default behaviour unchanged for other callers), https only,
no userinfo/port, SSRF guard (private, loopback, link-local, metadata,
IPv6-mapped; DNS-resolved), timeout 10 s, size caps (1 MB JSON / 8 MB CSV),
≤ 3 redirects, content-type check, per-provider minimum interval, no
automatic retry. Failures are operational: REGISTRY_UNAVAILABLE,
REGISTRY_RATE_LIMITED, REGISTRY_RESPONSE_INVALID, ORGANIZATION_NOT_FOUND —
never "not registered", never a negative signal (S-05).

Known residual (documented in `safe_fetch.ts` since IVE-X4C): DNS rebinding
window between resolution and connect; the host allowlist limits it to the
registries' own names.

## 5. Lab actions (IMPACT_LAB_API.md)

`search_registry` (read-only resolution, nothing persisted, nothing
attached), `ingest_provider_record` (idempotent on identical data, new version
on changed data, conflicts recorded by the database), `import_registry_claim`
(one neutral registry-statement claim + REGISTRY_RECORD evidence, only for a
snapshot that confirms the subject).

## 6. Fixtures

SYNTHETIC only: XA charity register (HopeBridge Foundation + former name
HopeBridge Trust + company cross-reference; Northstar Relief Initiative +
former name; Northstar Relief REMOVED; two "Example Aid Trust"), XA company
register (HopeBridge Foundation Limited → NAME_MISMATCH; Northstar Relief
REGISTERED vs charity REMOVED → STATUS_MISMATCH), XB charity register
(same-name HopeBridge Foundation in another jurisdiction). A synthetic trustee
in the fixture proves people are dropped (S-04).

## 7. Monetization boundary (preparation only)

Nothing is sold or gated beyond admin. Future tiers (Free / Pro / Premium /
Institutional-API) would differ in volume, freshness, jurisdictions and
export — never in how evidence is judged: the same engine, rules and
reputational safety for every tier; registry terms decide what may be
displayed or redistributed per tier (dossier §6).

## 8. Cache

No cache infrastructure was built. Snapshots are the persisted record of a
retrieval (retrievedAt, sourceAsOf, provider, data hash); freshness is always
recomputed at read time, so a stored snapshot is never presented as fresh.
