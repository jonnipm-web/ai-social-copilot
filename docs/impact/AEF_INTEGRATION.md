# AEF Integration

**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01  
**Files:** `supabase/functions/_shared/aef/`

## What the AEF Is

The Action Execution Framework (AEF) is a governance kernel for consequential Impact actions. It enforces:

1. **Idempotency** — same `(user, intentKind, idempotencyKey)` never executes twice
2. **Policy evaluation** — every class C action is evaluated before execution
3. **Human gate** — CONSEQUENTIAL/IRREVERSIBLE actions require a human approval step
4. **Receipt issuance** — every attempt (success or failure) produces a durable, immutable receipt
5. **Identity separation** — authentication / authorization / service / user / tenant are never conflated

The AEF does **not** execute the action itself. It governs the authorization envelope and returns an authorized receipt. Only after receiving `ok: true` with `executionOutcome: AUTHORIZED` may the caller proceed.

## Architecture

```
index.ts (Edge Function)
    │
    ├── buildCallerContext()   ← trust.ts: server-verified identity
    │
    ├── isImpactActionIntent() ← aef/types.ts: is this a class C kind?
    │
    └── submitAction(caller, intent, { store })
            │
            ├── findByIdempotencyKey()   ← idempotency check
            ├── insertRequest()          ← persist AefExecutionRequest
            ├── [policy evaluation]      ← classification → PolicyOutcome
            ├── insertPolicyDecision()   ← persist PolicyDecision
            ├── insertHumanGate()?       ← if CONSEQUENTIAL/IRREVERSIBLE
            ├── insertAttempt()          ← persist ExecutionAttempt
            └── insertReceipt()          ← persist immutable ExecutionReceipt
```

## Action Flow

```
REVERSIBLE action
  → submitAction → AUTHORIZED immediately → receipt.executionOutcome=AUTHORIZED → caller executes

CONSEQUENTIAL action
  → submitAction → REQUIRES_HUMAN_REVIEW → gate created → receipt issued
  → resolveHumanGate(APPROVED) → second receipt issued → caller now executes
  → resolveHumanGate(REJECTED) → action cancelled → receipt issued

IRREVERSIBLE action (Lab)
  → submitAction → DENIED → receipt issued → caller does not execute
```

## AEF in index.ts

```typescript
// Before handleLabRequest, if action === 'request_external_action' and kind is AEF-routed:
const aefResult = await submitAction(callerContext, intent, { store: aefStore });
if (!aefResult.ok) {
  return errorResponse({ code: aefResult.error.code, ... });
}
// Only reaches here if AUTHORIZED
return json(200, { ok: true, receipt: aefResult.receipt });
```

Non-AEF actions fall through to `handleLabRequest` unchanged.

## Policy Versions

Policy is versioned via `AEF_POLICY_VERSION = 'aef-policy/1+impact-i7'`. A policy upgrade must increment this string. All receipts carry the policy version at issue time for audit reconstruction.

## Store Interface

```typescript
interface AefStore {
  insertRequest(req: AefExecutionRequest): Promise<AefStoreResult<void>>
  findByIdempotencyKey(key, userId, kind): Promise<AefStoreResult<AefExecutionRequest | null>>
  insertPolicyDecision(decision: PolicyDecision): Promise<AefStoreResult<void>>
  insertHumanGate(gate: HumanGateState): Promise<AefStoreResult<void>>
  updateHumanGate(gateId, status, approverRef, bindingHash, now): Promise<AefStoreResult<void>>
  getHumanGate(requestId): Promise<AefStoreResult<HumanGateState | null>>
  insertAttempt(attempt: ExecutionAttempt): Promise<AefStoreResult<void>>
  insertReceipt(receipt: ExecutionReceipt): Promise<AefStoreResult<void>>
  getReceipt(requestId): Promise<AefStoreResult<ExecutionReceipt | null>>
}
```

`InMemoryAefStore` implements this interface for tests. Production requires `SupabaseAefStore` backed by the `impact_aef_*` tables (not yet implemented; migration is ready).

## Receipt Hash

Every receipt carries a `receiptHash`: SHA-256 of the canonical pipe-joined receipt fields. This is an integrity check (not a cryptographic proof of origin), allowing detection of receipt tampering at rest.

```
receiptId | requestId | correlationId | callerUserId | projectId | serviceId |
intentKind | investigationId | idempotencyKey | classification | policyVersion |
policyOutcome | executionOutcome | humanGateId | errorCode | issuedAt
```

## Privacy in Receipts

Receipts contain **no** PII, document content, or secrets:
- `callerUserId` = Supabase `auth.users.id` (opaque UUID, not email/name)
- `approverRef` = opaque reference chosen by approver (never a real name or email)
- `investigationId` = foreign key to `impact_investigations` (opaque UUID)
- No document text, no claim content, no evidence body
