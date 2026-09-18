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

## Codex round-1 adversarial review: remediation

Codex's first adversarial pass (Class D, mandatory) returned FAIL with
several findings, all reconciled below. See the mission's final report
for the full Codex output and Claude's per-finding classification
(ACCEPT/PARTIAL_ACCEPT/REJECT).

- **Approval spoofing** (P1, ACCEPTED): `InMemoryHumanGateStore`'s
  internal map was TypeScript-`private` only (compile-time, not
  runtime) -- reachable via `(store as any).records.set(...)`, bypassing
  `authorize()`'s independent approver verification entirely. Fixed with
  a true ECMAScript `#records` private field, which no `as any` cast can
  reach in any JS engine.
- **Direct execution fallback** (P1, ACCEPTED): `ToolRegistry.lookup()`
  returned the full `ToolDefinition`, including its `execute` closure --
  any caller holding a registry reference could invoke a tool directly,
  skipping the entire governed pipeline. Fixed by splitting the API into
  `describe()` (metadata only, no `execute` field -- `ToolDescriptor`)
  and `invoke()` (the only way to actually run a tool; does its own
  internal lookup so the closure itself is never handed out).
- **Tool spoofing / late registration** (P1, PARTIAL_ACCEPT): registering
  a tool is a startup-wiring-time operation (same trust tier as
  constructing `AefKernel` itself), not a per-request attack surface --
  Section 17's "no dynamic arbitrary tool selection" is about REQUEST-time
  selection, which was never possible. Still hardened with
  `ToolRegistry.seal()`, called by production wiring right after
  registering all tools, so a later `register()` call throws.
- **Impact policy bypass via misclassification** (P1, PARTIAL_ACCEPT,
  reclassified P2): a tool's classification is inherently a
  registration-time trust decision (Section 17). Rather than invent an
  Impact risk taxonomy (correctly out of scope, Finding F-09), the domain
  boundary was tightened to deny everything except exactly `READ_ONLY`
  for Impact (previously only `CONSEQUENTIAL` was denied) -- reduces, does
  not eliminate, the blast radius of a misclassified tool.
- **Unsupported-identity bypass via kernel trust** (accepted): the kernel
  only checked `identity.status === "VERIFIED"`, not `verifiedType` --
  a different/future `IdentityResolver` implementation returning VERIFIED
  for a non-`user` actor would have been silently accepted. Fixed with an
  explicit `verifiedType !== "user"` check in `kernel.ts`, independent of
  what any injected resolver claims. Applied symmetrically to
  `InMemoryHumanGateStore.authorize()`/`reject()` for the approver.
- **Fail-closed exception handling gaps** (P2, ACCEPTED): (a) the kernel
  dereferenced the raw claimed actor's `auth_ref` without checking it was
  actually an object first; (b) `evaluateHumanGate()`/its resolver call
  was not wrapped in try/catch; (c) the adapter constructed its synthetic
  `Request` OUTSIDE its try block. All three fixed.
- **Receipt falsification** (P2, PARTIAL_ACCEPT, documented not fully
  closed): `receipt_builder.ts`'s functions are exported (required for
  `kernel.ts`, a separate file, to import them) and could be called
  directly by any code with module access to construct a false SUCCESS
  receipt. A full fix needs a capability-based construction API or a
  durable, server-provenance receipt store -- disproportionate for a v0
  with zero persistence and zero network exposure. Documented explicitly
  as a dependency for whichever future mission adds a durable
  ExecutionReceipt store.
- **A bug Claude found while fixing the above**: `InMemoryHumanGateStore`
  had no injectable clock (always used real wall-clock time internally),
  while `AefKernel` uses an injectable one -- a latent test-flakiness
  risk, and the reason an earlier version of test #17 reached into
  private state via `as any` in the first place (to fake an already-past
  expiry without a controllable clock). Fixed by adding the same
  `now?: () => Date` pattern to the store; test #17 now uses two
  independently-clocked components instead of touching internals at all.

## Codex round-2 adversarial re-review: remediation

Round 2 re-verified every round-1 fix and found 3 of them incompletely
closed (all 3 accepted and fixed):

