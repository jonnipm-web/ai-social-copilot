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
| Syndication / publisher variants | publisher identity via syndicatedFrom, one voice per publisher | CF-04 |
| Caller-supplied provider registry | must be server-built at integration (I1) | CF-06 (deferred) |
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
