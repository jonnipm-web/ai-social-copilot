# IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01

## Mission Brief

**Title:** Impact Trust Boundary + Egress Pinning + AEF Integration  
**Status:** IMPLEMENTATION COMPLETE — CODEX RE-AUDIT PENDING (Phase 2: DB store + investigation binding)  
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

## Constraints Honored

- NO production deploy
- NO migration applied to production
- NO new billing or infrastructure
- NOT merged to main
- NO secrets modified
