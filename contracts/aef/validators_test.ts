/**
 * Contract test matrix (Section 21) + fuzz-lite cases (Section 22) +
 * cross-domain examples (Section 24) for the AEF contract foundation.
 *
 * Every VALID case must return { ok: true }.
 * Every INVALID case must return { ok: false } -- fail-closed is the
 * only acceptable outcome for anything this suite labels invalid.
 */
import { assert, assertFalse } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  validateActor,
  validateDelegationEnvelope,
  validateExecutionReceipt,
  validateExecutionRequest,
  validateHumanGateRecord,
  validatePolicySignal,
  validateRequestAgainstDelegation,
} from "./validators.ts";
import {
  DelegationEnvelope,
  ExecutionRequest,
  InMemoryNonceStore,
  InMemoryRequestIdStore,
} from "./types.ts";

const NOW = new Date("2026-09-18T12:00:00.000Z");
const FUTURE = new Date("2026-09-18T13:00:00.000Z").toISOString();
const PAST = new Date("2026-09-18T11:00:00.000Z").toISOString();
// MODULE-PORTFOLIO-ARCHITECTURE-01 -- the F-08 and N-04 regression tests
// below deliberately omit/garble `opts.now`, so the validator falls back to
// the REAL clock. They previously reused FUTURE (a fixed 2026-09-18T13:00Z
// instant), which made them fail deterministically once that instant passed
// (the validator was right to reject an expired REQUESTED gate). Real-clock
// tests use fixed instants far enough in the future to stay deterministic.
const REAL_CLOCK_FUTURE = "2099-01-01T00:00:00.000Z";
const REAL_CLOCK_PAST = "2026-09-18T11:55:00.000Z";
function realClockRequest(): Record<string, unknown> {
  return baseRequest({ requested_at: REAL_CLOCK_PAST, expires_at: REAL_CLOCK_FUTURE });
}

function uuid(seed: string): string {
  // Deterministic, valid-shaped UUID v4 for reproducible fixtures.
  const hex = seed.padEnd(32, "0").slice(0, 32).replace(/[^0-9a-f]/gi, "0");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

function baseRequest(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    contract_version: "1.0",
    request_id: uuid("req1"),
    requested_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    actor: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" },
    intent: "Generate a market strategy summary",
    domain: "core",
    action: "core.generate_strategy",
    ...overrides,
  };
}

function assertValid(result: { ok: boolean; errors?: string[] }, label: string) {
  assert(result.ok, `${label}: expected VALID but got errors: ${JSON.stringify((result as { errors?: string[] }).errors)}`);
}
function assertInvalid(result: { ok: boolean }, label: string) {
  assertFalse(result.ok, `${label}: expected INVALID (fail-closed) but was accepted`);
}

// =======================================================================
// SECTION 21 -- REQUIRED CONTRACT TEST MATRIX
// =======================================================================

Deno.test("1. VALID -- minimal valid user request", () => {
  const r = validateExecutionRequest(baseRequest(), { now: NOW });
  assertValid(r, "case 1");
});

Deno.test("2. VALID -- valid service-shaped request", () => {
  const r = validateExecutionRequest(
    baseRequest({ actor: { type: "service", id: "svc-scheduler", auth_ref: "svc:cron-job-01" } }),
    { now: NOW },
  );
  assertValid(r, "case 2");
});

Deno.test("3. VALID -- valid informational/read-only request", () => {
  const r = validateExecutionRequest(
    baseRequest({ action: "core.decision_center.read_summary", intent: "Read the current executive summary" }),
    { now: NOW },
  );
  assertValid(r, "case 3");
});

Deno.test("4. VALID -- supported version (1.0)", () => {
  const r = validateExecutionRequest(baseRequest({ contract_version: "1.0" }), { now: NOW });
  assertValid(r, "case 4");
});

Deno.test("5. VALID -- valid expiration (in the future relative to now)", () => {
  const r = validateExecutionRequest(baseRequest({ expires_at: FUTURE }), { now: NOW });
  assertValid(r, "case 5");
});

Deno.test("6. INVALID -- missing version", () => {
  const req = baseRequest();
  delete (req as Record<string, unknown>).contract_version;
  assertInvalid(validateExecutionRequest(req, { now: NOW }), "case 6");
});

Deno.test("7. INVALID -- unsupported version", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ contract_version: "0.9" }), { now: NOW }), "case 7");
});

Deno.test("8. INVALID -- expired request", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ expires_at: PAST }), { now: NOW }), "case 8");
});

