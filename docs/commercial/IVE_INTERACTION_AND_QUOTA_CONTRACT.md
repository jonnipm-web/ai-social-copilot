# IVE Interaction and Quota/Consent Contract

Status: PROPOSED (architecture mission COMMERCIAL-PRODUCT-ARCHITECTURE-10)
Owner gate: Agente Martins
Implements: mission brief Sections 05, 06, 07
Depends on: `PROJECT_CONTEXT_CONTRACT.md`

## 1. Current state (verified in repo)

### 1.1 "Ask IVE" invocation sites
All 6 `showCopilotChat(` call sites (see `PROJECT_CONTEXT_CONTRACT.md`
§2) already open a contextual bottom sheet in place, in the current
workflow — they do **not** redirect the user to an unrelated module.
That part of Section 05 is already satisfied. What is missing is the
*content* of the context they carry (covered by the Project Context
Contract), not *where* the dialog opens.

Two modules explicitly do **not** wire "Ask IVE" contextually at all:
- `opportunity_detail_screen.dart:925-929` — its "Ask IVE" button is
  `onPressed: () => context.go(AppConstants.routeOpportunityLab)`, i.e.
  it navigates back to the list screen and relies on the global overlay
  having "some" context.
- `action_detail_screen.dart:876` — identical pattern, navigates to
  `routeActionEngine`.

These two are true violations of Section 05 ("must open contextual
dialog... do NOT redirect users to unrelated modules merely to ask
IVE") and are the concrete fix target for Phase B, not a hypothetical.

### 1.2 Quota
Fully server-authoritative today — confirmed no client-side decrement
exists anywhere. `supabase/functions/_shared/quota.ts`'s
`reserveQuota()`/`refundQuota()` wrap SECURITY DEFINER RPCs
(`try_reserve_ai_quota`, `refund_ai_quota`) keyed off `auth.uid()`; the
client cannot supply user, plan, or count. This is the correct
foundation and needs no architectural change — only a consumption
contract layered in front of it on the client.

**Zero confirmation-before-charge UI exists anywhere.** Eight screens
fire the AI call immediately on button press, guarded only by a private
`bool _running`: `gap_analysis_screen.dart`,
`opportunity_discovery_screen.dart`, `revenue_planner_screen.dart`,
`niche_discovery_screen.dart`, `content_cluster_screen.dart`,
`competitor_discovery_screen.dart`, `persona_form_screen.dart`,
`action_engine_screen.dart`. This is the exact gap Section 06 targets —
not a hardening of an existing flow, but new UX inserted in front of
each of these eight call sites.

**No audit trail for "why was one analysis deducted"** beyond the
generic `diagnostic_events` `quota_fetch` read event from prior
missions. Section 30's requirement is net-new.

### 1.3 AI processing states
No canonical enum exists. Every AI-triggering screen (the same eight
above, plus more) uses its own private `_running`/`_loading` boolean →
binary spinner/disabled-button UI. Section 07's state machine is
**100% net-new** — there is nothing to migrate away from beyond
find/replace-consistency work, and nothing it would conflict with.

## 2. Canonical IVE interaction contract

Every "Ask IVE" / "Analisar com a IVE" / "Comparar com a IVE" /
"Explicar com a IVE" call site must supply:

```dart
class IveInteractionRequest {
  final ProjectContext? projectContext;  // from PROJECT_CONTEXT_CONTRACT.md
  final String operationType;            // 'ask' | 'analyze' | 'compare' | 'explain'
  final String sourceModule;
  final String? sourceEntityId;
  final String correlationId;
}
```

`showCopilotChat(...)` gains a required `IveInteractionRequest` parameter
(replacing the current bare `screenName`/`contextData` pair, which
`contextData` subsumes once `CopilotContextData` carries identity per
the Project Context Contract). The two non-conforming call sites
(`opportunity_detail_screen.dart:925`, `action_detail_screen.dart:876`)
are updated to open `showCopilotChat` directly with the current item's
context, instead of navigating away.

## 3. Canonical quota/consent contract

### 3.1 Confirmation flow (client)

Before any of the eight identified call sites fires its AI request:

1. Show: *"Esta análise vai consumir 1 das suas análises mensais."* +
   current remaining quota (read via existing `currentQuotaProvider`,
   unchanged).
2. Two actions: **CONFIRMAR** / **CANCELAR**.
3. CANCELAR: no network call, no quota touched. State returns to IDLE.
4. CONFIRMAR: proceeds through the state machine in §4, which calls the
   existing server-authoritative `reserveQuota`/`refundQuota` path
   unchanged — this contract adds a client-side gate in front of an
   already-correct server boundary, it does not touch the boundary
   itself.

### 3.2 What does NOT consume quota (explicit, so it is never
accidentally wired to the confirmation dialog)

