# Impact Lab API (I1) — `impact-lab` Edge Function

EXPERIMENTAL · admin-only · **not deployed** by I1 · not on the deploy
allowlist. `POST` JSON, ≤ 64 KiB, `Authorization: Bearer <session JWT>`.

Pipeline: AUTH → ENTITLEMENT → body/schema → OWNERSHIP (RLS read) → DOMAIN
VALIDATION → ENGINE → PERSISTENCE → structured response. No LLM, no network,
no quota (no paid call), no class C action.

## Actions

| action | fields | server derives |
|---|---|---|
| `create_investigation` | `subject {ref, type, identity{legalName, publicName, aliases, registrations[{country,scheme,value}], domains}}`, `project_id?` | owner = caller; project must be the caller's |
| `list_investigations` | — | caller's only |
| `get_investigation` | `investigation_id`, `lang? pt\|en` | report, latest results, history, indicators, identity status, audit (seq, head, chainOk) |
| `archive_investigation` | `investigation_id` | final |
| `add_source` | `source {ref, type, publisher, publisherOrgRef?, uri?, retrievedAt, publishedAt?, jurisdictionCountry?, newsGenre?, retention (REFERENCE_ONLY\|HASH_ONLY\|EXCERPT_AND_HASH), contentHash?, syndicatedFrom?, userUpload?}` | acquisition = ANALYST_ENTRY / USER_UPLOAD (never PROVIDER) |
| `ingest_provider_record` | `provider_id`, `record_id`, `ref` | the server fetches from the **server registry** and builds the PROVIDER source + snapshot |
| `update_source_status` | `source_ref`, `status (UPDATED\|RETRACTED\|UNAVAILABLE)` | affected claims → `reverificationRequired`; unchanged status → `ALREADY_EXISTS` |
| `add_claim` | `claim {ref, kind, text, textLanguage?, quantity?, level?, claimantOrgRef?, claimantLabel?, subjectProjectRef?, subjectCampaignRef?, period?, sourceRef, origin (MANUAL\|STRUCTURED_IMPORT)}` | subject = investigation subject; `extractedAt` |
| `add_evidence` | `evidence {ref, claimRef, sourceRef, aboutOrgRef, relationship, basis, reportedQuantity?, level?, observedPeriod?, excerpt?, locator?, personalData (NONE\|AGGREGATED\|PUBLIC_OFFICIAL_ROLE), legalStage?}` | `excerptHash`, `addedAt`, injection scan |
| `run_verification` | `claim_ref`, `idempotency_key?` (bound to the claim: reuse for another claim → `ALREADY_EXISTS`), `human_review_binding_hash?` | `evaluatedAt`, trusted providers, identity status, flags, open dispute, version |
| `open_dispute` | `ref`, `claim_ref`, `kind`, `submitted_evidence_refs` | `openedAt`; re-verifies at once → latest state `DISPUTED` (I1G2-02) |
| `resolve_dispute` | `dispute_ref`, `resolution` | `resolvedAt`; re-verifies at once |
| `request_external_action` | `kind` | class C → `403 ACTION_BLOCKED`, `requires: AEF_HUMAN_GATE` |

Unknown actions and **unknown fields** are rejected (`INVALID_REQUEST`) — this
is how `owner_id`, `user_id`, `role`, `plan`, `status`, `acquisition`,
`providerId`, `providerTrusted`, `authority`, `excerptHash`, `evaluated_at`,
`trusted_providers`, `subjectOrgRef` on a claim, etc. are refused.

## Responses

`200 {ok: true, action, data, correlation_id}`; errors `{ok: false, error:
<ImpactErrorCode>, message?, requires?, correlation_id}` (no message on 5xx).

| code | HTTP |
|---|---|
| AUTH (shared) | 401 |
| MODULE_NOT_AVAILABLE / PLAN_REQUIRED (shared) | 403 |
| ENTITLEMENT_UNAVAILABLE (shared) | 503 |
| INVALID_REQUEST, INVALID_SOURCE/CLAIM/EVIDENCE, UNSAFE_REFERENCE, SENSITIVE_DATA_REJECTED, CAPABILITY_NOT_SUPPORTED | 400 |
| ACTION_BLOCKED | 403 |
| INVESTIGATION_NOT_FOUND, CROSS_INVESTIGATION_DENIED, ORGANIZATION_NOT_FOUND | 404 (no existence oracle) |
| ALREADY_EXISTS, INVESTIGATION_NOT_ACTIVE | 409 |
| PAYLOAD_TOO_LARGE | 413 |
| LIMIT_EXCEEDED | 429 |
| REGISTRY_UNAVAILABLE | 503 |
| INTERNAL_ERROR | 500 |

`get_investigation.latest` / `report` apply a deterministic dispute overlay
(Codex I1F-02): an open dispute always reads as `DISPUTED`, a resolved one never
keeps reading as `DISPUTED`; either case is flagged `reverificationPending`
until a new version is stored. Retrying `open_dispute` / `resolve_dispute`
with the same arguments repairs a failed re-verification. Archive and status
updates succeed only if a row actually changed (I1F-03).

