# IVE Intelligence Core — Architecture

Mission: `IVE-INTELLIGENCE-CORE-01` · Module Lab · **not deployed** (functions
`ive-intelligence`, `ive-memory`; migration `20260924000000` not applied).
Companion docs: `IVE_INTELLIGENCE_CURRENT_STATE.md` (discovery),
`IVE_MEMORY_MODEL.md`, `IVE_CONTEXT_SECURITY.md`, `MODULE_ARCHITECTURE.md` §13
(Entitlement Core, which this builds on).

## 1. Flow

```
client (Android | Web)                         server  (_shared/ive/*)
──────────────────────                         ──────────────────────────────────────────────
message, surface, locale,        ───────▶  AUTH (GoTrue)                       auth.ts
project_id?, conversation,                 ENTITLEMENT 'context-copilot'       entitlement.ts   (fail closed)
source_module?, idempotency_key            VALIDATE request                    contracts.ts
                                           INTENT / RISK ROUTING               intent_router.ts
                                             └─ consequential → ACTION_REQUIRES_AEF (no context, no quota, no model)
                                           CONTEXT ASSEMBLER                   context_assembler.ts
                                             capabilities ← listModuleDecisions
                                             project      ← verified owner    (fail closed)
                                             opportunities/actions ← if authorized, owner+project filtered
                                             knowledge    ← if authorized, ranked, budgeted
                                             memory       ← active, this project + user scope
                                             provenance, budgets, contextStatus
                                           PROMPT (policy / verified context / untrusted envelopes / request)
                                           QUOTA reserve                       quota.ts (unchanged)
                                           MODEL via IntelligenceProvider       provider.ts (Groq today)
                                             └─ failure → MODEL_UNAVAILABLE + refund
answer, sources, suggestedActions, ◀────── RESPONSE (server-built sources/actions, memory candidates)
contextStatus, correlationId
```

## 2. Request contract — client-supplied vs server-verified

| Client-supplied (validated, untrusted) | Server-verified (never read from the request) |
|---|---|
| `message` (≤ 4000) · `surface` (`android`/`web`; `ios`/`pwa`/`browser_extension`/`desktop`/`api` reserved → `SURFACE_NOT_SUPPORTED`) · `locale` (normalized to `pt-BR`/`en`, malformed → 400) · `project_id` (UUID; a *request*) · `conversation` (≤ 10 turns × 2000, `user`/`assistant` only) · `requested_capability` / `source_module` (hints) · `idempotency_key` · `correlation_id` (telemetry only) | identity · plan · roles · authorized modules · project ownership + data · knowledge · memory · provenance · suggested actions · AEF routing · the audit correlation id |

Anything else in the body (plan, role, entitlements, context, documents,
memory…) is ignored: no code path reads it (tests AD-06..09, client
`ive_intelligence_contract_test.dart`).

## 3. Context model

`IveIntelligenceContext` (composition, not a god object): `subject`
(type/plan/roles), `surface`, `locale`, `authorizedModules`, `project`,
`opportunities`, `actions`, `knowledge` (excerpts), `memories`,
`provenance[]`, `degraded[]`, `contextStatus` per optional source
(`included | empty | not_authorized | not_applicable | unavailable`),
`counts`, `truncation`.

## 4. Context priority and budget (`budget.ts`)

Priority: SYSTEM POLICY > AUTH/CAPABILITIES > CURRENT PROJECT > USER REQUEST >
RELEVANT KNOWLEDGE > PROJECT STATE > DURABLE MEMORY > OLD CONVERSATION.
Budgets (chars, deterministic): project 1200 · knowledge 8000 (same as the
old client builder) · opportunities 1500 · actions 1500 · memory 1500 ·
conversation 6000 (newest kept). Item limits: 5 opportunities, 5 actions, 20
knowledge candidates, 10 memories. Truncation is reported in telemetry.

## 5. Knowledge grounding (`knowledge_retrieval.ts`)

Server port of the client `DocumentContextBuilder` (800/100 chunks, lexical
overlap, best chunk per document, recency tie-break). Only `status =
analyzed` documents with content are groundable; registered-but-unprocessed
ones are counted and the model is told they were not read. Scope: the
caller's documents of the verified project **plus** unassigned ones; never
another project's. No embeddings (no vector infrastructure exists).

## 6. Capability awareness, suggestions, entitlement

Capabilities = `listModuleDecisions(subject)` from the Entitlement Core; the
IVE never recomputes plan/role logic. Suggested actions are produced by the
router + `decideModuleAccess`: `open_module` only if allowed; `upgrade` only
when the sole obstacle is the plan; unreleased/internal modules are never
advertised. The client additionally keeps a suggestion only if its
capability id exists in the Flutter registry and the kind is known; it only
navigates (route guard + server still decide).

