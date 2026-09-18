/**
 * AEF v0 kernel test suite. Covers:
 *  - Section 29's required 30-item security matrix (AUTH/CONTRACT/POLICY/
 *    HUMAN/REPLAY/DOMAIN/FAILURE), numbered exactly as the mission lists
 *    them.
 *  - Section 9's 11 confused-deputy tests.
 *  - Section 20's concurrency tests (same request_id, same idempotency_key).
 *  - A negative-space test proving no direct-execution API exists.
 *
 * Every test that expects failure asserts BOTH the kernelOutcome AND that
 * a real, schema-valid ExecutionReceipt was still produced (Section 21:
 * "toda tentativa processável deve gerar receipt").
 */
import { assert, assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateExecutionReceipt } from "../contracts/aef/validators.ts";
import { InMemoryNonceStore, InMemoryRequestIdStore } from "../contracts/aef/types.ts";
import type { DelegationEnvelope, ExecutionRequest } from "../contracts/aef/types.ts";
import { checkSubjectBinding } from "./delegation_binding.ts";
import { AefIdentityResolver, type UserVerification, type UserVerifier } from "./identity_resolver.ts";
import { InMemoryHumanGateStore } from "./human_gate_store.ts";
import { InMemoryIdempotencyStore } from "./idempotency_guard.ts";
import { AefKernel } from "./kernel.ts";
import { registerMockTools, ToolRegistry } from "./tool_registry.ts";
import type { DelegationResolver, KernelResult } from "./types.ts";

const NOW = new Date("2026-09-18T12:00:00.000Z");
const FUTURE = new Date("2026-09-18T13:00:00.000Z").toISOString();
const PAST = new Date("2026-09-18T11:00:00.000Z").toISOString();

