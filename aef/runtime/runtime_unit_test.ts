/**
 * IV-IVE-AEF-RUNTIME-INTEGRATION-01 — LAB runtime unit tests (no database).
 * Kill switches, tool input schemas, mock-only registry, intent mapping on
 * the LAB table, presentation rules, the strict HTTP boundary.
 *   deno test --allow-read --allow-env aef/runtime/runtime_unit_test.ts
 */
import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import type { ExecutionRequest } from "../../contracts/aef/types.ts";
import { mapIveActionIntentWith } from "../persistence/ive_intent_mapping.ts";
import type { GovernanceResult } from "../persistence/governance.ts";
import { defineToolInputSchema, validateToolInput } from "../persistence/tool_input_schema.ts";
import { assertMockOnly, createLabToolRegistry, LAB_IVE_ACTION_TABLE, LAB_MOCK_TOOLS } from "./lab_tools.ts";
import { presentResult } from "./presentation.ts";
import { checkLabRuntime, type RuntimeEnv } from "./runtime_guard.ts";
import { handleAefRuntime } from "../../supabase/functions/_shared/aef_runtime_endpoint.ts";
import { fakeSubjectSource } from "../../supabase/functions/_shared/entitlement_test_support.ts";
import type { IveAefRuntime } from "./ive_aef_runtime.ts";
import type { RuntimePresentation } from "./presentation.ts";

const env = (vars: Record<string, string>): RuntimeEnv => ({ get: (k) => vars[k] });
const LAB = { AEF_RUNTIME_MODE: "LAB", AEF_TOOLS: "MOCK_ONLY", SUPABASE_URL: "http://127.0.0.1:54321" };

// ── kill switches (T27, T28) ──────────────────────────────────────────────
Deno.test("RU-01 kill switch: only LAB + MOCK_ONLY + a local stack passes", () => {
  assertEquals(checkLabRuntime(env(LAB)), { ok: true });
  for (const host of ["http://localhost:54321", "http://kong:8000", "http://host.docker.internal:54321", "http://[::1]:54321"]) {
    assertEquals(checkLabRuntime(env({ ...LAB, SUPABASE_URL: host })).ok, true, host);
  }
});

Deno.test("RU-02 kill switch: every missing, partial or production-shaped configuration fails closed", () => {
  const cases: [Record<string, string>, string][] = [
    [{}, "RUNTIME_NOT_ENABLED"],
    [{ ...LAB, AEF_RUNTIME_MODE: "lab" }, "RUNTIME_NOT_ENABLED"],
    [{ ...LAB, AEF_RUNTIME_MODE: "PRODUCTION" }, "RUNTIME_NOT_ENABLED"],
    [{ AEF_TOOLS: "MOCK_ONLY", SUPABASE_URL: LAB.SUPABASE_URL }, "RUNTIME_NOT_ENABLED"],
    [{ AEF_RUNTIME_MODE: "LAB", SUPABASE_URL: LAB.SUPABASE_URL }, "TOOLS_NOT_MOCK_ONLY"],
    [{ ...LAB, AEF_TOOLS: "REAL" }, "TOOLS_NOT_MOCK_ONLY"],
    [{ ...LAB, AEF_TOOLS: "MOCK_ONLY,REAL" }, "TOOLS_NOT_MOCK_ONLY"],
    [{ AEF_RUNTIME_MODE: "LAB", AEF_TOOLS: "MOCK_ONLY" }, "NOT_LOCAL_STACK"],
    [{ ...LAB, SUPABASE_URL: "https://nzngvbajrnruknpzzjbf.supabase.co" }, "PRODUCTION_LOCKED"],
    [{ ...LAB, SUPABASE_URL: "http://127.0.0.1:54321/?ref=NZNGVBAJRNRUKNPZZJBF" }, "PRODUCTION_LOCKED"],
    [{ ...LAB, SUPABASE_URL: "https://abcdefghijklmnopqrst.supabase.co" }, "NOT_LOCAL_STACK"],
    [{ ...LAB, SUPABASE_URL: "http://127.0.0.1.evil.example:54321" }, "NOT_LOCAL_STACK"],
    [{ ...LAB, SUPABASE_URL: "file:///etc/passwd" }, "NOT_LOCAL_STACK"],
    [{ ...LAB, SUPABASE_URL: "not a url" }, "NOT_LOCAL_STACK"],
    [{ ...LAB, AEF_RUNTIME_ALLOW_PRODUCTION: "1" }, "OVERRIDE_REFUSED"],
    [{ ...LAB, AEF_TOOLS_ALLOW_REAL: "true" }, "OVERRIDE_REFUSED"],
    [{ ...LAB, AEF_RUNTIME_FORCE: "" }, "OVERRIDE_REFUSED"],
  ];
  for (const [vars, reason] of cases) {
    const r = checkLabRuntime(env(vars));
    assert(!r.ok, JSON.stringify(vars));
    assertEquals(!r.ok && r.reason, reason, JSON.stringify(vars));
  }
});

