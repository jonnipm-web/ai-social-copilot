# Impact — Organization Identity (I2)

Code: `_shared/impact/organization_identity.ts` (`impact-identity/1`),
`entity_resolution.ts`, `provider.ts` (normalization). Tests: ID-01..18,
T-01/02, ER-*, SQL I2-01..11, I2-39/40.

## 1. Canonical identity

`canonicalOrgId = COUNTRY:scheme:NUMBER` — ISO 3166-1 country (upper case),
registry scheme (lower case, `[^a-z0-9-]` → `-`), registration number
normalized (NFKC, upper case, spaces/`-`/`.`/`/` removed). Example:
`XA:charity-number:XA1234567`. Mirrored exactly by SQL
`impact_canonical_org_id()` (vector I2-01); the database refuses a snapshot
whose canonical id is not derived from its own fields (I2-07).

It never depends on a display name, website or slug. `canonicalIds` adds the
registrations a registry itself cross-references (e.g. a charity's company
number) — only inside the provider's own jurisdiction.

## 2. Canonical registry record

Registry, jurisdiction, scheme, number, legal name, former names with
periods, trading names, status (+ verbatim `statusDetail`), organization type,
registered / dissolved dates, `statusAsOf`, `sourceAsOf`, domains,
cross-references, provider id, record id, adapter version, retrieval time,
`rawRecordHash` (exact payload) and `dataHash` (canonical data without
retrieval time). Anything malformed rejects the whole record; dates after the
retrieval, reversed periods, a dissolved date on an active record are refused
(T-01/02). People (trustees, officers, contacts) are never part of it.

## 3. Resolution

| Outcome | When | Identity status |
|---|---|---|
| EXACT | the queried registration belongs to exactly one organization (group) | CONFIRMED |
| STRONG | no registration; exactly one organization matches an official domain AND a registry name (legal/trading/former) | PROBABLE (never merged) |
| AMBIGUOUS | several organizations, or name-only / domain-only | UNCERTAIN — candidates for review |
| NO_MATCH | nothing | UNRESOLVED — **not** "does not exist" |

Rules: a name alone is never EXACT (even a single hit); a registration miss
never falls back to a name; records are grouped only through shared
identifiers (cross-references), never through names; a registration with a
name that is not a registry name stays EXACT but `requiresReview`
(`NAME_DIFFERS_FROM_REGISTRY`); other jurisdictions are ignored when a
country is given and a registry never answers for another jurisdiction;
candidates are bounded (10) and truncation is disclosed.

Registry lifecycle (REGISTERED / REMOVED / DISSOLVED / verbatim detail) is
returned as a typed `lifecycle` fact with `isFindingOfWrongdoing: false`,
separate from identity-matching `signals` (Codex I2G3-02); no registry outcome
(removed, ambiguous, no match, conflict, stale, provider failure) produces a
concern indicator (test I2G3-02).

## 4. Names

Normalization helps search and must never erase a legal distinction:
case, punctuation, accents and spacing are folded; equivalent spellings of the
SAME legal form collapse (Ltd = Limited, Inc = Incorporated, Corp =
Corporation, Co = Company, Ltda = Limitada), different forms stay different
(Ltd ≠ Inc, Foundation ≠ Trust). A former name is part of one organization's
timeline: `nameValidAt()` answers only for its period (never today's name for
the past, never an old name for today) and it never merges two organizations.

## 5. Temporal identity

`retrievedAt`, `sourceAsOf`, `statusAsOf`, former-name periods and
registered/dissolved dates are preserved. A snapshot is fresh only within the
provider's `freshnessDays` measured from the earlier of retrieval and the
registry's own as-of date; stale snapshots are flagged (`STALE_SNAPSHOT`),
never presented as fresh. A changed record is a new snapshot version; the old
one stays (ID-13, SQL I2-21).

## 6. Registry conflicts

Two ACTIVE snapshots of the same organization (shared canonical id, different
provider record) that disagree on name or status class are recorded by the
database trigger (`impact_registry_conflicts`, TS twin
`registryConflicts()`): no winner, `resolution = UNRESOLVED`,
`is_finding_of_wrongdoing = false` (CHECK). Possible explanations shown:
timing / registry lag, name change, different legal entity or scope, data
quality. A conflict is never fraud, corruption or deception.

## 7. Entity spoofing guard

A caller cannot say "this registry record belongs to this organization":
- registry-statement claims are generated only from a snapshot whose
  registration CONFIRMS the investigation subject;
- evidence declared ABOUT the subject from a registry snapshot of another
  organization is refused at insertion (Lab `ENTITY_MATCH_UNCERTAIN`; DB
  `IMPACT_ENTITY_MISMATCH`, I2-39) — gap found in I2, present since I1;
- defense in depth: the engine excludes it anyway
  (`R03B_REGISTRY_RECORD_OF_ANOTHER_ENTITY`, MUT-02) and the database refuses
  a stored result counting it (I2-39b);
- REGISTRY_RECORD evidence must carry the server statement text, as-of period
  and subject, recomputed in SQL (I2-41..44; Codex I2G1-03).
