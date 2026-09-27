# Impact — Roadmap (proposal, not a commitment)

Order derived from what the Foundation audit showed is missing. Each phase is
its own gated mission (Codex adversarial review; Class D where it touches
persistence, network, auth or external actions).

| Phase | Scope | Why here |
|---|---|---|
| **I1 Persistence + RLS + Lab EF** | Lab-only migration (investigations, sources, claims, evidence, results history, audit, disputes), owner/project RLS with disposable-DB tests, one admin-only `impact-lab` Edge Function (auth → entitlement → engine), observability wiring | Nothing is stored today; RLS is NOT_APPLICABLE until this exists |
| **I2 Registry Intelligence** ✅ Lab | Identity model, lineage (CF-04), registry adapters (UK/US) via `safe_fetch.ts`, dossier; real registries NOT enabled | Identity is the foundation of every other claim |
| **I3 Evidence Collection** | Knowledge Vault integration for documents (hash + locator), user-submitted evidence flow with review | Reuses existing owner-scoped ingestion |
| **I4 Claim Extraction (LLM, bounded)** | LLM extraction through `acceptLlmClaimCandidates` + `checkNarrative`; adversarial prompt-injection suite | LLM helps, never decides |
| **I5 Organization Profiles (Lab UI)** | Minimal EXPERIMENTAL Flutter screen rendering `ImpactReport` (PT/EN), admin-only | UI after semantics are proven |
| **I6 Project / Campaign verification** | Affiliation claims, look-alike domain signals, impersonation workflow | |
| **I7 Financial Transparency** | Structured filings/audited accounts per jurisdiction | |
| **I8 Impact Measurement** | Outcome/impact evidence (academic, government) | |
| **I9 IVE Impact** | Adapter to IVE Intelligence Core once IVE Foundation is PASS (Integration Gate) | |
| **I10 Monitoring / Alerts** | Re-verification on source change, staleness alerts | |
| **I11 Organization Response Portal** | Right-to-respond UI on top of `Dispute` | |
| **I12 Donation / Partner layer** | Only after legal/regulatory review; AEF persistence + Human Gate; no custody | Highest risk, last |

## Monetization (analysis only — nothing implemented)

- Consumer Free: ads (decided). Pro consumer; Donor Intelligence; Organization
  Verification tools; NGO tools; institutional due diligence; API/Enterprise.
- **Firewall COMMERCIAL ↔ VERIFICATION**: payment never buys a positive
  verification; advertisers/sponsors are disclosed next to reports
  (`CommercialRelationship.mustDisclose`); commercial metadata cannot enter
  the engine (VE-15); no sponsored ranking (`EDITORIAL_INDEPENDENCE`).
- An "Organization Verification" product must mean *organizing and
  presenting the organization's evidence*, with the same engine and rules —
  never a paid badge.
- Ads must not be shown next to reports in a way that implies endorsement;
  advertiser categories for Impact pages need a policy before ads ship.

## Status after I1

I1 (Lab persistence + RLS + Lab EF + server provider registry) is complete in
the Lab: migration not applied to production, EF not deployed.

Before any non-Lab exposure: decide the service_role residual (option A
least-privilege writer role or B database-side procedures —
IMPACT_RLS_MODEL.md §6), apply the migration through the normal production
gate, add the EF to the deploy allowlist through its own gate.

Next gate candidates (decision for Agente Martins): **I2 Registry
Intelligence** (first real registry adapter via safe_fetch) — recommended,
since identity confirmation now depends only on provider snapshots — or the
architectural closure of the service_role residual first.

## Status after I2

Registry Intelligence is complete in the Lab (synthetic registries; real
adapters written, offline-tested, one controlled read-only smoke; none
enabled). Before enabling a real registry: Owner terms/licence confirmation
and credentials (dossier §6). Before any non-Lab exposure: service-role gate
A/B re-evaluation.

Next gate candidates (decision for Agente Martins — NOT started):
**I3 Evidence Collection** (Knowledge Vault documents, hash + locator,
user-submitted evidence with review), or a "Registry Enablement" gate that
turns on ONE real registry (Charity Commission or Companies House) once the
Owner has confirmed terms and created the credential.

## Status after I3

Evidence Collection is complete in the Lab: uploaded / cloud-imported files
are hashed and extracted by the server, candidates are reviewed by a human
and promoted to bounded, locator-bound evidence that never counts as
authority. Not done on purpose: OCR, URL fetching (egress pinning), direct
Knowledge Vault linkage, storage of originals, LLM suggestions, billing.

Next gate candidates (decision for Agente Martins — NOT started): **I4**
(e.g. verification reporting / dossier export over the evidence graph), a
Registry Enablement gate (one real registry after Owner terms + credential),
or an OCR / URL-snapshot boundary gate (requires egress pinning). The
service-role A/B re-evaluation stays mandatory before any non-Lab exposure.

## Status after I4

The Verification Dossier is complete in the Lab: a deterministic,
explainable, hashed projection with limitations, non-findings, disputes,
staleness and snapshot verification; I3F-03 (orphan sources) is closed by
atomic ingestion. Not done on purpose: UI (no Impact surface exists), PDF,
public sharing, scheduled re-verification, monetization.

Next gate candidates (decision for Agente Martins — NOT started): Impact
product UX (a first admin screen over the dossier contract), Impact
monitoring / scheduled re-verification (the snapshot register + evidence-set
hashes already allow change detection), or a controlled Registry
Enablement gate (egress pinning + Owner terms + credential). Monetization
dimensions prepared (dossier count, exports, history, retention) without
degrading truth quality in any tier.
