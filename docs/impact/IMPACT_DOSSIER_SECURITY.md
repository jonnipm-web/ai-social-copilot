# Impact — Dossier Security & Threat Model (I4)

| # | Threat | Control | Test |
|---|---|---|---|
| T1 | forged dossier | server builds from persisted rows only; register of issued hashes | DI-03, DX-01 |
| T2 | stale dossier | `asOf`; LIVE vs SNAPSHOT envelope; `verify_dossier` → STALE; per-claim re-verification detection | DS-E |
| T3 | cross-user dossier | owner scoping in load; identical 404 | DS-J, EF-12, D4-25 |
| T4 | cross-project dossier | project ownership check (existing `own()` / DB guard) | DS-J2, I1 suite |
| T5 | cross-investigation dossier | content carries `investigation.ref`; register unique per investigation; hash replay elsewhere → NOT_ISSUED | DS-J, D4-18 |
| T6 | claim / evidence mismatch | buckets copied from the stored result; `evidenceRefs` per claim from rows | DS-A, DS-C |
| T7 | omitted conflicting evidence | all buckets + conflicts copied; CONFLICTING_EVIDENCE / REGISTRY_CONFLICT limitations | DS-C |
| T8 | omitted limitation | limitations derived from state, deduplicated, sorted; COMPLETE only with zero limitations | DS-B/D/H |
| T9 | fabricated authority | authority scope copied from assessed evidence (engine) | DS-A, DS-H |
| T10 | fabricated independence | lineage/voices copied from the engine; CF-04 | DS-G |
| T11 | temporal misrepresentation | deterministic `asOf`; statusAsOf / retrievedAt / sourceModifiedAt shown; SNAPSHOT notice | DS-E |
| T12 | dispute suppression | dispute overlay; DISPUTE_OPEN limitation; `disputes[]` always listed | DS-F |
| T13 | artifact / locator mismatch | `locatorState` recomputed (missing, hash mismatch, out of range, superseded) | DS-H |
| T14 | client-generated verdict | no verdict field; strict allowlist | DX-01 |
| T15 | LLM-generated verdict | no model is called anywhere in the dossier path | code, DX-02 |
| T16 | prompt injection | document text is quoted data; engine flags it | DX-02 |
| T17 | reputational amplification | generated text passes the verdict guard; quotes neutralized; non-findings | DS-*, DX-07 |
| T18 | export tampering | content hash + offline verification + server register | DI-03 |
| T19 | enumeration / oracle | same 404 for foreign and missing; verify answers only inside owned investigations | DS-J |
| T20 | unauthorized publication | no publish/share action or URL | DX-04, EF-12 |
| T21 | PII exposure | PERSONAL/PUBLIC_OFFICIAL_ROLE/SENSITIVE excerpts withheld; filenames not exported; logs carry codes/counts only | DX-03, EF-12 |
| T22 | minor-data exposure | minor-risk excerpts and claim texts withheld | DX-03 |
| T23 | source deletion / orphaning | I3F-03 atomic ingestion; nothing is ever deleted | EC-20, D4-03..10, DOSSIER_RACE |
| T24 | snapshot / hash mismatch | register row bound to a real audit event; ref derived from the hash | D4-13..15 |
| T25 | replay after material change | every material change moves the hash; STALE | DI-02, DS-E |

## I3F-03 (orphan sources) — closed

- **Root cause**: I3 ingestion wrote the USER_UPLOAD source and the artifact
  in two separate requests; if the artifact write failed or lost a
  concurrent duplicate race, the source remained without its artifact.
- **Fix**: `impact_ingest_artifact()` writes source + artifact + candidates in
  ONE transaction (SECURITY INVOKER, service_role only, every row still
  passes its table triggers). The in-memory twin restores its state on any
  failure. Nothing is deleted: history and snapshots stay intact; a legacy
  orphan (pre-I4, never cited) is adopted by an identical re-ingestion only.
- **Proof**: EC-20 (mid-way failure leaves nothing), D4-03..10 (DB rollback,
  mixed-investigation / unknown-column / non-owner refusal), two-session race
  (duplicate ingest ⇒ 1 source + 1 artifact).

## Boundaries preserved

SERVICE_ROLE_TRUST_GATE = LAB_ONLY (register: SELECT/INSERT only; ingestion
functions EXECUTE only; no UPDATE/DELETE). No network, registry, LLM, AEF
runtime, storage bucket or public surface in the dossier path. Class C
actions stay ACTION_BLOCKED / AEF_HUMAN_GATE.

### I3F-03 completion (Codex I4G2-01)

The API had a second way to create a `USER_UPLOAD` source without an artifact:
`add_source` with `userUpload: true` (or type `USER_DOCUMENT`). Both are now
refused by the contract: a user document enters **only** through
`ingest_artifact` (server hash, one transaction with its artifact);
client-declared sources are always `ANALYST_ENTRY`. Legacy rows written
before I4 are still read (and still count as USER_SUBMITTED, never
authority — LS-17). Test: G2-01.
