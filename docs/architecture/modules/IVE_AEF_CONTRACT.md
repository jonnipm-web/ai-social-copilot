# IVE → AEF Contract

Mission `IV-AEF-PERSISTENCE-01`. Code: `aef/persistence/ive_intent_mapping.ts`
(tests IM-01..07, PG-17). **Not wired into `ive-intelligence`** (mission
rule): IVE keeps returning `ACTION_REQUIRES_AEF` with an `IveActionIntent`;
nothing executes. This document is the contract the runtime integration
gate must implement.

## Principle

**IVE may suggest. IVE never authorizes.** An `IveActionIntent` is the
output of a language-model pipeline and is treated as untrusted input.

## Mapping

| IveActionIntent field | Treatment |
|---|---|
| (whole object) | exactly these six keys; any other key → `INTENT_INVALID` |
| `requestedAction` | looked up in the server-owned, frozen `IVE_ACTION_MAP` (own properties only); unknown → `INTENT_ACTION_UNKNOWN`; `trade_order` → `POLICY_DENIED` |
| `projectId` | UUID or null → `resource {type: "project"}`; ownership verified by the database at registration (`RESOURCE_FORBIDDEN`) |
| `riskClass` | validated, **ignored for authority**; class and gate come from the tool registry + policy |
| `capabilityId` | validated; carried only as `metadata.capability_hint` (not bound, not seen by the tool) |
| `contextRef` | UUID (IVE's server correlation id); bound into the payload |
| `parameters` | plain object; canonicalized and size-bounded; prohibited authority fields rejected by the contract validator |
| subject | **only** the caller's verified user id — never from the intent |
| idempotency key | `ive:` + sha256(canonical{contextRef, requestedAction, projectId, parameters}) → a replayed intent maps to the same durable operation |
| approval | none: the mapped request never carries `human_gate_ref` |

`IVE_ACTION_MAP` today: `publish_content, send_message, payment,
transfer_funds, delete_data, execute_workflow, module_action` → `core.*`
actions **with no registered tool**, so AEF refuses them (`UNKNOWN_TOOL`).
IVE therefore cannot cause any real action through AEF in this mission.

## Refusal matrix (tested)

| Attempt | Result |
|---|---|
| forged user / role / plan / admin / approval / tool / risk key | `INTENT_INVALID` |
| intent subject ≠ credential | `AUTH_FAILED` (contract identity check) |
| foreign or unknown project | `RESOURCE_FORBIDDEN` |
| unknown / prototype-named action | `INTENT_ACTION_UNKNOWN` |
| real-money trading | `POLICY_DENIED` |
| oversized parameters | `PAYLOAD_TOO_LARGE` |
| replayed intent | same operation (`replayed: true`), never a second one |
| `riskClass: READ_ONLY` on a consequential tool | still `AWAITING_APPROVAL` |
| real action names | `UNKNOWN_TOOL` (no tool exists) |

## Runtime integration (next gate, not done here)

1. An authenticated endpoint receives the intent + the user's JWT.
2. `mapIveActionIntent(intent, verifiedUserId)` → `AefGovernance.submit()`.
3. The UI shows the gate (`binding_hash`, action, project) and asks the
   user to confirm; confirmation calls `decideGate` with a fresh credential.
4. Execution only for registered, reviewed tools — none exist yet.