// ── tool input schema (T18) ───────────────────────────────────────────────
const PUBLISH = LAB_MOCK_TOOLS.find((t) => t.toolId === "internal.mock_publish_content")!.inputSchema;

Deno.test("RU-03 schema: exact input passes; missing, wrong type, extra, oversized, bad enum, nested all fail", () => {
  assert(validateToolInput(PUBLISH, { channel: "blog", text: "hello" }));
  const bad: unknown[] = [
    {}, // missing
    { channel: "blog" }, // missing text
    { channel: "blog", text: 42 }, // wrong type
    { channel: "blog", text: "hi", extra: 1 }, // extra field
    { channel: "blog", text: "hi", subject_id: "x" }, // forbidden authority-looking field
    { channel: "blog", text: "x".repeat(281) }, // oversized
    { channel: "blog", text: "" }, // below minLength
    { channel: "tiktok", text: "hi" }, // malformed enum
    { channel: "BLOG", text: "hi" }, // enum is exact
    { channel: "blog", text: { $ne: null } }, // nested injection
    { channel: ["blog"], text: "hi" }, // array
    null,
    [],
    "text",
    Object.assign(Object.create({ inherited: 1 }), { channel: "blog", text: "hi" }), // non-plain prototype
  ];
  for (const b of bad) assertEquals(validateToolInput(PUBLISH, b), false, JSON.stringify(b));
});

Deno.test("RU-04 schema definitions are validated and frozen at startup", () => {
  assertThrows(() => defineToolInputSchema({}));
  assertThrows(() => defineToolInputSchema({ "Bad-Name": { type: "boolean", required: true } }));
  assertThrows(() => defineToolInputSchema({ a: { type: "string", required: true, maxLength: 0 } }));
  assertThrows(() => defineToolInputSchema({ a: { type: "string", required: true, maxLength: 99_999 } }));
  assertThrows(() => defineToolInputSchema({ a: { type: "integer", required: true, min: 5, max: 1 } }));
  const s = defineToolInputSchema({ a: { type: "integer", required: false, min: 0, max: 3 } });
  assert(Object.isFrozen(s) && Object.isFrozen(s.fields) && Object.isFrozen(s.fields.a));
  assert(validateToolInput(s, {}) && validateToolInput(s, { a: 3 }) && !validateToolInput(s, { a: 1.5 }) && !validateToolInput(s, { a: 4 }));
});

// ── mock-only registry (T05, T17, T27) ────────────────────────────────────
Deno.test("RU-05 the LAB registry holds only internal.mock_* tools, each with a schema and a mandatory gate; sealed", () => {
  const { registry } = createLabToolRegistry();
  for (const spec of LAB_MOCK_TOOLS) {
    const d = registry.describe({ domain: "internal", action: spec.toolId } as ExecutionRequest)!;
    assertEquals(d.classification, "CONSEQUENTIAL");
    assertEquals(d.requiresHumanGate, true);
    assert(d.inputSchema !== undefined);
    assert(d.toolId.startsWith("internal.mock_"));
  }
  assertEquals(registry.describe({ domain: "core", action: "core.publish_content" } as ExecutionRequest), undefined);
  assertThrows(() => registry.register({ toolId: "internal.mock_x", domain: "internal", classification: "READ_ONLY", requiresHumanGate: false, execute: () => Promise.resolve({ outcome: "SUCCESS", detail: "" }) }));
});

Deno.test("RU-06 assertMockOnly refuses any non-mock, schema-less or duplicate tool", () => {
  const schema = PUBLISH;
  assertThrows(() => assertMockOnly([{ toolId: "core.publish_content", iveAction: "x", inputSchema: schema }]));
  assertThrows(() => assertMockOnly([{ toolId: "internal.real_email", iveAction: "x", inputSchema: schema }]));
  assertThrows(() => assertMockOnly([{ toolId: "internal.mock_a", iveAction: "x", inputSchema: undefined as never }]));
  assertThrows(() => assertMockOnly([{ toolId: "internal.mock_a", iveAction: "x", inputSchema: schema }, { toolId: "internal.mock_a", iveAction: "y", inputSchema: schema }]));
});