Deno.test("9. INVALID -- malformed request_id", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ request_id: "not-a-uuid" }), { now: NOW }), "case 9");
});

Deno.test("10. INVALID -- duplicate/invalid nonce (delegation)", () => {
  const store = new InMemoryNonceStore();
  const envelope = (overrides: Record<string, unknown> = {}) => ({
    contract_version: "1.0",
    delegation_id: uuid("del1"),
    issuer: { type: "service", id: "ive", auth_ref: "svc:ive-core" },
    subject: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" },
    audience: "aef.core",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-0123456789abcdef",
    purpose: "Generate a strategy on behalf of user-42",
    scope: ["core.generate_strategy"],
    request_binding: uuid("req1"),
    auth_assertion_ref: "assertion-ref-1",
    ...overrides,
  });
  // validateDelegationEnvelope now atomically consumes the nonce via
  // tryConsume() internally (Finding F-05) -- the first call both checks
  // AND records it, so no separate manual store.record() step exists or
  // is needed; calling it a second time with the same nonce is the
  // replay itself.
  const first = validateDelegationEnvelope(envelope(), { now: NOW, nonceStore: store });
  assertValid(first, "case 10 (first use)");
  const replayed = validateDelegationEnvelope(envelope({ delegation_id: uuid("del2") }), { now: NOW, nonceStore: store });
  assertInvalid(replayed, "case 10 (replay)");
});

Deno.test("11. INVALID -- unknown authority-shaped field at top level", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ superuser: true }), { now: NOW }), "case 11");
});

Deno.test("12. INVALID -- is_admin=true nested in parameters", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ parameters: { is_admin: true } }), { now: NOW }),
    "case 12",
  );
});

Deno.test("13. INVALID -- role=admin nested in metadata", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ metadata: { role: "admin" } }), { now: NOW }),
    "case 13",
  );
});

Deno.test("14. INVALID -- service_role=true", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ parameters: { service_role: true } }), { now: NOW }),
    "case 14",
  );
});

Deno.test("15. INVALID -- skip_checks=true", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ parameters: { skip_checks: true } }), { now: NOW }),
    "case 15",
  );
});

Deno.test("16. INVALID -- human_approved=true", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ parameters: { human_approved: true } }), { now: NOW }),
    "case 16",
  );
});

Deno.test("17. INVALID -- authoritative subscription tier (plan=premium)", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ parameters: { plan: "premium" } }), { now: NOW }),
    "case 17",
  );
});

Deno.test("18. INVALID -- tenant authority injection (tenant_id)", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ parameters: { tenant_id: "tenant-1" } }), { now: NOW }),
    "case 18 (tenant_id in parameters)",
  );
  assertInvalid(
    validateExecutionRequest(baseRequest({ tenant_id: "tenant-1" } as Record<string, unknown>), { now: NOW }),
    "case 18 (tenant_id top-level, also an unknown field)",
  );
});

Deno.test("19. INVALID -- malformed audience", () => {
  const badDelegation = {
    contract_version: "1.0",
    delegation_id: uuid("del3"),
    issuer: { type: "service", id: "ive", auth_ref: "svc:ive-core" },
    subject: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" },
    audience: "not-a-valid-audience",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-abcdefabcdefabcd",
    purpose: "test",
    scope: ["core.generate_strategy"],
    request_binding: uuid("req1"),
    auth_assertion_ref: "assertion-ref-1",
  };
  assertInvalid(validateDelegationEnvelope(badDelegation, { now: NOW }), "case 19");
});

Deno.test("20. INVALID -- mismatched audience (delegation for core used against a quant request)", () => {
  const request: ExecutionRequest = baseRequest({
    domain: "quant",
    action: "quant.controlled_live.submit_order",
    quant_execution_tier: "controlled_live",
    human_gate_ref: uuid("gate1"),
  }) as unknown as ExecutionRequest;
  const delegation: DelegationEnvelope = {
    contract_version: "1.0",
    delegation_id: uuid("del4"),
    issuer: { type: "service", id: "ive", auth_ref: "svc:ive-core" },
    subject: request.actor,
    audience: "aef.core", // wrong audience for a quant request
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-fedcbafedcbafedc",
    purpose: "test",
    scope: ["quant.controlled_live.submit_order"],
    request_binding: request.request_id,
    auth_assertion_ref: "assertion-ref-1",
  };
  assertInvalid(validateRequestAgainstDelegation(request, delegation), "case 20");
});