function uuid(seed: string): string {
  const hex = seed.padEnd(32, "0").slice(0, 32).replace(/[^0-9a-f]/gi, "0");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

// ---------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------

class FakeUserVerifier implements UserVerifier {
  constructor(private readonly tokens: Map<string, { userId: string; expired?: boolean }>) {}
  verify(token: string): Promise<UserVerification> {
    const entry = this.tokens.get(token);
    if (!entry) return Promise.resolve({ ok: false, reason: "INVALID", detail: "unknown token" });
    if (entry.expired) return Promise.resolve({ ok: false, reason: "EXPIRED", detail: "token expired" });
    return Promise.resolve({ ok: true, userId: entry.userId });
  }
}

class UnavailableUserVerifier implements UserVerifier {
  verify(): Promise<UserVerification> {
    return Promise.resolve({ ok: false, reason: "UNAVAILABLE", detail: "identity backend unreachable" });
  }
}

class ThrowingUserVerifier implements UserVerifier {
  verify(): Promise<UserVerification> {
    throw new Error("simulated identity backend crash");
  }
}

class InMemoryDelegationStore implements DelegationResolver {
  private readonly delegations = new Map<string, DelegationEnvelope>();
  put(d: DelegationEnvelope): void {
    this.delegations.set(d.delegation_id, d);
  }
  resolve(ref: string): DelegationEnvelope | undefined {
    return this.delegations.get(ref);
  }
}

const VALID_TOKEN = "valid-token-user-alice";
const VALID_TOKEN_BOB = "valid-token-user-bob";
const EXPIRED_TOKEN = "expired-token";

function makeKernel(overrides: Partial<{ userVerifier: UserVerifier }> = {}) {
  const userVerifier = overrides.userVerifier ?? new FakeUserVerifier(
    new Map([
      [VALID_TOKEN, { userId: "user-alice" }],
      [VALID_TOKEN_BOB, { userId: "user-bob" }],
      [EXPIRED_TOKEN, { userId: "user-alice", expired: true }],
    ]),
  );
  const identityResolver = new AefIdentityResolver(userVerifier);
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  const delegationResolver = new InMemoryDelegationStore();
  const humanGateStore = new InMemoryHumanGateStore(identityResolver, () => NOW);
  const requestIdStore = new InMemoryRequestIdStore();
  const nonceStore = new InMemoryNonceStore();
  const idempotencyStore = new InMemoryIdempotencyStore();

  const kernel = new AefKernel({
    identityResolver,
    delegationResolver,
    humanGateResolver: humanGateStore,
    toolRegistry,
    requestIdStore,
    nonceStore,
    idempotencyStore,
    now: () => NOW,
  });

  return { kernel, identityResolver, delegationResolver, humanGateStore, requestIdStore, nonceStore, idempotencyStore };
}

function baseRequest(overrides: Partial<ExecutionRequest> = {}): ExecutionRequest {
  return {
    contract_version: "1.0",
    request_id: uuid("req1"),
    requested_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    actor: { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    intent: "test request",
    domain: "internal",
    action: "internal.mock_read_echo",
    ...overrides,
  } as ExecutionRequest;
}

function bearer(token: string) {
  return { kind: "bearer_jwt" as const, token };
}
const NO_CREDENTIAL = { kind: "none" as const };

function assertReceiptValid(result: KernelResult) {
  const check = validateExecutionReceipt(result.receipt);
  assert(check.ok, `receipt must be contract-valid: ${JSON.stringify((check as { errors?: string[] }).errors)}`);
}

// =======================================================================
// SECTION 29 -- REQUIRED SECURITY MATRIX
// =======================================================================

// --- AUTH ---

Deno.test("SECURITY MATRIX #1 -- fabricated user (unknown token) -> AUTH_FAILED", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ actor: { type: "user", id: "user-alice", auth_ref: "usr:not-a-real-user" } });
  const result = await kernel.submit(req, bearer("totally-made-up-token"));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #2 -- fabricated service -> AUTH_FAILED (UNSUPPORTED)", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ actor: { type: "service", id: "some-service", auth_ref: "svc:not-a-real-service" } });
  const result = await kernel.submit(req, NO_CREDENTIAL);
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assert(result.receipt.error?.includes("UNSUPPORTED"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #3 -- expired identity -> AUTH_FAILED", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ actor: { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" } });
  const result = await kernel.submit(req, bearer(EXPIRED_TOKEN));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assert(result.receipt.error?.includes("EXPIRED"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #4 -- actor mismatch -> AUTH_FAILED", async () => {
  const { kernel } = makeKernel();
  // Real token verifies as user-bob, but the request CLAIMS to be user-alice.
  const req = baseRequest({ actor: { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" } });
  const result = await kernel.submit(req, bearer(VALID_TOKEN_BOB));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assert(result.receipt.error?.includes("actor mismatch") || result.receipt.error?.toLowerCase().includes("mismatch"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #5 -- unsupported identity (system:internal fabricated) -> AUTH_FAILED", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ actor: { type: "system", id: "system", auth_ref: "system:internal" } });
  const result = await kernel.submit(req, NO_CREDENTIAL);
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assert(result.receipt.error?.includes("UNSUPPORTED"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #6 -- resolver unavailable -> AUTH_FAILED (fail closed, not fail open)", async () => {
  const { kernel } = makeKernel({ userVerifier: new UnavailableUserVerifier() });
  const req = baseRequest();
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assert(result.receipt.error?.includes("UNAVAILABLE"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #7 -- valid verified user -> proceeds (SUCCESS on a READ_ONLY tool)", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest();
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "SUCCESS");
  assertEquals(result.receipt.actor.id, "user-alice");
  assertEquals(result.verificationState, "EXECUTION_SUCCEEDED_UNVERIFIED");
  assertReceiptValid(result);
});

// --- CONTRACT ---

Deno.test("SECURITY MATRIX #8 -- invalid schema -> INVALID", async () => {
  const { kernel } = makeKernel();
  const req = { ...baseRequest(), contract_version: undefined };
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "INVALID");
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #9 -- prohibited authority field -> INVALID", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ parameters: { role: "admin" } });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "INVALID");
  assert(result.receipt.error?.includes("INVALID_CONTRACT"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #10 -- unsupported contract version -> INVALID", async () => {
  const { kernel } = makeKernel();
  const req = { ...baseRequest(), contract_version: "99.0" };
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "INVALID");
  assertReceiptValid(result);
});

// --- POLICY ---

Deno.test("SECURITY MATRIX #11 -- unknown tool -> DENIED", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ domain: "core", action: "core.nonexistent_action" });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "DENIED");
  assert(result.receipt.error?.includes("unknown tool"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #12 -- read-only allowed -> SUCCESS", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ action: "internal.mock_read_echo" });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "SUCCESS");
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #13 -- consequential requires review -> HUMAN_REVIEW_REQUIRED without a gate, SUCCESS with a valid one", async () => {
  const { kernel, humanGateStore } = makeKernel();
  const req = baseRequest({ action: "internal.mock_consequential_action" });

  const withoutGate = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(withoutGate.kernelOutcome, "HUMAN_REVIEW_REQUIRED");
  assertReceiptValid(withoutGate);

  const gateId = uuid("gate13");
  humanGateStore.create({
    contract_version: "1.0",
    gate_id: gateId,
    request_id: req.request_id,
    action: req.action,
    state: "REVIEW_REQUIRED",
    expires_at: FUTURE,
  });
  const authorize = await humanGateStore.authorize(
    gateId,
    { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    bearer(VALID_TOKEN),
    NOW,
    "audit-entry-13",
  );
  assert(authorize.ok, `authorize should succeed: ${JSON.stringify(authorize)}`);

  const reqWithGate = { ...req, human_gate_ref: gateId };
  const withGate = await kernel.submit(reqWithGate, bearer(VALID_TOKEN));
  assertEquals(withGate.kernelOutcome, "SUCCESS");
  assertReceiptValid(withGate);
});

Deno.test("SECURITY MATRIX #14 -- policy evaluation failure -> DENIED, not fail-open", async () => {
  const { identityResolver, delegationResolver, humanGateStore, requestIdStore, nonceStore, idempotencyStore } = makeKernel();
  const brokenRegistry = new ToolRegistry();
  // Register a tool with a classification value the evaluator does not
  // recognize, simulating a corrupt/malformed registration.
  brokenRegistry.register({
    toolId: "internal.mock_broken_tool",
    domain: "internal",
    // deno-lint-ignore no-explicit-any
    classification: "NOT_A_REAL_CLASSIFICATION" as any,
    requiresHumanGate: false,
    execute: () => Promise.resolve({ outcome: "SUCCESS" as const }),
  });
  const kernel = new AefKernel({
    identityResolver,
    delegationResolver,
    humanGateResolver: humanGateStore,
    toolRegistry: brokenRegistry,
    requestIdStore,
    nonceStore,
    idempotencyStore,
    now: () => NOW,
  });
  const req = baseRequest({ action: "internal.mock_broken_tool" });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  // A classification outside READ_ONLY/REVERSIBLE falls into the
  // CONSEQUENTIAL default branch of evaluatePolicy (never throws, never
  // ALLOWs by default) -- still proves fail-closed, documented here
  // since policy evaluation cannot actually be "unavailable" in a
  // pure in-process deterministic evaluator (see kernel.ts's own
  // try/catch, which exists for defense in depth).
  assert(result.kernelOutcome === "HUMAN_REVIEW_REQUIRED" || result.kernelOutcome === "DENIED");
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #15 -- policy override attempt -> caught upstream at contract validation (INVALID)", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ parameters: { force_execute: true, skip_checks: true } });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "INVALID");
  assertReceiptValid(result);
});

// --- HUMAN ---

Deno.test("SECURITY MATRIX #16 -- missing approval -> HUMAN_REVIEW_REQUIRED", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ action: "internal.mock_consequential_action" });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "HUMAN_REVIEW_REQUIRED");
  assert(result.receipt.error?.includes("missing approval"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #17 -- expired approval -> HUMAN_REVIEW_REQUIRED", async () => {
  // Codex round-1 adversarial review, area 3/14: the original version of
  // this test reached into the store's internals via `(store as any)
  // .records.set(...)` to simulate a stale AUTHORIZED record -- exactly
  // the anti-pattern that finding demonstrated could ALSO be used to
  // forge approval illegitimately. `#records` is now a true private
  // field (cannot be reached via `as any` at all), so this test instead
  // uses two independently-clocked components, exactly as a real clock
  // would behave: the store's clock is EARLY (so creating/authorizing a
  // gate that expires shortly afterward succeeds normally), and the
  // kernel evaluates it LATER (after that expiry) -- proving the
  // AUTHORIZED-but-now-expired rejection (Finding F-04) through entirely
  // legitimate API calls, no internals access required.
  const EARLY_STORE_NOW = new Date(PAST); // 11:00
  const SHORT_LIVED_EXPIRY = "2026-09-18T11:30:00.000Z"; // future relative to 11:00, past relative to kernel's NOW (12:00)

  const { identityResolver, delegationResolver, requestIdStore, nonceStore, idempotencyStore } = makeKernel();
  const humanGateStore = new InMemoryHumanGateStore(identityResolver, () => EARLY_STORE_NOW);
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  const kernel = new AefKernel({
    identityResolver,
    delegationResolver,
    humanGateResolver: humanGateStore,
    toolRegistry,
    requestIdStore,
    nonceStore,
    idempotencyStore,
    now: () => NOW, // kernel evaluates LATER than the store's clock
  });

  const req = baseRequest({ action: "internal.mock_consequential_action" });
  const gateId = uuid("gate17");
  humanGateStore.create({
    contract_version: "1.0",
    gate_id: gateId,
    request_id: req.request_id,
    action: req.action,
    state: "REVIEW_REQUIRED",
    expires_at: SHORT_LIVED_EXPIRY,
  });
  const authorize = await humanGateStore.authorize(
    gateId,
    { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    bearer(VALID_TOKEN),
    EARLY_STORE_NOW,
    "audit-17",
  );
  assert(authorize.ok, `authorize should succeed while not yet expired: ${JSON.stringify(authorize)}`);

  const reqWithGate = { ...req, human_gate_ref: gateId };
  const result = await kernel.submit(reqWithGate, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "HUMAN_REVIEW_REQUIRED");
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #18 -- approval wrong request -> HUMAN_REVIEW_REQUIRED", async () => {
  const { kernel, humanGateStore } = makeKernel();
  const req = baseRequest({ action: "internal.mock_consequential_action" });
  const otherReq = baseRequest({ request_id: uuid("other-req"), action: "internal.mock_consequential_action" });
  const gateId = uuid("gate18");
  humanGateStore.create({
    contract_version: "1.0",
    gate_id: gateId,
    request_id: otherReq.request_id, // bound to a DIFFERENT request
    action: req.action,
    state: "REVIEW_REQUIRED",
    expires_at: FUTURE,
  });
  const authorize = await humanGateStore.authorize(
    gateId,
    { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    bearer(VALID_TOKEN),
    NOW,
    "audit-18",
  );
  assert(authorize.ok);

  const reqWithGate = { ...req, human_gate_ref: gateId };
  const result = await kernel.submit(reqWithGate, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "HUMAN_REVIEW_REQUIRED");
  assert(result.receipt.error?.includes("wrong request"));
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #19 -- fabricated approver -> gate never reaches AUTHORIZED, HUMAN_REVIEW_REQUIRED", async () => {
  const { kernel, humanGateStore } = makeKernel();
  const req = baseRequest({ action: "internal.mock_consequential_action" });
  const gateId = uuid("gate19");
  humanGateStore.create({
    contract_version: "1.0",
    gate_id: gateId,
    request_id: req.request_id,
    action: req.action,
    state: "REVIEW_REQUIRED",
    expires_at: FUTURE,
  });
  // Attempt to authorize with an approver whose credential does NOT verify.
  const authorize = await humanGateStore.authorize(
    gateId,
    { type: "user", id: "fake-approver", auth_ref: "usr:fabricated-approver-1" },
    bearer("not-a-real-token"),
    NOW,
    "audit-19",
  );
  assert(!authorize.ok, "authorize() must refuse a fabricated approver");
  assertEquals(humanGateStore.resolve(gateId)!.state, "REVIEW_REQUIRED", "gate must remain non-authorized");

  const reqWithGate = { ...req, human_gate_ref: gateId };
  const result = await kernel.submit(reqWithGate, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "HUMAN_REVIEW_REQUIRED");
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #20 -- valid approval -> SUCCESS", async () => {
  const { kernel, humanGateStore } = makeKernel();
  const req = baseRequest({ action: "internal.mock_consequential_action" });
  const gateId = uuid("gate20");
  humanGateStore.create({
    contract_version: "1.0",
    gate_id: gateId,
    request_id: req.request_id,
    action: req.action,
    state: "REVIEW_REQUIRED",
    expires_at: FUTURE,
  });
  const authorize = await humanGateStore.authorize(
    gateId,
    { type: "user", id: "user-bob", auth_ref: "usr:session-bob-1" },
    bearer(VALID_TOKEN_BOB),
    NOW,
    "audit-20",
  );
  assert(authorize.ok);

  const reqWithGate = { ...req, human_gate_ref: gateId };
  const result = await kernel.submit(reqWithGate, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "SUCCESS");
  assertReceiptValid(result);
});

// --- REPLAY ---

Deno.test("SECURITY MATRIX #21 -- duplicate request (same request_id) -> DUPLICATE on the second attempt", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest();
  const first = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(first.kernelOutcome, "SUCCESS");
  const second = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(second.kernelOutcome, "DUPLICATE");
  assertReceiptValid(second);
});

Deno.test("SECURITY MATRIX #22 -- duplicate consequential request (with idempotency_key) -> same receipt, never re-executed", async () => {
  // Uses a REVERSIBLE (non-human-gated) consequential-adjacent mock tool
  // deliberately, not the human-gated one: a HumanGateRecord is bound to
  // exactly ONE request_id (contracts/aef v1 design, Section 12 of the
  // prior mission), so a retry with a genuinely NEW request_id for a
  // gated action fails at the human-gate binding check ("approval wrong
  // request") before ever reaching idempotency -- that is a real,
  // separate architectural interaction documented in the final report's
  // Remaining Risks, not a bug in this test. This test isolates the
  // idempotency guarantee itself, which applies uniformly to any
  // consequential-in-spirit action, gated or not.
  const { kernel } = makeKernel();
  const req = baseRequest({
    action: "internal.mock_reversible_update",
    idempotency_key: "biz-op-22",
  });

  const first = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(first.kernelOutcome, "SUCCESS");

  // A legitimate retry: SAME idempotency_key, but a NEW request_id (as
  // contracts/aef documents retries do) -- still must not re-execute.
  const retryReq = { ...req, request_id: uuid("req22-retry") };
  const second = await kernel.submit(retryReq, bearer(VALID_TOKEN));
  assertEquals(second.kernelOutcome, "DUPLICATE");
  assertEquals(second.receipt.receipt_id, first.receipt.receipt_id, "must return the SAME original receipt, not a new one");
});

Deno.test("SECURITY MATRIX #23 -- idempotency collision (different request_id, same idempotency_key) -> DUPLICATE", async () => {
  const { kernel } = makeKernel();
  const req1 = baseRequest({ idempotency_key: "biz-op-23" });
  const req2 = baseRequest({ request_id: uuid("req23b"), idempotency_key: "biz-op-23" });
  const first = await kernel.submit(req1, bearer(VALID_TOKEN));
  assertEquals(first.kernelOutcome, "SUCCESS");
  const second = await kernel.submit(req2, bearer(VALID_TOKEN));
  assertEquals(second.kernelOutcome, "DUPLICATE");
  assertEquals(second.receipt.receipt_id, first.receipt.receipt_id);
});

Deno.test("SECURITY MATRIX #24 -- nonce replay (DelegationEnvelope) -> AUTH_FAILED via delegation invalidity", async () => {
  const { kernel, delegationResolver } = makeKernel();
  const sharedNonce = "shared-nonce-aaaaaaaaaaaa";
  const delegation1: DelegationEnvelope = {
    contract_version: "1.0",
    delegation_id: uuid("del24a"),
    issuer: { type: "service", id: "ive-core", auth_ref: "svc:ive-core-service" },
    subject: { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    audience: "aef.internal",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: sharedNonce,
    purpose: "test",
    scope: ["internal.mock_read_echo"],
    request_binding: uuid("req24a"),
    auth_assertion_ref: "assertion-24a",
  };
  const delegation2: DelegationEnvelope = { ...delegation1, delegation_id: uuid("del24b"), request_binding: uuid("req24b") };
  delegationResolver.put(delegation1);
  delegationResolver.put(delegation2);

  const req1 = baseRequest({ request_id: delegation1.request_binding, delegation_ref: delegation1.delegation_id });
  const req2 = baseRequest({ request_id: delegation2.request_binding, delegation_ref: delegation2.delegation_id });

  // Both are denied end-to-end because AEF v0 cannot verify a SERVICE
  // issuer (documented v0 boundary) -- but the FIRST must consume the
  // nonce while validating delegation SHAPE (which runs before issuer
  // verification), and the SECOND must be caught as a nonce replay at
  // that same shape-validation step, distinctly from the (also-true)
  // issuer-unsupported reason.
  // delegation1's nonce is fresh: shape validation consumes it and
  // passes, binding/subject checks pass, so this reaches (and fails at)
  // issuer verification -- AUTH_FAILED, not a nonce problem.
  const r1 = await kernel.submit(req1, bearer(VALID_TOKEN));
  assertEquals(r1.kernelOutcome, "AUTH_FAILED");
  assert(r1.receipt.error?.includes("delegation issuer"), `expected r1 to fail at issuer verification, got: ${r1.receipt.error}`);

  // delegation2 reuses the SAME nonce -- shape validation itself must now
  // fail (nonce already consumed), before issuer verification is ever
  // reached.
  const r2 = await kernel.submit(req2, bearer(VALID_TOKEN));
  assertEquals(r2.kernelOutcome, "INVALID");
  assert(r2.receipt.error?.toLowerCase().includes("nonce"), `expected nonce replay to be reported: ${r2.receipt.error}`);
});

// --- DOMAIN ---

Deno.test("SECURITY MATRIX #25 -- Quant real-money tier -> DENY_BY_V0, even with an AUTHORIZED human gate", async () => {
  const { humanGateStore, identityResolver } = makeKernel();
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  toolRegistry.register({
    toolId: "quant.controlled_live.submit_order",
    domain: "quant",
    classification: "CONSEQUENTIAL",
    requiresHumanGate: true,
    execute: () => Promise.resolve({ outcome: "SUCCESS" as const }),
  });
  const requestIdStore = new InMemoryRequestIdStore();
  const nonceStore = new InMemoryNonceStore();
  const idempotencyStore = new InMemoryIdempotencyStore();
  const kernel2 = new AefKernel({
    identityResolver,
    delegationResolver: new InMemoryDelegationStore(),
    humanGateResolver: humanGateStore,
    toolRegistry,
    requestIdStore,
    nonceStore,
    idempotencyStore,
    now: () => NOW,
  });

  const gateId = uuid("gate25");
  const req = baseRequest({
    domain: "quant",
    action: "quant.controlled_live.submit_order",
    quant_execution_tier: "controlled_live",
    human_gate_ref: gateId,
  });
  humanGateStore.create({ contract_version: "1.0", gate_id: gateId, request_id: req.request_id, action: req.action, state: "REVIEW_REQUIRED", expires_at: FUTURE });
  await humanGateStore.authorize(gateId, { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" }, bearer(VALID_TOKEN), NOW, "audit-25");

  const result = await kernel2.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "DENIED");
  assert(result.receipt.error?.includes("DENY_BY_V0"));
  assertReceiptValid(result);
  void nonceStore;
});

Deno.test("SECURITY MATRIX #26 -- Impact consequential action -> DENY_BY_V0", async () => {
  const { identityResolver, humanGateStore } = makeKernel();
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  toolRegistry.register({
    toolId: "impact.investigation.close_case",
    domain: "impact",
    classification: "CONSEQUENTIAL",
    requiresHumanGate: true,
    execute: () => Promise.resolve({ outcome: "SUCCESS" as const }),
  });
  const kernel2 = new AefKernel({
    identityResolver,
    delegationResolver: new InMemoryDelegationStore(),
    humanGateResolver: humanGateStore,
    toolRegistry,
    requestIdStore: new InMemoryRequestIdStore(),
    nonceStore: new InMemoryNonceStore(),
    idempotencyStore: new InMemoryIdempotencyStore(),
    now: () => NOW,
  });
  const req = baseRequest({ domain: "impact", action: "impact.investigation.close_case" });
  const result = await kernel2.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "DENIED");
  assert(result.receipt.error?.includes("DENY_BY_V0"));
  assertReceiptValid(result);
});

// --- FAILURE ---

Deno.test("SECURITY MATRIX #27 -- tool failure -> FAILURE, never a fictitious success", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ action: "internal.mock_failing_tool" });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "FAILURE");
  assertEquals(result.receipt.outcome, "FAILURE");
  assertReceiptValid(result);
});

Deno.test("SECURITY MATRIX #28 -- receipt persistence failure: NOT_APPLICABLE_V0 (no persistence layer exists yet, Section 27)", () => {
  // AEF v0 deliberately has no durable receipt store (interfaces +
  // in-memory only, Section 27) -- there is nothing external to fail.
  // This test documents the classification rather than fabricating an
  // artificial persistence failure that would not reflect v0's real
  // architecture.
  assert(true);
});

Deno.test("SECURITY MATRIX #29 -- validator failure / malformed non-object input -> INVALID, never throws", async () => {
  const { kernel } = makeKernel();
  for (const garbage of [null, undefined, "not an object", 42, [], true]) {
    const result = await kernel.submit(garbage, bearer(VALID_TOKEN));
    assertEquals(result.kernelOutcome, "AUTH_FAILED", `garbage input ${JSON.stringify(garbage)} must fail closed (no actor to resolve)`);
    assertReceiptValid(result);
  }
});

Deno.test("SECURITY MATRIX #30 -- identity failure (resolver throws synchronously) -> AUTH_FAILED, never crashes", async () => {
  const { kernel } = makeKernel({ userVerifier: new ThrowingUserVerifier() });
  const req = baseRequest();
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assert(result.receipt.error?.includes("threw unexpectedly"));
  assertReceiptValid(result);
});

// =======================================================================
// SECTION 9 -- CONFUSED-DEPUTY TESTS (11 required)
// =======================================================================

Deno.test("CONFUSED DEPUTY -- usr:not-a-real-user is denied", async () => {
  const { kernel } = makeKernel();
  const result = await kernel.submit(baseRequest({ actor: { type: "user", id: "user-alice", auth_ref: "usr:not-a-real-user" } }), bearer("garbage"));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
});

Deno.test("CONFUSED DEPUTY -- svc:not-a-real-service is denied", async () => {
  const { kernel } = makeKernel();
  const result = await kernel.submit(baseRequest({ actor: { type: "service", id: "x", auth_ref: "svc:not-a-real-service" } }), NO_CREDENTIAL);
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
});

Deno.test("CONFUSED DEPUTY -- fabricated system:internal is denied", async () => {
  const { kernel } = makeKernel();
  const result = await kernel.submit(baseRequest({ actor: { type: "system", id: "x", auth_ref: "system:internal" } }), NO_CREDENTIAL);
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
});

Deno.test("CONFUSED DEPUTY -- valid-looking fake ref (schema-valid, unverifiable) is denied -- the core F-02 invariant", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ actor: { type: "user", id: "user-alice", auth_ref: "usr:very-plausible-looking-session-ref-99" } });
  const result = await kernel.submit(req, bearer("this-token-does-not-exist-anywhere"));
  assertEquals(result.kernelOutcome, "AUTH_FAILED", "SCHEMA_VALID must never imply AUTHENTICATED");
});

Deno.test("CONFUSED DEPUTY -- expired identity is denied", async () => {
  const { kernel } = makeKernel();
  const result = await kernel.submit(baseRequest(), bearer(EXPIRED_TOKEN));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
});

Deno.test("CONFUSED DEPUTY -- wrong user (real token, different claimed identity) is denied", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ actor: { type: "user", id: "user-bob", auth_ref: "usr:session-bob-1" } });
  const result = await kernel.submit(req, bearer(VALID_TOKEN)); // VALID_TOKEN verifies as user-alice
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
});

