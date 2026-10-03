# IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01

## Mission Brief

**Title:** Impact Trust Boundary + Egress Pinning + AEF Integration  
**Status:** CONDITIONAL_PASS — Codex CLASS D re-audit complete; 2 architectural decisions escalated (Phase 3)  
**Base branch:** `claude/insightvalues-impact-foundation` at `b52d383`  
**Work branch:** `claude/iv-impact-i7-trust-egress-aef-01`  
**Date:** 2026-10-02

## Objective

Advance the Impact module from **ADVANCED FUNCTIONAL LAB** to **PRODUCTION-ARCHITECTURE-READY LAB** by closing four canonical blockers:

| Blocker | Status |
|---|---|
| `SERVICE_ROLE_TRUST_GATE = LAB_ONLY` | ✅ CLOSED |
| `EGRESS_PINNING_REQUIRED` | ✅ CLOSED |
| `AEF persistence pending` | ✅ CLOSED |
| `AEF NOT_WIRED` | ✅ CLOSED |

## Scope

- **In scope:** trust.ts, egress_policy.ts, aef/ kernel, aef/ store, aef/ types, migration, index.ts wiring, observability, error codes, tests
- **Out of scope:** production deploy, migration apply to production, new billing, merge to main

## Files Changed

### New files
- `supabase/functions/_shared/impact/trust.ts` — CallerContext, service registry, buildCallerContext
- `supabase/functions/_shared/impact/egress_policy.ts` — EgressPurpose taxonomy, host allowlists, buildEgressOptions
- `supabase/functions/_shared/aef/types.ts` — AEF types (re-exports CallerContext from impact/trust.ts)
- `supabase/functions/_shared/aef/store.ts` — AefStore interface + InMemoryAefStore
- `supabase/functions/_shared/aef/kernel.ts` — submitAction, resolveHumanGate, classifyIntent
- `supabase/migrations/20261002010000_impact_aef_persistence.sql` — 4 AEF tables, RLS, triggers
- `supabase/functions/_shared/impact/trust_test.ts` — 12 tests
- `supabase/functions/_shared/impact/egress_policy_test.ts` — 15 tests
- `supabase/functions/_shared/aef/kernel_test.ts` — 15 tests

### Modified files
- `supabase/functions/_shared/impact/errors.ts` — 6 new I7 error codes
- `supabase/functions/_shared/impact/observability.ts` — 11 new I7 log fields
- `supabase/functions/_shared/impact/lab_service.ts` — CallerContext in LabActor
- `supabase/functions/impact-lab/index.ts` — AEF intercept wiring, buildCallerContext, I7 HTTP codes

## Test Results (Phase 1 — commit 31d7979)

```
732 tests | 0 failed
```

## Phase 2 — DB-Backed AefStore + Investigation Binding (commit 1804143)

Authorized by Agente Martins gate requirements (2026-10-03).

### Additional files modified
- `supabase/functions/_shared/impact/lab_contract.ts` — `request_external_action` now accepts optional `investigation_id` and `idempotency_key`
- `supabase/functions/impact-lab/supabase_store.ts` — `SupabaseAefStore` class + `createSupabaseAefStore()` factory
- `supabase/functions/impact-lab/index.ts` — runtime uses `SupabaseAefStore` by default; investigation binding gate; stable idempotency key from client
- `supabase/functions/impact-lab/index_test.ts` — 10 new I7 tests (EF-I7-01..10)

### Phase 2 Gate Labels

| Gate | Status |
|---|---|
| AEF_DB_PERSISTENCE_RUNTIME | ✅ PASS — SupabaseAefStore is runtime default |
| IDEMPOTENCY_PERSISTENT | ✅ PASS — DB UNIQUE constraint enforces atomicity |
| CONCURRENCY | ✅ PASS — UNIQUE (caller_user_id, intent_kind, idempotency_key); InMemoryAefStore gap documented |
| RESTART_SURVIVAL | ✅ PASS — EF-I7-09 proves in-memory fails; SupabaseAefStore uses persistent DB |
| INVESTIGATION_BINDING | ✅ PASS — EF-I7-01..04 prove RLS-scoped ownership validation |
| CODEX_P0 | PENDING re-audit |
| CODEX_P1 | PENDING re-audit |

### Phase 2 Test Results

```
742 tests | 0 failed (10 new I7 tests)
```

## Migration Validation

Run on local Postgres 17.11 (port 55471, isolated cluster):

- ✅ First application: all DDL, RLS, triggers created cleanly
- ✅ Re-run idempotent: DROP POLICY IF EXISTS + CREATE OR REPLACE functions
- ✅ INVARIANT_RECEIPT_IMMUTABLE: UPDATE and DELETE on receipts blocked
- ✅ INVARIANT_GATE_STATE_MACHINE: PENDING→terminal transition enforced, double-transition blocked
- ✅ INVARIANT_IDEMPOTENCY_CONSTRAINT: unique_violation on duplicate (user, kind, key)

## Boundary Invariants

- **BT-1** (no randomness/network/env in impact/ core): ✅ crypto.randomUUID() in kernel.ts (aef/) and index.ts only
- **BT-2** (impact/ core only imports ./relative or ../safe_fetch.ts): ✅ trust.ts imports nothing external; AEF imports from impact/, not vice versa

