# IVE Intelligence — Current State (discovery)

Mission: `IVE-INTELLIGENCE-CORE-01` · Module Lab base `de94a56` · evidence-first.
Location note: kept next to the other module docs (`docs/architecture/modules/`)
instead of a new `docs/modules/` root, to avoid two parallel doc trees.

## 1. Where "IVE intelligence" actually lives today

| Layer | Artifact | What it does |
|---|---|---|
| Backend (only LLM path) | `supabase/functions/context-copilot/index.ts` | auth → entitlement (`context-copilot`) → validate body → reserve quota → Groq `openai/gpt-oss-120b` → parse trailing JSON block → answer + `sources/confidence/entities/action_suggestion` |
| Client request | `lib/providers/context_copilot_provider.dart` (`ContextCopilotNotifier.send`) | sends `message`, `screen_name`, `context` (client-built), `history`, `recent_questions`, `idempotency_key` |
| Client context | `lib/data/models/copilot_context_data.dart` | project / scores / opportunities / actions / documents (with `content_excerpt`) / personas / revenue / market + identity fields (`project_id`, `source_module`, `source_entity_*`, `correlation_id`) |
| Context builders | **24 `CopilotContextData(...)` construction sites in 10 screens/widgets** (projects command center, knowledge vault, opportunity detail, action detail, market intelligence hub, website result, executive dashboard, decision center, IVE detail sheet, explain button) | each screen decides what the model sees |
| Knowledge selection | `lib/data/services/document_context_builder.dart` | client-side chunking (800 chars, 100 overlap), word-overlap scoring, 8000-char budget |
| Ask-IVE contract | `lib/data/models/ive_interaction_request.dart` | UI entry-point identity (source module/entity, correlation id) |
| Presentation state | `ive_provider.dart`, `ive_visual_provider.dart`, `features/ive/visual/*`, `ive_overlay.dart` | avatar, expressions, thinking/speaking, placement — out of scope |
| Project/ecosystem context | `lib/providers/ive_context_provider.dart` | aggregates projects/scores/alerts in Dart (project-scoped since PROJECT_CONTEXT_CONTRACT) |
| Local memory | `lib/providers/ive_memory_provider.dart` → SharedPreferences | last route, **last project id/name**, **recent questions**, interaction count, ecosystem snapshot, dismissed alerts |
| Server memory | `public.business_memory` + `business_memory_service.dart` | columns id, user_id, project_id, memory_type, title, content, confidence_score, source, created_at; **no screen reads it**; only writer found: external agent |
| Chat transcript | `contextCopilotProvider` family keyed `(screenName, projectId)` | in-memory, not persisted; `copilot_sessions/messages/context` tables exist in schema but have no reader/writer in `lib/` or functions |
| Action suggestions | `context_copilot_widget.dart` `_handleActionSuggestion` | only NAVIGATES to the owning screen (create_action → Action Engine, approve_opportunity → Opportunity Lab, create_project → Projects); never executes |
| External agent | repo `insightvalues-ive-agent` (Python/ADK, Cloud Run) | inserts `action_queue` (origin `ive_agent`) and `business_memory` (source `ive_strategic_execution_agent`) with the user's JWT; no caller in this repo |
| AEF | `aef/*` | not called by any IVE path |
| Capability discovery | `module-access` EF + `serverModuleAccessProvider` (mission 02) | exists, **not consumed by IVE yet** |
| Diagnostics | `diagnostic_session_provider` (client), one `console.log` line in the EF | shape-only, no prompt text (good) |

## 2. Findings (drive the target architecture)

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| IVE-F01 | P1 | **Logout/login leak on a shared device.** Sign-out invalidates profile/quota/diagnostics only. `contextCopilotProvider` (not autoDispose) keeps the previous user's transcript in memory; a new user opening the same screen with no project (`projectId == null`) gets the same conversation key and **resends the previous user's history** to the model. `ive_memory_provider` keeps the previous user's recent questions and last project name in SharedPreferences. | `auth_provider.dart` `signOut()`; `context_copilot_provider.dart:233-238`; `ive_memory_provider.dart` keys |
| IVE-F02 | P2 | **Server trusts client-built context.** The model sees whatever the client puts in `context` (project, documents, excerpts). No cross-user read is possible (the client fetched via RLS and the server reads nothing), but project ownership is never verified server-side, and every screen builds its own context. | `context-copilot/index.ts:212-289` ("never as an authorization decision") |
| IVE-F03 | P2 | **Locale hardcoded** in the server prompt: "Responda sempre em Português do Brasil". | `index.ts:360` |
| IVE-F04 | P3 | `recent_questions` is sent by the client and ignored by the server (dead data flow, and it comes from device-local memory). | `context_copilot_provider.dart:134`; not read in `index.ts` |
| IVE-F05 | P3 | `action_suggestion` is free model output (`type`/`label`/`data`) with no capability id and no entitlement check; the UI only navigates, and the route guard still applies. | `index.ts:348-358`; widget `_handleActionSuggestion` |
| IVE-F06 | P2 | `business_memory` RLS is `FOR ALL USING (auth.uid() = user_id)`: an owner can write a row pointing at a project they do not own (no WITH CHECK on project ownership). Reads are owner-scoped, so nothing leaks cross-user. | baseline migration line 1278 |
| IVE-F07 | P3 | Provider coupling: Groq URL/model/key are inlined in each function (21 copies of the pattern), no shared generation interface or failure normalization; provider errors are returned as `String(err)` (may include upstream text). | `index.ts:372-394,443-448` |
| IVE-F08 | P3 | Unused tables `copilot_sessions/messages/context` (schema only). | grep of `lib/`, functions |

## 3. Storage / context matrix

| Store | Owner | Purpose | Scope | Source of truth | Writers | Readers | Retention | Security | Project-bound | User-bound | Side | Duplication |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `ive_memory` (SharedPreferences) | device | UX continuity | device (not user!) | device | overlay, copilot notifier | IVE provider, copilot | forever | none | partially (last project) | **no** | client | with business_memory (D2) |
| `business_memory` | user | durable business facts | user (+ optional project) | DB | external agent; service methods (unused) | nobody in app | forever | RLS own rows | optional | yes | server | with ive_memory |
| chat transcript | session | conversation | (screen, project) in memory | provider | notifier | notifier (sent as history) | app lifetime | none (**not reset on logout**) | yes (key) | **no** | client | — |
| `CopilotContextData` | screen | model context | per call | client | 24 sites | EF (interpolated) | per call | client RLS reads | yes | yes | client→server | each screen differs |
| `knowledge_items` | user | documents | user + optional project | DB | knowledge flows | client builder | forever | RLS | optional | yes | server | — |
| `action_queue` | user | actions | project | DB | Action Engine, external agent | Action Engine | forever | RLS + ownership triggers | yes | yes | server | — |
| `copilot_sessions/messages/context` | — | unused | — | — | none | none | — | RLS | — | — | server | dead |

## 4. Model / provider routing (today)

Every AI Edge Function calls `https://api.groq.com/openai/v1/chat/completions`
directly with `Deno.env.get('GROQ_API_KEY')` and model `openai/gpt-oss-120b`
(context-copilot: temperature 0.4, max 800 tokens). No Gemini call exists in
this repository (Gemini is only used by the external agent). Keys never
reach the client.
