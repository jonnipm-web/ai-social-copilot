# AEF — Current State (audit before IV-AEF-PERSISTENCE-01)

Audited at `2197759` (Module Lab). Scope: `aef/*`, `contracts/aef/*`,
`supabase/functions/_shared/module_policy.ts`, the IVE hand-off in
`supabase/functions/_shared/ive/intelligence.ts`.

## What AEF v0 is

An in-process, fail-closed pipeline (`aef/kernel.ts`):
identity → contract validation → delegation (always AUTH_FAILED in v0) →
tool lookup → policy → human gate → idempotency → mock tool → receipt.

| Property | v0 status | Evidence |
|---|---|---|
| Identity | USER only, verified through GoTrue (`SupabaseUserVerifier`); SERVICE/SYSTEM `UNSUPPORTED` | `identity_resolver.ts` |
| Contract | strict key allowlists, prohibited authority fields at any depth, version fail-closed | `contracts/aef/validators.ts` (65 tests) |
| Policy | deterministic; READ_ONLY → ALLOW, CONSEQUENTIAL → REQUIRE_HUMAN_REVIEW, Quant real-money / Impact non-read → DENY_BY_V0 | `policy_evaluator.ts`, `action_classification.ts` |
| Tool registry | server-owned, sealed, one-time execution capability, mock tools only | `tool_registry.ts` |
| Human Gate | `InMemoryHumanGateStore`; approver identity verified | `human_gate_store.ts` |
| Idempotency / replay | `InMemoryIdempotencyStore`, `InMemoryRequestIdStore`, `InMemoryNonceStore` | `idempotency_guard.ts`, `contracts/aef/types.ts` |
| Receipt | built in memory by exported builders; never persisted | `receipt_builder.ts` |
| Audit | none | — |
| Runtime | no endpoint, not deployed, IVE never calls it | `AEF_PERSISTENCE_AVAILABLE = false` |

Baseline at audit: AEF 138 tests, Edge Functions 373, Flutter 482, analyze
0 warnings — all green.

## Gaps that block durable use (input to this mission)

| # | Gap | Consequence if v0 were made durable as-is |
|---|---|---|
| G1 | All stores in memory | restart loses approvals, idempotency and replay state; a replayed request executes again after a restart; no multi-instance safety |
| G2 | Idempotency key is global, not namespaced | user B reusing user A's key receives A's completed receipt (cross-user leak) |
| G3 | Same key + different payload returns the old result silently | a changed operation is reported as done without running, with no conflict signal |
| G4 | Approval binds only `request_id` + `action` | no binding to subject, resource, payload, policy or risk version |
| G5 | Any verified user can approve any gate | `authorize()` verifies *who* the approver is, never *whether they may approve* |
| G6 | Gates are seeded by the caller (`create()`) | the approval record is not server-originated |
| G7 | Gate state `EXECUTED` is never written | a gate is not consumed; single use depends on the in-memory request-id store |
| G8 | Tool throw → idempotency claim released | a tool that failed *after* a side effect can run again on retry |
| G9 | No tool timeout, no lease, no crash recovery | a crash mid-execution leaves nothing to reconcile; an unknown outcome cannot be expressed |
| G10 | Receipt builders are exported and caller-constructed | a SUCCESS receipt can be built without any execution (acknowledged in `receipt_builder.ts`) |
| G11 | No audit trail | no evidence of decisions after the process ends |
| G12 | Policy has no version | an approval given under one policy remains valid after the policy changes |
| G13 | No payload size / canonical hash | payload identity cannot be bound or compared |
| G14 | No resource ownership check | a request can name another user's project |
| G15 | IVE → AEF mapping undefined | `IveActionIntent` has no documented translation or validation |

## Update — IV-AEF-HARDENING-01 (2026-09-26)

Gaps closed after the persistence mission: retention (policy table,
`aef_purge`, tombstones, checkpointed audit pruning, legal hold), erasure
(`aef_erase_subject`), audit growth control (coalesced denial counters),
UNKNOWN_OUTCOME reconciliation (`aef_reconcile`, append-only), receipt
format `aef-receipt/1.1` (v1 kept verbatim), and a READ-ONLY production
privilege preflight script (result NOT_VERIFIED). Still not runtime-available:
`AEF_PERSISTENCE_AVAILABLE = false`, no endpoint, mock tools only.

## What is kept

The v0 kernel and its 138 tests stay unchanged: it remains the reference
in-memory pipeline. Persistence is added as a separate governance service
(`aef/persistence/`) that reuses the v0 identity resolver, contract
validator, policy evaluator and tool registry, and replaces every in-memory
store with PostgreSQL-backed state (see `AEF_PERSISTENCE_MODEL.md`).
