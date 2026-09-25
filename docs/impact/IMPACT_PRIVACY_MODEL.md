# Impact — Privacy Model (IV-IMPACT-I6, closes Codex I5F-03)

Impact is **organization intelligence, never people intelligence**. This
document is the privacy threat model of the dossier path and the
fail-closed presentation policy implemented in
`supabase/functions/_shared/impact/privacy.ts`.

## 1. Principle: stored evidence ≠ safe presentation

- The store keeps what the reviewer recorded (needed to re-verify, audit and
  review). Nothing is destroyed.
- Every value that LEAVES the server in a dossier — live view, export JSON,
  issued snapshot, human-readable text — is produced by one projection
  (`dossier.ts`) that calls `present()` / `presentUri()` with the
  **semantics of the field**. The UI and the export therefore share exactly
  one privacy boundary; the UI renders only what the server presented and
  never reconstructs withheld text.
- When the server cannot tell whether text is safe to show, it **withholds**
  (fail-closed) and says so with a limitation.

## 2. Threat model (PII source → detection → redaction → contracts → residual)

| PII source | Detection | Presentation | Residual |
|---|---|---|---|
| Claim text | minor-risk rule; structured ids; private-name / private-address signals; caseless-script text | minor ⇒ withheld `MINOR_DATA_RISK`; ids ⇒ redacted; name/address signal or un-assessable script ⇒ **withheld `PERSONAL_DATA_RISK`** | a name no signal matches (e.g. a single lower-case word) |
| Evidence excerpt | same + reviewer classification (`PUBLIC_OFFICIAL_ROLE` ⇒ withheld; PERSONAL/SENSITIVE/MINOR not representable in the Lab contract) | withheld / redacted as above | same |
| Organization name (declared identity: legal / public name, aliases) | structured ids, minor rule, **and** name / address signals (client-supplied ⇒ untrusted, Codex I6G1R-04) | shown (quoted) unless a signal fires and no registry confirms it ⇒ withheld (`—`, limitation `EXCERPT_WITHHELD` / IDENTITY; headers fall back to the subject ref); never exempts other text | an organization whose name looks like a person's is over-withheld until a registry confirms it |
| Registry legal name | structured ids, minor rule | official organizational record: shown | none known |
| Source publisher | structured ids; name / address signals for **every** source type (the type is client-declared) | withheld on a signal unless registry-confirmed; SOCIAL_MEDIA / OTHER withheld unless registry-confirmed | a person's name no signal matches |
| Lineage names (syndicatedFrom / derivedFrom), conflict position publishers | as publisher, by the source's type | as publisher | same |
| URLs | parsed | **origin only** (scheme + host; never userinfo, port, path, query, fragment) and only for institutional types (OFFICIAL_REGISTRY, GOVERNMENT_RECORD, REGULATOR, COURT_RECORD) or a host within the subject's declared domains; every other URL withheld (Codex I6G1R-06) | none known |
| E-mail (ASCII and Unicode incl. combining marks; searched inside each token, so trailing / leading Unicode punctuation cannot hide it; look-alike `＠` / `﹫`; spelled-out `(at)` / `[at]` / `at` / `arroba` with literal or spelled dot — Codex I6G1R3-01), social handles (`@name`), phone (any Unicode digits, normalized to ASCII **for detection only** — text without PII keeps its original characters, Codex I6G1R-01; the only change ever made to safe text is the intentional removal of invisible / bidi / format characters, see below), IBAN / bank account, payment card (Luhn, spaced or compact), sort code + account, labelled account numbers, labelled ids (EIN, TIN, NIF, NIE, NINO, SSN, DNI, CPF, CNPJ, RG, CURP, RFC, PAN, passport, tax id, national id — value must contain 4+ digits; acronyms upper-case only), MRZ fragments, formatted CPF / CNPJ / SSN, UK NINO, long digit runs | deterministic patterns (`redactStructured`) | redacted `[redacted-…]` in every field | unlabelled identifiers in unusual formats |
| Addresses | street + number (EN / PT / ES), unit / apartment, UK / BR / US postcodes, PO box | free text withheld | an address written without any of these forms |
| Private names | honorific + name; person-role + name (EN / PT / ES); initial + surname ("J. Smith"); 2+ consecutive Title-case **or** 2+ consecutive ALL-CAPS (4+ letters) non-organizational words, commas and line breaks included ("SMITH, JOHN"); any letter of a caseless script (withheld as un-assessable) | free text withheld | lower-case names; a single name without honorific / role / initial |
| Minors | minor term AND age / birth expression (EN / PT / ES) | withheld in **every** field, precedence over every other rule | minors described without both signals (bounded by reviewer classification `MINOR` being unrepresentable) |
| Filenames, cloud file ids | — | **never** in the dossier (artifacts expose type, hash, host provider, status only) | — |
| Document locators | — | line / page / cell coordinates only | — |
| Disputes | — | kind, dates, resolution, counts only — no text | — |
| Snapshots | same projection | an issued snapshot is the export document; the server keeps only its registration (hash, envelope metadata), never its content | a snapshot copied BEFORE this policy (see §5) |
| Logs / observability | allowlisted fields (codes, ids, counts, latency) — unknown fields rejected | no dossier text | — |
| Error bodies | stable codes; 4xx messages name fields, never echo values; 5xx carry no message | — | — |

