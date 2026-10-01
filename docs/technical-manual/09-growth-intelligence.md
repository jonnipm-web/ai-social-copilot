# 09 — Growth / Social Intelligence

"AI Social Copilot" is the product's origin (see the legacy `README.md`: a post-improvement
app). "Growth Intelligence" is the current name for the content/marketing family.

## 1. Implemented vs designed vs planned

| Capability | E-MAIN | E-INT02 | Classification |
|---|---|---|---|
| Improve Post (EF `improve-post`, `post_generations`) | `IMPLEMENTED`, `commercialEnabled: false` | Commercial at Pro | implemented |
| Personas / Brands + Persona Training (`personas`, `persona_training`) | `IMPLEMENTED`, `minimumPlan: pro` but `commercialEnabled: false` → hidden and route-denied for every non-admin (Pro included) | Commercial at Pro | implemented |
| Content Library (`content_items`) | `IMPLEMENTED`, `commercialEnabled: false` (route-denied for non-admins) | Commercial at Pro | implemented |
| Editorial Calendar (`calendar_items`, `campaign_calendar`) | `IMPLEMENTED`, `commercialEnabled: false` (route-denied for non-admins); `campaign_calendar` has no UPDATE policy and is unused by the app (baseline comment) | Commercial at Pro | implemented (scheduling = internal planning only) |
| Campaigns (EF `generate-campaign`, `campaigns`) | `IMPLEMENTED`, not commercial | Commercial at Pro | implemented |
| Performance (manual metrics, platform names as enum strings) | `IMPLEMENTED`, not commercial | Commercial at Pro | implemented (no connectors) |
| ROI Tracker | `IMPLEMENTED`, not commercial | Commercial at Pro | implemented |
| Content clusters / distribution planning (Market Intelligence sub-module) | `IMPLEMENTED` | — | implemented (LLM planning) |
| Approval workflow for content | none beyond draft/status fields | — | `NOT_IMPLEMENTED` |
| Social network integrations (OAuth to Instagram/LinkedIn/Facebook/X/TikTok/YouTube) | none — channel names appear only as strings/colours/icons (`campaign_builder_screen.dart`, `performance_metrics.dart`, `calendar_item.dart`) | none | `NOT_IMPLEMENTED` |
| Scheduling / auto-publishing | none | none | `NOT_IMPLEMENTED` |
| MCP / tool concepts for social | none in code | none | `PLANNED` (concept only) |
| AEF governance of publishing | none | none | `PLANNED` — publishing would be `CONSEQUENTIAL` (public, irreversible) |

`VERIFIED` by grep on E-MAIN `lib/` for `instagram|linkedin|facebook|twitter|tiktok|youtube|graph.facebook|api.linkedin`:
only UI labels and enums, zero API calls.

## 2. Growth vs Social Copilot (generation reconciliation)

| Generation | Scope | Status |
|---|---|---|
| AI Social Copilot (2026-08, legacy `README.md`) | Single post improvement via Anthropic Claude EF | `SUPERSEDED` — the EF now calls Groq; README is stale |
| Growth Intelligence (Commercial Macro-01) | 7-module Pro family | E-MAIN not commercial; E-INT02 commercial at Pro |
| Social Intelligence & Distribution (V1 in `MODULE_PORTFOLIO.md`) | Connectors, posting, analytics | `PLANNED` (Premium future) |

## 3. Access rule on E-MAIN (verified)

`lib/core/modules/route_policy.dart` `decideForModule`: admin → allow; `commercialEnabled == false`
→ `redirectDenied` **before** any plan check. Therefore every Growth module on E-MAIN is reachable
only by admins, regardless of Pro status. The server does not enforce this (see [15](15-monetization.md)).
