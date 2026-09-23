# Impact — Evidence Collection (IV-IMPACT-I3-EVIDENCE-COLLECTION-01)

Status: **EXPERIMENTAL, Lab only** (admin-only `impact-lab` Edge Function, not
deployed; migration `20260926010000` not applied to production).

## 1. The chain

```
PROJECT → INVESTIGATION → ARTIFACT (server SHA-256) → EXTRACTION (structure index)
  → LOCATOR → EVIDENCE CANDIDATE (PENDING) → HUMAN REVIEW
  → CLAIM link (SUPPORTS / CONTRADICTS / CONTEXTUALIZES) → EVIDENCE (HUMAN_ASSESSED)
  → DETERMINISTIC VERIFICATION (impact-verification engine) → CONFLICT / DISPUTE → AUDIT
```

Each arrow is a separate, audited step. Nothing skips a step:

| Step | Who decides | What it is NOT |
|---|---|---|
| Artifact | server (bytes → type, hash, extraction) | not a source of authority (USER_UPLOAD) |
| Candidate | server extraction + analyst locator / deterministic value match | not evidence, not a fact |
| Human review | the investigation owner | not a verification |
| Evidence | promoted candidate, `HUMAN_ASSESSED`, USER_SUBMITTED source | not counted as independent/authoritative support |
| Verification | the deterministic engine | not a finding of wrongdoing |

## 2. Actions (impact-lab)

- `ingest_artifact {investigation_id, artifact{ref, filename, mediaType?, contentBase64, origin, cloud?, supersedesRef?, candidates[]}}`
  - the server decodes, validates (IMPACT_FILE_SECURITY.md), hashes (SHA-256
    over the exact bytes) and extracts; the client cannot send a hash, type,
    text, excerpt, method, review or authority (unknown fields → 400);
  - same bytes already in THIS investigation → **REUSE** (`duplicate: true`,
    no second artifact); dedup never crosses investigations or users;
  - `supersedesRef` → a new **version** (prior + 1; a version is superseded
    at most once — no forks);
  - requested candidates are validated **before any write**: the locator must
    address extracted content, an optional `quote` must occur at it;
  - deterministic `AUTO_VALUE_MATCH` candidates on first ingestion (a claim's
    structured quantity appears in a segment and survives PII redaction);
  - response: artifact view (no content, `originalBytesRetained: false`),
    candidates, `candidatesAreNotEvidence: true`.
- `review_candidate {investigation_id, candidate_ref, decision, relationship?, claim_ref?, about_org_ref?, personal_data?, observed_period?}`
  - `REJECTED` / `NEEDS_CONTEXT` carry no relationship; `REJECTED` and
    `ACCEPTED` are final; `NEEDS_CONTEXT` can be reviewed again;
  - `ACCEPTED` requires claim, relationship, subject (`about_org_ref`) and a
    personal-data class (else `EVIDENCE_REVIEW_REQUIRED`) and promotes the
    candidate to evidence `<candidate>.ev`, basis `HUMAN_ASSESSED`, bound to
    `{artifact: {ref, hash, locator}}` and the artifact's own source;
  - the promotion is **atomic** (Codex I3G2-01): inserting the bound evidence
    row IS the acceptance — a database trigger (`impact_promote_candidate`)
    marks the candidate ACCEPTED in the same statement; a direct update to
    ACCEPTED is refused, and a promoted candidate can never be rejected;
  - response carries `humanReviewIsNotVerification: true`.

Evidence citing an artifact's source can ONLY be such a promotion (TS store
and database). `add_evidence` cannot mint an artifact locator (contract
allowlist).

## 3. Candidate review reasons (computed, never client-set)