Invisible / bidi / format characters are removed **before** detection (a
zero-width space inside a name cannot split the signal) and — intentionally,
as anti-spoofing — from the presented text (Codex I6G1R2-02: this is the
one normalization applied to otherwise safe text; it removes no visible
character). No-break spaces and non-ASCII digits are normalized only in the
detection copy and are preserved in the presented text.

Performance (Codex I6G1R-03): values longer than 4,000 characters (the
largest accepted text) are withheld without scanning; e-mails are matched
per whitespace token; the quadratic-prone patterns (e-mail, obfuscated
e-mail, MRZ) only run when their anchor (`@`, "at … dot", `<<`) is present.
PV-20 bounds adversarial inputs at the maximum size.

Owner review DTOs are scrubbed recursively for minor-data risk in every
string field (Codex I6G1R-05).

### 2.1 Structured-identifier backstop (Codex I6G1R4)

Redaction keeps text readable for the common forms, but no list of patterns
can enumerate every encoding. After redaction, **one canonical detection
copy** is built (HTML entities decoded — numeric, hex and named; NFKC;
Unicode digits → ASCII; `@` look-alikes, dash / hyphen, middle-dot and slash
variants mapped; separators → space; lower-cased) and checked for any
surviving identifier signal:

- an `@` followed by an identifier character (e-mails of any spacing,
  handles of any length);
- a spelled-out e-mail (`at`, `at sign`, `arroba`, `em`, `chez`, `bei` +
  domain + `.`/`dot`/`ponto`/`punto`/`point`/`punkt` + TLD);
- an IBAN prefix (country + check digits + bank code), any case;
- an account / tax / identity label (account, acct, a/c, conta, cuenta,
  compte, konto, IBAN, VAT, GST(IN), USt-IdNr, TVA, IVA, NIF, NIE, NIPC, EIN,
  TIN, SSN, SIN, NINO, DNI, CURP, RFC, PAN, RG, CPF, CNPJ, passport, tax id,
  national id, aadhaar) followed by a value with 2+ digits;
- a run of 9+ digits with any separators, unless it is a grouped quantity
  (`1,250,000`, `1.250.000,50`, `12 000 000`).

If any signal survives, the **whole value is withheld** (fail-closed) in
every field kind. The canonical copy is never presented. PV-29..31 cover the
exhaustive-pass encodings end-to-end; PV-30 guards ordinary PT / EN prose
(years, dates, money, percentages, "em 2019.", "at the school.").

## 3. Names and addresses: an honest limit

No deterministic rule detects every private name or address. The signals
are deliberately **high recall**: they withhold some organizational text
too (e.g. an organization name that is not on record and looks like two
capitalized words). This over-withholding is the chosen trade-off
(WITHHOLD over EXPOSE) and is always visible as the limitation
`EXCERPT_WITHHELD` ("contains, or may contain, personal data — conservative
rule"). Only names confirmed by an **official registry snapshot** exempt
text (Codex I6G1-02). The subject's declared identity, aliases and public
name, and every client-entered publisher, are untrusted: they could
whitelist a person's name.

The remaining residual is bounded by:
1. the reviewer's mandatory personal-data classification on every evidence
   item (`PERSONAL` / `SENSITIVE` / `MINOR` cannot even be submitted);
2. admin-only Lab access;
3. no public sharing, no publication path.

## 4. Owner review DTOs (`OWNER_REVIEW_RAW`)

The Lab authoring / review actions — `get_investigation`, the candidate
queue (`ingest_artifact`, `review_candidate`), `import_registry_claim` —
return what **this caller** entered or uploaded, because reviewing and
classifying require it (stored evidence ≠ presentation). They are an
explicitly privileged, owner-only contract (Codex I6G1-04):
- every such response is marked `privacy.class = OWNER_REVIEW_RAW` (and each
  candidate `privacyClass`);
- minor-data risk is withheld **even here** (I6G1-07);
- they are never part of a dossier, export or snapshot (PV-17), and the
  Flutter Impact client can only send `list_investigations`, `get_dossier`,
  `export_dossier`, `verify_dossier` (UI-API-10 scans the client source).

## 5. Snapshots and policy changes

`policyVersions.privacy = impact-privacy/1` is part of the **hashed**
content. Consequences:
- a snapshot issued under the same policy verifies CURRENT (PV-11);
- a snapshot issued before I6 verifies **STALE** — honestly: the dossier
  content changed (presentation policy) after issue. Its registered hash is
  never rewritten, and the server never re-serves its content (only the
  registration is stored), so a policy change can never *reintroduce* data
  into an old snapshot. The UI wording of STALE says "evidence or
  presentation policy".
- No production snapshots exist (the Edge Function is not deployed).

## 6. Tests

`privacy_test.ts` PV-01..31 (structured ids incl. Unicode / labelled / MRZ,
all-caps / initials / surname-first / caseless names, client whitelist
attempts, publishers of every type, URL userinfo / IDN / IP / personal
types, owner review DTO; and the original: name / address signals,
organizational text kept, minors precedence, trusted-only exemption,
publishers, URLs, invisible characters, end-to-end live / export / text /
snapshot, stored evidence untouched), `dossier_test.ts` G3-02 (stricter),
`impact-lab/index_test.ts` EF-15 (logs and error bodies), Flutter UI-PRV-01/02
over the real-engine fixture `dossier_private_en` / `export_private_en`.
