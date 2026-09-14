# AI/Quota Auditability — Design Hook (IVE-COMMERCIAL-STABILITY-08 Phase 6)

Status: **DESIGN ONLY — not implemented, not wired to any call site.**
This document exists so a future UX mission (the owner's broader IVE
experience redesign) can wire real AI-consuming screens into the existing
07A/07B diagnostic logger without re-deriving the data model or the
security rules from scratch. It changes no behavior by itself.

## Why this exists

Mission 08 was asked to "prepare minimal architecture" for auditing
individual IVE/AI analyses (consent shown, accepted/rejected, quota
reservation result, execution id, success/failure, refund) without
implementing the new experience itself — that redesign is explicitly out
of scope here and belongs to a dedicated UX mission that consolidates the
owner's full request into one spec, not screen-by-screen patches.

## What already exists (07A/07B) and is reused, not replaced

- `DiagnosticCategory.ai` already exists in
  `lib/core/diagnostics/diagnostic_models.dart` — no new category needed.
- `DiagnosticLoggerService.logEvent()` already accepts `module`,
  `operation`, `route`, `status`, `durationMs`, `correlationId`, and a
  `metadata` map validated against `kDiagnosticMetadataKeys` (allowlist)
  before storage (`buildSafeMetadata` in `diagnostic_sanitizer.dart`) —
  this is the correct choke point for every field below, not a new table
  or a new logging path.
- `newDiagnosticCorrelationId()` already exists to link a "started" event
  to its later "success"/"failure" event across an await gap — exactly
  the mechanism an execution ID needs.
- Server-side quota reservation/refund (`reserveQuota`/`refundQuota` in
  `supabase/functions/_shared/quota.ts`, already audited across ~17 AI
  Edge Functions in Remediation 06) remains the sole authority for
  whether an analysis is actually charged. Nothing here changes that,
  duplicates it client-side, or lets the client assert its own quota
  outcome.

## Proposed event shape (design only)

Two AI-category events per analysis attempt, correlated by one
`correlationId` (from `newDiagnosticCorrelationId()`), mirroring the
existing "started"/"success"/"failure" pattern already used elsewhere in
this app's instrumentation:

**1. `ai_analysis_requested`** (logged when the user takes the action,
BEFORE the network call):
```
category: ai
eventName: 'ai_analysis_requested'
module: <source module, e.g. 'knowledge', 'market_intelligence'>
operation: <analysis target type, e.g. 'knowledge_item', 'gap_analysis'>
correlationId: <new id>
metadata: {
  'source_screen': <screen name>,
  'consent_shown': true|false,
}
```

**2. `ai_analysis_consent_decision`** (only when a consent/confirmation
prompt is actually shown — most current call sites have none today, this
is for the future UX that may add one):
```
category: ai
eventName: 'ai_analysis_consent_decision'
correlationId: <same id as above>
status: 'accepted' | 'rejected'
```
Rule: a `rejected` decision MUST short-circuit before any quota
reservation call is made — rejecting must never consume an analysis. This
is a client-side UX rule; the actual enforcement remains the Edge
Function never being called at all when rejected, not a client-side flag
the server trusts.

**3. `ai_analysis_result`** (after the network call settles):
```
category: ai
eventName: 'ai_analysis_result'
correlationId: <same id as above>
status: 'success' | 'failure'
durationMs: <elapsed>
metadata: {
  'quota_reservation_result': 'reserved' | 'denied' | 'refunded',
  'response_length': <int, success only>,
}
error / stackTrace: <on failure, same as every other logEvent call>
```
`quota_reservation_result` reflects what the Edge Function's own response
said happened (already returned today per Remediation 06's audit of
reserve/refund), not a client-side guess.

## New allowlisted metadata keys required

`kDiagnosticMetadataKeys` in `diagnostic_sanitizer.dart` would need three
additions to carry the fields above through `buildSafeMetadata`'s
allowlist: `source_screen` (already present), `consent_shown`,
`quota_reservation_result`. None of these are secret-shaped, so no
sanitizer change beyond the allowlist entry is needed. NOT added by this
document — left for the mission that actually wires a call site, so the
allowlist changes land together with its first real usage and its own
tests, per the existing 07A/07B convention (every allowlist addition so
far has shipped with the feature that needed it, not speculatively).

## Explicit non-goals of this design (per mission 08 scope)

- Does NOT implement a consent UI anywhere — no current screen has one.
- Does NOT change how any Edge Function reserves or refunds quota.
- Does NOT log prompt text, AI response content, or any other
  potentially-sensitive analysis content — only structural/outcome data,
  consistent with `kDiagnosticMetadataKeys`' existing "no free-form
  content" convention.
- Does NOT wire this into knowledge_service.dart, market_analysis_service.dart,
  or any other AI-calling service. That is the next mission's job, once
  the owner's full UX spec exists to design the real consent flow around.

## Server remains sole quota authority (restated)

Nothing in this design lets the client:
- assert that a reservation succeeded when the server said otherwise,
- skip a reservation call because a diagnostic event says "accepted",
- fabricate a free analysis by manipulating a client-side status field.

`quota_reservation_result` is a **read-only reflection** of the Edge
Function's own response, logged for observability after the fact — never
an input the server trusts.
