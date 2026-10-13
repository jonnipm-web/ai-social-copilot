# 04 — IVE (Intelligence layer / assistant)

IVE ("InsightValues Engine" persona) is the assistant surface. On E-MAIN it is **not a
server-side engine**: it is a client overlay + one LLM Edge Function (`context-copilot`)
+ client-side context builders + deterministic client-side scoring services.

## 1. Components (E-MAIN)

| Concern | Component | Evidence | Status |
|---|---|---|---|
| Context assembly | Each screen constructs `CopilotContextData` (project, scores, opportunities, actions, documents, personas, revenue, market, identity fields) | `lib/data/models/copilot_context_data.dart`, `lib/providers/context_copilot_provider.dart` | `IMPLEMENTED`, `TESTED` |
| Knowledge grounding | Client-side chunking and selection, 8000-char delivery budget matched server-side (`GROUNDING_DELIVERY_BUDGET_CHARS = 8000`) | `lib/data/services/document_context_builder.dart`, `supabase/functions/context-copilot/index.ts` | `IMPLEMENTED`, `TESTED` (40 static tests in builder) |
| Grounding contract | Prompt forbids claiming a document was analyzed unless its excerpt is present ("DOCUMENT EXISTS ≠ DOCUMENT ANALYZED") | `context-copilot/index.ts` system prompt | `VERIFIED` (source) |
| Untrusted-data handling | All context sections declared "EVIDÊNCIA NÃO-CONFIÁVEL"; instructions inside them must not be obeyed; request envelope validated (message ≤ 4000, history ≤ 20, context ≤ 50 000 serialized chars) before quota | same file, `validateRequestBody` | `VERIFIED`, `TESTED` (47 static tests) |
| Identity/provenance fields | `project_id`, `source_module`, `source_entity_type/id`, `correlation_id` — used for audit/correlation only, explicitly **not** for authorization | same file (comment "NEVER as an authorization decision") | `IMPLEMENTED` |
| Output structure | Trailing JSON: `sources[]`, `confidence`, `entities[]`, `action_suggestion` (`create_action`, `approve_opportunity`, `create_project`, `generate_roadmap`) | same file | `IMPLEMENTED` |
| Action intent | `action_suggestion` rendered as a **non-interactive chip** (`_actionChip`, no `onTap`) | `lib/shared/widgets/context_copilot_widget.dart` | `VERIFIED` — IVE cannot trigger actions on E-MAIN |
| Memory (device) | `SharedPreferences`: last route, last project, recent questions, interaction count | `lib/providers/ive_memory_provider.dart`, `lib/data/models/ive_memory.dart` | `IMPLEMENTED` (device-scoped, not user-scoped) |
| Memory (server) | `business_memory` table | baseline migration | `IMPLEMENTED` schema; no app reader (E-INT02 IVE doc) |
| Transcript | `contextCopilotProvider` family keyed `(screenName, projectId)`, in memory | `context_copilot_provider.dart:235` | `IMPLEMENTED`; not persisted |
| Intent routing | None. Single prompt with four "capabilities" (EXPLICAR, SIMULAR, RECOMENDAR, EXECUTAR-as-suggestion) | system prompt | `NOT_IMPLEMENTED` as routing |
| Strategy Intelligence context | Not present on E-MAIN (no Strategy001 / Quant context) | grep | `NOT_IMPLEMENTED` |
| Deterministic evidence | Ecosystem/project scores computed in Dart (`ecosystem_intelligence_service.dart`, `project_intelligence_service.dart`), passed to the LLM as context | `lib/data/services/` | `IMPLEMENTED` |
| LLM inference | All narrative, recommendations, confidence values | Groq `openai/gpt-oss-120b`, temperature/limits set per function | `IMPLEMENTED` |
| Visual presence | `IveOverlay`, `IveIntroGate`; `IveVisualFallback` is the commercial avatar; `IveRiveFeatureGate.enabled = false` compile-time constant | `lib/features/ive/visual/ive_visual_config.dart:42`, `docs/ive/IVE_RIVE_FREEZE_RECORD.md` | Rive `FROZEN` |

## 2. IVE context flow

```mermaid
sequenceDiagram
  participant S as Screen (client)
  participant B as DocumentContextBuilder
  participant P as ContextCopilotNotifier
  participant E as context-copilot EF
  participant A as GoTrue
  participant Q as try_reserve_ai_quota RPC
  participant G as Groq
  S->>B: select document chunks (≤ 8000 chars)
  S->>P: CopilotContextData + question
  P->>E: POST (user JWT, idempotency_key)
  E->>A: getUser(token) (fail-closed 401)
  E->>E: validate envelope (400 before quota)
  E->>Q: reserve 1 unit (429 if exceeded)
  E->>G: system prompt (untrusted context) + history
  G-->>E: answer + JSON block
  E-->>P: answer, sources, confidence, action_suggestion
  Note over E,Q: on Groq failure → refund_ai_quota(reservation)
  P-->>S: render; action_suggestion is display-only
```

## 3. Epistemic boundaries

| Boundary | E-MAIN behaviour | Gap |
|---|---|---|
| Fact vs inference | Not labelled. `confidence` is model-produced. | `docs/showcase/SHOW_00_CAPABILITY_GAP_MATRIX.md` §3 "Truth model MISSING" still holds on E-MAIN |
| Source lineage | `sources[]` are free-text names, not document IDs | Gap §5 still holds |
| Cross-project isolation | Context is built client-side from RLS-scoped reads; server does not verify project ownership | E-INT02 finding IVE-F02 (P2) |
| Cross-user isolation on shared device | Transcript provider is not `autoDispose` and is not invalidated on sign-out; device memory not user-scoped | E-INT02 finding IVE-F01 (P1). Still present on E-MAIN (`VERIFIED`: `auth_provider.dart` sign-out invalidates profile/quota only). See R-SEC-01 |
| Locale | Server prompt forces pt-BR answers | IVE-F03 (P2) |

## 4. Authority (verified)

IVE **analyzes, explains, recommends and proposes**. It does not authorize or execute on E-MAIN:
no tool calls, no DB writes, no AEF call. The only exception in the ecosystem is the
external ADK agent (E-AGENT), which is branded "IVE Strategic Execution Agent" and **does**
insert `action_queue` rows autonomously. See [05](05-aef.md) §7 and R-ARCH-02.

## 5. Unmerged evolution (E-INT02, `LAB`/unmerged)

`ive-intelligence` and `ive-memory` Edge Functions, `_shared/ive/{provider,budget,memory_policy,intelligence}.ts`,
session-isolation tests, action-suggestion navigation (`_handleActionSuggestion` navigates to the
owning screen, never executes), `IveActionIntent` → `aef-runtime` (LAB only). None of this is on E-MAIN.