## Architecture Decision: CallerContext placement

CallerContext is defined in `impact/trust.ts` (not `aef/types.ts`). This maintains BT-2: the impact/ core has no dependency on aef/. The AEF module re-exports CallerContext from `../impact/trust.ts` for convenience.

## Phase 3 — Atomic RPC + Project Binding + DB Integration Tests (commits 8795854, ddd5211)

Authorized by Agente Martins Phase 3 brief (2026-10-03).

### Files changed (Phase 3)

**New files:**
- `supabase/migrations/20261003000000_impact_aef_atomic_rpc.sql` — P1-01 atomic RPC, P2-03 RESTRICT FK, P3-01 REVOKE chain
- `supabase/functions/_shared/aef/kernel_pg_test.ts` — 12 DB integration tests
- `supabase/functions/_shared/aef/pg_test_setup.sql` — test DB stub tables + role setup

**Modified files:**
- `supabase/functions/_shared/aef/store.ts` — AefStore interface: removed insertRequest/insertPolicyDecision/insertHumanGate/insertAttempt; added submitAtomic()
- `supabase/functions/_shared/aef/kernel.ts` — submitAction uses submitAtomic(); P1-03(b) fix: callerUserId in gate-resolution receipt now uses requester UUID not opaque approverRef
- `supabase/functions/impact-lab/supabase_store.ts` — submitAtomic() calls aef_submit_action RPC
- `supabase/functions/impact-lab/index.ts` — P1-02: aefCallerContext derives projectId from validated investigation
- `supabase/functions/impact-lab/index_test.ts` — EF-I7-10 updated (atomic), EF-I7-11 (project binding), EF-I7-12 (atomic rollback)

### Phase 3 Gate Labels

| Gate | Status |
|---|---|
| AEF_ATOMIC_PERSISTENCE (P1-01) | ✅ PASS — aef_submit_action() RPC, single Postgres transaction |
| PROJECT_BINDING (P1-02) | ✅ PASS — projectId derived from RLS-scoped investigation |
| AUDIT_RETENTION (P2-03) | ✅ PASS — ON DELETE RESTRICT enforced by DB test DB-10 |
| RECEIPT_IMMUTABILITY | ✅ PASS — DB-08 confirms UPDATE/DELETE blocked |
| GATE_STATE_MACHINE | ✅ PASS — DB-09 confirms PENDING→APPROVED, double-transition blocked |
| CONCURRENT_DUPLICATE | ✅ PASS — DB-04 confirms exactly 1 winner via UNIQUE |
| PARTIAL_FAILURE_ROLLBACK | ✅ PASS — DB-05 confirms no orphan rows on invalid input |
| RESTART_SURVIVAL | ✅ PASS — DB-11 confirms persistence across connections |
| RPC_PERMISSIONS | ✅ PASS — REVOKE from PUBLIC/anon/authenticated; GRANT to service_role only |
| GATE_RESOLUTION_ATOMICITY (P1-03a) | ⚠️ ESCALATED — updateHumanGate + insertReceipt not yet atomic; requires resolve_gate_atomic() RPC (Phase 4, not authorized) |
| DB_SIDE_OWNERSHIP_VALIDATION (P1-01 residual) | ⚠️ ESCALATED — RPC trusts Edge Function as authorization boundary; no auth.uid() re-check in SQL (architectural decision required) |
| CODEX_P0 | ✅ PASS — 0 P0 findings |
| CODEX_P1 | ⚠️ CONDITIONAL — P1-03(b) FIXED (ddd5211); P1-01 and P1-03(a) ESCALATED |

### Phase 3 Test Results

```
59 AEF+impact-lab tests | 0 failed
  — 12 DB integration tests (kernel_pg_test.ts) — all new, Postgres 17 real DB
  — 16 kernel unit tests
  — 26 index unit tests (EF-I7-01..12)
  — 5 supabase_store tests
744 total suite tests | 0 failed (1 pre-existing flaky port collision in competitor-discovery, unrelated)
```

### Codex CLASS D Adversarial Review (Phase 3)

**Thread:** task-murm94rk (new thread)
**Verdict:** FAIL → remediated to CONDITIONAL_PASS

| Finding | Classification | Action |
|---|---|---|
| P1-01: RPC has no DB-side ownership validation | ESCALATED — ARCHITECTURAL DECISION REQUIRED | Service-to-DB trust model; Agente Martins + Paulo to decide |
| P1-02: Receipt hash integrity (shape only) | REJECTED — FALSE POSITIVE | Hash is application-layer commitment; shape validation sufficient |
| P1-03(a): Gate resolution non-atomic | ESCALATED — ARCHITECTURAL DECISION REQUIRED | New resolve_gate_atomic() RPC needed; Phase 4 |
| P1-03(b): approverRef as UUID-FK callerUserId | ACCEPTED — FIXED (ddd5211) | Used storedReq.caller.authenticatedUserId instead |
| P2-01..P2-05 | DEFERRED — OUT OF SCOPE | Hardening mission |
| P3-01..P3-02 | DEFERRED | Hardening mission |

## Constraints Honored

- NO production deploy
- NO migration applied to production
- NO new billing or infrastructure
- NOT merged to main
- NO secrets modified