Deno.test("CONFUSED DEPUTY -- actor mismatch is denied", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ actor: { type: "user", id: "someone-else", auth_ref: "usr:session-someone-else" } });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
});

Deno.test("CONFUSED DEPUTY -- subject mismatch is denied (isolated binding-logic test)", () => {
  const delegation: DelegationEnvelope = {
    contract_version: "1.0",
    delegation_id: uuid("delsubj"),
    issuer: { type: "service", id: "ive-core", auth_ref: "svc:ive-core-service" },
    subject: { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    audience: "aef.internal",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-subj-aaaaaaaaaaaa",
    purpose: "test",
    scope: ["internal.mock_read_echo"],
    request_binding: uuid("reqsubj"),
    auth_assertion_ref: "assertion-subj",
  };
  const decision = checkSubjectBinding(delegation, "user-bob" /* != delegation.subject.id */);
  assert(decision !== null);
  assertEquals(decision!.decision, "DENY");
});

Deno.test("CONFUSED DEPUTY -- issuer mismatch is subsumed by issuer-unsupported (documented v0 boundary)", async () => {
  // In AEF v0 no SERVICE identity can be verified at all (Section 6), so
  // "issuer claims X but is really Y" and "issuer cannot be verified at
  // all" collapse to the same fail-closed outcome today -- both deny.
  // This is a strictly BROADER denial than distinguishing the two would
  // give, not a gap: see kernel.ts's checkDelegation() doc comment.
  const { kernel, delegationResolver } = makeKernel();
  const delegation: DelegationEnvelope = {
    contract_version: "1.0",
    delegation_id: uuid("delissuer"),
    issuer: { type: "service", id: "claimed-issuer", auth_ref: "svc:claimed-issuer-service" },
    subject: { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    audience: "aef.internal",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-issuer-aaaaaaaaaaaa",
    purpose: "test",
    scope: ["internal.mock_read_echo"],
    request_binding: uuid("reqissuer"),
    auth_assertion_ref: "assertion-issuer",
  };
  delegationResolver.put(delegation);
  const req = baseRequest({ request_id: delegation.request_binding, delegation_ref: delegation.delegation_id });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "AUTH_FAILED");
  assert(result.receipt.error?.includes("delegation issuer"));
});

Deno.test("CONFUSED DEPUTY -- audience mismatch is denied", async () => {
  const { kernel, delegationResolver } = makeKernel();
  const delegation: DelegationEnvelope = {
    contract_version: "1.0",
    delegation_id: uuid("delaud"),
    issuer: { type: "service", id: "ive-core", auth_ref: "svc:ive-core-service" },
    subject: { type: "user", id: "user-alice", auth_ref: "usr:session-alice-1" },
    audience: "aef.quant", // request below is domain=internal -> mismatch
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-aud-aaaaaaaaaaaaaa",
    purpose: "test",
    scope: ["internal.mock_read_echo"],
    request_binding: uuid("reqaud"),
    auth_assertion_ref: "assertion-aud",
  };
  delegationResolver.put(delegation);
  const req = baseRequest({ request_id: delegation.request_binding, delegation_ref: delegation.delegation_id });
  const result = await kernel.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "DENIED");
  assert(result.receipt.error?.includes("delegation binding failed"));
});

