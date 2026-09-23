# Impact — Artifact Model (I3)

Policy `impact-artifact/1`, extractor `impact-extractor/1`.

## 1. Artifact

| Field | Meaning |
|---|---|
| `ref` / `source_ref` | investigation-scoped id; the artifact's source has the same ref |
| `artifact_type` | PDF · DOCX · XLSX · CSV · JSON · TEXT · MARKDOWN (detected, never declared) |
| `media_type` | canonical media type of the detected type (CHECK-bound) |
| `origin_type` | USER_UPLOAD · CLOUD_IMPORT (+ client-declared `cloud_provider`, `cloud_file_ref`, `source_modified_at`) |
| `original_filename` | display only: basename, no control / bidi / zero-width characters, ≤ 200 |
| `size_bytes` | 1 … 6 MB |
| `file_hash` | **FILE_HASH**: SHA-256 of the exact bytes, computed by the server |
| `normalized_content_hash` | **NORMALIZED_CONTENT_HASH**: lineage fingerprint of the extracted text (different file, same text ⇒ same value) — never used as the file identity |
| `version` / `supersedes_ref` | version chain, prior + 1, never forked |
| `extraction_status` | SUCCESS · PARTIAL · FAILED · UNSUPPORTED · OCR_REQUIRED |
| `extraction_summary` | structure index only (pages, paragraphs, table shapes, sheets {name, rows, columns}, rows, columns, lines, JSON nodes, notes) — no content keys (CHECK) |

The artifact's **source** row: `USER_DOCUMENT`, acquisition `USER_UPLOAD`,
retention `HASH_ONLY` (the original is not retained — I1 policy for user
documents unchanged), `content_hash = file_hash`, `user_submitted = true`,
lineage fingerprint/sketch/markers from the first 20 000 extracted characters.
It resolves to authority `USER_SUBMITTED` and is never counted as independent
or authoritative support (I1/I2 engine rules).

## 2. Locators (bound to the artifact hash)

| Kind | Shape | Format |
|---|---|---|
| `PDF_PAGE` | `{page}` | PDF |
| `DOCX_PARAGRAPH` | `{paragraph}` (top-level, 1-based) | DOCX |
| `DOCX_TABLE_CELL` | `{table, row, cell}` | DOCX |
| `SHEET_CELL` | `{sheet, cell: "B7"}` | XLSX |
| `CSV_CELL` | `{row, column}` | CSV |
| `JSON_POINTER` | `{pointer}` (RFC 6901, `~0`/`~1`) | JSON |
| `TEXT_LINES` | `{lineStart, lineEnd}` (range < 200) | TXT / MD |

Parsing is strict (unknown kind or extra key → invalid). A locator is valid
only if (a) it fits the stored structure index (TS `locatorFitsSummary` ≡ SQL
`impact_locator_fits`, same vector E3-18 / F-LOC-02) and (b) at ingestion, it
addresses a segment of the server's own extraction. Evidence carries
`{artifact: {ref, hash, locator}}`, so a later version (new hash) never
silently inherits old locators.

## 3. Candidate

`ref`, `artifact_ref`, `artifact_hash` (must equal the artifact's), `locator`,
`excerpt` (≤ 1000 chars, server-extracted, whitespace-normalized,
PII-redacted), `excerpt_hash` (recomputed by the database), optional
`claim_ref` / `proposed_relationship`, `generation_method`, `review_reasons`,
`review_status` (PENDING at birth), review fields (only on ACCEPTED:
relationship, claim, subject, `evidence_ref = ref || '.ev'`).

## 4. Extraction provenance

Every artifact records `extractor_version`; the summary repeats type, status
and version (CHECK-bound to the columns). Re-extraction with a newer extractor
is a future concern; the version makes the difference visible.

## 5. Deletion policy

Lab rows are append-only (no direct DELETE, even for service_role); an
investigation's rows go only with the investigation (cascade), which is an
administrative operation outside the Lab API. Candidate excerpts follow the
user-evidence retention (365 days, conceptual — enforcement arrives with the
retention job, not in I3). Original bytes are never retained, so there is no
file to delete.
