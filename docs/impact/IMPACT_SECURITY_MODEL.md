# Impact — Security Model

## 1. Threat model → control → test

| Threat | Control | Test |
|---|---|---|
| Cross-user access | `Investigation.authorize` (owner ref) | IW-1 |
| Cross-project access | actor must own `projectId` (also at create) | IW-1 |
| Cross-investigation records | investigationId check in engine + workspace | PV-1, IW-2 |
| Cross-subject attribution inside an investigation | claims must be about the investigation subject | CF-01 |
| Forged organization / fake registration number | entity resolution; only CONFIRMED merges; DISTINCT on number mismatch | ER-1..6 |
| False entity merge | name never identity; identity cap S10 | ER-2, VE-9, GOLDEN-E |
| Malformed evidence / oversize | validation + limits (text 4k, excerpt 2k, 200 items/claim) | PV-5, PV-6 |
| Tampered evidence | excerpt SHA-256 check; hash-chained audit | PV-4, IW-4 |
| Deleted/changed source | UPDATED/RETRACTED excluded; re-verification logged | VE-11, IW-3 |
| Stale registry record | state-claim staleness | GOLDEN-D |
| Source poisoning | per-publisher counting, content-hash dedupe, authority table | VE-6, SA-1..4 |
| Forged provenance (self report relabelled as audit/registry) | provenance gate: independence only via trusted provider for that type+jurisdiction | G1-01a/b/c |
| Future/reversed dates making stale data current | earliest as-of, period (start and end) ≤ retrieval, calendar check | G1-02a/b, CF-02 |
| Jurisdiction omission | jurisdiction-bound types need an explicit jurisdiction | CF-03 |
| Syndication / publisher variants | lineage never removes evidence; syndicatedFrom only merges voices for counting (union-find, order-independent, cycle-safe); conflict basis uses the raw publisher; corrections only via audited source status | CF-04, FV-01, FV2-01..03, FV3-01..03 |
| Caller-supplied provider registry | server-composed registry (I1); authority metadata server-owned (I2) | CF-06 CLOSED, LS-01, S-01 |
| Unestablished / syndicated sources inflating corroboration | lineage analysis: only established originals are separate voices; unknown lineage = one voice at most | CF-04 CLOSED, L-01..10, MUT-03 |
| Entity spoofing (another organization's registry record cited for the subject) | engine R03B + DB subject-registration guard; registry claims only from a confirming snapshot | ID-15, I2-39/40, MUT-02 |
| Entity collision / cross-jurisdiction merge | canonical id country:scheme:number; names never identity; grouping by identifiers only | ID-02..11 |
| Registry SSRF / redirect / oversize | transport: exact host allowlist per hop, https, SSRF guard, size/time caps, content type, no retry | RT-01..05 |
| PII in registry data | people never requested/parsed/stored; DB refuses snapshots with people keys | CH-01, CC-01, IRS-01, S-04, I2-08 |
| Provider failure read as a finding | operational error codes only; nothing persisted or inferred | S-05, RT-02 |
| Unknown / prototype-key enum values | own-property allowlists for every enum; status and dispute updates validated | G1-05a/b, CF-05 |
| Review binding bypass | reviewBindingHash covers flags, identity, dispute, providers | G1-04 |
| Prompt injection | engine never reads text; scan flags; wrapper; grounding | GOLDEN-H/H2, RS-4..6 |
| LLM hallucination / authority | LLM_SUGGESTED excluded; `checkNarrative` (case-insensitive PT/EN status phrases, confusable folding, invisible-char stripping, mark stripping, mixed-script rejection) | VE-2, RS-2, RS-3, G1-03a/b |
| HTML injection | report is structured data; generated text is fixed templates; renderers must escape | RP-1 |
| URL SSRF / redirect abuse | `checkReferenceUri` (scheme, credentials, loopback/private/link-local/metadata, numeric shorthands, internal TLDs); no fetch in Impact; future fetch only via `safe_fetch.ts` (DNS check, redirect re-validation, size/time limits) | SSRF-1/2, BT-1 |
| Entitlement bypass | module `impact` EXPERIMENTAL → admin-only via Entitlement Core; client fields not an input | BT-4..6 |
| Public action bypass | class C has no executor; unknown actions fail closed | BT-7, BT-3 |
| Ads/pay-to-trust | commercial metadata excluded from hash and engine | VE-15 |
| Log leakage | allowlist-only events (own-property keys; JWT-shaped values refused) | OB-1, C-02 |

Residual (documented, inherited): DNS-rebinding window in `safe_fetch.ts`
(no connection pinning) — relevant only when a network provider is added.

## 2. Entitlement

Reuses `_shared/entitlement.ts` unchanged. `impact` = EXPERIMENTAL,
minimumPlan free, actionClass REVERSIBLE. Free/Pro/Premium and beta testers
are denied; admin role allowed (audited). No Edge Function exists yet; when
one does, it must call `requireModuleAccess(req, user, 'impact', …)` after
authentication and before any work.

## 3. Isolation / RLS

No persistence in the Foundation → **RLS NOT_APPLICABLE**. Isolation is a
domain guard only. The persistence gate must add owner/project RLS with
tests: self read, authorized write, non-owner deny, anonymous deny,
cross-investigation deny, cross-project deny (disposable PostgreSQL 17, same
harness as `disposable-db-rls-ci`).

## 4. Action classes

A read/search/analyze (READ_ONLY) · B internal records (REVERSIBLE) ·
C public accusation, external contact, report to authority, payment/donation,
external publication (CONSEQUENTIAL) — **not implemented**; future path
Impact → ActionIntent → AEF → policy → Human Gate → tool → receipt.
AEF persistence is still unavailable (`AEF_PERSISTENCE_AVAILABLE = false`).

## 5. Donations

Not implemented. Impact does not custody money. A future donation layer needs
verified destination, payment provider, fraud controls, receipts,
refund/dispute and regulatory review — separate gate.

## 6. Privacy

Data minimization: organizational data only. PERSONAL/SENSITIVE/MINOR
evidence rejected; named officials only as PUBLIC_OFFICIAL_ROLE from
official registers. Audit trail and logs hold ids/codes only.

## 7. Moderation

AUTOMATED / REVIEW_REQUIRED / HUMAN_REVIEWED on every result; all CONCERN
indicators require human review.

## 8. Retention (conceptual)

Source metadata: while the investigation exists · snapshots: 730 days ·
user evidence: 365 days · verification results: history kept with the
investigation · audit trail: 2,555 days. Enforced with persistence.

## 9. I1 update

- RLS is now **applicable and tested** on PostgreSQL 17 (122 checks,
  mutation-tested) — see IMPACT_RLS_MODEL.md. Section 3 above is superseded.
- CF-06 closed (server-side provider registry, IMPACT_PROVIDER_REGISTRY.md).
- The Lab Edge Function adds: strict schemas (unknown fields rejected), 64 KiB
  body limit, per-investigation limits, 404 for foreign ids (no existence
  oracle), allowlisted logs, no LLM/network/quota, class C blocked.
- Escalated: service_role root-of-trust residual (IMPACT_RLS_MODEL.md §6).

## I2 notes

SERVICE_ROLE_TRUST_GATE = LAB_ONLY (Owner + Agente Martins): service_role is
privileged infrastructure root; RLS does not restrict it; the I1/I2 database
invariants still apply to it. I2 adds no new service_role privilege beyond
INSERT on the extended `impact_sources` columns (all CHECK-constrained) and
SELECT on `impact_registry_conflicts` (written only by the trigger).

## I3 notes

- Files: server-side detection and bounded parsing (IMPACT_FILE_SECURITY.md);
  executables, archives, macro documents, legacy OLE2 and disguised binaries
  refused; nothing persisted for a refused file.
- Trust: the server computes the file hash; the client cannot declare hash,
  type, text, excerpt, method, review or authority (strict contract).
- Spoofing blocked in TS and SQL: hash (artifact ↔ source ↔ candidate),
  locator (structure + extraction), review (candidates born PENDING, final
  states immutable, owner-only actor), evidence (artifact sources carry only
  promoted candidates matching excerpt/locator/claim).
- Human review ≠ verification; USER_UPLOAD never becomes authority.
- service_role not expanded beyond LAB_ONLY: INSERT/SELECT on artifacts,
  INSERT/SELECT/UPDATE (review fields only, trigger-enforced) on candidates,
  no DELETE. Residual: `file_hash` trusted from the server path.
- Observability: artifact events carry codes, sizes and counts only.