Deno.test("RU-07 the runtime modules import nothing that could reach a real system (static)", async () => {
  for (const f of ["lab_tools.ts", "ive_aef_runtime.ts", "presentation.ts", "runtime_guard.ts"]) {
    const src = await Deno.readTextFile(new URL(`./${f}`, import.meta.url));
    const imports = [...src.matchAll(/^import[^;]*from\s+["']([^"']+)["']/gm)].map((m) => m[1]);
    for (const i of imports) {
      assert(i.startsWith("./") || i.startsWith("../"), `${f} imports a remote module: ${i}`);
      assert(!/supabase|stripe|groq|fetch|http|service_client/i.test(i), `${f} imports ${i}`);
    }
    assert(!/\bfetch\(|Deno\.(connect|run|Command)|createClient/.test(src), `${f} reaches the network or a process`);
  }
});

// ── intent mapping on the LAB table (T01, T19) ────────────────────────────
const SUBJECT = "0a000000-0000-4000-8000-00000000000a";
const intent = (o: Record<string, unknown> = {}) => ({
  capabilityId: null,
  requestedAction: "publish_content",
  projectId: null,
  riskClass: "CONSEQUENTIAL",
  contextRef: "0b000000-0000-4000-8000-00000000000b",
  parameters: { channel: "blog", text: "hello" },
  ...o,
});

Deno.test("RU-08 LAB table: only the two mock actions map; everything else is refused before AEF", async () => {
  const ok = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent(), SUBJECT);
  assert(ok.ok);
  assertEquals(ok.ok && ok.request.action, "internal.mock_publish_content");
  assertEquals(ok.ok && ok.request.actor.id, SUBJECT);
  for (const action of ["payment", "transfer_funds", "delete_data", "execute_workflow", "module_action", "internal.mock_publish_content", "__proto__", "constructor"]) {
    const r = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent({ requestedAction: action }), SUBJECT);
    assertEquals(r.ok ? "ok" : r.code, "INTENT_ACTION_UNKNOWN", action);
  }
  const trade = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent({ requestedAction: "trade_order" }), SUBJECT);
  assertEquals(trade.ok ? "ok" : trade.code, "POLICY_DENIED");
});

Deno.test("RU-09 forged authority in the intent is refused (subject, role, plan, approval, state, receipt, tool, risk)", async () => {
  for (const extra of [{ subjectId: "x" }, { role: "admin" }, { plan: "premium" }, { approval: true }, { state: "AUTHORIZED" }, { receipt: {} }, { tool: "internal.mock_publish_content" }, { humanGateRef: "g" }]) {
    const r = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent(extra), SUBJECT);
    assertEquals(r.ok ? "ok" : r.code, "INTENT_INVALID", JSON.stringify(extra));
  }
  // Authority aliases in the parameters are refused by the mapping itself…
  const alias = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent({ parameters: { channel: "blog", text: "hi", user_id: SUBJECT } }), SUBJECT);
  assertEquals(alias.ok ? "ok" : alias.code, "INTENT_INVALID");
  // …and any other extra field (e.g. a forged "approved") by the tool's closed schema, before persistence.
  const extra = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent({ parameters: { channel: "blog", text: "hi", approved: true } }), SUBJECT);
  assert(extra.ok);
  assertEquals(validateToolInput(PUBLISH, extra.request.parameters), false);
});

Deno.test("RU-10 the payload is part of the identity: a changed payload maps to a different idempotency key", async () => {
  const a = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent(), SUBJECT);
  const a2 = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent(), SUBJECT);
  const b = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent({ parameters: { channel: "blog", text: "hello!" } }), SUBJECT);
  const c = await mapIveActionIntentWith(LAB_IVE_ACTION_TABLE, intent({ riskClass: "READ_ONLY" }), SUBJECT);
  assert(a.ok && a2.ok && b.ok && c.ok);
  assertEquals(a.request.idempotency_key, a2.request.idempotency_key);
  assert(a.request.idempotency_key !== b.request.idempotency_key);
  // riskClass is not authority: it neither changes the operation nor the tool/gate (server decides).
  assertEquals(a.request.idempotency_key, c.request.idempotency_key);
  assertEquals(a.request.action, c.request.action);
});

// ── presentation (T26, "never done before SUCCEEDED") ─────────────────────
const op = (state: string) => ({
  operationId: "0c000000-0000-4000-8000-00000000000c", state, stateReason: null, action: "internal.mock_publish_content",
  toolId: "internal.mock_publish_content", actionClass: "CONSEQUENTIAL", bindingHash: "a".repeat(64), payloadHash: "b".repeat(64),
  policyVersion: "p", riskVersion: "r", requiresHumanGate: true, attemptCount: 1, expiresAt: "2026-01-01T00:00:00Z",
});
const receipt = (outcome: string) => ({ receipt: { receipt_id: "r1", outcome, final_state: "SUCCEEDED" }, receiptHash: "c".repeat(64) });