`AUTOMATED_MATCH`, `SUBJECT_NOT_MENTIONED` (multi-entity / subject isolation —
a subject name glued to another capitalized name such as "… Foundation
International" does not count as a mention), `UNTRUSTED_INSTRUCTIONS`
(prompt-injection scan after removing invisible / bidi characters and folding
Cyrillic/Greek homoglyphs; mixed-script words are flagged), `PII_REDACTED`,
`EXCERPT_TRUNCATED`, `FORMULA_CELL`, `EXTRACTION_PARTIAL`, `VERDICT_LANGUAGE`
(the quoted text accuses or endorses).

Every candidate carries `excerptAttribution: "QUOTED_FROM_USER_UPLOAD"`: an
excerpt is a faithful quote of a user-provided document, never a statement of
the platform, and must be displayed as an attributed quote.
Accepting a `SUBJECT_NOT_MENTIONED` candidate **for the investigation
subject** requires `subject_confirmed: true` (else `EVIDENCE_REVIEW_REQUIRED`).

Automatic value matches ignore numbers that are part of a date, time, range,
id, signed value or percentage (`20/05/2025`, `10:20`, `2019-20`, `#20`, `20%`).
Redaction before storage: e-mails (also `[at]`/`[dot]` obfuscated), phone-like
numbers, IBANs, formatted national ids (CPF, CNPJ, SSN-style) and long digit
runs. Names and street addresses cannot be detected deterministically: the
reviewer must classify `personal_data` before any promotion (residual).
Personal data about a minor (minor term + numeric or written age, or birth
wording, in EN / PT / ES) is never stored:
analyst request → `SENSITIVE_DATA_REJECTED`; automatic → skipped and counted.

## 4. Generation methods

`ANALYST_LOCATOR` and `AUTO_VALUE_MATCH` are live. `LLM_SUGGESTED` exists only
as a schema value: no LLM is invoked in I3, a client cannot choose the method,
and any future LLM output can only ever be a candidate (review required).

## 5. Idempotency, interruption, concurrency

- Ingestion is repairable: source first, then artifact, then candidates; an
  identical retry completes a half-written ingestion (EC-20).
- Replayed candidates (same ref, locator, excerpt) are reported, never
  duplicated; a ref reused for other content → `ALREADY_EXISTS`.
- Promotion is one write (evidence insert + acceptance in one statement): a
  failure leaves the candidate PENDING with no evidence; the identical retry
  promotes once (EC-22). REJECTED / NEEDS_CONTEXT updates only transition from
  `PENDING`/`NEEDS_CONTEXT` (row-count checked) and never after a promotion.
- A failed or racing ingestion may leave its source without an artifact
  (Codex I3G2-02, partially accepted). Such a source is exactly what a client
  can already declare with `add_source` (`USER_UPLOAD`, `HASH_ONLY`,
  USER_SUBMITTED, never counted, no excerpt allowed), so it opens no path
  around review; and once cited by free-form evidence it can never be adopted
  as an artifact source (TS + SQL). The Lab API has no delete, so such an
  orphan stays until the investigation is removed.
- Concurrency is resolved by database uniques: `(investigation, ref)`,
  `(investigation, file_hash)`, `(investigation, supersedes_ref)`.
- Mobile / interrupted uploads: one request carries the whole file (≤ 6 MB);
  an interrupted request writes nothing or a repairable prefix; the client
  retries the identical request.

## 6. Boundaries (not implemented, on purpose)

- **OCR**: image-only PDFs are `OCR_REQUIRED`; nothing is OCRed; no
  candidates can be created from them.
- **URL evidence**: BOUNDARY_ONLY. No crawler, no fetch. A web page is still
  recorded as a `REFERENCE_ONLY` source via `add_source`; fetching would need
  egress pinning (`EGRESS_PINNING_REQUIRED`, I2) and is another gate.
- **Google Drive / cloud**: the client downloads the file with its existing
  `drive.readonly` flow and uploads the bytes as `origin: CLOUD_IMPORT` with
  client-declared `{provider, fileRef, modifiedAt}`. The server never calls a
  cloud API; the cloud host is not the source nor an authority.
- **Knowledge Vault**: concept `KNOWLEDGE → EVIDENCE_CANDIDATE →
  REVIEWED_EVIDENCE`. `knowledge_items` stores text without the original bytes
  or hash, so it cannot be evidence directly; the analyst re-attaches the
  original file, which is hashed and extracted by the server. No write to
  `knowledge_items` in I3.
- **Storage**: no bucket is created or used; original bytes are not retained.
  What IS stored (Codex I3G3-07): the sanitized filename, media type, size,
  hashes, client-declared cloud reference, the structure index (incl. sheet
  names), candidate excerpts (≤ 1000 chars, redacted) and — after review —
  the same excerpt on the promoted evidence row. "Originals not retained" does
  not mean "no document content stored"; retention obligations apply to
  these derived fields.

## 7. Absence is not a signal

A failed / partial / OCR-required extraction, or the absence of a matching
candidate, never produces CONTRADICTS, never lowers a status and never implies
wrongdoing (EC-14). Disputes and conflicts from I1/I2 are preserved unchanged.

## 8. Quota points (defined, NOT enforced, no billing)

| Operation | Points |
|---|---|
| `ingest_artifact` (text types) | 1 |
| `ingest_artifact` (PDF / DOCX / XLSX) | 2 |
| candidate created | 0 |
| `review_candidate` | 0 |

No meter, no paywall, no billing (monetization is out of scope).

## 9. Audit events

`ARTIFACT_INGESTED`, `ARTIFACT_VERSIONED`, `EXTRACTION_COMPLETED`,
`EVIDENCE_CANDIDATE_CREATED`, `EVIDENCE_CANDIDATE_REVIEWED`,
`EVIDENCE_PROMOTED` — written by the database trigger into the hash chain
(same writer as I1/I2), mirrored by the in-memory store.

See IMPACT_ARTIFACT_MODEL.md and IMPACT_FILE_SECURITY.md.