## 7. Intent / risk routing and the IVE ↔ AEF boundary

`intent_router.ts` maps PT/EN wording to a capability and flags
consequential verbs (publish, send, pay, trade, transfer, delete) plus any
module whose `actionClass` is `CONSEQUENTIAL`. Matching runs on a canonical
form (NFKC, invisible characters removed, look-alike letters folded,
punctuation-split words rejoined) and on the latest 3 **user** turns.
Consequential → `ACTION_REQUIRES_AEF` with an `IveActionIntent`
(`capabilityId, requestedAction, projectId, riskClass: CONSEQUENTIAL,
contextRef, parameters`) — contract only; nothing persists or executes it.

Boundary: **IVE** understands, retrieves, reasons, recommends, prepares
intents. **AEF** authorizes, applies policy and Human Gate, executes tools,
issues receipts. The IVE has **no execution tool**, so even an unrecognized
consequential request can only produce text: the router is UX, the absence
of tools is the security boundary.

## 8. Provider abstraction (`provider.ts`)

`IntelligenceProvider.generate(messages)`; `GroqChatProvider` keeps today's
endpoint and model (no vendor migration). Failures are normalized
(`config | http | empty | network`) and never echo upstream text. The key is
read server-side only.

## 9. Multi-surface and locale

Android and Web build the same request (`IveIntelligenceRequest.toJson`,
`currentIveSurface()`); the surface is telemetry/UX only. Locale drives the
server policy language (PT/EN); logic uses codes; the client translates
(`ive_failure_messages.dart`, ARB keys `iveCore*`).

## 10. Failure model

| Code | Status | Kind |
|---|---|---|
| `AUTH_REQUIRED` / `Unauthorized` | 401 | fail closed |
| `MODULE_NOT_AVAILABLE` / `PLAN_REQUIRED` / `MODULE_DISABLED` | 403 | fail closed (Entitlement Core) |
| `ENTITLEMENT_UNAVAILABLE` | 503 | fail closed |
| `INVALID_REQUEST` / `SURFACE_NOT_SUPPORTED` | 400 | rejected before work |
| `PROJECT_FORBIDDEN` | 403 | fail closed (not owned / not found) |
| `CONTEXT_UNAVAILABLE` | 503 | fail closed (project lookup error) |
| `QUOTA_EXCEEDED` | 429 | quota (unchanged) |
| `MODEL_UNAVAILABLE` | 503 | quota refunded |
| `ACTION_REQUIRES_AEF` | 200 status | routed, not executed |

Optional sources (knowledge, memory, opportunities, actions) **degrade**:
the answer continues and `contextStatus` / `degraded` say what was missing;
the chat shows "partial context". Authorization-bearing context never
degrades.

## 11. Observability

One `ive_intelligence` log line per request: server correlation id (client
id only as `client_correlation_id`), surface, locale, status, has_project,
knowledge/memory/context counts, degraded, truncation, latency bucket,
provider error kind, `quota_refund_attempted`. Never the message, prompt,
documents, memory text, tokens or raw user id (test IS-03).

## 12. Performance

Per answered request: 1 GoTrue call, 1 profile read (entitlement), 1 project
read, then up to 4 bounded reads **in parallel**, 1 quota RPC, 1 model call.
No N+1, no cross-request cache (so no cross-user cache risk).

## 13. Client integration and compatibility

`ContextCopilotNotifier` routes to the core only when
`--dart-define=IVE_INTELLIGENCE_CORE=true` (`iveIntelligenceCoreEnabledProvider`);
the default commercial build keeps the legacy `context-copilot` path
unchanged (no breaking change). In core mode the client sends no
screen-built context and no device-local memory; conversations stay keyed by
`(screen, project)`, AEF exchanges are not resent, failures are structured.
Existing UI (Global IVE, Meet IVE, Context Copilot, entry points, avatar,
placement) is untouched apart from the chat bubble states.

Session isolation (IVE-F01): sign-out and a different user's sign-in reset
transcripts, capability cache, project context and device-local IVE memory
(`ive_session_isolation.dart`, guarded against the async-load race).

Offline/degraded: the core is server-side; without connectivity the chat
shows a structured failure and nothing is answered from local state; no
capability is granted from a cache (`ServerModuleAccess` is default-deny).

## 14. External agent

`insightvalues-ive-agent` is not a caller and not an authority of the core.
The core does not call it; a future integration would be an
`IntelligenceProvider`/tool behind AEF, never a second context assembler.

## 15. Readiness for future modules (no hardcodes added)

Social: capability + intent routing already returns `ACTION_REQUIRES_AEF`
for publishing. Quant: `ive-quant` is `CONSEQUENTIAL` → routed to AEF; any
financial context would be another data-source method behind entitlement.
Impact: provenance/trust classes are the evidence backbone.