Deno.test("21. INVALID -- malformed actor", () => {
  assertInvalid(validateActor({ type: "user", id: "" }), "case 21 (empty id, missing auth_ref)");
  assertInvalid(validateActor({ type: "wizard", id: "x", auth_ref: "usr:x" }), "case 21 (bad type)");
});

Deno.test("22. INVALID -- user_id without trusted identity binding (missing/malformed auth_ref)", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ actor: { type: "user", id: "user-42" } }), { now: NOW }),
    "case 22 (no auth_ref)",
  );
  assertInvalid(
    validateExecutionRequest(
      baseRequest({ actor: { type: "user", id: "user-42", auth_ref: "svc:not-a-user-ref" } }),
      { now: NOW },
    ),
    "case 22 (auth_ref wrong namespace for actor type)",
  );
});

Deno.test("23. INVALID -- missing required delegation for a high-risk quant action", () => {
  // Contract-level: request itself must at least require human_gate_ref;
  // full delegation *presence* enforcement (delegation_ref resolving to a
  // real, matching DelegationEnvelope) is an AEF-side responsibility this
  // mission does not implement -- but the request-level guard is tested
  // here as the part this contract DOES own.
  assertInvalid(
    validateExecutionRequest(
      baseRequest({
        domain: "quant",
        action: "quant.controlled_live.submit_order",
        quant_execution_tier: "controlled_live",
        // human_gate_ref deliberately omitted
      }),
      { now: NOW },
    ),
    "case 23",
  );
});

Deno.test("24. INVALID -- unknown domain", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ domain: "wonderland", action: "wonderland.do_thing" }), { now: NOW }),
    "case 24",
  );
});

Deno.test("25. INVALID -- malformed parameters (not an object)", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ parameters: "not-an-object" }), { now: NOW }), "case 25");
});

Deno.test("26. INVALID -- replayed consequential request (request_id seen before)", () => {
  const store = new InMemoryRequestIdStore();
  const req = baseRequest();
  // validateExecutionRequest now atomically consumes request_id via
  // tryConsume() internally (Finding F-05) -- the first successful
  // validation already records it, no separate manual step needed.
  const first = validateExecutionRequest(req, { now: NOW, requestIdStore: store });
  assertValid(first, "case 26 (first time)");
  const second = validateExecutionRequest(req, { now: NOW, requestIdStore: store });
  assertInvalid(second, "case 26 (replay)");
});

Deno.test("27. INVALID -- future/unrecognized contract version", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ contract_version: "2.0" }), { now: NOW }), "case 27");
});

Deno.test("28. INVALID -- arbitrary extra field attempting privilege injection", () => {
  assertInvalid(
    validateExecutionRequest(baseRequest({ authorization_level: "root" }), { now: NOW }),
    "case 28",
  );
});

// =======================================================================
// Additional contract-object coverage (DelegationEnvelope, HumanGateRecord,
// PolicySignal, ExecutionReceipt) not fully exercised by the 28-case
// ExecutionRequest matrix above.
// =======================================================================

Deno.test("DelegationEnvelope: bare '*' scope is rejected even though it would structurally validate as a string array", () => {
  const bad = {
    contract_version: "1.0",
    delegation_id: uuid("del5"),
    issuer: { type: "service", id: "ive", auth_ref: "svc:ive-core" },
    subject: { type: "user", id: "u1", auth_ref: "usr:s1" },
    audience: "aef.core",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-1111111111111111",
    purpose: "test",
    scope: ["*"],
    request_binding: uuid("req1"),
    auth_assertion_ref: "ref-1",
  };
  assertInvalid(validateDelegationEnvelope(bad, { now: NOW }), "bare wildcard scope");
});

Deno.test("HumanGateRecord: human_approved cannot be smuggled onto the gate record itself", () => {
  const bad = {
    contract_version: "1.0",
    gate_id: uuid("gate2"),
    request_id: uuid("req1"),
    action: "quant.controlled_live.submit_order",
    state: "AUTHORIZED",
    approver: { type: "user", id: "approver-1", auth_ref: "usr:s2" },
    decided_at: "2026-09-18T11:59:00.000Z",
    audit_ref: "audit-log-entry-1",
    expires_at: FUTURE,
    human_approved: true, // prohibited field, must reject even on an otherwise-valid AUTHORIZED record
  };
  assertInvalid(validateHumanGateRecord(bad, { now: NOW }), "human_approved smuggled onto gate record");
});

