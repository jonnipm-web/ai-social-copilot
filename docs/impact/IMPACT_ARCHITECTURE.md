# InsightValues Impact — Architecture (Foundation)

Impact is an **evidence-based social-impact intelligence and verification**
vertical. It is not a fraud detector and never tells a user "trust" or
"don't trust". It shows who the entity is, what it claims, which evidence
supports or contradicts each claim, where the evidence came from and when,
what is unknown, which conflicts exist and which points merit a closer look.

```
SOURCE ─► VALIDATE ─► NORMALIZE ─► LINK ─► VERIFY ─► ANALYZE ─► REPORT
provider   provenance   provider     entity   verification  indicators  report
.ts        .ts          .ts          _resolution .ts        .ts         .ts
```

## Layout — `supabase/functions/_shared/impact/`

| File | Responsibility |
|---|---|
| `types.ts` | Domain model (organization, project, campaign, source, claim, evidence, statuses). |
| `errors.ts` | Structured error contract (`ImpactResult`, codes). |
| `source_authority.ts` | Source × claim-kind authority table (no universal credibility score). |
| `provenance.ts` | Validation, provenance, retention/snapshot policy, reference (SSRF) check. |
| `temporal.ts` | State-claim staleness, period overlap. |
| `verification.ts` | Deterministic Verification Engine. |
| `entity_resolution.ts` | Identity matching; only CONFIRMED may merge. |
| `risk_indicators.ts` | POSITIVE / CONCERN / INFORMATION_GAP indicators; no score. |
| `financial_and_metrics.ts` | Financial disclosure, impact chain, campaign affiliation. |
| `safety.ts` | Untrusted content, LLM boundary, verdict-language guard. |
| `provider.ts` | `ImpactSourceProvider` contract + `FixtureProvider` + RAW→CANONICAL. |
| `investigation.ts` | Workspace: isolation, versioned history, disputes, hash-chained audit. |
| `boundaries.ts` | Action classes A/B/C, AEF mapping, commercial firewall, module id. |
| `observability.ts` | Allowlist-only events. |
| `report.ts`, `i18n.ts` | Surface-independent report, PT/EN labels. |
| `fixtures/golden.ts` | Golden cases A–H (fictitious organizations, jurisdiction `XA`). |

## Properties (enforced by tests, not only documented)

- **Pure**: no network, env, wall clock, randomness, DB client or LLM
  (`boundary_test.ts` BT-1/BT-2). Timestamps are injected.
- **Reproducible**: same inputs → same `resultId` and `evidenceSetHash`,
  independent of input order (golden GOLDEN-ALL).
- **Isolated** from Commercial, Module Lab HEAD, Quant and IVE Intelligence:
  imports only `./*` and `../safe_fetch.ts` (BT-2).
- **Surface-independent**: the report is a typed object for Android/Web;
  no Flutter screen, no app, no extension in this Foundation.
- **Not exposed**: module `impact` is EXPERIMENTAL → admin-only through the
  existing Entitlement Core; no Edge Function, no route, no persistence.

## Integration boundaries (future gates, not built)

| Boundary | Contract today | Future |
|---|---|---|
| IVE Intelligence | `checkNarrative()` + `LLM_SYSTEM_POLICY` + `wrapUntrustedDocument()` | Adapter Impact Intelligence → IVE Core once IVE Foundation is PASS (Integration Gate). IVE may answer "what do we know / which sources / which conflicts", always from `VerificationResult`, never from its own judgement. |
| Knowledge Vault | Documents are UNTRUSTED data; `acceptLlmClaimCandidates()` requires verbatim grounding | Evidence documents stored by the Vault (owner-scoped). Impact keeps hash + locator, not the file. |
| Projects | `Investigation.projectId` + actor project check | Persisted with owner/project RLS. |
| AEF | `requestImpactAction()` returns BLOCKED for class C | Impact → ActionIntent → AEF → policy → Human Gate → tool → receipt. |
| Providers | `ImpactSourceProvider` + capability declaration | Registry adapters per jurisdiction through `safe_fetch.ts`. |

## I1 — Persistence and Lab API

```
client (admin) ──JWT──► impact-lab EF ─ auth ─ entitlement('impact') ─ schema
                              │ reads: caller JWT → PostgreSQL RLS
                              │ engine: server clock + server provider registry
                              └ writes: service_role → DB invariants + trigger audit
```

The pure core stays pure: the Lab service receives a store, the caller id and
the server clock by injection; only `impact-lab/` touches Supabase. See
IMPACT_PERSISTENCE_MODEL.md, IMPACT_RLS_MODEL.md, IMPACT_LAB_API.md and
IMPACT_PROVIDER_REGISTRY.md.

## I2 — Registry Intelligence

```
search_registry ─► server provider registry ─► provider (fixture | adapter)
                                                  │ adapters: _shared/impact_registry/
                                                  │ transport → safe_fetch (host allowlist per hop)
                   ◄─ canonical records ◄─ normalizeRegistryRecord (pure)
resolveOrganization (pure) ─► EXACT / STRONG / AMBIGUOUS / NO_MATCH (nothing attached)
ingest_provider_record ─► snapshot source (idempotent / versioned) ─► DB trigger: registry conflicts
import_registry_claim ─► registry statement + REGISTRY_RECORD evidence (subject must be CONFIRMED)
verifyClaim ─► analyzeIndependence (lineage) ─► sufficiency; R03B entity guard; R10B temporal
```

The pure core has no network; the network layer lives outside it and is only
reached through composed providers. No real registry is composed in the Lab.
See IMPACT_REGISTRY_INTELLIGENCE.md.