Deno.test("RU-11 presentation: completed ONLY for a persisted SUCCEEDED operation with a SUCCESS receipt", () => {
  const view = (state: string, rc: unknown, status: GovernanceResult["status"] = "FINAL") =>
    ({ status, replayed: false, operation: op(state), gate: null, receipt: rc, reconciliation: null }) as unknown as GovernanceResult;
  assertEquals(presentResult(view("SUCCEEDED", receipt("SUCCESS"))).completed, true);
  for (const [state, rc, status] of [
    ["SUCCEEDED", null, "FINAL"], ["SUCCEEDED", receipt("FAILURE"), "FINAL"], ["FAILED", receipt("FAILURE"), "FINAL"],
    ["UNKNOWN_OUTCOME", receipt("UNKNOWN_OUTCOME"), "FINAL"], ["AUTHORIZED", null, "AUTHORIZED"], ["EXECUTING", null, "EXECUTING"],
    ["AWAITING_APPROVAL", null, "AWAITING_APPROVAL"], ["REJECTED", receipt("NOT_EXECUTED"), "FINAL"], ["CANCELLED", receipt("NOT_EXECUTED"), "FINAL"],
    ["EXPIRED", receipt("NOT_EXECUTED"), "FINAL"], ["INVALIDATED", receipt("NOT_EXECUTED"), "FINAL"],
  ] as const) {
    const p = presentResult(view(state, rc, status as GovernanceResult["status"]));
    assertEquals(p.completed, false, `${state}/${status}`);
    assertEquals(p.retryAllowed, false);
  }
});

Deno.test("RU-12 presentation: UNKNOWN_OUTCOME and an unpersisted completion are distinct from FAILED, never completed, never retried", () => {
  const u1 = presentResult({ status: "OUTCOME_UNCONFIRMED", code: "STORE_UNAVAILABLE", operationId: "0c000000-0000-4000-8000-00000000000c" });
  const u2 = presentResult({ status: "REMAINS_UNKNOWN", operationId: "0c000000-0000-4000-8000-00000000000c" });
  const u3 = presentResult({ status: "FINAL", replayed: false, operation: op("UNKNOWN_OUTCOME"), gate: null, receipt: receipt("UNKNOWN_OUTCOME"), reconciliation: null } as unknown as GovernanceResult);
  for (const u of [u1, u2, u3]) {
    assertEquals(u.phase, "UNKNOWN_OUTCOME");
    assertEquals(u.completed, false);
    assertEquals(u.reconciliationRequired, true);
    assertEquals(u.retryAllowed, false);
  }
  const f = presentResult({ status: "FINAL", replayed: false, operation: op("FAILED"), gate: null, receipt: receipt("FAILURE"), reconciliation: null } as unknown as GovernanceResult);
  assertEquals(f.phase, "FAILED");
  assertEquals(f.reconciliationRequired, false);
  const d = presentResult({ status: "DENIED", code: "POLICY_DENIED" });
  assertEquals([d.phase, d.denialCode, d.operationId, d.completed], ["DENIED", "POLICY_DENIED", null, false]);
});

// ── HTTP boundary (T02, T03, T04, T25) ────────────────────────────────────
const auth = {
  auth: {
    getUser(token: string) {
      return Promise.resolve(token === "session-jwt"
        ? { data: { user: { id: SUBJECT } }, error: null }
        : { data: { user: null }, error: { message: "invalid" } });
    },
  },
};

class RecordingRuntime {
  calls: { op: string; args: unknown[] }[] = [];
  built = 0;
  private reply(op: string, args: unknown[]): Promise<RuntimePresentation> {
    this.calls.push({ op, args });
    return Promise.resolve({ phase: "AWAITING_APPROVAL", completed: false, reconciliationRequired: false, retryAllowed: false, operationId: null, denialCode: null, gate: null, receipt: null, replayed: false });
  }
  propose(...a: unknown[]) { return this.reply("propose", a); }
  execute(...a: unknown[]) { return this.reply("execute", a); }
  decide(...a: unknown[]) { return this.reply("decide", a); }
  status(...a: unknown[]) { return this.reply("status", a); }
  cancel(...a: unknown[]) { return this.reply("cancel", a); }
}

