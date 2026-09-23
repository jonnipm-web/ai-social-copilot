# Impact — File Security (I3)

All parsing is server-side, pure, bounded, dependency-free (native
`DecompressionStream` only; the impact core still imports nothing but `./`).

## 1. Acceptance

| Check | Result on failure |
|---|---|
| Canonical base64, ≤ 8.4 M chars; request body ≤ 9 MiB for `ingest_artifact` only (64 KiB for every other action, checked before the contract) | 400 / 413 |
| Decoded size 1 … 6 MB | `FILE_TOO_LARGE` 413 / `FILE_SIGNATURE_INVALID` 400 |
| Extension in the allowlist (pdf, docx, xlsx, csv, json, txt, md/markdown) | `UNSUPPORTED_FILE_TYPE` 415 |
| Declared MIME (if any, besides octet-stream) consistent with the type | `FILE_SIGNATURE_INVALID` |
| Executable / script signatures (MZ, ELF, Mach-O, `#!`) | `FILE_SIGNATURE_INVALID` |
| Archives (rar, 7z, gzip; `.zip`) | `UNSUPPORTED_FILE_TYPE` |
| Legacy OLE2 Office (macro-capable) | `FILE_SIGNATURE_INVALID` |
| PDF: `%PDF-` within the first 1024 bytes; no ZIP directory ending the file (PDF/ZIP polyglot) | `FILE_SIGNATURE_INVALID` |
| DOCX/XLSX: valid zip + `[Content_Types].xml` + main part; `vbaProject` / `vbaData` / `macroEnabled` / `activeX/` / `oleObject*` / executable-named parts / `.docm`/`.xlsm` refused (`printerSettings*.bin` allowed) | `UNSUPPORTED_FILE_TYPE` / `FILE_SIGNATURE_INVALID` |
| Text types: no NUL, strict UTF-8, BOM stripped; JSON starts with `{`/`[` | `FILE_SIGNATURE_INVALID` |
| Filename: basename only; control, bidi-override and zero-width characters stripped (TS) and refused (SQL CHECK) | `INVALID_REQUEST` |

A refused file persists **nothing** (EC-04).

## 2. Bounded parsing

| Parser | Bounds |
|---|---|
| ZIP | EOCD search bounded; ZIP64 refused; ≤ 2000 entries; duplicate names refused; encrypted entries refused; only stored/deflate; per-part size cap; inflate budget **32 MB for extraction** (shared by every part read) **+ 1 MB for detection** (`[Content_Types].xml` only) — ≤ 33 MB per file; streaming inflate aborts at the limit |
| PDF | ≤ 500 pages, ≤ 50 000 objects; object-stream entries increasing and non-overlapping; dictionary values read linearly (no regex rescans); page tree depth 64, cycle-safe; FlateDecode only (others → `UNSUPPORTED_STREAM_FILTER`, PARTIAL); page text ≤ 200 000 chars (`TRUNCATED_PAGE_TEXT`, PARTIAL); `/Encrypt` → FAILED ENCRYPTED; image-only → OCR_REQUIRED |
| DOCX / XLSX XML | linear tokenizer (`artifact_xml.ts`, indexOf-only, O(n) on hostile input); unterminated tag → `MALFORMED_XML`, PARTIAL; no DTD / entity expansion — only the 5 predefined entities + numeric references are decoded |
| XLSX | ≤ 20 sheets, ≤ 200 000 cells and shared strings (`TRUNCATED_*`, PARTIAL); external relationship targets and `..` refused; formulas kept as text, **never evaluated** |
| CSV | ≤ 50 000 rows, ≤ 200 columns; unterminated quote → FAILED; formula-like cells (`= + - @`) flagged |
| JSON | iterative walk, depth ≤ 64, ≤ 100 000 nodes |
| TXT/MD | ≤ 200 000 lines; Markdown/HTML are inert text, never rendered |
| All | ≤ 250 000 segments; any `TRUNCATED_*` / `MALFORMED_*` / `UNSUPPORTED_*` note forces PARTIAL; an extractor exception → `FAILED EXTRACTOR_ERROR` (never SUCCESS) |

## 3. Injection

- Document text is data. The `UNTRUSTED_INSTRUCTIONS` scan flags instruction-
  like content; no model reads it in I3; nothing in a file can set a status,
  relationship, authority or review (EC-11).
- CSV / XLSX formulas are stored as text and flagged; nothing is executed.
- Excerpts and filenames are returned as JSON strings; clients must render
  them as text.

## 4. Storage and privacy

- No storage bucket; original bytes are not retained; the structure index has
  no content (CHECK). Only reviewed-candidate excerpts (≤ 1000, PII-redacted)
  are stored.
- PII minimization: email, phone-like (≥ 10 digits) and long numeric ids are
  redacted before storage; data about a minor is never stored.
- Logs: artifact events carry type, extraction status, size and counts only —
  never file names, excerpts or organization names (EF-11).

## 5. Residuals

- The database cannot re-hash bytes it does not store: `file_hash` is trusted
  from the impact-lab server path (SERVICE_ROLE_TRUST_GATE = LAB_ONLY). Every
  other invariant binds service_role.
- `.txt` / `.md` files may contain HTML, SVG or JavaScript source: accepted
  as inert text (Codex I3G1-03, partially rejected). Original bytes are
  discarded; excerpts are returned only as JSON strings; any future viewer
  MUST render excerpts as escaped plain text.
- Sheet names are kept in the structure index as bounded structural labels
  (≤ 100 chars, control / bidi characters stripped) because SHEET_CELL
  locators and the SQL locator check need them (Codex I3G1-04, partially
  accepted); they are the only document-derived strings in the index.
- PDF text extraction is heuristic (no font CMap decoding): unusual encodings
  may yield `OCR_REQUIRED` or `PARTIAL`, which is reported, never hidden.
