# Impact — Verification Dossier (IV-IMPACT-I4-VERIFICATION-DOSSIER-01)

Status: **EXPERIMENTAL, Lab only** (admin-only `impact-lab`, not deployed;
migration `20260927010000` not applied to production).

## 1. What a dossier is — and is not

A dossier is a **deterministic projection** of one investigation's persisted
state:

```
PROJECT → INVESTIGATION → ORGANIZATION IDENTITY → REGISTRY FACTS → SOURCES
→ ARTIFACTS → HASHES → LOCATORS → CLAIMS → EVIDENCE → VERIFICATIONS
→ CONFLICTS → LIMITATIONS → DISPUTES → PROVENANCE → AUDIT → DOSSIER
```

It is **not** a source of truth, a verdict, a score, a ranking, a seal, a
recommendation or a publication. Every status, epistemic class, authority and
independence value is **copied** from the engine's stored results
(`impact-verification`, I1/I2) — the builder decides nothing. No client
field, reviewer text, document text or model output reaches it.

## 2. Questions it answers

| Question | Section |
|---|---|
| Which organization? How was identity determined? | `subject` (identityStatus from provider registry snapshots only; AMBIGUOUS/UNRESOLVED never shown as confirmed) |
| Official records? | `registryFacts` (attributed to the provider, `factClass: OFFICIAL_REGISTRY_RECORD`, freshness), `registryConflicts` |
| Which sources? who published / hosted / uploaded? | `sources` (publisher ≠ host: a cloud drive is `HOST_NOT_PUBLISHER`; uploads are `USER_UPLOAD`, never authority) |
| What supports each claim, and where exactly? | `claims[].verification.{supporting,partiallySupporting,contradicting,contextual,excluded}` + `evidence[].locator` + `locatorState` |
| Status of each claim? | engine `status` / `displayClass` / `sufficiency` / `reviewState` / `gaps` / `rulesApplied` |
| Conflicts? | claim `conflicts` (every position, no winner) + registry conflicts |
| What is unknown or insufficient? | `limitations` (derived from real state) |
| Disputes / pending reviews? | `disputes`, `reverificationPending`, `EVIDENCE_REVIEW_PENDING` |
| Which point in time? | `asOf` (latest material timestamp) + envelope `LIVE` / `SNAPSHOT` |
| Provenance / reproducibility? | refs to every row, artifact hashes, `policyVersions`, `evidenceSetHash`, audit position in the envelope |
| What does it NOT claim? | `doesNotEstablish` (always present) |

## 3. Taxonomy (reused, not invented)

The dossier uses the engine's real vocabulary — no new truth states:

- `ClaimStatus`: SUPPORTED · PARTIALLY_SUPPORTED · CONTRADICTED · INCONCLUSIVE ·
  OUTDATED · DISPUTED · UNVERIFIED (+ `verification: null` = not yet verified).
- `EpistemicClass`: FACT · CLAIM · EVIDENCE · INFERENCE · ALLEGATION · CONFLICT ·
  UNKNOWN · ABSENCE_OF_EVIDENCE.
- `EvidenceSufficiency`: NO_EVIDENCE · SELF_REPORTED · SINGLE_SOURCE ·
  INDEPENDENT_SUPPORT · MULTI_SOURCE_SUPPORT · CONFLICTING_EVIDENCE.

FACT remains exclusively the engine's deterministic class (official source,
within its authority scope). "Insufficient evidence" (`INSUFFICIENT_EVIDENCE`
limitation) is informative: *"We did not find enough evidence in the sources
analyzed to confirm a claim. This does not indicate it is false."*

## 4. Dossier status (completeness, not character)

`INCOMPLETE` (no claims, a claim never verified, or re-verification pending) ›
`REVIEW_REQUIRED` (engine review required, open dispute, pending candidates) ›
`PARTIAL` (any limitation) › `COMPLETE`. There is no TRUSTED / SAFE / RISKY
state (also refused by a SQL CHECK on the snapshot register).

## 5. Limitations and non-findings

Limitations (with scope and ref): IDENTITY_NOT_CONFIRMED · IDENTITY_AMBIGUOUS ·
NO_REGISTRY_RECORD (≠ "not registered") · REGISTRY_RECORD_NOT_FRESH ·
REGISTRY_CONFLICT · SOURCE_NOT_ACTIVE · EXTRACTION_OCR_REQUIRED ·
EXTRACTION_PARTIAL · EXTRACTION_FAILED · ARTIFACT_SUPERSEDED ·
EVIDENCE_REVIEW_PENDING · CLAIM_NOT_VERIFIED · REVERIFICATION_PENDING ·
INSUFFICIENT_EVIDENCE · CONFLICTING_EVIDENCE · DISPUTE_OPEN · EVIDENCE_OUTDATED ·
LINEAGE_UNCERTAIN · HUMAN_REVIEW_REQUIRED · LOCATOR_UNVERIFIABLE ·
EXCERPT_WITHHELD.

`doesNotEstablish` always contains NOT_A_FINDING_OF_WRONGDOING,
NO_INTENT_OR_INNOCENCE, NO_DONATION_ADVICE, NOT_PROFESSIONAL_DUE_DILIGENCE,
ABSENCE_IS_NOT_EVIDENCE, plus, when relevant: UNVERIFIED_IS_NOT_FALSE,
CONFLICT_IS_NOT_WRONGDOING, REGISTRY_STATUS_IS_NOT_WRONGDOING (inactive /
dissolved / removed is not an accusation), DOCUMENTS_ARE_NOT_INDEPENDENT_SOURCES
(CF-04), USER_UPLOADS_ARE_NOT_AUTHORITY, QUOTED_TEXT_IS_NOT_A_PLATFORM_STATEMENT.

## 6. Time, staleness, snapshots

- `asOf` = the latest material timestamp of the persisted state (claims,
  evidence, sources, verifications, disputes, artifacts, reviews) —
  deterministic, never "now".
- A claim is `reverificationPending` when the evidence-set hash recomputed
  over the current evidence differs from the one the stored verification
  used (`EVIDENCE_CHANGED`), or a dispute was opened / resolved after it.
- `LIVE` (get_dossier) reflects the current state; `SNAPSHOT`
  (export_dossier) is historical: it never updates itself.
  `verify_dossier` answers NOT_ISSUED / CURRENT / STALE.
- Registry freshness uses each provider's declared `freshnessDays` (no
  universal threshold). Stale means *"may need updating"*, never *"false"*.

## 7. Change detection (prepared)

Two dossiers of one investigation are comparable ref by ref (claims,
evidence, sources, artifacts, disputes are sorted by ref, code-point order);
the snapshot register keeps every issued hash with its `asOf`. A future
"what changed since the previous dossier" is a diff of two contents — no
schema change needed.

## 8. Explainability

Every claim carries the engine's machine-readable *why*: `rulesApplied`, the
evidence ids per bucket with their authority scope, `gaps`, `sufficiency`,
independence (`independentVoices`, lineage state per source), and each
evidence's artifact / hash / locator. No model reasoning is involved.

See IMPACT_DOSSIER_SCHEMA.md, IMPACT_DOSSIER_EXPORT.md, IMPACT_DOSSIER_SECURITY.md.
