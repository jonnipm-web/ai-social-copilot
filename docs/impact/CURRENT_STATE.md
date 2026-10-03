# Impact Module — Current State

**As of:** 2026-10-03  
**Branch:** `claude/iv-impact-i7-trust-egress-aef-01`  
**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01

## Component Matrix

| Component | I1 | I2 | I3 | I4 | I5 | I6 | I7 |
|---|---|---|---|---|---|---|---|
| Persistence + RLS | ✅ | — | — | — | — | — | ✅ AEF tables |
| Evidence ingestion | — | ✅ | — | — | — | — | — |
| File artifacts | — | — | ✅ | — | — | — | — |
| Dossier + chain-of-custody | — | — | — | ✅ | — | — | — |
| Rate limiting | — | — | — | — | ✅ | — | — |
| Conflict resolution | — | — | — | — | — | ✅ | — |
| Trust boundary | — | — | — | — | — | — | ✅ |
| Egress pinning | — | — | — | — | — | — | ✅ |
| AEF kernel | — | — | — | — | — | — | ✅ |
| AEF wiring | — | — | — | — | — | — | ✅ |
| AEF atomic RPC | — | — | — | — | — | — | ✅ |
| AEF gate resolution atomic | — | — | — | — | — | — | ✅ |

## Classification

| Dimension | Status |
|---|---|
| Lab readiness | ADVANCED FUNCTIONAL (I1–I6) → PRODUCTION-ARCHITECTURE-READY (I7) |
| Auth boundary | EXPLICIT — CallerContext from JWT only |
| Egress | PINNED — EgressPurpose taxonomy enforced |
| Consequential actions | AEF-gated — submitAction before any class C execution |
| Audit trail | DURABLE — append-only receipts, immutable triggers |
| Human gate | IMPLEMENTED — PENDING→terminal, 24h TTL, binding hash |
| Idempotency | ENFORCED — DB UNIQUE via aef_submit_action() RPC (single transaction) |
| Privacy | NO PII in AEF tables — opaque IDs only |
| Migration | VALIDATED on Postgres 17 local DB (aef_test_i7); 3 migrations applied + 25 DB integration tests PASS |
| Tests | 47 AEF unit + 25 DB integration (0 failed); 744+ total suite |
| Production deploy | NOT DEPLOYED — lab only |

## Known Lab Limitations (by design)

- IRREVERSIBLE actions always DENIED in Lab (no real executor available)
- `aef-gate-resolver` as service_id in gate receipts is a placeholder (real gate endpoint not yet implemented)
- Egress registry hosts list is static; production will need version control
- RPC trusts Edge Function as authorization boundary; no redundant auth.uid() re-check inside the SQL function (accepted for lab; production-hardening requirement)
- Gate resolution (resolveHumanGate) is atomic via aef_resolve_gate() RPC (Phase 4, commit 8689c1e)

## Next Gates (not authorized by this mission)

1. Gate resolution endpoint (`impact-lab/gate.ts` or `impact-gate/index.ts`)
2. DB-side ownership validation decision (Agente Martins + Paulo architectural gate)
3. End-to-end production AEF path with real Supabase tables
4. Migration applied to staging → production
5. Merge gate after Agente Martins + Paulo review
