# Impact — Persistence Model (I1)

Migration: `supabase/migrations/20260924010000_impact_lab_persistence.sql`
(Impact Lab only — **not applied to production**). Tests:
`supabase/tests/impact_lab_rls_test.sql` (PostgreSQL 17, disposable).

## 1. Principle

Persistence stores evidence without changing what it means. A stored row is
not truer than an unstored one: claims have **no status column**; status
exists only in `impact_verifications`, produced by the Verification Engine and
checked by the database (`result.status = status`, `isFindingOfWrongdoing =
false`). There is no verdict, score, trust or fraud column anywhere (tested).

## 2. Tables (8) and why each exists

| Table | Why it is persisted | Mutability |
|---|---|---|
| `impact_investigations` | ownership, project link, RLS anchor, audit head | only `status` (ACTIVE→ARCHIVED, final), audit head/seq, `project_id`→NULL on project deletion |
| `impact_sources` | provenance (type, publisher, dates, jurisdiction, retention, hash, acquisition, syndication, provider snapshot) | only `status` (source correction) |
| `impact_claims` | assertions with claimant, subject, period, quantity, source | append-only |
| `impact_evidence` | claim↔source link, relationship + basis, locator, excerpt hash | append-only |
| `impact_verifications` | versioned engine results (full result JSON + queryable columns) | append-only |
| `impact_conflicts` | queryable conflicts, expanded from each verification by trigger | append-only |
| `impact_disputes` | right-to-respond / corrections | resolution recorded once |
| `impact_audit_events` | hash-chained trail, written only by SECURITY DEFINER triggers (no role can insert directly) | append-only |

**Not persisted (decision):** organizations other than the subject (the
subject's identity snapshot lives on the investigation row — one subject per
investigation, CF-01), projects/campaigns (claims keep `subject_project_ref` /
`subject_campaign_ref`), indicators and reports (derived on read from the
latest verification per claim — deterministic and versioned by policy, so
storing them would only create a second, driftable truth).

## 3. Relational vs JSON

Relational for everything that needs ownership, RLS, integrity or queries
(ids, refs, enums, statuses, hashes, dates). JSONB only for:
`subject_identity` (optional nested identity snapshot), `snapshot` (canonical
provider registry record), `locator`, `result` (the full engine result, kept
verbatim for audit/replay) and `positions` (conflict positions).

## 4. Keys and integrity

- UUID primary keys; a per-investigation domain `ref` with
  `UNIQUE (investigation_id, ref)` on every child table.
- **Composite foreign keys** `(investigation_id, ref)` for claim→source,
  evidence→claim, evidence→source, verification→claim, dispute→claim: a record
  of one investigation cannot reference another investigation's record, even
  when written by `service_role`.
- `impact_claims (investigation_id, subject_org_ref)` → investigation
  `(id, subject_org_ref)`: claims are always about the investigation subject.
- Domain timestamps are stored as the canonical ISO text the engine hashed, so
  re-reading reproduces the same `evidenceSetHash` (proved for all 8 golden
  cases: `supabase_store_test.ts` SS-01). Triggers validate them
  (`impact_ts()`: format + real calendar date).

## 5. Versioning, idempotency, concurrency

- Verification `version` is assigned by a BEFORE INSERT trigger under a row
  lock on the investigation → concurrent runs serialize; `UNIQUE (investigation,
  claim, version)` backs it.
- `UNIQUE (investigation, result_id)` and `UNIQUE (investigation,
  idempotency_key)`: a retried `run_verification` returns the stored row
  (`replayed: true`), never a duplicate. Source/claim/evidence/dispute retries
  hit the ref uniqueness → `ALREADY_EXISTS`.
- Audit appends lock the investigation row, so the chain never forks.
- A retried `run_verification` without a key re-evaluates at the new server
  time (a legitimate new version: staleness depends on time).
- The latest version per claim is read from the `impact_latest_verifications`
  view (`security_invoker`, RLS applies) — complete whatever the history
  length (Codex I1G1-02; tested with 2,001 versions). History is returned
  newest-first and bounded.

## 6. Lifecycle / deletion

- No direct `DELETE` for anyone (trigger, also blocks `service_role`); the Lab
  API has no delete action. Investigations are archived (final).
- The only deletion path is account erasure: `auth.users` → investigations →
  children cascade (privacy/right to erasure). Tested (E01/E02).

## 7. Source correction and disputes

A source becoming `UPDATED`/`RETRACTED`/`UNAVAILABLE` changes only its status,
audits `SOURCE_STATUS_CHANGED` + `REVERIFICATION_REQUIRED`, and the API lists
the affected claims. Earlier verifications stay; re-verification appends a new
version (`STATUS_CHANGED` audited when the status moves). Disputes never delete
history; an open dispute yields `DISPUTED`; resolution is recorded once and
requires re-verification.

## 8. Retention

As designed in the Foundation (`RETENTION_POLICY`): enforcement jobs are not
built in I1 (no scheduler in scope); the schema keeps only what the retention
table allows (no full pages; snapshots only for provider registry records;
excerpts ≤ 2,000 chars with hash).

## 9. Shared Evidence/Provenance core with Quant (future)

Real convergences observed (not extracted): content-hash provenance, freshness
classes, provider abstraction with capability declaration, deterministic result
ids. A shared core would be an Integration Gate decision; nothing is imported
from Quant.
