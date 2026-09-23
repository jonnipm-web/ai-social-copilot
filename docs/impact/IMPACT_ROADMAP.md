# Impact — Roadmap (proposal, not a commitment)

Order derived from what the Foundation audit showed is missing. Each phase is
its own gated mission (Codex adversarial review; Class D where it touches
persistence, network, auth or external actions).

| Phase | Scope | Why here |
|---|---|---|
| **I1 Persistence + RLS + Lab EF** | Lab-only migration (investigations, sources, claims, evidence, results history, audit, disputes), owner/project RLS with disposable-DB tests, one admin-only `impact-lab` Edge Function (auth → entitlement → engine), observability wiring | Nothing is stored today; RLS is NOT_APPLICABLE until this exists |
| **I2 Registry Intelligence** | First real registry adapter (one jurisdiction), via `safe_fetch.ts`, terms/robots review, freshness; entity-resolution against real records | Identity is the foundation of every other claim |
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