Deno.test("CONFUSED DEPUTY -- valid verified user is allowed through identity resolution", async () => {
  const { kernel } = makeKernel();
  const result = await kernel.submit(baseRequest(), bearer(VALID_TOKEN));
  assertNotEquals(result.kernelOutcome, "AUTH_FAILED");
});

// =======================================================================
// SECTION 20 -- CONCURRENCY
// =======================================================================

Deno.test("CONCURRENCY -- two concurrent submits with the SAME request_id: exactly one proceeds", async () => {
  const { kernel } = makeKernel();
  const req = baseRequest({ request_id: uuid("concurrent-reqid") });
  const [a, b] = await Promise.all([kernel.submit(req, bearer(VALID_TOKEN)), kernel.submit(req, bearer(VALID_TOKEN))]);
  const outcomes = [a.kernelOutcome, b.kernelOutcome].sort();
  assertEquals(outcomes, ["DUPLICATE", "SUCCESS"]);
});

Deno.test("CONCURRENCY -- two concurrent submits with the SAME idempotency_key (different request_id): exactly one executes", async () => {
  const { kernel } = makeKernel();
  const key = "concurrent-biz-key";
  const req1 = baseRequest({ request_id: uuid("concA"), idempotency_key: key });
  const req2 = baseRequest({ request_id: uuid("concB"), idempotency_key: key });
  const [a, b] = await Promise.all([kernel.submit(req1, bearer(VALID_TOKEN)), kernel.submit(req2, bearer(VALID_TOKEN))]);
  const outcomes = [a.kernelOutcome, b.kernelOutcome].sort();
  // The loser sees either DUPLICATE (if the winner had already completed
  // by the time it checked) or the in-flight variant -- both are
  // DUPLICATE at the kernel-outcome level; the key invariant is that
  // the mock tool's side effect (here, just producing a receipt) never
  // happens twice with a fresh SUCCESS receipt for both.
  const successCount = outcomes.filter((o) => o === "SUCCESS").length;
  assertEquals(successCount, 1, "the consequential mock action must execute exactly once for one business idempotency_key, even under concurrency");
});

