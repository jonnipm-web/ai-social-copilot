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
| Claim text | minor-risk rule; structured ids; private-name / private-address signals | minor ⇒ withheld `MINOR_DATA_RISK`; ids ⇒ redacted; name/address signal ⇒ **withheld `PERSONAL_DATA_RISK`** | a name no signal matches (e.g. a single lower-case word) |
| Evidence excerpt | same + reviewer classification (`PUBLIC_OFFICIAL_ROLE` ⇒ withheld; PERSONAL/SENSITIVE/MINOR not representable in the Lab contract) | withheld / redacted as above | same |
| Organization name (declared identity) | structured ids, minor rule | organizational information: shown (quoted), ids redacted | a person declared as the subject organization (contract misuse; subject type is an organization type) |
| Registry legal name | structured ids, minor rule | official organizational record: shown | none known |
| Source publisher | structured ids; SOCIAL_MEDIA / OTHER may be a person | organizational types shown; SOCIAL_MEDIA / OTHER **withheld unless an organization on record** | a person publishing under an organizational source type |
| Lineage names (syndicatedFrom / derivedFrom), conflict position publishers | as publisher, by the source's type | as publisher | same |
| URLs | parsed | **origin only** (scheme + host); non-http(s) / unparsable ⇒ withheld | a personal host name (e.g. `janedoe.example`) |
| E-mail, phone, IBAN / bank account, payment card (Luhn), sort code + account, labelled account numbers, CPF / CNPJ / SSN, UK NINO, long digit runs | deterministic patterns (`redactStructured`) | redacted `[redacted-…]` in every field | unusual formats |
| Addresses | street + number (EN / PT / ES), unit / apartment, UK / BR / US postcodes, PO box | free text withheld | an address written without any of these forms |
| Private names | honorific + name; person-role + name (EN / PT / ES); 2+ consecutive capitalized non-organizational words | free text withheld | lower-case names, single names without context, names in scripts without letter case |
| Minors | minor term AND age / birth expression (EN / PT / ES) | withheld in **every** field, precedence over every other rule | minors described without both signals (bounded by reviewer classification `MINOR` being unrepresentable) |
| Filenames, cloud file ids | — | **never** in the dossier (artifacts expose type, hash, host provider, status only) | — |
| Document locators | — | line / page / cell coordinates only | — |
| Disputes | — | kind, dates, resolution, counts only — no text | — |
| Snapshots | same projection | an issued snapshot is the export document; the server keeps only its registration (hash, envelope metadata), never its content | a snapshot copied BEFORE this policy (see §5) |
| Logs / observability | allowlisted fields (codes, ids, counts, latency) — unknown fields rejected | no dossier text | — |
| Error bodies | stable codes; 4xx messages name fields, never echo values; 5xx carry no message | — | — |

Invisible / bidi / format characters are removed **before** detection (a
zero-width space inside a name cannot split the signal) and from the
presented text.

## 3. Names and addresses: an honest limit

No deterministic rule detects every private name or address. The signals
are deliberately **high recall**: they withhold some organizational text
too (e.g. an organization name that is not on record and looks like two
capitalized words). This over-withholding is the chosen trade-off
(WITHHOLD over EXPOSE) and is always visible as the limitation
`EXCERPT_WITHHELD` ("contains, or may contain, personal data — conservative
rule"). Only names from trusted origins exempt text: the subject's declared
identity and official registry snapshots; client-entered publisher names
never do (they could whitelist a person's name).

The remaining residual is bounded by:
1. the reviewer's mandatory personal-data classification on every evidence
   item (`PERSONAL` / `SENSITIVE` / `MINOR` cannot even be submitted);
2. admin-only Lab access;
3. no public sharing, no publication path.

## 4. Where raw stored text is still visible

Authoring / review actions of the admin Lab (the candidate review queue,
registry-claim import replies) return the stored text to the admin
reviewer, who needs it to classify. They are not used by the Impact UI and
are not part of any export.

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

`privacy_test.ts` PV-01..11 (structured ids, name / address signals,
organizational text kept, minors precedence, trusted-only exemption,
publishers, URLs, invisible characters, end-to-end live / export / text /
snapshot, stored evidence untouched), `dossier_test.ts` G3-02 (stricter),
`impact-lab/index_test.ts` EF-15 (logs and error bodies), Flutter UI-PRV-01/02
over the real-engine fixture `dossier_private_en` / `export_private_en`.
