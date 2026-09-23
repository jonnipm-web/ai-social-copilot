# Impact — Evidence Model

Code: `types.ts` (`EvidenceItem`), `provenance.ts`.

## 1. EvidenceItem

investigationId · claimId · sourceId · aboutOrganizationId (after entity
resolution) · relationship (SUPPORTS / CONTRADICTS / CONTEXTUALIZES) ·
relationshipBasis · reportedQuantity · level · observedPeriod · excerpt +
excerptHash · locator (page/section/char range) · personalData · legalStage ·
addedAt.

## 2. Provenance (required)

Every item must point to a known `Source` (publisher, publishedAt,
retrievedAt, contentHash per retention). The claim itself must cite the
source where it was made. Missing provenance → `INVALID_EVIDENCE` /
`INVALID_CLAIM`. Excerpts are optional; when present they are hashed and
verified. The engine never relies on an AI summary.

## 3. Relationship basis

| Basis | Counted? |
|---|---|
| STRUCTURED_MATCH | yes — the engine **derives** the relationship by comparing structured quantities (same metric+unit). ≥ claimed → SUPPORTS, 0 → CONTRADICTS, otherwise PARTIALLY_SUPPORTS. The declared relationship is ignored. |
| HUMAN_ASSESSED | yes — declared relationship used |
| LLM_SUGGESTED | **no** — excluded (`UNCONFIRMED_LLM_LINK`) until confirmed |

An LLM cannot set "evidence = true".

## 4. Exclusions (kept and shown, not counted)

OUT_OF_AUTHORITY_SCOPE · ENTITY_MISMATCH · STALE · PERIOD_MISMATCH ·
LEVEL_MISMATCH · UNITS_NOT_COMPARABLE · UNCONFIRMED_LLM_LINK ·
SOURCE_RETRACTED · SOURCE_CHANGED · DUPLICATE_CONTENT.

## 5. Sufficiency (describes the evidence base, never the organization)

| Code | Rule |
|---|---|
| NO_EVIDENCE | no usable (non-excluded) item |
| SELF_REPORTED | usable items all come from the subject |
| SINGLE_SOURCE | no independent item; only context/user/attribution material |
| INDEPENDENT_SUPPORT | exactly one independent publisher, agreeing |
| MULTI_SOURCE_SUPPORT | ≥ 2 distinct independent publishers, agreeing |
| CONFLICTING_EVIDENCE | independent items disagree |

Publishers are normalized and counted once (source-poisoning guard);
identical content hashes across sources are deduplicated (syndication).
Sufficiency is never converted into a public ranking.

## 6. Positive evidence

Modelled symmetrically: verified registration, audited accounts, independent
impact evidence, multi-source corroboration, favourable legal outcome
(`risk_indicators.ts`, polarity POSITIVE).

## 7. User-submitted evidence (prepared)

`Source.userSubmitted` / USER_DOCUMENT → authority USER_SUBMITTED: context
only, triggers review. Files belong to the Knowledge Vault (validation,
ownership, project isolation already exist there); Impact keeps HASH_ONLY.

## 8. Translation

Original claim/evidence text is preserved; translations are derived
representations tagged with a language (`RP-2`).