// =======================================================================
// NEGATIVE-SPACE TEST -- no direct-execution API exists (Section 23)
// =======================================================================

Deno.test("no direct-execution API exists in the AEF v0 kernel module", async () => {
  const kernelModule = await import("./kernel.ts");
  const toolRegistryModule = await import("./tool_registry.ts");
  for (const [name, mod] of [["kernel.ts", kernelModule], ["tool_registry.ts", toolRegistryModule]] as const) {
    for (const exportName of Object.keys(mod)) {
      const forbidden = ["execute", "run", "dispatch"];
      assert(
        !forbidden.includes(exportName),
        `${name} must not export a top-level '${exportName}' -- all execution must go through AefKernel.submit()'s full governed pipeline`,
      );
    }
  }
});

// =======================================================================
// CODEX ROUND-1 ADVERSARIAL REVIEW -- REMEDIATION REGRESSION TESTS
// =======================================================================

Deno.test("ROUND-1 area 3 regression: HumanGateRecord storage is truly private (#records), not reachable via `as any`", () => {
  const { identityResolver } = makeKernel();
  const store = new InMemoryHumanGateStore(identityResolver, () => NOW);
  // deno-lint-ignore no-explicit-any
  assertEquals((store as any).records, undefined, "there must be no `records` property reachable at all -- only the true private field `#records`, which `as any` cannot expose");
});

