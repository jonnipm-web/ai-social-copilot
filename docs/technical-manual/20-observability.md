# 20 — Observability

| Signal | Implementation | Scope | Status |
|---|---|---|---|
| Diagnostic sessions / events | `lib/core/diagnostics/*`, tables `diagnostic_sessions`, `diagnostic_events`; admin-started START/STOP sessions; categories incl. navigation, quota, AI; crash capture via `runZonedGuarded` | Admin-only, opt-in | `IMPLEMENTED`, `TESTED` |
| Build identity | `BUILD_SHA` baked via `--dart-define` in `deploy-web.yml`; `diagnostic_events.build_sha` column | Web builds | `IMPLEMENTED` |
| Crash symbolication | Source maps encrypted as 90-day artifacts; `tool/stability09o/symbolicate.mjs` | Web | `IMPLEMENTED` |
| IVE forensic snapshot | `lib/core/diagnostics/ive_forensic_snapshot.dart` (settled route, lifecycle, null-child flag) | Client | `IMPLEMENTED`, `TESTED` (17) |
| Sanitization | Allowlisted metadata + secret-fragment denylist (`diagnostic_sanitizer.dart`) | Client | `IMPLEMENTED`, `TESTED` (41) |
| Quota audit | Structured `console.log` JSON events (`quota_reservation_created/reused`, `quota_exceeded`, `quota_refund_*`) — ids/enums only | Edge Function logs (Supabase retention) | `IMPLEMENTED` |
| Stripe events | `processed_webhook_events` | DB | `IMPLEMENTED` |
| Execution receipts / audit trail | AEF v0 receipts in memory only; persisted receipts + audit on E-INT02 (`LAB`) | — | E-MAIN: `NOT_IMPLEMENTED` durable |
| Provenance | `sources[]`, `confidence`, correlation ids on IVE requests | Partial | `IMPLEMENTED` (weak) |
| Intelligence Debug | Admin screen with score breakdowns / validation report | Admin | `IMPLEMENTED` |
| Compute / token metrics | Not collected (no token counts, latency, error rate per function) | — | `NOT_IMPLEMENTED` |
| Product analytics | None | — | `NOT_IMPLEMENTED` |
| Error reporting service (Sentry etc.) | None | — | `NOT_IMPLEMENTED` |
| Deployment drift detection | None; manual `list_edge_functions` comparisons only | — | `NOT_IMPLEMENTED` (proposed in `docs/ive/OUT_OF_BAND_DEPLOYMENT_THREAT_MODEL.md` §6) |

Gaps: no cost telemetry for Groq, no alerting, no uptime checks, no durable audit of admin role
changes (role writes go straight to `profiles`), no link between a deployed function version and a
git SHA. No new observability was built by this mission.
