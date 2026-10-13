# 28 — Glossary

One definition per term. Terms are unique (checked by `tools/validate_manual.py`).

| Term | Definition |
|---|---|
| InsightValues | The ecosystem and brand: the Flutter/Supabase product (repo `ai-social-copilot`), its vertical labs, the Quant research repo, the hackathon agent and the content site. |
| IVE | The intelligence/assistant layer and persona. On E-MAIN: overlay UI + `context-copilot` Edge Function + client context builders. Proposes; never authorizes. |
| AEF | Autonomous Execution Fabric: the governed execution layer (contracts, fail-closed kernel, policy, Human Gate, tool registry, receipts). On E-MAIN a library with mock tools only. |
| Project | The primary contextual object (`projects` row, owned by one user) to which knowledge, analyses, opportunities and actions attach. |
| Knowledge Vault | The user's documents and notes (`knowledge_items`) plus their AI analyses and strategies; ingestion via text, URL, file or Google Drive. |
| Intelligence | Analyses produced for a project: market, competitor, gap, niche, opportunity discovery, content cluster, revenue plan, website analysis. Mostly LLM inference. |
| Opportunity | A candidate initiative in the Opportunity Lab (`opportunity_lab`) with score, sources, rationale, risks and status. |
| Action Intent | A proposal to act. On E-MAIN: Context Copilot's `action_suggestion`; in AEF terms: an `ExecutionRequest` (E-INT02 names it `IveActionIntent`). Never an authorization. |
| Human Gate | The AEF step that requires an authorized `HumanGateRecord` (verified approver) before a gated action may execute. |
| ExecutionReceipt | AEF record of a governed attempt: actor, action, policy decision, outcome (`SUCCESS`, `FAILURE`, `PARTIAL`, `ROLLED_BACK`, `NOT_EXECUTED`), timestamps, optional gate/tool refs. |
| Robot Builder | Owner-described Macro-09 Financial RC component for building strategies. Not found in accessible evidence (`ENVIRONMENT_BLOCKED`). |
| Strategy Lab | Owner-described Macro-09 surface for strategy experiments. Not found in accessible evidence (`ENVIRONMENT_BLOCKED`). |
| Strategy Specification | Owner-described declarative definition of a strategy consumed by the Validation/Backtest engines. Not found in accessible evidence (`ENVIRONMENT_BLOCKED`). |
| Strategy001 | Historical strategy-engine / state-machine architecture in `insightvalues_quant/strategy001/`: tracks trend → pullback → Fibonacci → confirmation → trigger/target/reset and emits events; never trading signals. |
| Strategy #001 | Product identifier for the Paulo Trend Fibonacci V10 reference strategy (owner definition). Not verified in accessible evidence. |
| Paulo Trend Fibonacci V10 | Current verified reference strategy implementation per owner definition. Latest version found in accessible repos is V4; V10 is `ENVIRONMENT_BLOCKED`. |
| Quant | The financial vertical: deterministic calculation engines (Python research repo; TypeScript Quant Lab on E-INT02). Calculates evidence; does not execute. |
| Impact | The social-impact verification vertical (organizations, claims, evidence, verification dossier). Lab-only on E-INT02. |
| Growth | The content/marketing module family (Improve Post, Personas, Content Library, Calendar, Campaigns, Performance, ROI Tracker). No social-platform connectors. |
| Experiment | A controlled research run (E-QUANT research runs with run ids/hashes). No product-level experiment registry on E-MAIN. |
| Simulation | A non-executing projection: `decision-simulator` (LLM scenario deltas) or AEF `research/backtest/paper` tiers (contract only). Never real-money. |
| Result | Observed outcome recorded by the user (ROI Tracker, Performance) or an AEF receipt outcome. |
| Learning | Feeding results back into intelligence. `NOT_IMPLEMENTED` on E-MAIN (`business_memory` exists but is unread). |
| Module Registry | `kModuleRegistry` in `lib/core/modules/module_registry.dart`: single client metadata source for modules, availability and minimum plan. |
| Quota unit | One reserved AI call counted in `ai_usage` against `profiles.monthly_limit` for the calendar month. |
| Evidence baseline | A repository@ref@SHA used as the source for manual claims (E-MAIN, E-INT02, E-QUANT, E-AGENT, E-SITE). |
| LAB | Code that only runs behind a lab kill switch, local stack or mock tools; never production. |
| Kill switch | Mechanism that keeps LAB code from running in production (e.g. `AEF_RUNTIME_MODE=LAB`, `IveRiveFeatureGate.enabled`). |
| Promotion Gate | E-INT02 policy defining what a module needs to move from EXPERIMENTAL/INTERNAL to commercial. |
| Macro | A named, gated mission (e.g. `INSIGHTVALUES-INTEGRATION-MACRO-02`) executed by an agent under Owner/Architect authority. |