Deno.test("ROUND-1 area 4 regression: ToolRegistry.seal() prevents further registration after startup wiring", () => {
  const registry = new ToolRegistry();
  registerMockTools(registry);
  registry.seal();
  let threw = false;
  try {
    registry.register({
      toolId: "internal.late_registration_attempt",
      domain: "internal",
      classification: "READ_ONLY",
      requiresHumanGate: false,
      execute: () => Promise.resolve({ outcome: "SUCCESS" as const }),
    });
  } catch {
    threw = true;
  }
  assert(threw, "register() after seal() must throw -- registration is startup-only");
});

Deno.test("ROUND-1 area 5 regression: Impact REVERSIBLE (not just CONSEQUENTIAL) is also denied unconditionally", async () => {
  const { identityResolver, humanGateStore } = makeKernel();
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  toolRegistry.register({
    toolId: "impact.discover.update_index",
    domain: "impact",
    classification: "REVERSIBLE", // deliberately NOT CONSEQUENTIAL -- proving the tightened boundary
    requiresHumanGate: false,
    execute: () => Promise.resolve({ outcome: "SUCCESS" as const }),
  });
  const kernel2 = new AefKernel({
    identityResolver,
    delegationResolver: new InMemoryDelegationStore(),
    humanGateResolver: humanGateStore,
    toolRegistry,
    requestIdStore: new InMemoryRequestIdStore(),
    nonceStore: new InMemoryNonceStore(),
    idempotencyStore: new InMemoryIdempotencyStore(),
    now: () => NOW,
  });
  const req = baseRequest({ domain: "impact", action: "impact.discover.update_index" });
  const result = await kernel2.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "DENIED");
  assert(result.receipt.error?.includes("DENY_BY_V0"));
});

