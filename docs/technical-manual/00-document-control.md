# 00 — Document Control

| Field | Value |
|---|---|
| Manual | `INSIGHTVALUES-TECHNICAL-MANUAL-v0.1` |
| Status | BASELINE / LIVING DOCUMENT |
| Mission | `INSIGHTVALUES-TECHNICAL-DOCUMENTATION-MACRO-01` |
| Generation date | 2026-09-28 |
| Owner | Paulo Martins |
| Architect | ChatGPT / Agente Martins |
| Documentation executor | Claude Code |
| Documentation branch | `claude/sleepy-noether-ef89my` (repo `jonnipm-web/ai-social-copilot`) |
| Base SHA (this branch) | `ff8ef3461293697fe175cb1b0849e87d12d71c44` (= `origin/main`) |
| Write scope | `docs/technical-manual/**` only |
| Product code changed | NO |

## 1. Evidence baselines

Every claim in this manual is tied to one of the evidence baselines below. When a chapter
does not name a baseline, the default is **E-MAIN**.

| ID | Repository | Ref | SHA | Last commit date | Role |
|---|---|---|---|---|---|
| **E-MAIN** | `jonnipm-web/ai-social-copilot` | `main` | `ff8ef34` | 2026-09-18 (merge of PR #102, AEF v0) | Canonical, merged product code. The only baseline that the production deploy workflows build from. |
| **E-INT02** | `jonnipm-web/ai-social-copilot` | `claude/insightvalues-integration-macro-02` | `d841ebf` | 2026-09-27 | Unmerged integration of four lines (Commercial Macro-01, AEF Module Lab, Impact Lab, Quant Lab). Read via `git show`/`git grep` only. |
| **E-QUANT** | `jonnipm-web/insightvalues-quant` | `codex/quant-robust-strategy-research` (+14 other branches) | `ff6518b` | 2026-08-19 | Python research framework: Strategy001, Fibonacci, historical backtest. `main` is an empty initial commit (`73d7ec0`). |
| **E-AGENT** | `jonnipm-web/insightvalues-ive-agent` | `main` | `7f7f46f` | 2026-08-29 | Hackathon agent (Google ADK + Gemini, Cloud Run). |
| **E-SITE** | `jonnipm-web/insightvalues-site` | `main` | `567009a` | 2026-08-21 | Content/SEO planning repo for a hosted WordPress site. Not an application. |
| **E-DOC** | any of the above | — | — | — | Markdown reports/ADRs inside those repos. Treated as `HISTORICAL_EVIDENCE_ONLY` unless re-verified against code. |

Other refs used as secondary evidence (read-only, fetched locally, never checked out):
`claude/insightvalues-quant-foundation@f473597`, `claude/insightvalues-impact-foundation@b52d383`,
`claude/insightvalues-module-architecture@5bc767a`, `claude/commercial-macro-01@e399bcd`.

## 2. Known evidence gaps

| Gap | Label | Consequence |
|---|---|---|
| Macro-09 "InsightValues Financial RC" workspace (Robot Builder, Strategy Specification, Validation Engine, Strategy Lab, dataset/engine registries, Paulo Trend Fibonacci **V10**) | `ENVIRONMENT_BLOCKED` | Not present in any branch of the four accessible repositories (searched: "robot builder", "strategy lab", "V10", "holdout", "contamination", "macro-09"). Chapter [07](07-financial-intelligence.md) documents those components as owner-described only. |
| Live Supabase production state (applied migrations, deployed function versions) | `UNKNOWN` | No production read was performed by this mission. Deployment status comes from in-repo reports (`HISTORICAL_EVIDENCE_ONLY`). |
| Test execution | `ENVIRONMENT_BLOCKED` (not attempted) | Test counts in this manual are **static counts** of test declarations, not pass results, unless stated otherwise. |
| Codex independent audit of this manual | Not performed (per mission §47) | — |

## 3. Status taxonomy (canonical)

Maturity / verification labels:

| Label | Meaning |
|---|---|
| `VERIFIED` | Claim re-checked directly against code or config at the baseline SHA during this mission. |
| `IMPLEMENTED` | Source exists at the baseline. Says nothing about deploy or runtime. |
| `TESTED` | Automated tests exist that target the component. Does not imply they were run by this mission. |
| `DEPLOYED` | Evidence of a deploy exists (workflow + report). Never inferred from source existence. |
| `FUNCTIONAL` | Evidence that the component works end-to-end in some environment. |
| `EXPERIMENTAL` | Built, deliberately not commercial, usually admin-only. |
| `LAB` | Runs only behind a lab kill switch / local stack / mock tools. |
| `FROZEN` | Deliberately stopped by an owner decision; re-opening needs explicit authorization. |
| `PLANNED` | Designed or named; no implementation at the baseline. |
| `DEPRECATED` | Kept for history/compatibility, must not be extended. |
| `NOT_IMPLEMENTED` | Confirmed absent after search. |
| `ENVIRONMENT_BLOCKED` | Could not be verified in this environment. |
| `UNKNOWN` | No evidence either way. |

Evidence-quality labels: `CONFLICTING_EVIDENCE`, `HISTORICAL_EVIDENCE_ONLY`.

Generation labels (chapter [26](26-legacy-deprecation-register.md)): `CURRENT`, `LEGACY`, `ABSORBED`,
`SUPERSEDED`, `FROZEN`, `RECOVERED`, `PLANNED`.

Forbidden promotions: `IMPLEMENTED` → `DEPLOYED`, `TESTED` → production-ready, `PLANNED` → `IMPLEMENTED`.
The token "production-ready" is intentionally not a status in this manual.

## 4. Review and update rules

- See [30 — Change Log](30-change-log.md) for versions.
- See [README](README.md#documentation-drift-policy) for the drift policy future macros must follow.
- Run `python3 docs/technical-manual/tools/validate_manual.py` before committing manual changes.
