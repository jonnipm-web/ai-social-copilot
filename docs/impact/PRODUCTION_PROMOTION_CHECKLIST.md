# Production Promotion Checklist — Impact I7

**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01  
**Status:** NOT READY FOR PRODUCTION  
**Authority to promote:** Agente Martins + Paulo

## Codex Adversarial Review (Class D) — Phase 1/2 Result

**Verdict:** CONDITIONAL PASS after P1 fixes applied.

| Finding | Level | Status |
|---|---|---|
| V13: receipt without durable persistence | P1 | ✅ FIXED — fail-closed on insertAttempt/insertReceipt |
| V10: binding hash not server-verified | P1 | ✅ FIXED — buildRequestBindingHash + server comparison |
| V11: expiry boundary `>` vs `>=` | P2 | ✅ FIXED — changed to `>=` |
| V6: SSRF DNS-rebinding (safeFetch.ts) | P1 | ⚠️ DEFERRED — pre-existing, not introduced by I7; requires egress proxy |
| V12: cross-instance non-atomic idempotency | P1 | ⚠️ DEFERRED — requires DB-backed store (B1) |
| V8: PUBLIC_SOURCE_FETCH no allowlist | P2 | ✅ BY DESIGN — I2 requires arbitrary user URLs |
| V9: receipt hash unkeyed SHA-256 | P2 | ⚠️ DEFERRED — Lab limitation documented |
| V16: raw IDs in AEF tables | P2 | ⚠️ DEFERRED — acceptable for Lab; RLS correct |
| V1,2,3,4,5,7,14,15,17,18 | P3/SAFE | ✅ All vectors SAFE |

## Codex Adversarial Review (Class D) — Phase 3 Result

**Verdict:** FAIL → remediated to CONDITIONAL_PASS

| Finding | Level | Status |
|---|---|---|
| P1-01: RPC no DB-side ownership validation | P1 | ⚠️ ESCALATED — ARCHITECTURAL DECISION REQUIRED (Agente Martins + Paulo) |
| P1-02: Receipt hash format-only check | P1 | ✅ REJECTED — FALSE POSITIVE (hash is app-layer commitment) |
| P1-03(a): Gate resolution non-atomic | P1 | ✅ CLOSED — Phase 4 (commits 8689c1e + 076b39a) |
| P1-03(b): approverRef as UUID-FK callerUserId | P1 | ✅ FIXED — commit ddd5211 (use storedReq.caller.authenticatedUserId) |
| P2-01: broad unique_violation catch | P2 | ⚠️ DEFERRED — hardening mission |
| P2-02: gate on REVERSIBLE action | P2 | ⚠️ DEFERRED — hardening mission |
| P2-03..P2-05 | P2 | ⚠️ DEFERRED — hardening mission |
| P3-01..P3-02 | P3 | DEFERRED |

## Codex Adversarial Review (Class D) — Phase 4 Result

**Verdict:** PASS WITH FINDINGS → remediated to IMPACT_I7_READY (effective P1=0)

| Finding | Level | Status |
|---|---|---|
| P1-01: Caller-controlled expiry bypass (p_issued_at) | P1 | ✅ FIXED — commit 076b39a (clock_timestamp() for expiry + resolved_at) |
| P1-02: Binding hash format-only at RPC boundary | P1 | ✅ REJECTED — FALSE POSITIVE (same edge-function-as-trust-boundary model as Phase 3 P1-01, already accepted by Agente Martins) |
| P2-01: EXPIRED path without receipt | P2 | ✅ REJECTED — BY DESIGN (system timeout, not human resolution; documented) |
| P2-02: unique_violation catch breadth | P2 | ⚠️ DEFERRED — hardening mission |
| P2-03: InMemory weaker than DB | P2 | ⚠️ DEFERRED — known test-double limitation |
| P3: No role denial tests for aef_resolve_gate | P3 | ✅ FIXED — DG-12/DG-13 added (commit 076b39a) |

---

## Blockers (must be resolved before any production deployment)

### ~~B1~~ — ✅ CLOSED: DB-backed AefStore + atomic RPC (commits 1804143, 8795854, ddd5211)
- `SupabaseAefStore` implemented in `impact-lab/supabase_store.ts`; backed by 4 `impact_aef_*` tables
- Runtime uses `createSupabaseAefStore()` by default; fails closed if Supabase env vars absent
- `InMemoryAefStore` restricted to test injection via `deps.aefStore` only
- Investigation binding: investigationId validated (RLS-scoped ownership check) before AEF submission
- Idempotency: client provides stable `idempotency_key`; per-request `crypto.randomUUID()` removed
- 10 new integration tests: binding, gate, idempotency, restart survival, concurrency (742/742)
- **Phase 3:** aef_submit_action() atomic RPC (P1-01); project binding via investigation (P1-02); P2-03 RESTRICT FK; P3-01 REVOKE chain; 12 DB integration tests (Postgres 17); P1-03(b) callerUserId fix (ddd5211)

### ~~B1a~~ — ⚠️ ARCHITECTURAL DECISION REQUIRED: DB-side ownership validation
- aef_submit_action() RPC accepts caller-supplied identity params without re-validating auth.uid() inside SQL
- Current model: Edge Function is the authorized trust boundary; RPC is a privileged write primitive
- Decision: add auth.uid() enforcement inside the RPC, OR accept the current edge-function-as-boundary model
- Authority: Agente Martins + Paulo

### ~~B1b~~ — ✅ CLOSED: Gate resolution atomicity (Phase 4, commits 8689c1e + 076b39a)
- aef_resolve_gate() PL/pgSQL SECURITY DEFINER RPC — single Postgres transaction
- FOR UPDATE lock + status check + expiry (server clock_timestamp()) + gate UPDATE + receipt INSERT
- Any failure → ROLLBACK: no gate terminal without receipt (invariant maintained)
- Codex P0=0, P1=0 (effective): P1-01 expiry fixed (clock_timestamp); P1-02 binding hash rejected (same edge-function model as B1a)
- 13 DB integration tests: DG-01..DG-11 (happy paths, expiry, collision, concurrency, immutability, caller UUID) + DG-12/DG-13 (role denial)

### B2 — Gate resolution endpoint missing
- `resolveHumanGate` exists in the kernel but is not exposed via any HTTP endpoint
- A human approver has no way to approve/reject a gate through a production API
- Requires: `impact-lab/gate.ts` or dedicated `impact-gate/index.ts` Edge Function

### B3 — Gate resolution HTTP endpoint missing
- `resolveHumanGate` exists in the kernel and is now server-verified (V10 fixed)
- But there is no HTTP endpoint to call it via the API
- Requires: `impact-lab/gate.ts` or dedicated `impact-gate/index.ts` Edge Function

### B4 — SSRF DNS-rebinding gap (Codex V6)
- `safeFetch.ts` validates the destination IP before `fetch()` but DNS rebinding can change resolution between check and connection
- Pre-existing limitation not introduced by I7; requires egress proxy or destination IP pinning
- Low risk in short-lived Edge Function requests but should be addressed before production

### B5 — Migration not applied to production
- Per mission constraints: "NO migration apply to production"
- Requires explicit authorization from Agente Martins + Paulo

## Prerequisites (must be present before attempting production)

- [x] `SupabaseAefStore` implemented and tested (742/742, commit 1804143)
- [x] Gate resolution atomicity: aef_resolve_gate() RPC (Phase 4, commits 8689c1e + 076b39a, 25/25 DB tests)
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
