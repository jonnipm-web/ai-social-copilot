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