- Reading/opening an existing stored analysis result.
- Opening a card, expanding a summary.
- Reopening a saved IVE analysis.

Only an explicit *new* analysis request goes through §3.1. A rerun/
reanalyze is a new analysis for this purpose and goes through §3.1
again (see `ANALYSIS_RESULT_PERSISTENCE` note in
`COMMERCIAL_PRODUCT_ARCHITECTURE.md` §Analysis Lifecycle).

### 3.3 Audit trail

Extend the existing diagnostic event pipeline (07A/07B design, already
production-proven) with a dedicated, safe event sequence per paid
interaction — this reuses `DiagnosticCategory`, `correlationId`
generation, and the metadata allowlist/denylist sanitizer already built
and hardened over three prior missions, rather than inventing a parallel
logging path:

```
analysis_requested
consent_accepted | consent_rejected
quota_reserved
analysis_started
analysis_succeeded | analysis_failed
quota_refunded            (when applicable)
```

Each event carries `projectId`, `sourceModule`, `sourceEntityId`,
`correlationId` — never JWTs, OAuth tokens, secrets, full prompt/document
content. This directly answers Section 30's "why was one analysis
deducted" support requirement using evidence, not speculation. See
`docs/ive/AI_QUOTA_AUDITABILITY_DESIGN.md` (already written, design-only,
in a prior mission) — this contract formally adopts and extends that
design rather than replacing it.

## 4. Canonical AI processing state machine

```
IDLE
  → AWAITING_CONFIRMATION   (user clicked "Analisar")
  → RESERVING_QUOTA         (user confirmed; reserveQuota() in flight)
  → THINKING                (quota reserved; request sent)
  → GENERATING              (streaming/long-running response, if applicable)
  → PERSISTING              (writing result row)
  → SUCCESS
  → ERROR | RETRYABLE_ERROR
```

Rules:
- Every AI-triggering button in the 8 identified screens is migrated
  from its private `bool _running` to this enum. This is a mechanical,
  low-risk change per screen (same call sites, richer state), not a
  redesign of any screen's layout.
- A button may not be pressed a second time while state is anything
  other than `IDLE`, `SUCCESS`, or `ERROR`/`RETRYABLE_ERROR` — this is
  the direct fix for "double click → double reservation" risk,
  independent of (but complementary to) any server-side idempotency.
- Visual treatment: a subtle, consistent "thinking" indicator (e.g.
  animated three-dot pulse) replaces each screen's ad hoc spinner text,
  for consistency — this is a shared small widget, not a per-screen
  redesign.

## 5. Acceptance criteria for Phase A/B implementation

- All 8 identified AI-triggering screens gate their action behind the
  §3.1 confirmation dialog and the §4 state machine.
- `opportunity_detail_screen.dart` and `action_detail_screen.dart`'s
  "Ask IVE" buttons open a contextual dialog directly, no longer
  navigate away first.
- A new diagnostic event sequence (§3.3) is emitted for at least one
  full accept→success path and one reject path, verified against
  `diagnostic_events` the same way prior missions verified 07A/07B.
- No client-side quota decrement is introduced anywhere — the server
  RPCs remain the sole source of truth.
