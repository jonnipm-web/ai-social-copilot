# Impact — Reputational Safety (P0 requirement)

The product must never turn uncertainty into an accusation.

## 1. What the system will not say

No output may call an organization fraudulent, a scam, corrupt, criminal or
guilty, nor "trustworthy"/"safe to donate"/"don't donate" — in PT or EN.
`findVerdictLanguage()` (Unicode-aware) guards generated text and LLM
narratives; the report builder self-checks its templates and throws if one
ever produced verdict language. There is no verdict, score, rank or
"trust" field in any type (BT-3, RP-1).

## 2. Display classes

Every claim is rendered with its epistemic class:
VERIFIED FACT (authoritative source, within its scope) · SOURCE CLAIM ·
ALLEGATION · INFERENCE · CONFLICT · UNKNOWN · NO EVIDENCE FOUND — plus the
status and sufficiency labels (`i18n.ts`). Fixed disclaimers: no verdict;
absence of evidence is not evidence of wrongdoing; indicators are not proof;
EXPERIMENTAL.

## 3. Guarantees (tested)

| Guarantee | Test |
|---|---|
| Absence of evidence → UNVERIFIED + INFORMATION_GAP, never CONCERN | GOLDEN-F |
| Self-declaration ≠ verification | GOLDEN-B, SA-1 |
| Allegation ≠ fact; news allegation never contradicts | VE-7 |
| Investigation/charge ≠ guilt; exact stage shown | VE-8 |
| Conflicts shown side by side; no side chosen | GOLDEN-C |
| No attribution to an unconfirmed identity | GOLDEN-E, VE-9 |
| Negative records are updatable (dispute, correction, retraction) | VE-11, VE-12, IW-3 |
| LLM cannot declare fraud or invent evidence/status/numbers | RS-2, RS-3 |
| High overhead is not an indicator | FM-1 |
| Adversarial fixtures use fictitious organizations only | BT-10 |

## 4. Disputed claims / right to respond (foundation)

`Dispute` kinds: ORGANIZATION_RESPONSE, CORRECTION_REQUEST,
RETRACTION_REQUEST, SOURCE_UPDATE; resolutions: CORRECTED, UPHELD, WITHDRAWN,
SOURCE_RETRACTED. An open dispute makes the claim DISPUTED (underlying status
preserved) and requires review; resolution forces re-verification; nothing is
deleted and history is kept. No organization portal yet (roadmap I10).

## 5. Publication

Nothing is published. Public accusation, external publication, contact with
organizations and reports to authorities are class C — blocked, future AEF +
Human Gate only. No public "best/worst NGO" ranking will be created by the
Foundation.