Deno.test("HumanGateRecord: AUTHORIZED without approver/decided_at/audit_ref is rejected", () => {
  const bad = {
    contract_version: "1.0",
    gate_id: uuid("gate3"),
    request_id: uuid("req1"),
    action: "quant.controlled_live.submit_order",
    state: "AUTHORIZED",
    expires_at: FUTURE,
  };
  assertInvalid(validateHumanGateRecord(bad, { now: NOW }), "AUTHORIZED missing approver");
});

Deno.test("HumanGateRecord: approver type='system' is never valid", () => {
  const bad = {
    contract_version: "1.0",
    gate_id: uuid("gate4"),
    request_id: uuid("req1"),
    action: "quant.controlled_live.submit_order",
    state: "REJECTED",
    approver: { type: "system", id: "system", auth_ref: "system:internal" },
    decided_at: "2026-09-18T11:59:00.000Z",
    audit_ref: "audit-log-entry-2",
    expires_at: FUTURE,
  };
  assertInvalid(validateHumanGateRecord(bad, { now: NOW }), "system approver");
});

Deno.test("HumanGateRecord: illegal state transition (EXECUTED without ever being AUTHORIZED)", () => {
  const record = {
    contract_version: "1.0",
    gate_id: uuid("gate5"),
    request_id: uuid("req1"),
    action: "quant.controlled_live.submit_order",
    state: "EXECUTED",
    expires_at: FUTURE,
  };
  assertInvalid(
    validateHumanGateRecord(record, { now: NOW, previousState: "REQUESTED" }),
    "REQUESTED -> EXECUTED is not a legal transition",
  );
});

Deno.test("PolicySignal: IVE source claiming AUTHORITATIVE is rejected", () => {
  const bad = {
    contract_version: "1.0",
    kind: "AUTHORITATIVE",
    source: "ive.reasoning",
    signal: "policy_decision: ALLOW",
    computed_at: "2026-09-18T11:55:00.000Z",
  };
  assertInvalid(validatePolicySignal(bad), "IVE claiming authoritative");
});

Deno.test("PolicySignal: IVE source as ADVISORY is accepted", () => {
  const good = {
    contract_version: "1.0",
    kind: "ADVISORY",
    source: "ive.reasoning",
    signal: "recommended_risk_level: low",
    computed_at: "2026-09-18T11:55:00.000Z",
  };
  assertValid(validatePolicySignal(good), "IVE advisory");
});

Deno.test("PolicySignal: allow-listed source may issue AUTHORITATIVE", () => {
  const good = {
    contract_version: "1.0",
    kind: "AUTHORITATIVE",
    source: "aef.policy_engine",
    signal: "policy_decision: DENY",
    computed_at: "2026-09-18T11:55:00.000Z",
  };
  assertValid(validatePolicySignal(good), "aef.policy_engine authoritative");
});

Deno.test("ExecutionReceipt: DENIED policy_decision must have outcome=NOT_EXECUTED", () => {
  const bad = {
    contract_version: "1.0",
    receipt_id: uuid("rcpt1"),
    request_id: uuid("req1"),
    actor: { type: "user", id: "u1", auth_ref: "usr:s1" },
    action: "core.generate_strategy",
    policy_decision: "DENIED",
    started_at: "2026-09-18T11:55:00.000Z",
    outcome: "SUCCESS", // contradiction: denied but claims success
  };
  assertInvalid(validateExecutionReceipt(bad), "DENIED with SUCCESS outcome");
});

// =======================================================================
// SECTION 22 -- FUZZ-LITE / PROPERTY-STYLE CASES
// =======================================================================

Deno.test("fuzz: unknown top-level field", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ totally_unexpected_field: 1 }), { now: NOW }), "fuzz unknown field");
});

Deno.test("fuzz: type confusion -- domain as a number", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ domain: 42 }), { now: NOW }), "fuzz type confusion domain");
});

Deno.test("fuzz: type confusion -- actor as a string", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ actor: "user-42" }), { now: NOW }), "fuzz actor as string");
});

Deno.test("fuzz: null in required field", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ request_id: null }), { now: NOW }), "fuzz null request_id");
});

Deno.test("fuzz: nested object where a string is expected (intent)", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ intent: { nested: "object" } }), { now: NOW }), "fuzz nested intent");
});

Deno.test("fuzz: oversized string in intent", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ intent: "x".repeat(10000) }), { now: NOW }), "fuzz oversized intent");
});

Deno.test("fuzz: unexpected array where an object is expected (parameters)", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ parameters: ["a", "b"] }), { now: NOW }), "fuzz array parameters");
});

