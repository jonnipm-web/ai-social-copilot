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
| Migration | VALIDATED on Postgres 17 local DB (aef_test_i7); 2 migrations applied + 12 DB integration tests PASS |
| Tests | 59 AEF+impact-lab (0 failed); 744 total suite (0 related failures) |
| Production deploy | NOT DEPLOYED — lab only |

## Known Lab Limitations (by design)

- IRREVERSIBLE actions always DENIED in Lab (no real executor available)
- `aef-gate-resolver` as service_id in gate receipts is a placeholder (real gate endpoint not yet implemented)
- Egress registry hosts list is static; production will need version control
- Gate resolution (resolveHumanGate) is not yet atomic — updateHumanGate + insertReceipt are two DB calls; a future `resolve_gate_atomic()` RPC closes this gap (Phase 4, not authorized)
- RPC trusts Edge Function as authorization boundary; no redundant auth.uid() re-check inside the SQL function (architectural decision escalated to Agente Martins + Paulo)

## Next Gates (not authorized by this mission)

1. Gate resolution endpoint (`impact-lab/gate.ts` or `impact-gate/index.ts`)
2. `resolve_gate_atomic()` RPC to make gate resolution atomic (Phase 4)
3. DB-side ownership validation decision (Agente Martins + Paulo architectural gate)
4. End-to-end production AEF path with real Supabase tables
5. Migration applied to staging → production
6. Merge gate after Agente Martins + Paulo review