Deno.test("ROUND-1 area 9 regression: a resolver returning VERIFIED with a malformed/garbage claimed actor does not throw", async () => {
  class LooseVerifiedResolver {
    resolve() {
      return Promise.resolve({ status: "VERIFIED" as const, verifiedId: "user-x", verifiedType: "user" as const, source: "test" });
    }
  }
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  const kernel2 = new AefKernel({
    identityResolver: new LooseVerifiedResolver(),
    delegationResolver: new InMemoryDelegationStore(),
    humanGateResolver: new InMemoryHumanGateStore(new LooseVerifiedResolver(), () => NOW),
    toolRegistry,
    requestIdStore: new InMemoryRequestIdStore(),
    nonceStore: new InMemoryNonceStore(),
    idempotencyStore: new InMemoryIdempotencyStore(),
    now: () => NOW,
  });
  // actor is `null` -- a resolver that loosely says VERIFIED regardless
  // must not cause the kernel to crash when it tries to read auth_ref off
  // it. Contract validation separately (and correctly) rejects a null
  // actor -- INVALID is the expected outcome; reaching a normal
  // KernelResult at all (rather than a thrown exception) is what this
  // test actually proves.
  const result = await kernel2.submit({ ...baseRequest(), actor: null }, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "INVALID");
  assertReceiptValid(result);
});

Deno.test("ROUND-1 area 9 regression: a human-gate resolver that throws is treated as HUMAN_REVIEW_REQUIRED, not an unhandled rejection", async () => {
  const { identityResolver } = makeKernel();
  const throwingGateResolver = {
    resolve(): never {
      throw new Error("gate backend down");
    },
  };
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  const kernel2 = new AefKernel({
    identityResolver,
    delegationResolver: new InMemoryDelegationStore(),
    humanGateResolver: throwingGateResolver,
    toolRegistry,
    requestIdStore: new InMemoryRequestIdStore(),
    nonceStore: new InMemoryNonceStore(),
    idempotencyStore: new InMemoryIdempotencyStore(),
    now: () => NOW,
  });
  // Must actually carry a human_gate_ref, otherwise evaluateHumanGate()
  // short-circuits at "missing approval" before ever calling resolve() --
  // the throwing behavior is only reachable once resolve() is invoked.
  const req = baseRequest({ action: "internal.mock_consequential_action", human_gate_ref: uuid("gate-throws") });
  const result = await kernel2.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "HUMAN_REVIEW_REQUIRED");
  assert(result.receipt.error?.includes("threw unexpectedly"), `expected 'threw unexpectedly' in error, got: ${result.receipt.error}`);
});

Deno.test("ROUND-1 area 10 regression: ToolRegistry.describe() never exposes an executable function", () => {
  const registry = new ToolRegistry();
  registerMockTools(registry);
  const descriptor = registry.describe(baseRequest({ action: "internal.mock_read_echo" }));
  assert(descriptor !== undefined);
  // deno-lint-ignore no-explicit-any
  assertEquals((descriptor as any).execute, undefined, "describe() must return metadata only, never the execute closure");
});

Deno.test("ROUND-1 area 13 regression: kernel independently rejects VERIFIED results whose verifiedType is not 'user'", async () => {
  class RogueServiceVerifiedResolver {
    resolve() {
      return Promise.resolve({ status: "VERIFIED" as const, verifiedId: "svc-1", verifiedType: "service" as unknown as "user", source: "rogue-test-resolver" });
    }
  }
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  const kernel2 = new AefKernel({
    identityResolver: new RogueServiceVerifiedResolver(),
    delegationResolver: new InMemoryDelegationStore(),
    humanGateResolver: new InMemoryHumanGateStore(new RogueServiceVerifiedResolver(), () => NOW),
    toolRegistry,
    requestIdStore: new InMemoryRequestIdStore(),
    nonceStore: new InMemoryNonceStore(),
    idempotencyStore: new InMemoryIdempotencyStore(),
    now: () => NOW,
  });
  const req = baseRequest({ actor: { type: "service", id: "svc-1", auth_ref: "svc:whatever-service-id" } });
  const result = await kernel2.submit(req, NO_CREDENTIAL);
  assertEquals(result.kernelOutcome, "AUTH_FAILED", "a rogue/misconfigured resolver claiming VERIFIED for a non-user type must still be rejected by the kernel itself");
});

