# Availability / Durability Rule: NO FALLBACK TO UNGOVERNED EXECUTION

**Section 16 of `IVE-AEF-CONTRACT-SECURITY-GATE-01`.**

## The rule

If AEF (or any dependency in the governed-execution chain: auth resolution, policy engine, entitlement source, human-gate service, tool adapter, receipt persistence) is unavailable, **IVE must never fall back to performing the domain action directly.** Unavailability of the governance layer is not, and can never become, an authorization to bypass it.

This applies regardless of urgency, user frustration, retry count, or how "obviously safe" the action seems. There is no severity of outage that converts "AEF is down" into "therefore I may act without AEF."

## What IVE MAY do instead

1. **Report unavailability** to the user/caller honestly — "I can't do that right now, the execution layer is unavailable" — rather than silently succeeding via an ungoverned path or silently failing in a way that looks like success.
2. **Return a PENDING state**, if the surrounding product experience supports asynchronous resolution (e.g. "your request has been recorded and will run once the system is available").
3. **Enqueue the intent in a safe, non-executing form**, if and when a future architecture provides a durable, non-executing queue for this purpose. This mission does not build that queue — the rule exists independent of whether the queue exists yet.

## Why this is enforced structurally, not just documented

This package contains no `execute()`, `run()`, `dispatch()`, `invoke()`, or `call()` function anywhere — only `validate*()` functions that return a verdict (`ValidationResult`). See `validators_test.ts`'s final test, `"no direct-execution API exists in this module"`, which asserts this by inspecting the module's own exports. If a future change to this package ever adds an execution-shaped export, that test fails immediately, on every run, with no reliance on a human noticing during review.

This is a deliberate design choice: the absence of a capability is a much stronger guarantee than a policy that says "don't call this function in this situation." A future AEF implementation that needs an actual execution primitive must build it in a *different* package/service — specifically one that can enforce the full governance chain (policy, entitlement, human gate, receipt) as a precondition, which is exactly what this contract foundation exists to make checkable.

## Relationship to the prior mission's Deployment/Runtime Truth finding

`INSIGHTVALUES-ECOSYSTEM-TARGET-ARCHITECTURE-01` (Finding 11, Codex-reviewed) flagged that AEF, once built, would be a potential single point of failure if its own availability/durability requirements were never specified. This document is the first half of that answer: whatever AEF's internal availability guarantees turn out to be, the answer to "what does IVE do when they're not met" is fixed now, independent of AEF's eventual implementation — **never silent ungoverned execution.**
