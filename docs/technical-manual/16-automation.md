# 16 — Automation Architecture

Automation score must never mean removing necessary safety gates.

## 1. Automation levels

| Level | Definition | Where it exists today |
|---|---|---|
| L0 Manual | User enters data / changes status | Action Engine status transitions, ROI/Performance metrics, project CRUD |
| L1 Assisted | AI generates content/analysis after explicit confirmation | All 16 AI Edge Functions via `AiExecutionController` confirmation (16 client sites) |
| L2 Deterministic automation | Code computes without an LLM | Ecosystem/project scoring (Dart), quota ledger, Stripe state application, route policy, CI governance scripts; Quant analytics (E-INT02 Lab); Strategy001 state machine (E-QUANT) |
| L3 Agentic recommendation | LLM proposes next steps | Context Copilot `action_suggestion` (display-only on E-MAIN) |
| L4 Governed automation | Proposal → policy → Human Gate → execution → receipt | AEF v0 library (mock tools); E-INT02 LAB runtime |
| L5 Batch automation with confirmation | Several AI calls in one user-approved run | Auto-bootstrap (opportunities + actions + revenue per project; confirmation shows estimated units) |
| L6 Autonomous agent | Agent acts without per-action approval | E-AGENT ADK agent inserts `action_queue` rows — **outside AEF** |
| L7 External execution | Real-world side effects (money, posts, emails, orders) | `NOT_IMPLEMENTED` anywhere |

## 2. Where human approval is intentionally required

| Point | Mechanism | Status |
|---|---|---|
| Any AI call that consumes quota (UI) | Confirmation dialog | `IMPLEMENTED` |
| Auto-bootstrap | Confirmation with estimated units | `IMPLEMENTED` |
| Opportunity → Action | User approval (status) | `IMPLEMENTED` (no gate record) |
| Consequential AEF actions | `REQUIRE_HUMAN_REVIEW` + authorized `HumanGateRecord` | `IMPLEMENTED` (library) |
| Quant live tiers | Hard deny even with approval | `IMPLEMENTED` (policy) |
| Edge Function deploy | `workflow_dispatch` + `confirm=DEPLOY` | `IMPLEMENTED` |
| Migration apply | Manual, outside CI | By design (no automation exists) |
| Rive re-enable | Code change of a compile-time constant on a non-commercial branch | `FROZEN` |

## 3. Automation that deliberately does not exist

Scheduled jobs/cron, background workers, queue consumers, webhooks other than Stripe,
auto-publishing, auto-trading, automated drift detection between git and Supabase.
