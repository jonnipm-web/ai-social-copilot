/**
 * AefGovernance without a database: the store is a scripted transport, so
 * these tests pin the service's own fail-closed behavior (store down,
 * malformed replies, protocol drift, identity failures). The state machine
 * itself is only tested against real PostgreSQL (governance_pg_test.ts) —
 * there is deliberately no second, in-memory implementation of it.
 */
import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import type { ExecutionRequest } from "../../contracts/aef/types.ts";
import { AefIdentityResolver, type UserVerifier } from "../identity_resolver.ts";
import { ToolRegistry } from "../tool_registry.ts";
import type { IdentityResolver } from "../types.ts";
import { AefGovernance, type GovernanceResult } from "./governance.ts";
import { MOCK_REVERSIBLE_TOOL, MockEffectLedger, registerMockEffectTools } from "./mock_effect_tool.ts";
import { type AefRpcName, PostgresAefStore, type RpcTransport } from "./store.ts";

const USER = "a1000000-0000-4000-8000-00000000000a";
const TOKEN = { kind: "bearer_jwt" as const, token: "tok-a" };
const OP = "a4000000-0000-4000-8000-000000000001";
const HEX = (c: string) => c.repeat(64);

class ScriptedTransport implements RpcTransport {
  calls: AefRpcName[] = [];
  constructor(private readonly script: Partial<Record<AefRpcName, (args: Record<string, unknown>) => unknown>>) {}
  call(fn: AefRpcName, args: Record<string, unknown>): Promise<unknown> {
    this.calls.push(fn);
    const handler = this.script[fn];
    if (!handler) return Promise.resolve({ ok: true });
    try {
      return Promise.resolve(handler(args));
    } catch (err) {
      return Promise.reject(err);
    }
  }
}

const verifier: UserVerifier = { verify: (t) => Promise.resolve(t === "tok-a" ? { ok: true, userId: USER } : { ok: false, reason: "INVALID", detail: "x" }) };

function setup(script: ConstructorParameters<typeof ScriptedTransport>[0], identity?: IdentityResolver) {
  const transport = new ScriptedTransport(script);
  const ledger = new MockEffectLedger();
  const registry = new ToolRegistry();
  registerMockEffectTools(registry, ledger, () => "SUCCEED");
  const gov = new AefGovernance({ identityResolver: identity ?? new AefIdentityResolver(verifier), toolRegistry: registry, store: new PostgresAefStore(transport) });
  return { gov, transport, ledger, registry };
}

function request(extra: Record<string, unknown> = {}): ExecutionRequest {
  const now = Date.now();
  return {
    contract_version: "1.0",
    request_id: crypto.randomUUID(),
    requested_at: new Date(now).toISOString(),
    expires_at: new Date(now + 60_000).toISOString(),
    actor: { type: "user", id: USER, auth_ref: `usr:${USER}` },
    intent: "unit",
    domain: "internal",
    action: MOCK_REVERSIBLE_TOOL,
    parameters: { n: 1 },
    idempotency_key: "k-1",
    metadata: { note: "never reaches the tool" },
    ...extra,
  } as ExecutionRequest;
}

function opView(state: string, payloadHash: string, extra: Record<string, unknown> = {}) {
  return {
    operation: {
      operation_id: OP, state, state_reason: null, action: MOCK_REVERSIBLE_TOOL, tool_id: MOCK_REVERSIBLE_TOOL,
      action_class: "REVERSIBLE", binding_hash: HEX("b"), payload_hash: payloadHash, policy_version: "p", risk_version: "r",
      requires_human_gate: false, attempt_count: state === "AUTHORIZED" ? 0 : 1, expires_at: "2099-01-01T00:00:00.000000Z", ...extra,
    },
    gate: null,
    receipt: null,
  };
}

/** Echo the payload hash the service computed, like the real DB does. */
const registerAuthorized = (args: Record<string, unknown>) => ({ ok: true, outcome: "CREATED", ...opView("AUTHORIZED", String(args.payload_hash)) });
const status = (r: GovernanceResult) => r.status === "DENIED" || r.status === "OUTCOME_UNCONFIRMED" ? `${r.status}:${r.code}` : r.status;