Deno.test("fuzz: unicode / homoglyph field name attempting to dodge the prohibited-field scanner", () => {
  const caseVariant = validateExecutionRequest(baseRequest({ parameters: { RoLe: "admin" } }), { now: NOW });
  assertInvalid(caseVariant, "fuzz ASCII case-variant field name (RoLe) must still be caught");
});

Deno.test("fuzz: duplicate semantic field via different casing does not create a bypass (IS_ADMIN)", () => {
  assertInvalid(validateExecutionRequest(baseRequest({ parameters: { IS_ADMIN: true } }), { now: NOW }), "fuzz IS_ADMIN uppercase");
});

Deno.test("fuzz: empty object as request", () => {
  assertInvalid(validateExecutionRequest({}, { now: NOW }), "fuzz empty object");
});

Deno.test("fuzz: array instead of object as request", () => {
  assertInvalid(validateExecutionRequest([1, 2, 3], { now: NOW }), "fuzz array as request");
});

Deno.test("fuzz: primitive instead of object as request", () => {
  assertInvalid(validateExecutionRequest("just a string", { now: NOW }), "fuzz string as request");
  assertInvalid(validateExecutionRequest(42, { now: NOW }), "fuzz number as request");
  assertInvalid(validateExecutionRequest(null, { now: NOW }), "fuzz null as request");
  assertInvalid(validateExecutionRequest(undefined, { now: NOW }), "fuzz undefined as request");
});

// =======================================================================
// SECTION 24 -- CROSS-DOMAIN EXAMPLES (Core / Quant / Impact)
// =======================================================================

Deno.test("cross-domain: Core example validates", async () => {
  const fixture = JSON.parse(await Deno.readTextFile(new URL("./fixtures/examples/core-example.json", import.meta.url)));
  assertValid(validateExecutionRequest(fixture, { now: NOW }), "core example");
});

Deno.test("cross-domain: Quant example (research tier, low risk) validates", async () => {
  const fixture = JSON.parse(await Deno.readTextFile(new URL("./fixtures/examples/quant-example.json", import.meta.url)));
  assertValid(validateExecutionRequest(fixture, { now: NOW }), "quant example");
});

Deno.test("cross-domain: Impact example validates", async () => {
  const fixture = JSON.parse(await Deno.readTextFile(new URL("./fixtures/examples/impact-example.json", import.meta.url)));
  assertValid(validateExecutionRequest(fixture, { now: NOW }), "impact example");
});

// =======================================================================
// CODEX ADVERSARIAL REVIEW REGRESSION TESTS (Findings F-01 through F-07)
// Each test below proves the specific bypass Codex demonstrated is now
// closed. See the mission report's "Claude Reconciliation" section for
// the full writeup of each finding.
// =======================================================================

Deno.test("F-01 regression: alias field names not on the literal list are still caught after normalization", () => {
  const aliases: Record<string, unknown>[] = [
    { tenantId: "org-7" },
    { workspace_id: "ws-1" },
    { subscriptionLevel: "premium" },
    { paid: true },
    { execution_mode: "live" },
    { "Tenant-Id": "org-7" },
  ];
  for (const parameters of aliases) {
    assertInvalid(
      validateExecutionRequest(baseRequest({ parameters }), { now: NOW }),
      `F-01: alias ${JSON.stringify(parameters)} must be rejected`,
    );
  }
});

