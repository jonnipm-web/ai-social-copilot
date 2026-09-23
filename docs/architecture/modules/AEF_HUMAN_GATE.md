# AEF Human Gate (persistent)

Mission `IV-AEF-PERSISTENCE-01`. Table `aef_human_gates`, functions
`aef_register_operation` (creates the gate) and `aef_decide_gate`,
consumed by `aef_claim_execution`.

## What an approval is bound to

An approval is valid only for the exact operation the approver saw:

| Bound element | Where |
|---|---|
| operation identity | gate ↔ operation 1:1 (`UNIQUE(operation_id)`) |
| subject | `subject_id`; the approver must be that subject |
| action and tool | inside `binding_hash` |
| resource (project) | inside `binding_hash`; ownership checked at registration |
| payload | `payload_hash` inside `binding_hash` |
| policy version | stored on the gate and inside `binding_hash`; re-checked at decision and at claim |
| risk version | inside `binding_hash` |
| time | `expires_at` (≤ operation expiry, ≤ 1 h; default 15 min) |

The decision request must echo `binding_hash`. If the operation behind a
key changes in any bound element, it is a different binding: the old
approval cannot be applied to it (`APPROVAL_BINDING_MISMATCH`), and
re-registering the same idempotency key with a different binding is refused
(`IDEMPOTENCY_CONFLICT`).

## Who can decide

v1 rule: **only the operation's own subject**, authenticated by a fresh
credential verified through GoTrue (same `IdentityResolver` as requests).
This is the human-in-the-loop confirmation for actions IVE proposes on the
user's behalf. A different user gets `GATE_NOT_FOUND` (no existence oracle)
and the attempt is recorded in the owner's audit chain
(`APPROVER_NOT_AUTHORIZED`).

Four-eyes / delegated / organizational approval is **not** implemented: it
needs an authorization model (who may approve for whom) that does not exist
yet → `ESCALATED — ARCHITECTURAL DECISION REQUIRED` for any class C module
that needs it.

## What cannot approve

- the request itself: a client `human_gate_ref` is refused
  (`CLIENT_APPROVAL_REJECTED`); `approved`, `human_approved`, `role`, etc.
  are prohibited fields;
- the IveActionIntent (`riskClass`, any extra key → `INTENT_INVALID`);
- an end user writing to the tables (no INSERT/UPDATE grant);
- service_role writing `AUTHORIZED` directly with another approver (guard
  trigger: approver must equal subject).

## Single use

The claim moves the gate `AUTHORIZED → EXECUTED` in the same transaction as
`AUTHORIZED → EXECUTING`; the operation cannot execute twice
(`attempt_count ≤ 1`), so an approval authorizes at most one execution.

## Expiry, rejection, cancellation, policy change

| Event | Gate | Operation | Receipt |
|---|---|---|---|
| reject | `REJECTED` | `REJECTED` | `NOT_EXECUTED` |
| window passes | `EXPIRED` | `EXPIRED` | `NOT_EXECUTED` |
| subject cancels (before execution) | `CANCELLED` | `CANCELLED` | `NOT_EXECUTED` |
| policy version differs at decision or claim | `INVALIDATED` | `INVALIDATED` | `NOT_EXECUTED` |

Approval does not execute anything by itself: execution happens only when
the service is called again with the same idempotency key and the same
payload (the payload is never stored, so only the caller holding the exact
approved bytes can execute them).