Deno.test("GU-01 store down at registration → STORE_UNAVAILABLE, tool never runs", async () => {
  const { gov, ledger } = setup({ aef_register_operation: () => { throw new Error("down"); } });
  assertEquals(status(await gov.submit(request(), TOKEN)), "DENIED:STORE_UNAVAILABLE");
  assertEquals(ledger.invocations.size, 0);
});

Deno.test("GU-02 malformed or drifting store replies fail closed (STORE_PROTOCOL_ERROR), tool never runs", async () => {
  const replies: unknown[] = [
    null,
    "ok",
    { ok: "true" },
    { ok: false, code: "SOMETHING_NEW" },
    { ok: true, outcome: "CREATED" },
    { ok: true, outcome: "MAYBE", ...opView("AUTHORIZED", HEX("a")) },
    { ok: true, outcome: "CREATED", ...opView("DONE_ISH", HEX("a")) },
    { ok: true, outcome: "CREATED", ...opView("AUTHORIZED", HEX("a"), { attempt_count: 2 }) },
  ];
  for (const reply of replies) {
    const { gov, ledger } = setup({ aef_register_operation: () => reply });
    assertEquals(status(await gov.submit(request(), TOKEN)), "DENIED:STORE_PROTOCOL_ERROR", JSON.stringify(reply));
    assertEquals(ledger.invocations.size, 0);
  }
});

Deno.test("GU-03 a reply bound to a different payload hash is refused", async () => {
  // Everything downstream would succeed: only the hash check stops execution.
  const { gov, ledger, transport } = setup({
    aef_register_operation: () => ({ ok: true, outcome: "CREATED", ...opView("AUTHORIZED", HEX("e")) }),
    aef_claim_execution: () => ({ ok: true, execution_token: "a5000000-0000-4000-8000-000000000001", ...opView("EXECUTING", HEX("e")) }),
  });
  assertEquals(status(await gov.submit(request(), TOKEN)), "DENIED:STORE_PROTOCOL_ERROR");
  assertEquals(ledger.invocations.size, 0);
  assertEquals(transport.calls, ["aef_register_operation"]);
});

Deno.test("GU-04 no execution without a granted claim (claim down / refused / malformed)", async () => {
  for (const claim of [() => { throw new Error("down"); }, () => ({ ok: false, code: "GATE_NOT_AUTHORIZED" }), () => ({ ok: true, ...opView("EXECUTING", HEX("a")) })]) {
    const { gov, ledger } = setup({ aef_register_operation: registerAuthorized, aef_claim_execution: claim });
    const r = await gov.submit(request(), TOKEN);
    assertEquals(r.status, "DENIED");
    assertEquals(ledger.invocations.size, 0);
  }
});

Deno.test("GU-05 tool ran but completion reply is unusable → OUTCOME_UNCONFIRMED, never success", async () => {
  let payloadHash = "";
  const { gov, ledger } = setup({
    aef_register_operation: (a) => { payloadHash = String(a.payload_hash); return registerAuthorized(a); },
    aef_claim_execution: () => ({ ok: true, execution_token: "a5000000-0000-4000-8000-000000000001", ...opView("EXECUTING", payloadHash) }),
    aef_complete_execution: () => ({ ok: true, ...opView("SUCCEEDED", payloadHash) }), // terminal without receipt
  });
  assertEquals(status(await gov.submit(request(), TOKEN)), "OUTCOME_UNCONFIRMED:STORE_PROTOCOL_ERROR");
  assertEquals(ledger.totalEffects(), 1);
  const garbled = setup({
    aef_register_operation: (a) => { payloadHash = String(a.payload_hash); return registerAuthorized(a); },
    aef_claim_execution: () => ({ ok: true, execution_token: "a5000000-0000-4000-8000-000000000001", ...opView("EXECUTING", payloadHash) }),
    aef_complete_execution: () => "garbage",
  });
  assertEquals(status(await garbled.gov.submit(request(), TOKEN)), "OUTCOME_UNCONFIRMED:STORE_PROTOCOL_ERROR");
});

