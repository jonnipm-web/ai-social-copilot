# Impact — Dossier Export & Integrity

## Actions (impact-lab, admin-only)

| Action | Body | Result |
|---|---|---|
| `get_dossier` | `{investigation_id, lang?}` | LIVE `DossierDocument` + PT/EN text |
| `export_dossier` | `{investigation_id, lang?}` | SNAPSHOT document + text + `snapshot {ref, contentHash, exportedAt, replayed}`; registers the hash (idempotent: the same content keeps its original registration and date) and audits `DOSSIER_EXPORTED` |
| `verify_dossier` | `{investigation_id, content_hash}` | `state`: NOT_ISSUED · CURRENT · STALE, the registration (if any), `currentContentHash`, `integrityIsNotTruth: true` |

Authorization chain (unchanged pattern): AUTH → ENTITLEMENT (admin) →
OWNERSHIP (investigation + project) → build from server state → export. A
foreign or missing id answers the same 404. The client can name only the
investigation, a language and (verify) a hash — no owner, status, FACT,
authority, independence or hash can be supplied (strict allowlist, DX-01).

## JSON export

`DossierDocument` (IMPACT_DOSSIER_SCHEMA.md). Never included: JWTs, tokens,
signed URLs, owner ids, audit internals beyond the chain position, original
file names, original bytes, withheld excerpts.

## Human-readable export

`renderDossierText(doc, 'pt'|'en')` (dossier_render.ts): title, EXPERIMENTAL
banner, as-of and LIVE/SNAPSHOT notice, status, summary first, identity,
registry, claims (status · class · sufficiency · independent voices ·
evidence per bucket with authority · gaps · rules · re-verification ·
disputes · evidence locators and state), limitations, *what this dossier
does NOT establish*, sources (publisher, host), disputes, integrity hash with
*"the hash proves this content was not altered; it does not prove it is
true"*. Source words appear only inside « » (quote marks inside quoted text
are neutralized so nothing can escape); every generated line passes the
verdict-language guard (the renderer throws otherwise). PDF: not
implemented (no dependency added); the text is printable.

## Integrity

- `contentHash = SHA-256(canonical(content))`. Anyone holding an export can
  recompute it offline (`verifyDossierIntegrity`) — a changed byte of the
  content is detected.
- A forger can recompute a self-consistent hash; the server's register then
  answers `NOT_ISSUED` for it (DI-03).
- The register row is bound to a real audit-chain event (FK + trigger) and
  is append-only.
- Hash ⇒ integrity of the snapshot, **never** truth of its content. No legal
  signature is implied.

## Sharing

No public URL, no share link, no indexing, no publication path exists
(`publish_dossier` / `share_dossier` are unknown actions, DX-04 / EF-12).
Public sharing is a future, separately governed gate.