Deno.test("F-02 regression: delegation issuer must be Actor-shaped with a resolvable auth_ref, and must not be type=user", () => {
  const base = {
    contract_version: "1.0",
    delegation_id: uuid("delf2"),
    subject: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" },
    audience: "aef.core",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-f02-aaaaaaaaaaaa",
    purpose: "test",
    scope: ["core.generate_strategy"],
    request_binding: uuid("req1"),
    auth_assertion_ref: "assertion-ref-1",
  };
  // Bare string issuer (the pre-fix shape) must now be rejected outright.
  assertInvalid(
    validateDelegationEnvelope({ ...base, issuer: "ive" }, { now: NOW }),
    "F-02: bare string issuer must be rejected",
  );
  // A self-declared issuer claiming to BE an authoritative component,
  // without a resolvable auth_ref, is still rejected (auth_ref presence
  // is required by validateActor regardless of the claimed id).
  assertInvalid(
    validateDelegationEnvelope({ ...base, issuer: { type: "service", id: "aef_policy_engine" } }, { now: NOW }),
    "F-02: issuer missing auth_ref must be rejected",
  );
  // type=user is never a valid issuer.
  assertInvalid(
    validateDelegationEnvelope(
      { ...base, issuer: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" } },
      { now: NOW },
    ),
    "F-02: type=user issuer must be rejected",
  );
  // A properly Actor-shaped service issuer with an auth_ref is accepted.
  assertValid(
    validateDelegationEnvelope(
      { ...base, issuer: { type: "service", id: "ive", auth_ref: "svc:ive-core" } },
      { now: NOW },
    ),
    "F-02: well-formed service issuer must be accepted",
  );
});

Deno.test("F-03 regression: audience prefix confusion (aef.coreextra) no longer satisfies domain=core", () => {
  const request: ExecutionRequest = baseRequest() as unknown as ExecutionRequest;
  const delegation: DelegationEnvelope = {
    contract_version: "1.0",
    delegation_id: uuid("delf3"),
    issuer: { type: "service", id: "ive", auth_ref: "svc:ive-core" },
    subject: request.actor,
    audience: "aef.coreextra", // must NOT satisfy domain='core' via naive prefix matching
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: FUTURE,
    nonce: "nonce-f03-aaaaaaaaaaaa",
    purpose: "test",
    scope: ["core.generate_strategy"],
    request_binding: request.request_id,
    auth_assertion_ref: "assertion-ref-1",
  };
  assertInvalid(validateRequestAgainstDelegation(request, delegation), "F-03: aef.coreextra must not match domain=core");

  // Sanity: the legitimate boundary form (a genuine subcomponent) still works.
  const goodDelegation = { ...delegation, audience: "aef.core.action_engine" };
  assertValid(validateRequestAgainstDelegation(request, goodDelegation), "F-03: aef.core.action_engine must still match domain=core");
});

Deno.test("F-04 regression: an AUTHORIZED HumanGateRecord past its own expiry is rejected", () => {
  const staleAuthorized = {
    contract_version: "1.0",
    gate_id: uuid("gatef4"),
    request_id: uuid("req1"),
    action: "quant.controlled_live.submit_order",
    state: "AUTHORIZED",
    approver: { type: "user", id: "approver-1", auth_ref: "usr:session-f4" },
    decided_at: "2026-09-18T10:00:00.000Z",
    audit_ref: "audit-log-entry-f4",
    expires_at: PAST, // already expired relative to NOW
  };
  assertInvalid(validateHumanGateRecord(staleAuthorized, { now: NOW }), "F-04: stale AUTHORIZED gate must be rejected");

  // Sanity: the same record with a future expiry is accepted.
  const freshAuthorized = { ...staleAuthorized, expires_at: FUTURE };
  assertValid(validateHumanGateRecord(freshAuthorized, { now: NOW }), "F-04: non-expired AUTHORIZED gate must be accepted");
});

Deno.test("F-05 regression: nonce/request_id consumption is atomic (tryConsume), not check-then-record", () => {
  const nonceStore = new InMemoryNonceStore();
  assert(nonceStore.tryConsume("shared-nonce-aaaaaaaaaa"), "F-05: first consume must succeed");
  assertFalse(nonceStore.tryConsume("shared-nonce-aaaaaaaaaa"), "F-05: second consume of the same value must fail -- this is the atomic replay defense");

  const reqIdStore = new InMemoryRequestIdStore();
  assert(reqIdStore.tryConsume(uuid("f05req")), "F-05: first request_id consume must succeed");
  assertFalse(reqIdStore.tryConsume(uuid("f05req")), "F-05: second request_id consume must fail");
});

Deno.test("F-06 regression: unknown fields are rejected on HumanGateRecord, PolicySignal, and ExecutionReceipt", () => {
  assertInvalid(
    validateHumanGateRecord({
      contract_version: "1.0",
      gate_id: uuid("gatef6"),
      request_id: uuid("req1"),
      action: "quant.controlled_live.submit_order",
      state: "REQUESTED",
      expires_at: FUTURE,
      is_authoritative: true, // unknown field
    }, { now: NOW }),
    "F-06: HumanGateRecord unknown field must be rejected",
  );
  assertInvalid(
    validatePolicySignal({
      contract_version: "1.0",
      kind: "ADVISORY",
      source: "ive.reasoning",
      signal: "test",
      computed_at: "2026-09-18T11:55:00.000Z",
      is_authoritative: true, // unknown field
    }),
    "F-06: PolicySignal unknown field must be rejected",
  );
  assertInvalid(
    validateExecutionReceipt({
      contract_version: "1.0",
      receipt_id: uuid("rcptf6"),
      request_id: uuid("req1"),
      actor: { type: "user", id: "u1", auth_ref: "usr:s1" },
      action: "core.generate_strategy",
      policy_decision: "ALLOWED",
      started_at: "2026-09-18T11:55:00.000Z",
      outcome: "SUCCESS",
      is_authoritative: true, // unknown field
    }),
    "F-06: ExecutionReceipt unknown field must be rejected",
  );
});

Deno.test("F-07 regression: quant_execution_tier can no longer disagree with the tier named in the action itself", () => {
  // The attack Codex demonstrated: claim tier='research' (no human gate
  // required) while the action itself names 'controlled_live' (a
  // real-money action).
  assertInvalid(
    validateExecutionRequest(
      baseRequest({
        domain: "quant",
        action: "quant.controlled_live.submit_order",
        quant_execution_tier: "research",
      }),
      { now: NOW },
    ),
    "F-07: mismatched tier vs. action namespace must be rejected",
  );

  // Sanity: matching tier + action + human_gate_ref is accepted.
  assertValid(
    validateExecutionRequest(
      baseRequest({
        domain: "quant",
        action: "quant.controlled_live.submit_order",
        quant_execution_tier: "controlled_live",
        human_gate_ref: uuid("gatef7"),
      }),
      { now: NOW },
    ),
    "F-07: matching tier + human_gate_ref must be accepted",
  );
});

Deno.test("F-01 regression (round 2): non-ASCII-identifier field keys are rejected outright, closing the homoglyph bypass class", () => {
  // Cyrillic 'а' (U+0430 CYRILLIC SMALL LETTER A) in place of Latin 'a' --
  // visually indistinguishable, but a genuinely distinct key that
  // normalizeFieldName's case/separator folding alone does not catch
  // (Codex adversarial review, round 2, Finding F-01 partial). Rather than
  // attempt full Unicode confusable-skeleton normalization, the fix
  // rejects ANY key that is not a plain ASCII identifier, anywhere in
  // parameters/constraints/metadata, regardless of what it appears to say.
  const homoglyphKey = "pаid"; // "paid" with Cyrillic 'а'
  assertInvalid(
    validateExecutionRequest(baseRequest({ parameters: { [homoglyphKey]: true } }), { now: NOW }),
    "F-01: Cyrillic-homoglyph key must be rejected as a non-ASCII identifier",
  );

  // Sanity: a legitimate plain-ASCII parameter name is unaffected.
  assertValid(
    validateExecutionRequest(baseRequest({ parameters: { topic: "quarterly report" } }), { now: NOW }),
    "F-01: legitimate ASCII parameter name must still be accepted",
  );
});

Deno.test("F-02 regression (round 2): a bare or near-empty auth_ref suffix is rejected as degenerate", () => {
  // Codex adversarial review (round 2, Finding F-02 partial): an
  // Actor-shaped issuer/actor with a syntactically-valid-but-meaningless
  // auth_ref (e.g. 'svc:' or 'svc:x') previously passed. This is a
  // partial, proportionate mitigation only -- it cannot prove auth_ref
  // resolves to anything real (no crypto in scope, Section 7) -- but it
  // does remove the most trivial degenerate values.
  assertInvalid(
    validateActor({ type: "service", id: "svc-x", auth_ref: "svc:x" }),
    "F-02: near-empty auth_ref suffix ('svc:x') must be rejected",
  );
  assertInvalid(
    validateActor({ type: "service", id: "svc-x", auth_ref: "svc:" }),
    "F-02: bare auth_ref prefix with empty suffix must be rejected",
  );
  assertInvalid(
    validateActor({ type: "user", id: "u1", auth_ref: "usr:a" }),
    "F-02: near-empty user auth_ref suffix must be rejected",
  );
  assertValid(
    validateActor({ type: "service", id: "svc-x", auth_ref: "svc:ive-core" }),
    "F-02: a substantive auth_ref suffix (>= 8 chars) must still be accepted",
  );
});

Deno.test("F-07 regression (round 2): a non-standard quant action segment bypasses no longer possible", () => {
  // Codex adversarial review (round 2, Finding F-07 partial): the round-1
  // fix only checked tier-vs-action consistency WHEN the action's second
  // segment happened to already be a recognized tier name -- a
  // non-standard segment like 'live' (not one of the five known tiers)
  // bypassed the check entirely. Fixed by making the taxonomy mandatory
  // for every domain='quant' action, not merely checked when convenient.
  assertInvalid(
    validateExecutionRequest(
      baseRequest({
        domain: "quant",
        action: "quant.live.submit_order",
        quant_execution_tier: "research",
      }),
      { now: NOW },
    ),
    "F-07: a quant action whose second segment is not a known tier name must be rejected outright",
  );
});

Deno.test("F-08 regression (round 2): explicit null for the options parameter behaves like omitting it entirely", () => {
  // Codex adversarial review (round 2, Finding F-08/N-01): a default
  // parameter value only applies when the caller passes `undefined`, not
  // when they explicitly pass `null` -- validateHumanGateRecord(record,
  // null) previously threw a TypeError instead of returning a normal
  // { ok: false } / { ok: true } result. Fixed by normalizing opts ??
  // {} at the top of every function taking an options object.
  const validGate = {
    contract_version: "1.0",
    gate_id: uuid("gatef8"),
    request_id: uuid("req1"),
    action: "core.generate_strategy",
    state: "REQUESTED",
    expires_at: REAL_CLOCK_FUTURE,
  };
  // deno-lint-ignore no-explicit-any
  assertValid(validateHumanGateRecord(validGate, null as any), "F-08: null opts on validateHumanGateRecord must not throw");
  // deno-lint-ignore no-explicit-any
  assertValid(validateExecutionRequest(realClockRequest(), null as any), "F-08: null opts on validateExecutionRequest must not throw");

  const validDelegation: Record<string, unknown> = {
    contract_version: "1.0",
    delegation_id: uuid("delf8"),
    issuer: { type: "service", id: "ive", auth_ref: "svc:ive-core" },
    subject: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" },
    audience: "aef.core",
    issued_at: REAL_CLOCK_PAST,
    expires_at: REAL_CLOCK_FUTURE,
    nonce: "nonce-f8-aaaaaaaaaaaa",
    purpose: "test",
    scope: ["core.generate_strategy"],
    request_binding: uuid("req1"),
    auth_assertion_ref: "ref-f8",
  };
  // deno-lint-ignore no-explicit-any
  assertValid(validateDelegationEnvelope(validDelegation, null as any), "F-08: null opts on validateDelegationEnvelope must not throw");
});

Deno.test("N-04 regression (round 3): a malformed opts.now does not throw, falls back to real time", () => {
  // Codex adversarial review (round 3, Finding N-04): a type-confused
  // caller passing e.g. opts.now = "not-a-Date" (a string) reached
  // `now.getTime()` downstream and threw a TypeError instead of getting
  // back a normal ValidationResult. Fixed via resolveNow() in
  // validators.ts, which falls back to the real current time for any
  // non-Date or Invalid Date value, exactly as if `now` had been omitted.
  // deno-lint-ignore no-explicit-any
  assertValid(validateExecutionRequest(realClockRequest(), { now: "not-a-Date" as any }), "N-04: string now on validateExecutionRequest must not throw");
  // deno-lint-ignore no-explicit-any
  assertValid(validateExecutionRequest(realClockRequest(), { now: new Date("not-a-real-date") as any }), "N-04: Invalid Date now on validateExecutionRequest must not throw");

  const gate = {
    contract_version: "1.0",
    gate_id: uuid("gaten04"),
    request_id: uuid("req1"),
    action: "core.generate_strategy",
    state: "REQUESTED",
    expires_at: REAL_CLOCK_FUTURE,
  };
  // deno-lint-ignore no-explicit-any
  assertValid(validateHumanGateRecord(gate, { now: "not-a-Date" as any }), "N-04: string now on validateHumanGateRecord must not throw");
});

// =======================================================================
// SECTION 16 -- NEGATIVE-SPACE TEST: no execution capability exists here
// =======================================================================

Deno.test("no direct-execution API exists in this module (Section 16 / NO_DIRECT_EXECUTION.md)", async () => {
  const validatorsModule = await import("./validators.ts");
  const typesModule = await import("./types.ts");
  const forbiddenNames = ["execute", "run", "dispatch", "invoke", "call"];
  for (const name of Object.keys(validatorsModule)) {
    assertFalse(
      forbiddenNames.some((f) => name.toLowerCase().includes(f)),
      `validators.ts exports '${name}', which looks execution-shaped -- this module must only validate, never execute`,
    );
  }
  for (const name of Object.keys(typesModule)) {
    assertFalse(
      forbiddenNames.some((f) => name.toLowerCase().includes(f)),
      `types.ts exports '${name}', which looks execution-shaped`,
    );
  }
});
