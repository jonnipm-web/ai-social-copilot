# InsightValues — Technical & Architecture Manual

`INSIGHTVALUES-TECHNICAL-MANUAL-v0.1` · BASELINE / LIVING DOCUMENT · generated 2026-09-28

This is the canonical, evidence-based technical reference for the InsightValues ecosystem.
It reconstructs what **exists today** from source code, tests, migrations, CI and in-repo
reports. It is not a product brochure, a roadmap, or a user manual.

**Read first:** [00 — Document Control](00-document-control.md) defines the evidence baselines
(E-MAIN, E-INT02, E-QUANT, E-AGENT, E-SITE) and the status vocabulary used everywhere below.

## One-paragraph summary

InsightValues today is a **Flutter (Android + Web) client on Supabase** (Postgres + RLS, Auth,
20 Deno Edge Functions) whose AI features call **Groq** (`openai/gpt-oss-120b`) server-side
behind a real authentication gate and an atomic monthly quota. The merged product (`main`)
covers Projects, Knowledge Vault, Market Intelligence, Opportunity Lab, Action Engine,
the IVE assistant (Context Copilot + fallback avatar), Stripe billing in TEST mode, and
diagnostics. **AEF** exists on `main` only as a contract + in-memory kernel with mock tools
(no runtime caller). Quant, Impact, AEF persistence/runtime and server-side entitlements
exist **only on unmerged branches** as `LAB`/`EXPERIMENTAL` code. The Python
**insightvalues-quant** repository holds the Strategy001 / Paulo Trend Fibonacci research
engine (V2–V4, research status negative/unverified). There is **no broker, no live trading,
no social-network posting, and no production AEF** anywhere in the accessible evidence.

## Chapters

| # | Chapter | Scope |
|---|---|---|
| 00 | [Document Control](00-document-control.md) | Version, baselines, taxonomy, gaps |
| 01 | [Executive Technical Overview](01-executive-technical-overview.md) | What exists, at what maturity |
| 02 | [Ecosystem Architecture](02-ecosystem-architecture.md) | Repositories, lines, families, diagram |
| 03 | [Core Commercial Flow](03-core-commercial-flow.md) | PROJECT → … → LEARNING, stage by stage |
| 04 | [IVE](04-ive.md) | Context assembly, grounding, memory, boundaries |
| 05 | [AEF](05-aef.md) | Contracts, kernel, Human Gate, tools, receipts |
| 06 | [Projects + Knowledge](06-projects-knowledge.md) | Primitives, isolation, ingestion |
| 07 | [Financial Intelligence](07-financial-intelligence.md) | Quant Lab, Strategy001, V-series research |
| 08 | [Impact Intelligence](08-impact-intelligence.md) | Claims/evidence/dossier (Lab) |
| 09 | [Growth / Social Intelligence](09-growth-intelligence.md) | Content, campaigns, social (absent) |
| 10 | [Data Architecture](10-data-architecture.md) | Entities by domain, ownership, lifecycle |
| 11 | [Supabase](11-supabase.md) | Auth, RLS, RPCs, SECURITY DEFINER, migrations |
| 12 | [Edge Functions](12-edge-functions.md) | Inventory of all 20 functions |
| 13 | [Client Architecture](13-client-architecture.md) | Riverpod, GoRouter, registry, i18n |
| 14 | [Security](14-security.md) | Security architecture and residual risks |
| 15 | [Monetization](15-monetization.md) | Plans, quotas, billing, activation |
| 16 | [Automation](16-automation.md) | Automation levels and human gates |
| 17 | [Testing](17-testing.md) | Test systems and counts (DATE/SHA/SCOPE) |
| 18 | [CI/CD](18-ci-cd.md) | Workflows, gates, secrets (names only) |
| 19 | [Environments + Deployment](19-environments-deployment.md) | Environments, deploy paths, rollback |
| 20 | [Observability](20-observability.md) | Logs, receipts, diagnostics, gaps |
| 21 | [Integrations](21-integrations.md) | External services, current vs historical |
| 22 | [Mobile / Web](22-mobile-web.md) | Android, Web, differences |
| 23 | [Module Maturity Matrix](23-module-maturity-matrix.md) | Canonical per-module status |
| 24 | [Documented × Verified Matrix](24-verification-matrix.md) | Anti-drift matrix |
| 25 | [Architecture Decisions](25-architecture-decisions.md) | Recovered ADRs |
| 26 | [Legacy / Deprecation Register](26-legacy-deprecation-register.md) | What not to resurrect |
| 27 | [Risk Register](27-risk-register.md) | Technical risks with evidence |
| 28 | [Glossary](28-glossary.md) | Canonical terms |
| 29 | [Source Evidence Index](29-source-evidence-index.md) | Claim → evidence map |
| 30 | [Change Log](30-change-log.md) | Manual versions |

Tooling: [`tools/validate_manual.py`](tools/validate_manual.py) — documentation-only checks
(chapters, links, Mermaid, glossary duplicates, status vocabulary, repo paths, secret patterns).

## Future documentation tracks

1. **Technical & Architecture Manual** — this document.
2. Operations / Deployment Runbook — not started (inputs: chapters 18, 19, 20).
3. Product / User Manual — not started (inputs: chapters 03, 15, 23).

## Documentation drift policy

Any future macro that **materially** changes one of the following must list the affected
chapters in its final report and update them (or explicitly record "manual not updated"
in [30 — Change Log](30-change-log.md)):

| Change type | Chapters to review |
|---|---|
| Architecture / new module / module removal | 01, 02, 23, 24, 26 |
| Module maturity, lifecycle or `commercialEnabled` | 23, 24, 15 |
| Security boundary (auth, RLS, JWT policy, SECURITY DEFINER, kill switch) | 11, 14, 27 |
| Database (migration added/applied/reverted) | 10, 11, 19, 24 |
| API (Edge Function added/removed/contract change) | 12, 24 |
| Entitlement / plan / quota / billing | 15, 13, 23 |
| Deployment (function deployed, migration applied, workflow changed) | 18, 19, 24 |
| Integration (new provider, key, OAuth scope) | 21, 14, 27 |
| Merge of an unmerged line (E-INT02, Quant, Impact, AEF) into `main` | all chapters that cite E-INT02 |

Trivial implementation changes (refactors, copy, styling, test additions that do not change
a status) do **not** require manual updates. When a line is merged, re-verify every row of
[24](24-verification-matrix.md) whose evidence is E-INT02 and update `LAST VERIFIED SHA`.
