# AEF Audit Growth & Rate Limit

Mission `IV-AEF-HARDENING-01` — closes the deferred findings G2-03 and
CF-01 (residual). Migration `20260926000000_aef_hardening.sql`. Tests:
`aef_hardening_test.sql` H05/H09, `hardening_pg_test.ts` HP-10.

## Problem

Every refused request of a verified subject, and every foreign attempt to
approve a subject's gate, appended one immutable audit event. A caller could
grow a chain (its own, or a victim's via approval spam) without bound.

## Design: coalesce, never drop

- **Coalescible** event types: `REQUEST_DENIED`, `APPROVAL_DENIED`.
  **Never coalesced**: operation/gate transitions, receipts, reconciliations,
  purges, erasures, `RECONCILIATION_DENIED` — these are bounded by the
  admission limits (≤ 50 open operations per subject, one receipt / one
  reconciliation per operation).
- Per subject, per window (`denial_window_seconds`, default 60 s): the first
  `denial_window_limit` (default 20) coalescible events are written
  individually.
- Beyond that, each event increments a **durable counter**
  (`aef_audit_pending`, keyed by subject, event type and reason code). The
  count is never lost: it survives restarts and is part of erasure.
- When the window closes (next coalescible event after it, or the
  `aef_recover` sweep), each counter is flushed as **one** chain event
  `DENIALS_COALESCED` (reason = the code) whose `ref_hash` commits to the
  `aef_audit_coalesced` row (type, code, count, window start/end).
- `aef_verify_audit_chain` recomputes that commitment: altering a count is
  detected (`COALESCED_MISMATCH`, H05g). The event hash formula is
  unchanged, so pre-hardening chains stay valid.

Result: at most `limit + number_of_distinct_codes` events per subject per
window, with every denial accounted for (`individual + pending + coalesced =
total`, proven with 3,000 sequential and 400 concurrent denials).

## Security properties

- The client cannot silence auditing: a denial is either an event or a
  durable counter, and the counter is itself anchored in the chain.
- Security-relevant denials (`RESOURCE_FORBIDDEN`, `APPROVER_NOT_AUTHORIZED`,
  `IDEMPOTENCY_CONFLICT`, …) are preserved as exact counts per code.
- Rate limiting applies to **audit storage**, never to authorization: a
  request over the limit is still fully checked and refused; nothing is
  skipped or allowed because of the limit.
- Lock order: window row → audit head; the sweep uses `SKIP LOCKED` before
  any operation lock (no deadlock, HP-10 / HP-07).

## Not in scope (documented)

- Request-level throttling (rejecting requests before evaluation) belongs to
  the future runtime endpoint (API gateway / Edge Function), not to AEF.
- Very long-term growth of `aef_audit_coalesced` follows audit retention
  (pruned with the prefix, AEF_RETENTION_ERASURE_MODEL.md).
