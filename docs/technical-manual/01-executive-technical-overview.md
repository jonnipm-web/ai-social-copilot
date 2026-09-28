# 01 — Executive Technical Overview

## 1. What InsightValues is, technically

A multi-generation product that started as an "AI Social Copilot" (post improver) and grew
into a project-centric business-intelligence platform with an assistant persona (**IVE**)
and a governed-execution layer under construction (**AEF**). Domain verticals (Quant,
Impact) are being built in isolated lab branches and one separate Python repository.

| Layer | Technology | Status (E-MAIN) | Evidence |
|---|---|---|---|
| Client | Flutter (Dart ≥ 3.3), Riverpod, GoRouter, Material, gen-l10n (PT/EN) | `IMPLEMENTED`, `DEPLOYED` (Web via GitHub Pages workflow) | `pubspec.yaml`, `lib/app.dart`, `.github/workflows/deploy-web.yml` |
| Backend | Supabase: Postgres + RLS, GoTrue Auth, Deno Edge Functions | `IMPLEMENTED` | `supabase/migrations/`, `supabase/functions/` |
| AI provider (commercial) | Groq Chat Completions, model `openai/gpt-oss-120b`, key server-side only | `VERIFIED` (source) | 16 functions reference `api.groq.com` |
| Billing | Stripe Checkout + webhook, TEST mode | `IMPLEMENTED`; production activation `UNKNOWN` | `supabase/functions/create-checkout-session/`, `stripe-webhook/` |
| Governed execution | AEF v0 contracts + in-memory kernel, mock tools only | `IMPLEMENTED`, `TESTED`, **not wired** | `aef/`, `contracts/aef/` |
| Financial research | Python `insightvalues_quant` (Strategy001, Fibonacci, historical backtest) | `IMPLEMENTED` on branches of E-QUANT, not integrated | E-QUANT |
| Hackathon agent | Python, Google ADK, Gemini, Cloud Run | `IMPLEMENTED` in E-AGENT; current runtime `UNKNOWN` | E-AGENT `ive_agent/agent.py` |

## 2. Maturity at a glance

| Area | Where | Maturity |
|---|---|---|
| Auth, Projects, Knowledge Vault, Market Intelligence, Opportunity Lab, Action Engine, Context Copilot, quota | E-MAIN | `IMPLEMENTED`, largely `TESTED`; commercial V1 per module registry |
| Growth modules (Improve Post, Personas, Content Library, Calendar, Campaigns, Performance, ROI) | E-MAIN | `IMPLEMENTED`, `commercialEnabled: false` on main; launched at Pro on E-INT02 (unmerged) |
| Executive layer (Executive Dashboard, Decision Center, Resource Allocation, Weekly Briefing) | E-MAIN | `IMPLEMENTED`, registry status beta, not commercial |
| IVE avatar | E-MAIN | Rive runtime `FROZEN`; deterministic fallback is the commercial avatar |
| AEF v0 | E-MAIN | `IMPLEMENTED`, `TESTED`, `LAB`-grade library, zero runtime callers |
| AEF persistence + IVE→AEF runtime | E-INT02 | `LAB`, not applied, not deployed |
| Server-side module entitlements (`module-access`, `entitlement.ts`) | E-INT02 | `IMPLEMENTED` on branch only |
| Quant Lab (TypeScript analytics, watchlists) | E-INT02 | `EXPERIMENTAL` (admin-only), not deployed, no data vendor |
| Impact Lab (claims/evidence/dossier) | E-INT02 | `EXPERIMENTAL` (admin-only), not deployed |
| Strategy001 / Paulo Trend Fibonacci V2–V4 | E-QUANT | `IMPLEMENTED` research code; research result negative / not verifiable |
| Robot Builder, Strategy Lab, Validation Engine, V10 | Macro-09 workspace | `ENVIRONMENT_BLOCKED` |
| Social network connectors / scheduling / posting | nowhere | `NOT_IMPLEMENTED` |
| Broker / live trading | nowhere | `NOT_IMPLEMENTED` (and hard-denied by AEF policy) |

## 3. Five facts a new engineer must know

1. **Merge ≠ deploy.** Edge Functions deploy only via a manual, single-function workflow with
   an allowlist; migrations have no CI deploy path at all. See [18](18-ci-cd.md), [19](19-environments-deployment.md).
2. **`main` is behind.** The richest architecture (AEF persistence, Quant, Impact, server
   entitlements) lives on `claude/insightvalues-integration-macro-02`, unmerged. Do not
   document it as current product. See [02](02-ecosystem-architecture.md).
3. **IVE proposes, never executes.** On E-MAIN, IVE's `action_suggestion` is a display-only
   chip; no code path lets IVE write data or call a tool. See [04](04-ive.md).
4. **Plan gating is client-side on `main`.** The server enforces authentication and a monthly
   AI quota; it does not enforce which *module* a plan may use. See [15](15-monetization.md), [27](27-risk-register.md) R-SEC-03.
5. **Evidence discipline.** Many in-repo reports say "NOT APPLIED" / "NOT DEPLOYED" at the
   time they were written. Their later status is `UNKNOWN` unless a newer report or live
   check says otherwise. See [24](24-verification-matrix.md).

## 4. Three-pillar snapshot

| Pillar | Assessment | Why |
|---|---|---|
| Automation | Medium | Strong CI gates and deterministic governance tooling; AI features automated with confirmation; no governed execution in production yet. |
| Monetization | Medium-low | Quota + Stripe TEST path exist; module entitlements not server-enforced on `main`; no live billing evidence; Growth/Financial not commercial on `main`. |
| Execution security | Medium-high | Fail-closed auth helper on every AI function, RLS on all 45 tables, anti-self-promotion trigger, SSRF guard, deploy governance; residual risks listed in [27](27-risk-register.md). |
