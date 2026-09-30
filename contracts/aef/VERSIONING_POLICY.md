# Versioning Policy

**Section 18 of `IVE-AEF-CONTRACT-SECURITY-GATE-01`.**

Every contract type (`ExecutionRequest`, `DelegationEnvelope`, `HumanGateRecord`, `PolicySignal`, `ExecutionReceipt`) carries its own `contract_version` field, independently. There is no single "API version" covering all five — a future change to `ExecutionReceipt` should not force every `ExecutionRequest` producer to also change.

## Current state

Only `"1.0"` exists and is supported, for every contract type. This mission does not define `"1.1"` or `"2.0"` — those are hypothetical until a real need arises.

## Policy for each case

| Case | Behavior |
|---|---|
| **Missing `contract_version`** | Reject unconditionally, for every contract type, with no default assumed. A caller that omits the field is not "using an old version" — it is sending a malformed object. |
| **Supported version** (`"1.0"` today) | Proceed to full validation. |
| **Unsupported future version** (e.g. `"2.0"` when only `1.0` exists) | Reject, for consequential actions, unconditionally (Section 18's explicit instruction: fail-closed for unknown versions in consequential execution). The validator does not attempt best-effort parsing of a version it does not recognize — an unrecognized version could carry semantics (e.g. a relaxed field) that this validator has no way to know are actually safe to relax. |
| **Deprecated version** (hypothetical future case: `"1.0"` superseded by `"1.1"` with a breaking change) | Reject by default, with an explicit, actionable error identifying the required migration. A deployment MAY choose to configure a transition window that accepts both old and new versions, but that is an explicit opt-in configuration a future AEF must set, never an implicit default here. |
| **Malformed version string** (not a recognized format at all, e.g. `"latest"`, `42`, `null`) | Reject, same as unsupported — treated identically to "unsupported," not as a special case. |

## Why per-type, not global

`IVE → AEF` (ExecutionRequest), `component → component` (DelegationEnvelope), `human → gate` (HumanGateRecord), `reasoning → policy` (PolicySignal), and `AEF → audit` (ExecutionReceipt) are five different relationships with different rates of change and different parties responsible for updating each side. Coupling their versions would force synchronized rollouts across parties that don't need to be synchronized. This does mean a future implementation must track five version numbers instead of one — a small, deliberate cost in exchange for independent evolution.
