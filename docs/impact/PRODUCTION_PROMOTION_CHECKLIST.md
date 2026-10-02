# Production Promotion Checklist — Impact I7

**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01  
**Status:** NOT READY FOR PRODUCTION  
**Authority to promote:** Agente Martins + Paulo

## Blockers (must be resolved before any production deployment)

### B1 — DB-backed AefStore not implemented
- `InMemoryAefStore` is used in the Edge Function (non-persistent across invocations)
- Requires: `SupabaseAefStore` in `impact-lab/supabase_store.ts` backed by `impact_aef_*` tables
- Migration is ready (`20261002010000_impact_aef_persistence.sql`) — must be applied to production DB
- Authorization required: explicit mission from Agente Martins + Paulo

### B2 — Gate resolution endpoint missing
- `resolveHumanGate` exists in the kernel but is not exposed via any HTTP endpoint
- A human approver has no way to approve/reject a gate through a production API
- Requires: `impact-lab/gate.ts` or dedicated `impact-gate/index.ts` Edge Function

### B3 — bindingHash not verified against request state (TM-1)
- `resolveHumanGate` validates binding hash format (64 hex chars) but does not verify it against the actual request contents
- A P2 security gap; should be resolved before production consequential actions are live

### B4 — Migration not applied to production
- Per mission constraints: "NO migration apply to production"
- Requires explicit authorization

## Prerequisites (must be present before attempting production)

- [ ] `SupabaseAefStore` implemented and tested with integration tests against Supabase
- [ ] Gate resolution HTTP endpoint implemented and adversarial-reviewed
- [ ] Migration applied to staging, smoke-tested, then applied to production
- [ ] `bindingHash` verification against request state implemented (TM-1)
- [ ] AEF bypass gap (TM-2) addressed: new class C kinds systematically go through IMPACT_ACTION_INTENTS
- [ ] Codex adversarial review of DB-backed AefStore (CLASS D)
- [ ] Agente Martins architectural gate
- [ ] Paulo owner approval

## Ready in Current State (Lab only)

- [x] Trust boundary: CallerContext, service identity, project scope validation
- [x] Egress pinning: purpose taxonomy, host allowlists, safeFetch integration
- [x] AEF kernel: policy evaluation, human gate state machine, receipt hash, idempotency
- [x] AEF wiring: index.ts intercepts class C actions, routes through submitAction
- [x] 4 AEF DB tables with RLS, triggers, immutability constraints (migration validated locally)
- [x] 42 new tests (trust: 12, egress: 15, AEF kernel: 15) — 731/731 total passing
- [x] Observability: 11 new structured log fields
- [x] Documentation: 8 docs covering trust, egress, AEF, threats, promotion checklist

## Deployment Gate Requirements (per CLAUDE.md governance)

Before ANY production action:
1. Codex adversarial review passes with P0/P1 = 0
2. Agente Martins reviews architecture and accepts
3. Paulo gives final approval
4. PR is merged only after all gates pass
5. Migration is applied only after PR is merged and tests pass on staging
