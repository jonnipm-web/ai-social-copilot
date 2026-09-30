# Failure Model

**Section 15 of `IVE-AEF-CONTRACT-SECURITY-GATE-01`.** See also `NO_DIRECT_EXECUTION.md` for the availability/durability rule this failure model depends on.

## Principle

For **consequential** actions (anything that writes, executes, spends money, or is otherwise hard to reverse): **fail closed, always.** For **informational/read-only** actions, a safer degraded response is acceptable, but must be explicit (a clearly-labeled degraded/partial result), never a silent substitution.

## Per-dependency behavior

| Dependency unavailable | Consequential action | Read-only/informational action |
|---|---|---|
| AEF itself unavailable | FAIL CLOSED — see `NO_DIRECT_EXECUTION.md`, no fallback | May degrade to "cached/last-known" data, explicitly labeled as such |
| Auth resolution unavailable | FAIL CLOSED — an actor whose `auth_ref` cannot be resolved is not a verified actor | FAIL CLOSED — informational actions still require knowing who is asking, for audit purposes at minimum |
| Policy engine unavailable | FAIL CLOSED — absence of a policy decision is not an implicit ALLOW | May proceed if the specific read has no policy dependency (e.g. public information) |
| Entitlement source unavailable | FAIL CLOSED — never infer entitlement from a cached or client-supplied value | May degrade with a clear "entitlement-gated features temporarily unavailable" message |
| Human approval unavailable (gate unreachable) | FAIL CLOSED — a `HumanGateRecord` that cannot be resolved is treated as `REVIEW_REQUIRED`/pending, never as `AUTHORIZED` | N/A — read-only actions should not require human gates |
| Tool/adapter unavailable | FAIL CLOSED for that specific action; does not need to fail the whole request pipeline | Degrade gracefully, report which specific capability is unavailable |
| Receipt persistence unavailable | FAIL CLOSED for consequential actions — an action whose receipt cannot be durably recorded must not be allowed to execute, since it would be unauditable | N/A |
| Request malformed (fails contract validation) | FAIL CLOSED unconditionally — see `validators.ts`, every validator returns `{ ok: false }` for any structural violation | Same — malformed is malformed regardless of stakes |
| Contract version unsupported | FAIL CLOSED unconditionally (see `VERSIONING_POLICY.md`) | Same |
| Delegation expired | FAIL CLOSED unconditionally | Same — an expired delegation proves nothing about current authority |

## Why read-only actions get any leniency at all

A dashboard that shows slightly stale data because the policy engine is briefly unreachable is a UX degradation. A dashboard that silently executes a write because the policy engine was unreachable is a security incident. The asymmetry in this table exists to make that distinction impossible to blur by accident — an implementer has to actively look up "is this action read-only" (a property that must come from a trusted, server-side action registry, never from a client-settable field on the request) before any leniency applies at all.