No response contains a verdict/score/trust/fraud field; verification payloads
carry `isFindingOfWrongdoing: false`, `policyVersion`, `evidenceSetHash`,
`reviewBindingHash`, `rulesApplied`, conflicts and gaps.

## Limits

Body 64 KiB · text 4,000 · excerpt 2,000 · 100 investigations/owner · 200
sources · 200 claims · 1,000 evidence · 100 disputes per investigation · 200
evidence per claim (engine). Platform rate limiting is the existing Supabase
gateway; no custom limiter was added.

## Observability

One allowlisted JSON line per request: `event (impact.lab.<action>)`,
`correlation_id`, `investigation_id`, `latency_ms`, `policy_version`, counts,
`verification_status`, `error_code`. Never claim text, excerpts, JWTs,
secrets or personal data (EF-05).

## I2 actions (Registry Intelligence)

| action | fields | notes |
|---|---|---|
| `search_registry` | `investigation_id`, `provider_id`, `query {name?, registration?, scheme?, domain?, country?}` | read-only; returns `outcome` (EXACT/STRONG/AMBIGUOUS/NO_MATCH), ≤ 10 candidates with signals, `requiresReview`, `identityStatus`, `absenceIsNotEvidenceOfWrongdoing: true`; nothing persisted or attached |
| `ingest_provider_record` | unchanged fields | identical data → `replayed: true` with the existing `sourceRef`; changed data → new snapshot; response carries `canonicalOrgId`, snapshot view (freshness, authority metadata), `registryConflicts` |
| `import_registry_claim` | `investigation_id`, `source_ref`, `ref` | neutral registry statement (origin `REGISTRY_IMPORT`, server-only) + REGISTRY_RECORD evidence; only from an ACTIVE snapshot that CONFIRMS the subject (`ENTITY_MATCH_UNCERTAIN` otherwise); identical retry replays or repairs a missing evidence row (`repaired: true`); any other reuse of the ref → ALREADY_EXISTS |
| `add_source` | + `contentText?` (≤ 20,000, never stored), `derivedFrom?` | server computes fingerprint, sketch, markers |

`get_investigation` adds `registry { snapshots, conflicts, conflictExplanations, conflictIsNotWrongdoing: true }`.
New error codes: REGISTRY_RATE_LIMITED (429), REGISTRY_RESPONSE_INVALID (502),
ORGANIZATION_AMBIGUOUS (409). Fields that do not exist for a client:
independent, lineage, fingerprint, sketch, markers, official, authority,
primaryPublisher, canonicalOrgId (L-14, S-02).

## I3 actions (Evidence Collection)

| Action | Body | Notes |
|---|---|---|
| `ingest_artifact` | `{investigation_id, artifact: {ref, filename, mediaType?, contentBase64, origin: USER_UPLOAD \| CLOUD_IMPORT, cloud?: {provider, fileRef, modifiedAt?}, supersedesRef?, candidates?: [{ref, locator, quote?, claimRef?, proposedRelationship?}] ≤ 20}}` | only action allowed up to 9 MiB; server hash/type/extraction; REUSE per investigation |
| `review_candidate` | `{investigation_id, candidate_ref, decision: ACCEPTED \| REJECTED \| NEEDS_CONTEXT, relationship?, claim_ref?, about_org_ref?, personal_data?, observed_period?}` | ACCEPTED promotes to `<candidate>.ev` evidence |

New errors: `UNSUPPORTED_FILE_TYPE` 415, `FILE_TOO_LARGE` 413,
`FILE_SIGNATURE_INVALID` 400, `LOCATOR_INVALID` 400,
`EVIDENCE_REVIEW_REQUIRED` 400. `get_investigation` now includes `artifacts`
(no content) and `candidates`.

New events (`impact.*`): `artifact_ingestion_completed` / `_failed`,
`extraction_completed` / `_failed`, `candidate_created`,
`candidate_reviewed` — fields `artifact_type`, `extraction_status`,
`size_bytes`, `candidates_count`, `review_status`, `error_code` only.

Limits: 6 MB per file, 100 artifacts and 2000 candidates per investigation,
50 candidates per artifact, 20 requested per call, excerpt ≤ 1000 chars.

## I4 actions (Verification Dossier)

| Action | Body | Notes |
|---|---|---|
| `get_dossier` | `{investigation_id, lang?: pt\|en}` | LIVE dossier + text; read-only (works on archived investigations) |
| `export_dossier` | `{investigation_id, lang?}` | SNAPSHOT + registration (idempotent on content hash) + `DOSSIER_EXPORTED` audit |
| `verify_dossier` | `{investigation_id, content_hash}` | NOT_ISSUED / CURRENT / STALE |

New error: `DOSSIER_TOO_LARGE` 413. New events (`impact.*`):
`dossier_generated`, `dossier_generation_failed`, `dossier_exported`,
`dossier_stale_detected`, `dossier_reverification_pending` — fields
`dossier_status`, `claims_count`, `reverification_count`, `error_code` only.
`ingest_artifact` is unchanged for clients; it now persists in one
transaction.

`add_source` (I4 change): `userUpload` is no longer accepted and type
`USER_DOCUMENT` is refused — uploaded documents enter only through
`ingest_artifact` (Codex I4G2-01, I3F-03 closure).
