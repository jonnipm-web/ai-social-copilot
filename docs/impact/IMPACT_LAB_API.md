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
