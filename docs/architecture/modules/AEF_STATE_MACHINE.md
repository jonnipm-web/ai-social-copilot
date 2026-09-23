# AEF State Machine

Mission `IV-AEF-PERSISTENCE-01`. Enforced twice in PostgreSQL: by the RPC
functions (which choose the transition) and by the `aef_operations_guard` /
`aef_human_gates_guard` triggers (which refuse any other transition, for
every role including service_role). Fail-closed: anything not listed is
refused.

## Operation

```
                 register (gated)            register (no gate)
                       │                            │
                       ▼                            ▼
              AWAITING_APPROVAL ──approve──▶  AUTHORIZED ──claim──▶ EXECUTING
                 │  │  │  │                     │  │  │                │  │  │
          reject │  │  │  │ policy changed      │  │  │ policy changed │  │  │
                 ▼  │  │  ▼                     │  │  ▼                ▼  ▼  ▼
          REJECTED  │  │ INVALIDATED            │  │ INVALIDATED   SUCCEEDED FAILED UNKNOWN_OUTCOME
                    │  │                        │  │
           expire   ▼  ▼ cancel        expire   ▼  ▼ cancel
                 EXPIRED CANCELLED           EXPIRED CANCELLED
```

| From | Allowed to | Trigger-level extra condition |
|---|---|---|
| (insert) | `AWAITING_APPROVAL` if gated, else `AUTHORIZED` | attempt 0, no token/lease/outcome |
| `AWAITING_APPROVAL` | `AUTHORIZED` | gate `AUTHORIZED`, approver = subject, same binding |
| | `REJECTED`, `EXPIRED`, `CANCELLED`, `INVALIDATED` | — |
| `AUTHORIZED` | `EXECUTING` | attempt 0→1, token and lease set; gated ⇒ gate already `EXECUTED` |
| | `EXPIRED`, `CANCELLED`, `INVALIDATED` | — |
| `EXECUTING` | `SUCCEEDED`, `FAILED`, `UNKNOWN_OUTCOME` | only via token-matched completion or lease-expiry recovery |
| terminal | — | never changes again |

Terminal: `SUCCEEDED, FAILED, UNKNOWN_OUTCOME, REJECTED, EXPIRED, CANCELLED, INVALIDATED`.
Every terminal transition issues exactly one receipt in the same transaction.

Immutable after insert: subject, request id, key hash, domain, action, tool,
class, resource, payload hash/size, binding hash, policy/risk version,
gate requirement, creation and expiry time.

## Human gate

| From | Allowed to |
|---|---|
| (insert) `REVIEW_REQUIRED` | only for an `AWAITING_APPROVAL`, gated operation with the same subject, binding and policy version; expiry ≤ operation expiry |
| `REVIEW_REQUIRED` | `AUTHORIZED`, `REJECTED` (approver = subject, before expiry), `EXPIRED`, `CANCELLED`, `INVALIDATED` |
| `AUTHORIZED` | `EXECUTED` (consumed by the claim, operation still `AUTHORIZED`, before expiry), `EXPIRED`, `CANCELLED`, `INVALIDATED` |

## Failure → state

| Situation | Result | Retried? |
|---|---|---|
| tool succeeds | `SUCCEEDED` / `SUCCESS` | — |
| tool fails, declares no side effect | `FAILED` / `FAILURE` | no (new key needed) |
| tool fails after its side effect | `FAILED` / `PARTIAL` | no; no automatic compensation |
| tool fails without declaring | `UNKNOWN_OUTCOME` | no |
| tool throws | `UNKNOWN_OUTCOME` | no |
| tool exceeds timeout | `UNKNOWN_OUTCOME` (tool is aborted) | no |
| process dies after the claim | stays `EXECUTING` until lease expiry → recovery → `UNKNOWN_OUTCOME` | no |
| completion write fails | caller gets `OUTCOME_UNCONFIRMED`; recovery → `UNKNOWN_OUTCOME` | no |
| late completion after recovery | refused (`EXECUTION_TOKEN_INVALID`); history not rewritten | — |
| approval window passes | `EXPIRED` (lazily on next touch, or by `aef_recover`) | — |
| policy version changes before execution | `INVALIDATED` | — |

`UNKNOWN_OUTCOME` is terminal for automation. Reconciliation (a human or a
tool-specific verifier deciding what really happened) is out of scope and
must be a future, explicit, audited transition — never an automatic retry.

## Clock

Deadlines are evaluated with the database clock (`now()`) — the service
cannot pass its own time. Tests move deadlines by editing stored timestamps
as superuser with triggers disabled (`session_replication_role = replica`);
the service's own clock is injectable for request-validity checks only.
