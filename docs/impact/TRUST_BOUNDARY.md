# Impact Trust Boundary

**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01  
**File:** `supabase/functions/_shared/impact/trust.ts`

## The Problem: service_role ≠ Authorization

Supabase Edge Functions run with a `service_role` JWT when making server-side database calls. This grants them full database access, bypassing Row Level Security. This is a **technical capability**, not a **business authorization**.

Before I7, the Impact module treated service_role implicitly as "the request is authorized." This is wrong:

| What service_role tells you | What it does NOT tell you |
|---|---|
| The call came from a backend function | Which user initiated the action |
| The function has DB access | Whether that user is entitled to Impact |
| — | Which project is in scope |
| — | Whether the user owns that project |
| — | Which policy governs the action |

## CallerContext: Explicit Trust Separation

`CallerContext` captures six orthogonal concerns that were previously conflated:

```typescript
interface CallerContext {
  authenticatedUserId: string;  // AUTHENTICATION: from verified session JWT only
  moduleId: string;             // AUTHORIZATION: which module entitlement is active
  correlationId: string;        // TRACEABILITY: carried through the full chain
  projectId: string | null;     // TENANT SCOPE: null = user-level scope
  serviceId: string;            // SERVICE IDENTITY: which Edge Function is acting
}
```

**Key invariants:**
- `authenticatedUserId` is derived from the Supabase session JWT (`auth.uid()`), never from request body
- `serviceId` must be in the known registry (`IMPACT_SERVICE_IDS = ['impact-lab', 'impact-monitor']`)
- A service_role client held by an unknown serviceId is rejected at `buildCallerContext`

## Service Identity Registry

```typescript
export const IMPACT_SERVICE_IDS = Object.freeze(['impact-lab', 'impact-monitor'] as const);
```

Only these services may issue consequential Impact actions. Adding a new service requires updating this list AND its AEF policy scope.

## CallerContext Placement (BT-2)

`CallerContext` is defined in `impact/trust.ts`, **not** `aef/types.ts`. This maintains Boundary Test 2: the `impact/` core never imports from `aef/`. The AEF module re-exports CallerContext for consumer convenience:

```
impact/trust.ts  →  defines CallerContext
aef/types.ts     →  re-exports CallerContext from ../impact/trust.ts
index.ts         →  imports both, routes through AEF
```

## Project Scope Validation

`validateProjectScope(claimedProjectId, context, userOwnedProjectIds)` adds a second layer of protection on top of RLS:

1. RLS prevents the user from reading other users' data
2. `validateProjectScope` prevents a user from submitting requests for projects they own but that don't match the authenticated session's project scope

This closes the confused-deputy attack where a user authenticates for project A but submits a consequential action claiming project B.

## buildCallerContext: Fail-Closed

```typescript
function buildCallerContext(input: TrustContextInput): CallerContext {
  if (!isKnownServiceId(input.serviceId)) throw TRUST_VIOLATION
  if (!input.authenticatedUserId)         throw TRUST_VIOLATION
  if (!input.correlationId)               throw TRUST_VIOLATION
  return Object.freeze({ ... });
}
```

Any missing or invalid field throws before any business logic runs. The returned object is frozen (no mutation after construction).

## What CallerContext Is NOT

- Not a capability token (it does not grant access by itself)
- Not substitutable for entitlement check (that happens in `requireModuleAccess`)
- Not a secret (it contains only opaque IDs and policy labels)
- Not derived from request body (all fields come from server-verified sources)

## Investigation Binding Gate (added 2026-10-03)

Before the AEF intercept accepts any class C action, `index.ts` now validates
that the `investigationId` from the request body is owned by the authenticated
user. This is done via a lab store read (RLS-scoped to the caller's JWT):

```
request_external_action(investigation_id, idempotency_key, kind)
    │
    ├── investigation_id required + UUID format → INVALID_REQUEST if missing
    ├── idempotency_key required + UUID format  → INVALID_REQUEST if missing
    │
    ├── labStore.getInvestigation(investigationId)  ← RLS: only owner sees it
    │   └── null → 404 INVESTIGATION_NOT_FOUND
    │
    └── submitAction(callerContext, { investigationId, idempotencyKey, kind }, ...)
```

**Why client-provided idempotencyKey:** The client holds the logical identity of a
request (e.g., "this is my request to verify claim C for investigation I"). The
server generates only the physical `requestId`; the `idempotencyKey` must be stable
across retries. This is the only model that satisfies "same logical request = same
idempotency key" without relying on per-attempt random UUID generation.

## Project Binding via Investigation (P1-02, added 2026-10-03 Phase 3)

After investigation ownership is confirmed, `index.ts` derives `projectId` from the
validated investigation record and builds a **separate `aefCallerContext`** with it:

```
invResult.value.projectId → aefCallerContext.projectId
```

The outer `callerContext` retains `projectId: null` for non-AEF paths. This ensures
every AEF request/receipt is bound to the exact project the investigation belongs to,
not a client-supplied claim.

## AEF Persistence Trust Boundary (aef_submit_action RPC, Phase 3)

The `aef_submit_action()` PL/pgSQL SECURITY DEFINER RPC is the terminal write boundary.

**What the RPC enforces:**
- Parameter validation (format, enum membership, FK constraints)
- Idempotency: UNIQUE constraint on `(caller_user_id, intent_kind, idempotency_key)` — catches racing duplicates
- Atomicity: all 4 records in a single Postgres transaction

**What the RPC does NOT enforce (architectural escalation):**
- It does not re-derive `auth.uid()` or validate investigation ownership inside SQL.
- Authorization is enforced at the Edge Function boundary (JWT + RLS + investigation binding).
- The RPC trusts the Edge Function as the authorized caller.

**Security posture:** REVOKE ALL on all 4 AEF tables from PUBLIC; REVOKE from anon + authenticated; GRANT EXECUTE only to service_role. The RPC is not reachable from client-side Supabase clients.

## Gate Resolution Trust Boundary (aef_resolve_gate RPC, Phase 4)

The `aef_resolve_gate()` PL/pgSQL SECURITY DEFINER RPC is the terminal write boundary for gate resolution.

**What the RPC enforces (atomically in one Postgres transaction):**
- Parameter validation (format, enum, length)
- `FOR UPDATE` lock on gate row — prevents concurrent double-resolution
- Status = PENDING check (returns GATE_ALREADY_RESOLVED if not)
- Server-time expiry: `clock_timestamp() >= expires_at` (caller-supplied `p_issued_at` CANNOT bypass expiry — P1-01 fix)
- Gate status update (APPROVED/REJECTED) + `resolved_at` = server time
- Resolution receipt INSERT with `caller_user_id = v_request.caller_user_id` (requester UUID, not approverRef — P1-03(b) fix)
- On receipt PK collision: ROLLBACK (gate stays PENDING) → RECEIPT_ALREADY_EXISTS
- On any other failure: Postgres rolls back implicitly (no orphan gate updates)

**What the RPC does NOT enforce:**
- Binding hash semantic verification (format-only check; semantic equality is enforced by the kernel before calling the RPC — same trust model as aef_submit_action)
- auth.uid() re-derivation (accepted for lab; production-hardening requirement)

**Security posture:** Same REVOKE/GRANT chain as aef_submit_action — only service_role can call the function (confirmed by DG-12/DG-13 tests).
