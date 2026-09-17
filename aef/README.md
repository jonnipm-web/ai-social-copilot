# AEF v0 -- Autonomous Execution Fabric (kernel)

Mission: `IV-AEF-FOUNDATION-01`. Builds the FIRST real AEF kernel on top of
the contract foundation from `IVE-AEF-CONTRACT-SECURITY-GATE-01`
(`contracts/aef/`). This kernel is **minimal, domain-agnostic,
fail-closed, auditable, testable, non-autonomous, non-production** --
see Section 3 of the mission brief.

## What this is NOT

- **Not a network service.** No public API, no Edge Function, no Cloud
  Run endpoint, no queue worker, no scheduler. `AefKernel` is an internal
  library/test harness only -- ZERO DEPLOY (Section 12).
- **Not connected to any real system.** Every registered tool is a mock
  (`tool_registry.ts`'s `registerMockTools`) -- none can write Supabase,
  call Stripe, send email, publish content, execute a broker order, or
  touch Impact (Section 18/32).
- **Not a service/system identity provider.** AEF v0 only verifies
  `user` identities, because that is the only identity type this
  repository can genuinely, cryptographically verify today (Section 6 --
  see "F-02 closure" below).
- **Not a persistence layer.** Every store here (`InMemoryNonceStore`,
  `InMemoryRequestIdStore`, `InMemoryIdempotencyStore`,
  `InMemoryHumanGateStore`, `InMemoryDelegationStore` in tests) is
  in-memory, single-process, test/harness-grade (Section 27). No
  migration, no table, was created by this mission.

## Pipeline (Section 3)

```
ExecutionRequest
  -> Identity Resolution      (identity_resolver.ts)
  -> Contract Validation      (contracts/aef/validators.ts, reused)
  -> [Delegation Validation]  (kernel.ts's checkDelegation(), if delegation_ref present)
  -> Policy Evaluation        (policy_evaluator.ts + action_classification.ts)
  -> Human Gate               (human_gate_evaluator.ts, if REQUIRE_HUMAN_REVIEW)
  -> Idempotency              (idempotency_guard.ts)
  -> Controlled Tool Registry (tool_registry.ts)
  -> Mock Execution
  -> Execution Receipt        (receipt_builder.ts)
  -> Verification State
```

Every exit point (`AefKernel.submit()`) returns a `KernelResult` with a
real, schema-valid `contracts/aef` `ExecutionReceipt` -- there is no path
that silently drops a processed attempt, and no path that reports SUCCESS
without a tool having actually run (Section 21/22).

## F-02 closure: `auth_ref` is now independently resolved (for USER)

The inherited finding: `auth_ref` proved only good formation
(`svc:not-a-real-service` is syntactically valid but meaningless).
Invariant required: `SCHEMA_VALID != AUTHENTICATED`.

**Auth discovery (Section 5), evidence-based, before writing any
resolver code:**

| Actor type | Real verification exists today? | Mechanism |
|---|---|---|
| `user` (`usr:`) | **YES** | `supabase.auth.getUser(token)` against real Supabase Auth/GoTrue -- the exact pattern already used by every real business Edge Function via `supabase/functions/_shared/auth.ts`'s `resolveAuthenticatedUser()`. |
| `service` (`svc:`) | **NO** | Only a shared `SUPABASE_SERVICE_ROLE_KEY` env var (proves possession, not a distinct per-service identity) and one vendor-specific HMAC check (Stripe webhooks) that does not generalize. No service registry, no signed service tokens, no mTLS. |
| `system` (`system:internal`) | **NO** | Purely conventional -- no cron/scheduler attestation, no signed trigger, exists in this repo. |

Per Section 6 ("DO NOT INVENT AUTH"), this mission did **not** invent a
service registry, custom JWT, or scheduler attestation just to claim
closure. **AEF v0 supports USER identity verification only.**
`service`/`system` actors are `UNSUPPORTED_BY_V0` -- fail-closed, always
(`identity_resolver.ts`'s `AefIdentityResolver.resolve()`), regardless of
how well-formed their `auth_ref` looks.

`IdentityResolver.resolve(actor, credential)`:
- validates actor SHAPE first (reuses `contracts/aef/validators.ts`'s
  `validateActor` -- never trusts an unchecked shape);
- for `service`/`system`: always `UNSUPPORTED`;
- for `user`: requires a real bearer credential, verifies it via
  `UserVerifier` (production: `adapters/supabase_identity_resolver.ts`'s
  `SupabaseUserVerifier`, a thin wrapper around the EXISTING
  `resolveAuthenticatedUser()` -- not a reimplementation), and rejects
  the result outright if the independently-verified id does not match
  the CLAIMED `actor.id` (closes the actor-mismatch/confused-deputy
  vector, Section 8/9).

**This closes F-02 for the only identity type this repository can
currently verify.** Full closure for `service`/`system` requires a real
service-identity registry or signed-assertion mechanism that does not
exist yet -- tracked as an explicit next-mission dependency (see the
Final Report's "Exact Next Mission" section), not silently assumed.

## Kernel outcome vs. contract outcome

Section 21 asks for 7 kernel-level outcomes (`SUCCESS`, `FAILURE`,
`DENIED`, `HUMAN_REVIEW_REQUIRED`, `DUPLICATE`, `INVALID`,
`AUTH_FAILED`). The existing, already-adversarially-reviewed
`contracts/aef` `ExecutionReceipt` v1 schema constrains `outcome` to only
5 values and separately has `policy_decision` (`ALLOWED`/`DENIED`).
Rather than reopen and re-version that already-PASSed v1 contract, this
kernel keeps `KernelOutcome` as its own internal vocabulary and maps it
onto the existing receipt fields -- see `receipt_builder.ts`'s header
comment for the full mapping table. This is a deliberate architectural
decision to avoid an unnecessary, riskier contract change, not an
oversight; the full 7-value vocabulary IS represented, just at the
kernel layer instead of forcing it into the wire contract.

## Delegation flows: a known, deliberate v0 boundary

A `DelegationEnvelope`'s `issuer` can never be `type=user`
(`contracts/aef/validators.ts` already rejects that, Finding F-02 from
the prior mission). Since AEF v0 can only verify `user` identities, ANY
request declaring a `delegation_ref` will resolve to `AUTH_FAILED` today
-- the issuer identity check always returns `UNSUPPORTED`. This is
correct, fail-closed behavior, not a bug: delegated execution is not
supported end-to-end until a future mission adds real service-identity
verification. The subject/audience binding logic
(`delegation_binding.ts`, `contracts/aef/validators.ts`'s
`validateRequestAgainstDelegation`) is still implemented and unit-tested
in isolation now, so that guarantee already exists for the day issuer
verification is added.

## Quant/Impact hard boundaries (Sections 24/25)

`action_classification.ts`'s `checkDomainBoundary()` runs before policy
evaluation and unconditionally denies:
- any Quant action whose `quant_execution_tier` is `controlled_live` or
  `expanded_live` -- **even with a valid, AUTHORIZED HumanGateRecord**
  (no broker, no live trading, no financial credentials exist in AEF v0);
- any Impact action classified `CONSEQUENTIAL` -- Impact has no
  canonical consequential-action risk taxonomy yet (Finding F-09,
  deliberately deferred in the contract mission).

## Files

| File | Purpose |
|---|---|
| `types.ts` | Kernel-internal types (deliberately separate from `contracts/aef/types.ts` -- see its header comment). |
| `identity_resolver.ts` | `AefIdentityResolver` -- the F-02 closure for `user` identities; `UserVerifier` interface. |
| `adapters/supabase_identity_resolver.ts` | `SupabaseUserVerifier` -- thin real-world adapter wrapping `resolveAuthenticatedUser()`. The ONLY file in `aef/` depending on `supabase/functions/_shared/`. |
| `action_classification.ts` | `ActionClassification` taxonomy + the hard Quant/Impact domain boundary. |
| `policy_evaluator.ts` | Deterministic ALLOW/DENY/REQUIRE_HUMAN_REVIEW policy engine. |
| `human_gate_evaluator.ts` | Validates a resolved `HumanGateRecord` against binding rules before allowing a gated action. |
| `human_gate_store.ts` | In-memory `HumanGateRecord` store -- the ONLY path to `AUTHORIZED` independently re-verifies the approver's identity. |
| `delegation_binding.ts` | Subject-binding check for delegated requests (see "Delegation flows" above). |
| `tool_registry.ts` | `ToolRegistry` + `registerMockTools()` -- safe mock tools only. |
| `idempotency_guard.ts` | Atomic idempotency-key claim/complete + request_id replay defense, positioned right before tool execution. |
| `receipt_builder.ts` | Builds `KernelResult`/`ExecutionReceipt` for every outcome; the kernel-outcome-to-contract-outcome mapping. |
| `kernel.ts` | `AefKernel` -- orchestrates the full pipeline. |
| `kernel_test.ts` | Section 29's 30-item security matrix + Section 9's 11 confused-deputy tests + Section 20's concurrency tests + negative-space test. |
| `adapters/supabase_identity_resolver_test.ts` | Proves the real adapter wraps `resolveAuthenticatedUser()` correctly, with no network access. |

## Running tests

```
deno check aef/*.ts aef/adapters/*.ts
deno lint aef/*.ts aef/adapters/*.ts
deno test --allow-read --allow-net=deno.land,esm.sh aef/kernel_test.ts aef/adapters/supabase_identity_resolver_test.ts
```