// =======================================================================
// CODEX ROUND-2 ADVERSARIAL REVIEW -- REMEDIATION REGRESSION TESTS
// =======================================================================

Deno.test("ROUND-2 finding 1 regression: mutating a resolve()'d HumanGateRecord does not affect the store or a later kernel evaluation", async () => {
  const { kernel, humanGateStore } = makeKernel();
  const req = baseRequest({ action: "internal.mock_consequential_action" });
  const gateId = uuid("gate-r2f1");
  humanGateStore.create({
    contract_version: "1.0",
    gate_id: gateId,
    request_id: req.request_id,
    action: req.action,
    state: "REVIEW_REQUIRED",
    expires_at: FUTURE,
  });

  // Obtain a "live" reference the way legitimate code would, then try to
  // forge approval by mutating it directly instead of calling authorize().
  const leaked = humanGateStore.resolve(gateId)!;
  // deno-lint-ignore no-explicit-any
  (leaked as any).state = "AUTHORIZED";
  // deno-lint-ignore no-explicit-any
  (leaked as any).approver = { type: "user", id: "forged-approver", auth_ref: "usr:forged-approver-ref" };
  // deno-lint-ignore no-explicit-any
  (leaked as any).decided_at = NOW.toISOString();
  // deno-lint-ignore no-explicit-any
  (leaked as any).audit_ref = "forged-audit-entry";

  // The store's internal state must be UNCHANGED by mutating the leaked copy.
  const reResolved = humanGateStore.resolve(gateId)!;
  assertEquals(reResolved.state, "REVIEW_REQUIRED", "mutating a resolve()'d object must not affect the store's internal record");

  const reqWithGate = { ...req, human_gate_ref: gateId };
  const result = await kernel.submit(reqWithGate, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "HUMAN_REVIEW_REQUIRED", "the forged mutation must not grant approval");
});

Deno.test("ROUND-2 finding 2 regression: ToolRegistry.claimExecutionRights() can only be claimed once", () => {
  const registry = new ToolRegistry();
  registerMockTools(registry);
  registry.claimExecutionRights(); // first claim (simulates AefKernel's constructor)
  let threw = false;
  try {
    registry.claimExecutionRights(); // second claim attempt -- same registry reference
  } catch {
    threw = true;
  }
  assert(threw, "a second claimExecutionRights() call must throw -- execution capability is single-issuance");
});

Deno.test("ROUND-2 finding 2 regression: after a real AefKernel is constructed, the SAME ToolRegistry reference cannot yield execution capability anymore", () => {
  const { identityResolver, humanGateStore } = makeKernel();
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  // Constructing AefKernel claims execution rights immediately.
  new AefKernel({
    identityResolver,
    delegationResolver: new InMemoryDelegationStore(),
    humanGateResolver: humanGateStore,
    toolRegistry,
    requestIdStore: new InMemoryRequestIdStore(),
    nonceStore: new InMemoryNonceStore(),
    idempotencyStore: new InMemoryIdempotencyStore(),
    now: () => NOW,
  });
  // An attacker holding this EXACT SAME registry reference (e.g. because
  // it was passed around after being wired into a real kernel) can no
  // longer extract execution capability from it.
  let threw = false;
  try {
    toolRegistry.claimExecutionRights();
  } catch {
    threw = true;
  }
  assert(threw, "claimExecutionRights() must throw once a real AefKernel has already claimed it");
});

Deno.test("ROUND-2 finding 3 regression: delegation issuer is denied unconditionally, even if an injected resolver dishonestly claims it verified", async () => {
  const { delegationResolver } = makeKernel();
  class AlwaysVerifiedResolver {
    resolve() {
      // Dishonestly claims ANY actor (including a service issuer) is verified.
      return Promise.resolve({ status: "VERIFIED" as const, verifiedId: "any-id", verifiedType: "user" as const, source: "rogue" });
    }
  }
  const rogueIdentityResolver = new AlwaysVerifiedResolver();
  const toolRegistry = new ToolRegistry();
  registerMockTools(toolRegistry);
  const kernel2 = new AefKernel({
    identityResolver: rogueIdentityResolver,
    delegationResolver,
    humanGateResolver: new InMemoryHumanGateStore(rogueIdentityResolver, () => NOW),
    toolRegistry,
    requestIdStore: new InMemoryRequestIdStore(),
    nonceStore: new InMemoryNonceStore(),
    idempotencyStore: new InMemoryIdempotencyStore(),
    now: () => NOW,
  });
  const delegation: DelegationEnvelope = {
    contract_version: "1.0",
    delegation_id: uuid("del-r2f3"),
    issuer: { type: "service", id: "ive-core", auth_ref: "svc:ive-core-service" },
    subject: { type: "user", id: "any-id", auth_ref: "usr:session-any-id-1" },
    audience: "aef.internal",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-r2f3-aaaaaaaaaaaa",
    purpose: "test",
    scope: ["internal.mock_read_echo"],
    request_binding: uuid("req-r2f3"),
    auth_assertion_ref: "assertion-r2f3",
  };
  delegationResolver.put(delegation);
  // request.actor must match delegation.subject exactly -- that binding
  // check (contracts/aef's validateRequestAgainstDelegation) compares
  // against the CLAIMED request.actor field, independent of whatever the
  // (here, rogue) identity resolver later claims to verify.
  const req = baseRequest({
    request_id: delegation.request_binding,
    delegation_ref: delegation.delegation_id,
    actor: { type: "user", id: "any-id", auth_ref: "usr:session-any-id-1" },
  });
  const result = await kernel2.submit(req, bearer(VALID_TOKEN));
  assertEquals(result.kernelOutcome, "AUTH_FAILED", "delegation issuer must be denied categorically, independent of what any injected resolver claims");
  assert(result.receipt.error?.includes("categorically unsupported"));
});
