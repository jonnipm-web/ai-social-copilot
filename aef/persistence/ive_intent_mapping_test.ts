import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { validateExecutionRequest } from "../../contracts/aef/validators.ts";
import { defineIveActionTable, IVE_ACTION_MAP, type IveActionTable, mapIveActionIntent, mapIveActionIntentWith } from "./ive_intent_mapping.ts";

const USER = "a1000000-0000-4000-8000-00000000000a";
const PROJECT = "a2000000-0000-4000-8000-00000000000a";
const base = () => ({
  capabilityId: "social-copilot",
  requestedAction: "publish_content",
  projectId: PROJECT,
  riskClass: "CONSEQUENTIAL",
  contextRef: "c3000000-0000-4000-8000-000000000001",
  parameters: {},
});

async function codeOf(intent: unknown, user = USER): Promise<string> {
  const r = await mapIveActionIntent(intent, user);
  assert(!r.ok, "expected refusal");
  return r.code;
}

Deno.test("IM-01 a valid intent maps to a contract-valid request whose subject is the verified user", async () => {
  const r = await mapIveActionIntent(base(), USER);
  assert(r.ok);
  assertEquals(r.request.actor, { type: "user", id: USER, auth_ref: `usr:${USER}` });
  assertEquals(r.request.domain, "core");
  assertEquals(r.request.action, "core.publish_content");
  assertEquals(r.request.resource, { type: "project", id: PROJECT });
  assertEquals(r.request.human_gate_ref, undefined);
  assertEquals(validateExecutionRequest(r.request).ok, true);
  assert(!JSON.stringify(r.request).includes("CONSEQUENTIAL"), "riskClass is never propagated as authority");
});

Deno.test("IM-02 forged authority keys in the intent are refused", async () => {
  for (const forged of ["userId", "user_id", "role", "plan", "is_admin", "approved", "human_gate_ref", "tool", "toolId", "risk", "ownerId"]) {
    assertEquals(await codeOf({ ...base(), [forged]: "x" }), "INTENT_INVALID", forged);
  }
  const { contextRef: _omit, ...missing } = base();
  assertEquals(await codeOf(missing), "INTENT_INVALID");
  assertEquals(await codeOf(null), "INTENT_INVALID");
  assertEquals(await codeOf([base()]), "INTENT_INVALID");
});

Deno.test("IM-03 malformed fields are refused", async () => {
  assertEquals(await codeOf({ ...base(), projectId: "../other" }), "INTENT_INVALID");
  assertEquals(await codeOf({ ...base(), contextRef: "not-a-uuid" }), "INTENT_INVALID");
  assertEquals(await codeOf({ ...base(), riskClass: "SAFE" }), "INTENT_INVALID");
  assertEquals(await codeOf({ ...base(), capabilityId: "Social Copilot!" }), "INTENT_INVALID");
  assertEquals(await codeOf({ ...base(), parameters: [] }), "INTENT_INVALID");
  assertEquals(await codeOf({ ...base(), parameters: new Date() }), "INTENT_INVALID");
  assertEquals(await codeOf({ ...base(), requestedAction: 42 }), "INTENT_INVALID");
});

Deno.test("IM-04 unknown and categorically forbidden actions are refused; the table is server-owned", async () => {
  assertEquals(await codeOf({ ...base(), requestedAction: "unknown" }), "INTENT_ACTION_UNKNOWN");
  assertEquals(await codeOf({ ...base(), requestedAction: "__proto__" }), "INTENT_ACTION_UNKNOWN");
  assertEquals(await codeOf({ ...base(), requestedAction: "toString" }), "INTENT_ACTION_UNKNOWN");
  assertEquals(await codeOf({ ...base(), requestedAction: "trade_order" }), "POLICY_DENIED");
  assert(Object.isFrozen(IVE_ACTION_MAP));
  assert(Object.isFrozen(IVE_ACTION_MAP.publish_content), "targets are frozen too (Codex G3-01)");
});

Deno.test("IM-05 oversized parameters are refused before reaching AEF", async () => {
  assertEquals(await codeOf({ ...base(), parameters: { blob: "x".repeat(20_000) } }), "PAYLOAD_TOO_LARGE");
});

Deno.test("IM-06 the idempotency key is derived from the intent: replay → same key, any change → new key", async () => {
  const a = await mapIveActionIntent(base(), USER);
  const b = await mapIveActionIntent(base(), USER);
  const c = await mapIveActionIntent({ ...base(), parameters: { n: 2 } }, USER);
  const d = await mapIveActionIntent({ ...base(), projectId: null }, USER);
  assert(a.ok && b.ok && c.ok && d.ok);
  assertEquals(a.request.idempotency_key, b.request.idempotency_key);
  assert(a.request.request_id !== b.request.request_id, "each mapping is a new request");
  assert(a.request.idempotency_key !== c.request.idempotency_key);
  assert(a.request.idempotency_key !== d.request.idempotency_key);
  assertEquals(d.request.resource, undefined);
});

Deno.test("IM-07 without a verified user id nothing is mapped", async () => {
  assertEquals(await codeOf(base(), ""), "AUTH_FAILED");
  assertEquals(await codeOf(base(), "admin"), "AUTH_FAILED");
});

Deno.test("IM-08 action tables are validated and frozen in depth; hand-made tables are refused (Codex G3-01)", async () => {
  assertThrows(() => (IVE_ACTION_MAP.publish_content as { action: string }).action = "core.delete_data");
  const r = await mapIveActionIntent(base(), USER);
  assert(r.ok && r.request.action === "core.publish_content");
  assertThrows(() => defineIveActionTable({ publish_content: { domain: "quant", action: "quant.paper.order" } }));
  assertThrows(() => defineIveActionTable({ publish_content: { domain: "core", action: "internal.other_domain" } }));
  assertThrows(() => defineIveActionTable({ "Bad Key": { domain: "core", action: "core.x" } }));
  const forged = Object.freeze({ publish_content: { domain: "core", action: "core.forged" } }) as unknown as IveActionTable;
  const viaForged = await mapIveActionIntentWith(forged, base(), USER);
  assert(!viaForged.ok && viaForged.code === "INTENT_ACTION_UNKNOWN");
});

Deno.test("IM-09 authority aliases inside parameters are refused at any depth (Codex G3-02)", async () => {
  for (const alias of ["owner_id", "user_id", "userId", "risk", "tool_allowed", "subject_id", "approver-id"]) {
    assertEquals(await codeOf({ ...base(), parameters: { deep: [{ [alias]: "x" }] } }), "INTENT_INVALID", alias);
  }
  const ok = await mapIveActionIntent({ ...base(), parameters: { title: "x", tags: ["a"] } }, USER);
  assert(ok.ok);
});
