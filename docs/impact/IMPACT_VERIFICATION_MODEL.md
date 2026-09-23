# Impact — Verification Model

Code: `verification.ts`, `temporal.ts`, `risk_indicators.ts`.
Policy version: `impact-verification/1+impact-source-authority/1+impact-temporal/1`.

## 1. Contract

```
verifyClaim({claim, evidence[], sources[]}, {evaluatedAt, subjectIdentity,
             openDispute?, flaggedSourceIds?, humanReview?})
  → ImpactResult<VerificationResult>
```

`VerificationResult`: status, underlyingStatus, sufficiency, displayClass,
supporting / partiallySupporting / contradicting / contextual / excluded,
conflicts, gaps, reviewState + reasons, rulesApplied (ordered rule ids),
subjectIdentity, evaluatedAt, policyVersion, evidenceSetHash, resultId,
and the literals `isFindingOfWrongdoing: false`,
`absenceOfEvidenceIsNotEvidenceOfWrongdoing: true`. Deep-frozen.

## 2. Pipeline per evidence item (rule ids)

R01 retracted · R02 changed · R03 entity mismatch · R04 LLM link not counted ·
R05 out of scope · R06 units · R07 non-final legal stage is not a
contradiction · R08 news allegation is context · R09 output ≠ outcome ·
R10 period mismatch · R11 stale state evidence · R12 duplicate content.
Survivors with AUTHORITATIVE/INDEPENDENT authority and a non-context
relationship are **counted**; the rest are **contextual**.

## 3. Conclusion

| Rule | Condition | Status |
|---|---|---|
| S01 | nothing counted, stale items exist | OUTDATED |
| S02/S03 | nothing counted | UNVERIFIED (absence ≠ wrongdoing) |
| S04 | authoritative items disagree | INCONCLUSIVE |
| S05 | authoritative items agree | their relationship decides (within scope); S06 records lower-tier disagreement as a conflict |
| S07 | independent items disagree | INCONCLUSIVE + ConflictRecord |
| S08 | independent items agree | SUPPORTED / PARTIALLY_SUPPORTED / CONTRADICTED |
| S09 | subject's own reports disagree with its claim | conflict recorded (context, never a contradiction by itself) |
| S10 | subject identity not CONFIRMED | SUPPORTED/PARTIAL/CONTRADICTED → INCONCLUSIVE (false-attribution guard) |
| S11 | open dispute | DISPUTED (underlyingStatus kept) |

Conflicts list every position with its source and value;
`resolution: 'UNRESOLVED'` — the engine never picks who is right.

## 4. Temporal consistency

State claims (registration, regulatory status, governance: 365 days;
affiliation: 180 days) — older evidence is STALE and cannot establish the
current state. Period claims — evidence whose observed period does not
overlap is excluded. Unknown bounds never create a mismatch. The clock is
injected (`evaluatedAt`).

## 5. Review states

AUTOMATED · REVIEW_REQUIRED · HUMAN_REVIEWED. Review required on:
contradiction, conflict, allegation, legal record, identity not confirmed,
untrusted instructions, open dispute, user-submitted material. A human review
binds to the exact `evidenceSetHash`; new evidence re-opens review (H02).

## 6. Versioning

`evidenceSetHash` = SHA-256 over an **explicit field list** of claim,
evidence and provenance-relevant source fields (extra metadata cannot enter).
`resultId` = hash(policy, claim, evaluatedAt, evidenceSetHash, context).
`Investigation.verify()` appends to history; nothing is overwritten
(`STATUS_CHANGED` audit event when the status moves).

## 7. Indicators (no score)

POSITIVE: VERIFIED_REGISTRATION, AUDITED_ACCOUNTS, INDEPENDENT_IMPACT_EVIDENCE,
MULTI_SOURCE_CORROBORATION, FAVOURABLE_LEGAL_OUTCOME.
CONCERN (requires human review): REGISTRATION_MISMATCH, IDENTITY_INCONSISTENCY,
DOMAIN_MISMATCH, CONFLICTING_CLAIMS, CLAIM_CONTRADICTED_BY_INDEPENDENT_SOURCE,
REGULATORY_OR_COURT_RECORD (final adverse stage only, stage carried),
UNVERIFIED_AFFILIATION.
INFORMATION_GAP: UNVERIFIED_CLAIMS, ONLY_SELF_REPORTED_EVIDENCE,
OUTDATED_EVIDENCE, UNRESOLVED_ALLEGATION.

Every indicator carries its basis ids and `isProofOfWrongdoing: false`.
Not indicators on their own: absence of evidence, high overhead, an
allegation, an open investigation. No fraud score, no 0–100, no ranking; a
future scorecard must be explainable, calibrated, versioned, tested and
contestable (separate gate).

## 8. Golden cases (`fixtures/golden.ts`)

| Case | Scenario | Expected |
|---|---|---|
| A | registration claim + current official registry | SUPPORTED · INDEPENDENT_SUPPORT · FACT · VERIFIED_REGISTRATION |
| B | beneficiary figure only in the org's own report | UNVERIFIED · SELF_REPORTED · no CONCERN |
| C | 20 claimed; gov 12, news 20, news "3 abandoned" (context) | INCONCLUSIVE · CONFLICTING_EVIDENCE · CONFLICT · conflict [12, 20] |
| D | registry evidence from 2023 evaluated in 2026 | OUTDATED · EVIDENCE_OUTDATED |
| E | similar name, identity UNCERTAIN, registry record about another entity | UNVERIFIED · IDENTITY_UNCONFIRMED · evidence excluded |
| F | no evidence | UNVERIFIED · NO_EVIDENCE · ABSENCE_OF_EVIDENCE · no CONCERN |
| G | gov 20 + academic 22 wells | SUPPORTED · MULTI_SOURCE_SUPPORT · positive indicators |
| H | self-published report with prompt injection | UNVERIFIED · SELF_REPORTED · UNTRUSTED_INSTRUCTIONS_DETECTED · review |