Deno.test("GU-06 identity failure (invalid token, throwing resolver) stops before any store call", async () => {
  const bad = setup({});
  assertEquals(status(await bad.gov.submit(request(), { kind: "bearer_jwt", token: "nope" })), "DENIED:AUTH_FAILED");
  assertEquals(bad.transport.calls.length, 0);
  const throwing = setup({}, { resolve: () => Promise.reject(new Error("boom")) });
  assertEquals(status(await throwing.gov.submit(request(), TOKEN)), "DENIED:AUTH_FAILED");
  assertEquals(throwing.transport.calls.length, 0);
});

Deno.test("GU-07 refused requests of a verified user are audited but never registered", async () => {
  const { gov, transport } = setup({});
  assertEquals(status(await gov.submit(request({ intent: "" }), TOKEN)), "DENIED:INVALID_REQUEST");
  assertEquals(status(await gov.submit(request({ action: "internal.unknown_tool" }), TOKEN)), "DENIED:UNKNOWN_TOOL");
  assertEquals(status(await gov.submit(request({ resource: { type: "file", id: "x" } }), TOKEN)), "DENIED:RESOURCE_TYPE_UNSUPPORTED");
  assertEquals(transport.calls, ["aef_record_denial", "aef_record_denial", "aef_record_denial"]);
});

Deno.test("GU-08 audit failure on a denial never turns it into an allow", async () => {
  const { gov } = setup({ aef_record_denial: () => { throw new Error("audit down"); } });
  assertEquals(status(await gov.submit(request({ action: "internal.unknown_tool" }), TOKEN)), "DENIED:UNKNOWN_TOOL");
});

Deno.test("GU-09 decision / cancel / read inputs are strictly shaped before identity or store", async () => {
  const { gov, transport } = setup({});
  const actor = { type: "user", id: USER, auth_ref: `usr:${USER}` };
  for (const input of [
    null,
    [],
    { gate_id: OP, decision: "APPROVE", binding_hash: HEX("a"), approver: actor, state: "AUTHORIZED" },
    { gate_id: "x", decision: "APPROVE", binding_hash: HEX("a"), approver: actor },
    { gate_id: OP, decision: "YES", binding_hash: HEX("a"), approver: actor },
    { gate_id: OP, decision: "APPROVE", binding_hash: "short", approver: actor },
  ]) {
    assertEquals(status(await gov.decideGate(input, TOKEN)), "DENIED:INPUT_REJECTED", JSON.stringify(input));
  }
  assertEquals(status(await gov.cancel({ operation_id: OP, actor, subject_id: USER }, TOKEN)), "DENIED:INPUT_REJECTED");
  assertEquals(status(await gov.getOperation({ operation_id: "nope", actor }, TOKEN)), "DENIED:INPUT_REJECTED");
  assertEquals(transport.calls.length, 0);
});

Deno.test("GU-10 execution capability is claimed once: a second service cannot be built on the same registry", () => {
  const { registry } = setup({});
  assertThrows(() => new AefGovernance({ identityResolver: new AefIdentityResolver(verifier), toolRegistry: registry, store: new PostgresAefStore(new ScriptedTransport({})) }));
  assertThrows(() => registry.claimExecutionRights());
});

Deno.test("GU-11 the tool receives a frozen copy of the bound request, without metadata", async () => {
  let payloadHash = "";
  const receipt = () => ({
    receipt: { receipt_id: "a6000000-0000-4000-8000-000000000001", operation_id: OP, outcome: "SUCCESS", final_state: "SUCCEEDED", binding_hash: HEX("b") },
    receipt_hash: HEX("c"),
  });
  const { gov, ledger } = setup({
    aef_register_operation: (a) => { payloadHash = String(a.payload_hash); return registerAuthorized(a); },
    aef_claim_execution: () => ({ ok: true, execution_token: "a5000000-0000-4000-8000-000000000001", ...opView("EXECUTING", payloadHash) }),
    aef_complete_execution: () => ({ ok: true, ...opView("SUCCEEDED", payloadHash), receipt: receipt() }),
  });
  const r = await gov.submit(request(), TOKEN);
  assertEquals(r.status, "FINAL");
  const seen = ledger.seenRequests[0];
  assertEquals(seen.metadata, undefined);
  assert(Object.isFrozen(seen));
});
