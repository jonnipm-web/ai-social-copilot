# AEF Action Catalog

**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01

## Classification

| Classification | Description | Lab policy |
|---|---|---|
| `READ_ONLY` | No external effects; pure reads | AUTHORIZED immediately |
| `REVERSIBLE` | External effects that can be undone | AUTHORIZED immediately |
| `CONSEQUENTIAL` | External effects with real-world impact, difficult to reverse | REQUIRES_HUMAN_REVIEW |
| `IRREVERSIBLE` | External effects that cannot be undone | DENIED (Lab only) |

## Current ImpactActionIntentKinds

| Kind | Classification | Human gate required | Description |
|---|---|---|---|
| `ACKNOWLEDGE_CONFLICT` | REVERSIBLE | No | User acknowledges a flagged conflict in an investigation |
| `MARK_INVESTIGATION_REVIEWED` | REVERSIBLE | No | User marks an investigation as reviewed |
| `REQUEST_MANUAL_VERIFICATION` | CONSEQUENTIAL | Yes (24h TTL) | Requests a human verification step for a claim or source |
| `APPROVE_DOSSIER_PUBLICATION` | CONSEQUENTIAL | Yes (24h TTL) | Approves a dossier for publication or distribution |

## Routing Logic

An action is AEF-routed if and only if its `kind` appears in `IMPACT_ACTION_INTENTS`. All other actions flow through `handleLabRequest` as before.

```typescript
const IMPACT_ACTION_INTENTS = [
  'REQUEST_MANUAL_VERIFICATION',
  'APPROVE_DOSSIER_PUBLICATION',
  'ACKNOWLEDGE_CONFLICT',
  'MARK_INVESTIGATION_REVIEWED',
];
```

## Adding a New Action

1. Add the kind to `ImpactActionIntentKind` union in `aef/types.ts`
2. Add it to `IMPACT_ACTION_INTENTS` array
3. Add its classification to `INTENT_CLASSIFICATION` in `kernel.ts`
4. Add the corresponding DB `CHECK` constraint value to the migration
5. Write at least one test in `kernel_test.ts` covering the new kind's policy outcome
6. Update this catalog

## Human Gate Protocol

When a CONSEQUENTIAL action returns `REQUIRES_HUMAN_REVIEW`:

1. Caller receives `{ ok: false, error: { code: 'REQUIRES_HUMAN_REVIEW', gateId, expiresAt } }`
2. Gate is `PENDING` with 24-hour TTL
3. Approver calls `resolveHumanGate(requestId, 'APPROVED'|'REJECTED', approverRef, bindingHash)`
4. `approverRef` must be a non-empty opaque string ≤ 64 chars (never a real name or email)
5. `bindingHash` must be the SHA-256 hex of the request state at approval time
6. Gate can only transition to `APPROVED`, `REJECTED`, or `EXPIRED` — never back to `PENDING`
7. Expiry check runs at resolution time; an expired gate cannot be approved

## Idempotency Key

The caller provides an idempotency key (UUID). The AEF enforces uniqueness on `(callerUserId, intentKind, idempotencyKey)`. A second submission with the same triple returns `IDEMPOTENCY_CONFLICT` with the existing `requestId`.

The caller should generate a new UUID per logical operation. Re-submitting the same UUID for the same user+kind is safe and returns the prior result.
