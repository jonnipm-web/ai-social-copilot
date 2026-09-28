# 21 — External Integrations

Credentials are never reproduced here; only variable/secret **names**.

| Integration | Used by | Credential names | State | Evidence |
|---|---|---|---|---|
| Supabase (Auth, Postgres, Edge Runtime) | Everything | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ACCESS_TOKEN` (CI) | `CURRENT` | E-MAIN |
| Groq (OpenAI-compatible API), model `openai/gpt-oss-120b` | 16 AI Edge Functions | `GROQ_API_KEY` | `CURRENT` (commercial LLM) | E-MAIN grep |
| Groq `llama-3.3-70b-versatile` | earlier model | same | `SUPERSEDED` (recorded 2026-08-13 in `docs/showcase/SHOW_00_CAPABILITY_GAP_MATRIX.md` §20) | E-DOC |
| Anthropic Claude | original `improve-post` per legacy `README.md` | `ANTHROPIC_API_KEY` (legacy README) | `SUPERSEDED` — no Anthropic call in code | E-MAIN grep |
| Google Sign-In (OAuth, identity scopes) | Login | `GOOGLE_CLIENT_ID` | `CURRENT` | `auth_service.dart` |
| Google Drive API (`drive.readonly`) | Knowledge import | Google OAuth token (user) | `CURRENT`; scope overbroad | `drive_service.dart` |
| Firebase config (`android/app/google-services.json`) | Android Google Sign-In | config file committed | `CURRENT` | E-MAIN |
| Stripe (Checkout, Subscriptions, webhooks) | Billing | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID_PRO` | `IMPLEMENTED`, TEST mode; live `UNKNOWN` | E-MAIN |
| GitHub Pages | Web hosting | `GITHUB_TOKEN` | `CURRENT` | `deploy-web.yml` |
| Public web (URL fetch) | `analyze-website`, `extract-knowledge` via `safeFetch` | none | `CURRENT` | E-MAIN |
| Rive | Avatar runtime | none | `FROZEN` | `IVE_RIVE_FREEZE_RECORD.md` |
| Google ADK + Gemini (`gemini-3.5-flash`), FastAPI, Cloud Run | Hackathon "IVE Strategic Execution Agent" | see E-AGENT `.env.example` | `EXPERIMENTAL`; hackathon-only (All Things Agentic 2026); runtime `UNKNOWN` | E-AGENT `ive_agent/agent.py:76`, README |
| Registry providers (Companies House, Charity Commission, IRS EO BMF) | Impact Lab | none composed | `LAB` adapters, not live | E-INT02 |
| Market-data vendors | Quant Lab | none | `NOT_IMPLEMENTED` (licensing dossier, no winner) | E-INT02 |
| Broker | — | — | `NOT_IMPLEMENTED` | all baselines |
| Social platforms (Instagram, LinkedIn, Facebook, X, TikTok, YouTube) | — | — | `NOT_IMPLEMENTED` | E-MAIN grep |
| MCP | Used by engineering agents (Supabase MCP deploy path documented as out-of-band) — not a product integration | — | Operational only | `OUT_OF_BAND_DEPLOYMENT_THREAT_MODEL.md` |
| WordPress / AdSense (insightvalues.com) | Marketing site | hosting panel | Separate property | E-SITE |

Groq (commercial) vs Gemini (hackathon) is a deliberate split: no Gemini call exists in the
product repository; the product LLM path is Groq only (see ADR-004 in [25](25-architecture-decisions.md)).