function call(body: unknown, o: { token?: string | null; role?: string; vars?: Record<string, string> } = {}) {
  const rt = new RecordingRuntime();
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  const token = o.token === undefined ? "session-jwt" : o.token;
  if (token) headers.Authorization = `Bearer ${token}`;
  const req = new Request("http://localhost/", { method: "POST", headers, body: JSON.stringify(body) });
  const res = handleAefRuntime(req, {
    env: env(o.vars ?? LAB),
    authClient: auth as never,
    subjectSource: fakeSubjectSource(o.role ?? "admin"),
    runtime: () => {
      rt.built++;
      return rt as unknown as IveAefRuntime;
    },
  });
  return { res, rt };
}

Deno.test("RU-13 endpoint order: auth → entitlement (admin only) → kill switch; nothing is built before all pass", async () => {
  let c = call({ op: "propose", intent: intent() }, { token: null });
  assertEquals((await c.res).status, 401);
  assertEquals(c.rt.built, 0);
  for (const role of ["free", "pro", "premium", "beta_tester"]) {
    c = call({ op: "propose", intent: intent() }, { role });
    assertEquals((await c.res).status, 403, role);
    assertEquals(c.rt.built, 0);
  }
  c = call({ op: "propose", intent: intent() }, { vars: { ...LAB, SUPABASE_URL: "https://nzngvbajrnruknpzzjbf.supabase.co" } });
  const res = await c.res;
  assertEquals(res.status, 503);
  assertEquals((await res.json()).reason, "PRODUCTION_LOCKED");
  assertEquals(c.rt.built, 0);
  c = call({ op: "propose", intent: intent() });
  assertEquals((await c.res).status, 200);
  assertEquals(c.rt.calls.map((x) => x.op), ["propose"]);
  // the subject passed to the runtime is the verified user, never a body field
  assertEquals(c.rt.calls[0].args[1], SUBJECT);
});

Deno.test("RU-14 endpoint body is strict: unknown op, extra keys, forged subject/role/plan/approval/state/receipt are refused", async () => {
  const bad: unknown[] = [
    [], null, "x", {}, { op: "run" }, { op: "__proto__" }, { op: "propose" },
    { op: "propose", intent: intent(), subjectId: SUBJECT },
    { op: "propose", intent: intent(), role: "admin" },
    { op: "propose", intent: intent(), plan: "premium" },
    { op: "execute", intent: intent(), approval: { approved: true } },
    { op: "execute", intent: intent(), state: "AUTHORIZED" },
    { op: "status", operationId: "x", receipt: {} },
    { op: "decide", gate: {}, result: "SUCCEEDED" },
  ];
  for (const body of bad) {
    const c = call(body);
    assertEquals((await c.res).status, 400, JSON.stringify(body));
    assertEquals(c.rt.calls.length, 0, JSON.stringify(body));
  }
});

// ── Promotion Gate coupling and deploy exclusion (T27, T28) ───────────────
Deno.test("RU-15 'aef-runtime-lab' is EXPERIMENTAL (admin only) and non-CONSEQUENTIAL ONLY while every LAB tool is a mock", async () => {
  const { MODULE_POLICY } = await import("../../supabase/functions/_shared/module_policy.ts");
  const m = MODULE_POLICY.modules["aef-runtime-lab"];
  assertEquals(m.lifecycle, "EXPERIMENTAL");
  // A real tool would make this module CONSEQUENTIAL, which MP-03/MP-09 refuse
  // to serve while AEF_PERSISTENCE_AVAILABLE is false: the class may stay
  // REVERSIBLE only because nothing reachable leaves the process.
  assert(LAB_MOCK_TOOLS.every((t) => t.toolId.startsWith("internal.mock_")));
  assertEquals(m.actionClass, "REVERSIBLE");
  assertEquals(MODULE_POLICY.edgeFunctions["aef-runtime"], { kind: "MODULE", moduleId: "aef-runtime-lab", gateFile: "_shared/aef_runtime_endpoint.ts" });
});

Deno.test("RU-16 aef-runtime is absent from the deploy allowlist and hard-blocked by the deploy resolver", async () => {
  const allow = await Deno.readTextFile(new URL("../../.github/deploy-allowlist.tsv", import.meta.url));
  const names = allow.split(/\r?\n/).map((l) => l.split("\t")[0].trim()).filter((l) => l && !l.startsWith("#"));
  assert(!names.includes("aef-runtime"));
  const resolver = await Deno.readTextFile(new URL("../../scripts/ci/resolve_deploy_selection.sh", import.meta.url));
  assert(/if \[ "\$FUNCTION_NAME" = "aef-runtime" \]; then\s+deny /.test(resolver));
});
