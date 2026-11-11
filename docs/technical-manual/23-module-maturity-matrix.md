# 23 — Module Maturity Matrix

Canonical per-module status. Source of module metadata on E-MAIN: `lib/core/modules/module_registry.dart`
(37 entries). "Deployment" refers to the backend piece (Edge Function / table); the Web client is
`DEPLOYED` on every push to main, so client screens inherit that unless stated.
Deployment of Supabase pieces is `UNKNOWN` unless a dated report exists (`HISTORICAL_EVIDENCE_ONLY`).

Legend for COMMERCIAL: V1 = `commercialEnabled: true` on E-MAIN; post-V1 / beta / internal = not
reachable by non-admins on E-MAIN.

| MODULE | PURPOSE | CODE | TEST | DEPLOYMENT | COMMERCIAL (E-MAIN) | SECURITY | DEPENDENCIES | KNOWN BLOCKERS | SOURCE EVIDENCE |
|---|---|---|---|---|---|---|---|---|---|
| Auth & profiles | Sign-in, roles | `IMPLEMENTED` | `TESTED` | `UNKNOWN` (Supabase) | Core | Role trigger; `is_active` unenforced | GoTrue, Google | R-SEC-05 | `auth_service.dart`, migration 022 |
| command-center | Aggregated OS view | `IMPLEMENTED` | partial | client | V1 free | RLS reads | projects, action_queue, opportunity_lab, knowledge | overlap with dashboard | registry |
| business-dashboard | Dashboard | `IMPLEMENTED` | — | client | V1 free | RLS | same | duplication D4 | registry |
| projects | Project primitive | `IMPLEMENTED` | `TESTED` | `UNKNOWN` | V1 free | RLS own | — | R-DATA-01 | `project_command_center_screen.dart` |
| knowledge-vault | Knowledge storage/analysis | `IMPLEMENTED` | `TESTED` | `HISTORICAL_EVIDENCE_ONLY` | V1 free | RLS, SSRF, file caps | `extract-knowledge`, `process-file` | R-AI-01 | registry, EFs |
| strategy-generation | Knowledge → strategy | `IMPLEMENTED` | `TESTED` (5) | `HISTORICAL_EVIDENCE_ONLY` | V1 free (sub-flow) | auth + quota | `generate-strategy` | — | registry |
| website-analyzer | Analyze a URL | `IMPLEMENTED` | `TESTED` (5) | `HISTORICAL_EVIDENCE_ONLY` | V1 free | SSRF guard | `analyze-website` | no `project_id` | registry |
| market-intelligence (+6 sub-modules) | Niche/competitor/gap/opportunity/cluster/revenue analysis | `IMPLEMENTED` | EF untested | `HISTORICAL_EVIDENCE_ONLY` | V1 free | auth + quota; ownership check on `market_analyses` | 7 EFs | LLM-generated numbers (R-AI-02) | registry |
| opportunity-lab | Opportunity pipeline | `IMPLEMENTED` | partial | `UNKNOWN` | V1 free | RLS + ownership WITH CHECK | `generate-project-opportunities` | duplicate actions | registry, 14S migration |
| action-engine | Action queue | `IMPLEMENTED` | partial | `UNKNOWN` | V1 free | RLS; no AEF | `generate-project-actions` | no `paused`, duplicates, outside AEF | registry, `COMMERCIAL_PRODUCT_ARCHITECTURE.md` |
| context-copilot (IVE) | Assistant | `IMPLEMENTED` | `TESTED` (47) | `HISTORICAL_EVIDENCE_ONLY` | V1 free | auth, quota, untrusted context | Groq | R-SEC-01 | EF, provider |
| file-import | PDF/DOCX/TXT | `IMPLEMENTED` | `TESTED` (10) | `HISTORICAL_EVIDENCE_ONLY` | V1 free | caps, auth | `process-file` | — | registry |
| google-drive-import | Drive files | `IMPLEMENTED` | `TESTED` (12) | client | V1 free | `drive.readonly` overbroad | Google | scope hardening | registry note |
| usage-quota | AI quota | `IMPLEMENTED` | `TESTED` | `UNKNOWN` | V1 free | DEFINER RPCs, idempotent | `ai_usage`, reservations | Pro limit conflict | migrations |
| plans-upgrade | Stripe checkout | `IMPLEMENTED` | `TESTED` | TEST mode, `HISTORICAL_EVIDENCE_ONLY` | V1 free | HMAC, ordering, service_role | Stripe | live activation HOLD; R-SEC-06 | registry |
| improve-post | Post improvement | `IMPLEMENTED` | — | `HISTORICAL_EVIDENCE_ONLY` | post-V1 | auth + quota | Groq | not commercial on main | registry |
| personas | Brand personas + training | `IMPLEMENTED` | — | client | post-V1 (Pro) | RLS | — | not commercial | registry |
| content-library | Content items | `IMPLEMENTED` | — | client | post-V1 (Pro) | RLS; `project_id` unchecked | — | not commercial | registry |
| calendar | Editorial planning | `IMPLEMENTED` | — | client | post-V1 (Pro) | RLS | — | no publishing | registry |
| campaigns | Campaign generation | `IMPLEMENTED` | `TESTED` (5) | `HISTORICAL_EVIDENCE_ONLY` | post-V1 | auth + quota | `generate-campaign` | — | registry |
| performance | Manual metrics | `IMPLEMENTED` | — | client | post-V1 | RLS | — | no connectors | registry |
| roi-tracker | ROI metrics | `IMPLEMENTED` | — | client | post-V1 | RLS | — | — | registry |
| executive-dashboard | Exec aggregation | `IMPLEMENTED` | — | client | beta | RLS | client-side | — | registry |
| decision-center | Exec aggregation | `IMPLEMENTED` | — | client | beta | RLS | client-side | — | registry |
| resource-allocation | Budget allocation | `IMPLEMENTED` | `TESTED` (29) | `UNKNOWN` (table) | beta | RLS via project | `project_resource_allocations` | — | migration `20260917000000` |
| weekly-briefing | Briefing | `IMPLEMENTED` | `TESTED` (scoping) | client | beta | RLS | client-side | — | registry |
| advisor-onboarding | Onboarding | `IMPLEMENTED` (orphan route) | — | client | internal | RLS | `advisor_profiles` | no entry point | registry |
| decision-simulator | Scenario simulation | `IMPLEMENTED` (EF only) | — | `HISTORICAL_EVIDENCE_ONLY` | internal (admin) | auth + quota | Groq | no UI | registry |
| intelligence-debug | Internal audit | `IMPLEMENTED` | — | client | internal | admin gate | — | — | registry |
| admin-panel | User/role admin | `IMPLEMENTED` | — | client | internal | RLS admin + trigger | `profiles` | Pro limit 100 vs 300 | registry |
| ive-avatar | Visual presence | `IMPLEMENTED` (fallback) | `TESTED` (32) | client | beta (commercialEnabled) | none needed | — | Rive `FROZEN` | freeze record |
| ive-quant | Financial vertical | `PLANNED` on E-MAIN | — | — | not commercial | AEF hard boundary | E-QUANT | licensing, Macro-09 | registry |
| AEF v0 | Governed execution | `IMPLEMENTED` (library) | `TESTED` (138 static) | not deployable | n/a | fail-closed, mock only | — | not wired | `aef/`, `contracts/aef/` |
| AEF persistence + runtime | Durable governance | `LAB` (E-INT02) | `TESTED` (E-INT02) | not applied | n/a | kill switch | subject_roles | executor decision pending | E-INT02 docs |
| Server entitlements (`module-access`) | Server plan gating | E-INT02 only | `TESTED` (E-INT02) | not deployed | n/a | closes R-SEC-03 | — | merge | E-INT02 |
| Quant Lab | Market analytics | `EXPERIMENTAL` (E-INT02) | `TESTED` (E-INT02) | not deployed | admin-only | read-only/reversible | no vendor | licensing | E-INT02 |
| Strategy001 / Paulo Trend Fibonacci V2–V4 | Research engine | `IMPLEMENTED` (E-QUANT) | `TESTED` (2496 static) | none | none | no execution | Python | negative research result | E-QUANT |
| Robot Builder / Strategy Lab / V10 | Financial RC | `ENVIRONMENT_BLOCKED` | `ENVIRONMENT_BLOCKED` | `ENVIRONMENT_BLOCKED` | `ENVIRONMENT_BLOCKED` | `ENVIRONMENT_BLOCKED` | — | Macro-09 access | none |
| Impact Lab | Verification dossier | `EXPERIMENTAL` (E-INT02) | `TESTED` (E-INT02) | not applied/deployed | admin-only | privacy/safety guards | registries not live | F-09 taxonomy | E-INT02 |
| Social distribution | Posting/scheduling | `NOT_IMPLEMENTED` | — | — | — | — | — | OAuth, AEF | grep |
| ive-agent-runner | Retired runner | `DEPRECATED` stub | — | `DEPLOYED` v6 (report) | none | 410 after auth | — | — | SR04/SR05 closure |
| External ADK agent | Hackathon agent | `IMPLEMENTED` (E-AGENT) | `TESTED` (103 static) | `UNKNOWN` | none | outside AEF | Gemini, Cloud Run | R-SEC-02 | E-AGENT |