- **Finding 1 (mutable HumanGateRecord escape, P1)**: `#records` being a
  true private field stopped `(store as any).records.set(...)`, but
  `resolve()` still returned the SAME live object stored internally -- a
  caller could mutate its `state`/`approver`/`decided_at`/`audit_ref`
  fields directly (no `.set()` call needed, since the mutated object WAS
  the stored object). Symmetrically, `create()` stored the caller's own
  object by reference. Fixed by defensively `structuredClone()`-ing on
  every write (`create()`/`authorize()`/`reject()`) AND every read
  (`resolve()`) in `human_gate_store.ts`.
- **Finding 2 (public `invoke()` still bypasses the kernel, P1)**: the
  round-1 `describe()`/`invoke()` split hid the `execute` closure, but
  `invoke()` itself remained public and unconditionally callable by
  anyone holding a `ToolRegistry` reference. Fixed with a
  single-issuance capability: `ToolRegistry.claimExecutionRights()`
  returns a bound execution function EXACTLY ONCE across the registry's
  lifetime (a second call throws); `AefKernel`'s constructor claims it
  immediately and stores it in its own `#private` field. Once a real
  `AefKernel` exists, no other code -- even code holding that exact same
  `ToolRegistry` reference -- can extract execution capability from it
  anymore. This does not (and, in a single JS process without real
  process isolation, cannot) defend against code with arbitrary
  execution BEFORE a real kernel is constructed; it closes the
  realistic, demonstrated scenario of a caller reusing an
  already-wired-in registry reference after the fact.
- **Finding 3 (delegation issuer verified-type bypass, P1)**: the issuer
  identity check trusted `identityResolver.resolve()`'s result without
  checking `verifiedType`, so a rogue/misconfigured injected resolver
  could claim a service issuer was "verified" and let a delegated flow
  through. Fixed by removing the dependency on the resolver entirely for
  this path: since a contract-valid `DelegationEnvelope.issuer` can never
  legitimately be `type=user` (already enforced at the contract layer),
  and AEF v0 has no real verification mechanism for `service`/`system`
  at all, `kernel.ts`'s `checkDelegation()` now denies EVERY delegation
  issuer categorically and unconditionally, without ever calling the
  identity resolver for it -- no injected resolver implementation,
  however dishonest, can make this path succeed in v0.

Round 2 also confirmed CLOSED (no further action): 9a (malformed raw
actor), 9b (human-gate resolver exceptions), 9c (adapter Request
construction), and the injectable-clock fix. Round 2 assessed areas
4/5/11 as acceptable-as-scoped, consistent with round 1's classification.

## Codex round-3 adversarial re-review: remediation

Round 3 confirmed all 3 round-2 findings genuinely CLOSED and found one
new P1 (accepted and fixed):

- **New finding (mutable registered ToolDefinition, P1)**: `register()`
  stored the CALLER'S own object by reference -- a caller retaining that
  reference could mutate its `execute` field (or any other field) AFTER
  registration and even after `seal()`, retroactively changing what the
  kernel would execute. Separately, `AefKernel` never auto-sealed the
  registry, so a registry that was never explicitly sealed by wiring
  code remained open to new registrations indefinitely. Fixed both:
  `register()` now stores `Object.freeze({ ...tool })` -- an independent,
  frozen shallow copy, so the caller's own object can be mutated freely
  afterward with zero effect; and `claimExecutionRights()` now
  unconditionally seals the registry too, so registration and
  execution-capability issuance close together in one step, with no
  separate `seal()` call required.

Round 3 confirmed CLOSED: Finding 1 (mutable HumanGateRecord escape --
`structuredClone()` genuinely severs the reference on both read and
write, including nested fields like `approver`), Finding 2 (public
`invoke()` -- no equivalent method remains, `#executeClaimedTool` is
unreachable from outside `AefKernel`, and `claimExecutionRights()`
cannot be called a second time through any means Codex attempted,
including prototype/property inspection), Finding 3 (delegation issuer
denial is genuinely resolver-independent -- `identityResolver` is not
referenced anywhere in `checkDelegation()` anymore, and the earlier
delegation-shape/nonce/binding/subject checks still run first).

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
| `tool_registry.ts` | `ToolRegistry` (`describe()`/`invoke()`/`seal()`) + `registerMockTools()` -- safe mock tools only; `execute` is never exposed to any caller (see round-1 remediation above). |
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
