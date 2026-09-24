# Impact — Dossier Schema `impact-dossier/1`

```
DossierDocument {
  schemaVersion: "impact-dossier/1"
  content: DossierContent            ← hashed
  integrity: { algorithm: "SHA-256", canonicalization: "impact-canonical-json/1", contentHash }
  envelope: { kind: LIVE|SNAPSHOT, generatedAt, auditSeq, auditHead, snapshotRef|null, notice,
              registryFreshAtGeneration: [{sourceRef, fresh}] }   ← NOT hashed (request-clock facts)
}
```

Canonicalization `impact-canonical-json/1` = `verification.ts canonical()`:
object keys sorted, `undefined` omitted, arrays in their (deterministic)
order, JSON scalars. Every array in `content` is sorted by ref in code-point
order (locale-independent).

## DossierContent (language-neutral: codes and refs, no UI strings)

| Field | Content |
|---|---|
| `schemaVersion`, `kind: "VERIFICATION_DOSSIER"` | |
| `isFindingOfWrongdoing: false`, `absenceOfEvidenceIsNotEvidenceOfWrongdoing: true`, `isPublication: false` | contract literals |
| `policyVersions` | verification, lineage, artifact, provider registry |
| `investigation` | `ref`, `projectRef`, `status` (no owner id) |
| `asOf` | latest material timestamp, or null |
| `subject` | `ref`, `type`, `declaredIdentity` (organization fields only), `identityStatus`, `identityConfirmed`, `identityBasis: PROVIDER_REGISTRY_SNAPSHOTS_ONLY` |
| `registryFacts[]` | provider, record, canonical id, legal name, `registryStatus`, statusAsOf, sourceAsOf, registeredOn, dissolvedOn, retrievedAt, dataHash, synthetic, `freshnessDays`, `freshAtAsOf` (freshness evaluated at the dossier asOf — the request clock never enters the hash, Codex I4G1-N01), provider authority, `factClass: OFFICIAL_REGISTRY_RECORD` |
| `registryConflicts[]` | kind, both source refs, canonical id |
| `claims[]` | ref, kind, `text` (or null + `textWithheld`), language, source, origin, period, quantity, level, extractedAt, project/campaign refs; `verification` (null if never verified) with version, resultId, status, underlyingStatus, displayClass, sufficiency, reviewState, reviewReasons, gaps, rulesApplied, evaluatedAt, policyVersion, evidenceSetHash, subjectIdentity, evidence buckets `{evidenceRef, sourceRef, sourceType, authority, declared/effective relationship, basis, asOf}`, excluded `{evidenceRef, reason}`, conflicts, independence; `reverificationPending`, `reverificationReasons`, `disputeRefs`, `evidenceRefs`, `isFindingOfWrongdoing: false` |
| `evidence[]` | ref, claim, source, aboutOrg, relationship, basis, observedPeriod, level, reportedQuantity, legalStage, personalData, `excerpt` (or null + `excerptWithheld: PERSONAL_DATA / MINOR_DATA_RISK`), excerptHash, `excerptAttribution` (QUOTED_FROM_SOURCE / QUOTED_FROM_USER_UPLOAD), `locator`, `locatorState`, addedAt |
| `sources[]` | ref, type, publisher, publisherOrgRef, uri, retrievedAt, publishedAt, status, retention, contentHash, acquisition, providerId, userSubmitted, hasRegistrySnapshot, newsGenre, syndicatedFrom, derivedFrom, syndicationMarkers, artifactRef, `host {provider, role: HOST_NOT_PUBLISHER}` |
| `artifacts[]` | ref, sourceRef, type, origin, fileHash, version, supersedesRef, supersededBy, extractionStatus, extractorVersion, extractionNotes, cloudHost, sourceModifiedAt, ingestedAt, pendingCandidates, `originalBytesRetained: false` — **no filename** |
| `disputes[]` | ref, claim, kind, openedAt, open, resolution, resolvedAt, submittedEvidenceCount |
| `limitations[]` | `{code, scope, ref}` |
| `doesNotEstablish[]` | codes |
| `summary` | counts by ClaimStatus and EpistemicClass (all keys, zero-filled), notVerified, reverificationPending, openDisputes, conflicts, registryConflicts, evidence, sources, artifacts, limitations |
| `dossierStatus` | COMPLETE · PARTIAL · REVIEW_REQUIRED · INCOMPLETE |

`locatorState`: VALID · NOT_ARTIFACT_BOUND · ARTIFACT_SUPERSEDED · ARTIFACT_MISSING
· HASH_MISMATCH · OUT_OF_RANGE (never invented, never silently "valid").

Bound: canonical content ≤ 2 000 000 characters, else `DOSSIER_TOO_LARGE`
(413) — never truncated. A max-size Lab investigation (200 claims, 1000
evidence) is ~0.5 MB and builds in ~0.1 s (DX-06).
