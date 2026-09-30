/**
 * IV-AEF-PERSISTENCE-01 — AefGovernance end-to-end against a REAL, disposable
 * PostgreSQL with every migration applied (scripts/ci/run_disposable_db_tests.sh
 * creates the database and sets AEF_PG_DB). Every store call is a separate
 * psql process = a separate connection, so the concurrency tests race real
 * transactions. The "clock" is moved only by the superuser test helper
 * (session_replication_role=replica), never through the service.
 *
 * Without AEF_PG_DB these tests are ignored; the runner never skips them
 * silently (AEF_PG_INTEGRATION=skip must be explicit).
 */
import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import type { ExecutionRequest } from "../../contracts/aef/types.ts";
import { AefIdentityResolver, type UserVerification, type UserVerifier } from "../identity_resolver.ts";
import { buildSuccess } from "../receipt_builder.ts";
import { ToolRegistry } from "../tool_registry.ts";
import { AefGovernance, type GovernanceResult } from "./governance.ts";
import { AEF_POLICY_VERSION } from "./limits.ts";
import { defineIveActionTable, mapIveActionIntent, mapIveActionIntentWith } from "./ive_intent_mapping.ts";
import { MOCK_CONSEQUENTIAL_TOOL, MOCK_REVERSIBLE_TOOL, type MockBehavior, MockEffectLedger, registerMockEffectTools } from "./mock_effect_tool.ts";
import { type AefRpcName, PostgresAefStore, type RpcTransport } from "./store.ts";
import { PsqlTransport, psqlOptionsFromEnv, runPsql } from "./testing/psql_transport.ts";

const PG = psqlOptionsFromEnv();
const ignore = PG === null;
const CONCURRENCY = 40;
/** At least this many store calls must have been in flight at once (real overlap, runner-independent). */
const MIN_OVERLAP = 5;

class TokenVerifier implements UserVerifier {
  constructor(private readonly tokens: Map<string, string>) {}
  verify(token: string): Promise<UserVerification> {
    const userId = this.tokens.get(token);
    return Promise.resolve(userId ? { ok: true, userId } : { ok: false, reason: "INVALID", detail: "unknown token" });
  }
}

interface World {
  a: string;
  b: string;
  projectA: string;
  projectB: string;
  tokA: { kind: "bearer_jwt"; token: string };
  tokB: { kind: "bearer_jwt"; token: string };
}

async function world(): Promise<World> {
  const a = crypto.randomUUID();
  const b = crypto.randomUUID();
  const projectA = crypto.randomUUID();
  const projectB = crypto.randomUUID();
  await runPsql(PG!, `
    INSERT INTO auth.users (id, email) VALUES ('${a}', 'a-${a}@test.invalid'), ('${b}', 'b-${b}@test.invalid');
    INSERT INTO public.projects (id, user_id, name) VALUES ('${projectA}', '${a}', 'A'), ('${projectB}', '${b}', 'B');`);
  return { a, b, projectA, projectB, tokA: { kind: "bearer_jwt", token: `tok-${a}` }, tokB: { kind: "bearer_jwt", token: `tok-${b}` } };
}

interface Harness {
  gov: AefGovernance;
  store: PostgresAefStore;
  ledger: MockEffectLedger;
  overlap: OverlapTransport;
  setBehavior(b: MockBehavior): void;
}

/**
 * Codex Gate 2 G2-01: records how many calls of each RPC were in flight at
 * the same time (each call = its own psql process and connection), so the
 * concurrency tests prove real overlap instead of assuming it.
 */
class OverlapTransport implements RpcTransport {
  private readonly inFlight = new Map<string, number>();
  readonly peak = new Map<string, number>();
  constructor(private readonly inner: RpcTransport) {}
  async call(fn: AefRpcName, args: Record<string, unknown>): Promise<unknown> {
    const now = (this.inFlight.get(fn) ?? 0) + 1;
    this.inFlight.set(fn, now);
    this.peak.set(fn, Math.max(this.peak.get(fn) ?? 0, now));
    try {
      return await this.inner.call(fn, args);
    } finally {
      this.inFlight.set(fn, (this.inFlight.get(fn) ?? 1) - 1);
    }
  }
}

function harness(w: World, opts: { delayMs?: number; transport?: RpcTransport; toolTimeoutMs?: number; lateEffectMs?: number } = {}): Harness {
  let behavior: MockBehavior = "SUCCEED";
  const ledger = new MockEffectLedger();
  const registry = new ToolRegistry();
  registerMockEffectTools(registry, ledger, () => behavior, opts.delayMs ?? 0, opts.lateEffectMs);
  const overlap = new OverlapTransport(opts.transport ?? new PsqlTransport(PG!));
  const store = new PostgresAefStore(overlap);
  const tokens = new Map([[w.tokA.token, w.a], [w.tokB.token, w.b]]);
  const gov = new AefGovernance({
    identityResolver: new AefIdentityResolver(new TokenVerifier(tokens)),
    toolRegistry: registry,
    store,
    toolTimeoutMs: opts.toolTimeoutMs,
  });
  return { gov, store, ledger, overlap, setBehavior: (b) => (behavior = b) };
}

function req(user: string, o: { key?: string; action?: string; params?: Record<string, unknown>; project?: string; extra?: Record<string, unknown> } = {}): ExecutionRequest {
  const now = Date.now();
  const r: Record<string, unknown> = {
    contract_version: "1.0",
    request_id: crypto.randomUUID(),
    requested_at: new Date(now).toISOString(),
    expires_at: new Date(now + 5 * 60_000).toISOString(),
    actor: { type: "user", id: user, auth_ref: `usr:${user}` },
    intent: "mock effect for persistence tests",
    domain: "internal",
    action: o.action ?? MOCK_CONSEQUENTIAL_TOOL,
    parameters: o.params ?? { n: 1 },
    idempotency_key: o.key ?? crypto.randomUUID(),
    ...(o.project ? { resource: { type: "project", id: o.project } } : {}),
    ...(o.extra ?? {}),
  };
  return r as unknown as ExecutionRequest;
}

function expectStatus<S extends GovernanceResult["status"]>(r: GovernanceResult, status: S): Extract<GovernanceResult, { status: S }> {
  assertEquals(r.status, status, `expected ${status}, got ${JSON.stringify(r)}`);
  return r as Extract<GovernanceResult, { status: S }>;
}

function approve(h: Harness, w: World, r: GovernanceResult, token = w.tokA, approver = w.a): Promise<GovernanceResult> {
  const pending = expectStatus(r, "AWAITING_APPROVAL");
  return h.gov.decideGate({
    gate_id: pending.gate!.gateId,
    decision: "APPROVE",
    binding_hash: pending.gate!.bindingHash,
    approver: { type: "user", id: approver, auth_ref: `usr:${approver}` },
  }, token);
}

/** Registers, approves and returns a request ready to execute on resubmission. */
async function approvedRequest(h: Harness, w: World, o: Parameters<typeof req>[1] = {}) {
  const first = req(w.a, o);
  const pending = await h.gov.submit(first, w.tokA);
  expectStatus(await approve(h, w, pending), "AUTHORIZED");
  return { resubmit: () => ({ ...structuredClone(first), request_id: crypto.randomUUID() }), operationId: expectStatus(pending, "AWAITING_APPROVAL").operation.operationId };
}

async function shiftClock(sql: string) {
  await runPsql(PG!, `SET session_replication_role = replica;\n${sql}\nSET session_replication_role = origin;`);
}

Deno.test({ name: "PG-01 consequential lifecycle: pending → approve → execute once → replay returns the persisted receipt", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const first = req(w.a, { project: w.projectA });
  const pending = expectStatus(await h.gov.submit(first, w.tokA), "AWAITING_APPROVAL");
  assertEquals(h.ledger.invocations.size, 0, "tool must not run before approval");
  assertEquals(pending.gate?.state, "REVIEW_REQUIRED");
  expectStatus(await approve(h, w, pending), "AUTHORIZED");
  assertEquals(h.ledger.invocations.size, 0, "approval alone never executes");

  const done = expectStatus(await h.gov.submit({ ...first, request_id: crypto.randomUUID() }, w.tokA), "FINAL");
  assertEquals(done.operation.state, "SUCCEEDED");
  assertEquals(done.receipt!.receipt.outcome, "SUCCESS");
  assertEquals(done.receipt!.receipt.approver_id, w.a);
  assertEquals(done.receipt!.receipt.policy_version, AEF_POLICY_VERSION);
  assertEquals(done.gate?.state, "EXECUTED");
  assertEquals(h.ledger.totalEffects(), 1);

  const again = expectStatus(await h.gov.submit({ ...first, request_id: crypto.randomUUID() }, w.tokA), "FINAL");
  assert(again.replayed);
  assertEquals(again.receipt!.receipt.receipt_id, done.receipt!.receipt.receipt_id);
  assertEquals(h.ledger.totalEffects(), 1, "replay never re-executes");
  assertEquals((await h.gov.verifyReceipt(structuredClone(done.receipt!.receipt))).valid, true);
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
  // The tool saw only bound fields.
  assertEquals(h.ledger.seenRequests[0].metadata, undefined);
}});

Deno.test({ name: "PG-02 reversible tool without gate executes on first submit, exactly once", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const r = req(w.a, { action: MOCK_REVERSIBLE_TOOL });
  const done = expectStatus(await h.gov.submit(r, w.tokA), "FINAL");
  assertEquals(done.receipt!.receipt.outcome, "SUCCESS");
  assertEquals(done.gate, null);
  expectStatus(await h.gov.submit({ ...r, request_id: crypto.randomUUID() }, w.tokA), "FINAL");
  assertEquals(h.ledger.totalEffects(), 1);
}});

Deno.test({ name: "PG-03 idempotency: same key + different payload is a conflict, never a silent replay", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const key = crypto.randomUUID();
  expectStatus(await h.gov.submit(req(w.a, { key, params: { amount: 1 } }), w.tokA), "AWAITING_APPROVAL");
  const conflict = expectStatus(await h.gov.submit(req(w.a, { key, params: { amount: 1000 } }), w.tokA), "DENIED");
  assertEquals(conflict.code, "IDEMPOTENCY_CONFLICT");
  const project = expectStatus(await h.gov.submit(req(w.a, { key, params: { amount: 1 }, project: w.projectA }), w.tokA), "DENIED");
  assertEquals(project.code, "IDEMPOTENCY_CONFLICT", "resource is part of the binding");
  const sameRequest = req(w.a, { key: crypto.randomUUID() });
  expectStatus(await h.gov.submit(sameRequest, w.tokA), "AWAITING_APPROVAL");
  const replayedId = expectStatus(await h.gov.submit({ ...sameRequest, idempotency_key: crypto.randomUUID() }, w.tokA), "DENIED");
  assertEquals(replayedId.code, "REQUEST_REPLAYED");
  assertEquals(h.ledger.invocations.size, 0);
}});

Deno.test({ name: "PG-04 cross-user: namespaced keys, no foreign decision, read or cancel", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const key = crypto.randomUUID();
  const aPending = expectStatus(await h.gov.submit(req(w.a, { key }), w.tokA), "AWAITING_APPROVAL");
  const bPending = expectStatus(await h.gov.submit(req(w.b, { key }), w.tokB), "AWAITING_APPROVAL");
  assertNotEquals(aPending.operation.operationId, bPending.operation.operationId, "same key, different subjects → different operations");

  const foreignDecision = expectStatus(await approve(h, w, aPending, w.tokB, w.b), "DENIED");
  assertEquals(foreignDecision.code, "GATE_NOT_FOUND");
  const spoofedApprover = expectStatus(await approve(h, w, aPending, w.tokB, w.a), "DENIED");
  assertEquals(spoofedApprover.code, "AUTH_FAILED", "claiming to be A with B's credential");
  const read = expectStatus(await h.gov.getOperation({ operation_id: aPending.operation.operationId, actor: { type: "user", id: w.b, auth_ref: `usr:${w.b}` } }, w.tokB), "DENIED");
  assertEquals(read.code, "OPERATION_NOT_FOUND");
  const cancel = expectStatus(await h.gov.cancel({ operation_id: aPending.operation.operationId, actor: { type: "user", id: w.b, auth_ref: `usr:${w.b}` } }, w.tokB), "DENIED");
  assertEquals(cancel.code, "OPERATION_NOT_FOUND");
  const still = expectStatus(await h.gov.getOperation({ operation_id: aPending.operation.operationId, actor: { type: "user", id: w.a, auth_ref: `usr:${w.a}` } }, w.tokA), "AWAITING_APPROVAL");
  assertEquals(still.gate?.state, "REVIEW_REQUIRED");
}});

Deno.test({ name: "PG-05 cross-project: a foreign or unknown project is refused server-side", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  assertEquals(expectStatus(await h.gov.submit(req(w.a, { project: w.projectB }), w.tokA), "DENIED").code, "RESOURCE_FORBIDDEN");
  assertEquals(expectStatus(await h.gov.submit(req(w.a, { project: crypto.randomUUID() }), w.tokA), "DENIED").code, "RESOURCE_FORBIDDEN");
  const rows = await runPsql(PG!, `SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}';`);
  assertEquals(rows[0], "0");
}});

Deno.test({ name: "PG-06 the request carries no authority (forged actor, approval, role, tool, size, mass assignment)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const code = async (r: unknown, tok = w.tokA) => expectStatus(await h.gov.submit(r, tok), "DENIED").code;
  assertEquals(await code(req(w.b), w.tokA), "AUTH_FAILED");
  assertEquals(await code(req(w.a, { extra: { human_gate_ref: "gate-forged-by-client" } })), "CLIENT_APPROVAL_REJECTED");
  assertEquals(await code(req(w.a, { params: { role: "admin" } })), "INVALID_REQUEST");
  assertEquals(await code(req(w.a, { params: { approved: true } })), "INVALID_REQUEST");
  for (const alias of ["owner_id", "userId", "risk", "tool_allowed", "APPROVER-ID"]) {
    assertEquals(await code(req(w.a, { params: { nested: [{ [alias]: "x" }] } })), "INVALID_REQUEST", alias);
  }
  assertEquals(await code(req(w.a, { extra: { state: "AUTHORIZED" } })), "INVALID_REQUEST");
  assertEquals(await code(req(w.a, { action: "internal.send_real_email" })), "UNKNOWN_TOOL");
  assertEquals(await code(req(w.a, { params: { blob: "x".repeat(20_000) } })), "PAYLOAD_TOO_LARGE");
  assertEquals(await code(req(w.a, { params: { a: { b: { c: { d: { e: { f: { g: { h: 1 } } } } } } } } })), "PAYLOAD_TOO_LARGE");
  assertEquals(await code(req(w.a, { extra: { idempotency_key: undefined } })), "IDEMPOTENCY_KEY_REQUIRED");
  assertEquals(await code(req(w.a, { extra: { delegation_ref: "delegation-1" } })), "DELEGATION_UNSUPPORTED");

  const pending = expectStatus(await h.gov.submit(req(w.a), w.tokA), "AWAITING_APPROVAL");
  const massAssign = await h.gov.decideGate({
    gate_id: pending.gate!.gateId, decision: "APPROVE", binding_hash: pending.gate!.bindingHash,
    approver: { type: "user", id: w.a, auth_ref: `usr:${w.a}` }, approver_id: w.a,
  }, w.tokA);
  assertEquals(expectStatus(massAssign, "DENIED").code, "INPUT_REJECTED");
  const wrongBinding = await h.gov.decideGate({
    gate_id: pending.gate!.gateId, decision: "APPROVE", binding_hash: "f".repeat(64),
    approver: { type: "user", id: w.a, auth_ref: `usr:${w.a}` },
  }, w.tokA);
  assertEquals(expectStatus(wrongBinding, "DENIED").code, "APPROVAL_BINDING_MISMATCH");
  assertEquals(h.ledger.invocations.size, 0);
}});

Deno.test({ name: `PG-07 concurrency: ${CONCURRENCY} parallel submits of one approved operation run the tool exactly once`, ignore, fn: async () => {
  const w = await world();
  const h = harness(w, { delayMs: 150 });
  const { resubmit, operationId } = await approvedRequest(h, w);
  const results = await Promise.all(Array.from({ length: CONCURRENCY }, () => h.gov.submit(resubmit(), w.tokA)));
  assert((h.overlap.peak.get("aef_claim_execution") ?? 0) >= MIN_OVERLAP, `claims overlapped: peak ${h.overlap.peak.get("aef_claim_execution")}`);
  assertEquals(h.ledger.invocations.get(operationId), 1, "exactly one invocation");
  assertEquals(h.ledger.totalEffects(), 1, "exactly one side effect");
  for (const r of results) assert(r.status === "FINAL" || r.status === "EXECUTING", JSON.stringify(r));
  const receiptIds = new Set(results.filter((r) => r.status === "FINAL").map((r) => (r as { receipt: { receipt: { receipt_id: string } } }).receipt.receipt.receipt_id));
  assertEquals(receiptIds.size, 1, "one receipt for the operation");
  const rows = await runPsql(PG!, `SELECT attempt_count, state FROM public.aef_operations WHERE id = '${operationId}';`);
  assertEquals(rows[0], "1|SUCCEEDED");
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: `PG-08 concurrency: ${CONCURRENCY} parallel first submits with one key create exactly one operation and one gate`, ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const key = crypto.randomUUID();
  const results = await Promise.all(Array.from({ length: CONCURRENCY }, () => h.gov.submit(req(w.a, { key }), w.tokA)));
  assert((h.overlap.peak.get("aef_register_operation") ?? 0) >= MIN_OVERLAP, `registrations overlapped: peak ${h.overlap.peak.get("aef_register_operation")}`);
  const ids = new Set(results.map((r) => expectStatus(r, "AWAITING_APPROVAL").operation.operationId));
  assertEquals(ids.size, 1);
  const rows = await runPsql(PG!, `SELECT (SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}') || '|' || (SELECT count(*) FROM public.aef_human_gates WHERE subject_id = '${w.a}');`);
  assertEquals(rows[0], "1|1");
}});

Deno.test({ name: `PG-09 concurrency: ${CONCURRENCY} parallel approve/reject decisions — exactly one wins`, ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const pending = expectStatus(await h.gov.submit(req(w.a), w.tokA), "AWAITING_APPROVAL");
  const results = await Promise.all(Array.from({ length: CONCURRENCY }, (_, i) => h.gov.decideGate({
    gate_id: pending.gate!.gateId, decision: i % 2 === 0 ? "APPROVE" : "REJECT", binding_hash: pending.gate!.bindingHash,
    approver: { type: "user", id: w.a, auth_ref: `usr:${w.a}` },
  }, w.tokA)));
  assert((h.overlap.peak.get("aef_decide_gate") ?? 0) >= MIN_OVERLAP, `decisions overlapped: peak ${h.overlap.peak.get("aef_decide_gate")}`);
  const winners = results.filter((r) => r.status !== "DENIED");
  assertEquals(winners.length, 1, JSON.stringify(results.map((r) => r.status)));
  for (const r of results) if (r.status === "DENIED") assertEquals(r.code, "GATE_NOT_PENDING");
  const events = await runPsql(PG!, `SELECT count(*) FROM public.aef_audit_events WHERE subject_id = '${w.a}' AND event_type = 'GATE_TRANSITION';`);
  assertEquals(events[0], "1");
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: `PG-10 concurrency: ${CONCURRENCY} parallel first submits of a no-gate tool execute it once`, ignore, fn: async () => {
  const w = await world();
  const h = harness(w, { delayMs: 100 });
  const base = req(w.a, { action: MOCK_REVERSIBLE_TOOL });
  const results = await Promise.all(Array.from({ length: CONCURRENCY }, () => h.gov.submit({ ...structuredClone(base), request_id: crypto.randomUUID() }, w.tokA)));
  assert((h.overlap.peak.get("aef_register_operation") ?? 0) >= MIN_OVERLAP, `registrations overlapped: peak ${h.overlap.peak.get("aef_register_operation")}`);
  assertEquals(h.ledger.totalEffects(), 1);
  let invocations = 0;
  for (const v of h.ledger.invocations.values()) invocations += v;
  assertEquals(invocations, 1);
  assert(results.every((r) => r.status === "FINAL" || r.status === "EXECUTING"));
}});

for (const [behavior, state, outcome] of [
  ["FAIL_BEFORE_EFFECT", "FAILED", "FAILURE"],
  ["FAIL_AFTER_EFFECT", "FAILED", "PARTIAL"],
  ["FAIL_UNDECLARED", "UNKNOWN_OUTCOME", "UNKNOWN_OUTCOME"],
  ["THROW_AFTER_EFFECT", "UNKNOWN_OUTCOME", "UNKNOWN_OUTCOME"],
  ["HANG", "UNKNOWN_OUTCOME", "UNKNOWN_OUTCOME"],
] as const) {
  Deno.test({ name: `PG-11 tool ${behavior} → ${state}/${outcome}, never retried, never success`, ignore, fn: async () => {
    const w = await world();
    const h = harness(w, { toolTimeoutMs: 300 });
    h.setBehavior(behavior);
    const { resubmit, operationId } = await approvedRequest(h, w);
    const done = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
    assertEquals(done.operation.state, state);
    assertEquals(done.receipt!.receipt.outcome, outcome);
    h.setBehavior("SUCCEED");
    const again = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
    assertEquals(again.receipt!.receipt.outcome, outcome, "terminal outcome never changes");
    assertEquals(h.ledger.invocations.get(operationId), 1, "no automatic retry");
  }});
}

Deno.test({ name: "PG-12 crash after claim: recovery records UNKNOWN_OUTCOME; late completion and resubmits change nothing", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const { resubmit, operationId } = await approvedRequest(h, w);
  const pending = expectStatus(await h.gov.getOperation({ operation_id: operationId, actor: { type: "user", id: w.a, auth_ref: `usr:${w.a}` } }, w.tokA), "AUTHORIZED");
  // The "process" claims execution and dies before completing.
  const claim = await h.store.claimExecution({ operation_id: operationId, subject_id: w.a, binding_hash: pending.operation.bindingHash, policy_version: AEF_POLICY_VERSION, lease_seconds: 60 });
  assert(claim.ok);
  expectStatus(await h.gov.submit(resubmit(), w.tokA), "EXECUTING");
  await shiftClock(`UPDATE public.aef_operations SET lease_expires_at = now() - interval '1 second' WHERE id = '${operationId}';`);
  assertEquals((await h.gov.recover()).unknownOutcome >= 1, true);
  const final = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
  assertEquals(final.receipt!.receipt.outcome, "UNKNOWN_OUTCOME");
  assertEquals(final.operation.stateReason, "LEASE_EXPIRED");
  const late = await h.store.completeExecution({ operation_id: operationId, execution_token: (claim as { executionToken: string }).executionToken, result: "SUCCEEDED" });
  assertEquals(late.ok, false);
  assertEquals(h.ledger.invocations.size, 0, "the tool never ran in this process, and was never retried");
}});

Deno.test({ name: "PG-13 completion cannot be persisted: OUTCOME_UNCONFIRMED, then UNKNOWN_OUTCOME — a real success is never claimed", ignore, fn: async () => {
  const w = await world();
  const real = new PsqlTransport(PG!);
  const flaky: RpcTransport = {
    call: (fn: AefRpcName, args) => fn === "aef_complete_execution" ? Promise.reject(new Error("connection lost")) : real.call(fn, args),
  };
  const h = harness(w, { transport: flaky });
  const { resubmit, operationId } = await approvedRequest(h, w);
  const r = expectStatus(await h.gov.submit(resubmit(), w.tokA), "OUTCOME_UNCONFIRMED");
  assertEquals(r.code, "STORE_UNAVAILABLE");
  assertEquals(h.ledger.totalEffects(), 1, "the effect did happen");
  await shiftClock(`UPDATE public.aef_operations SET lease_expires_at = now() - interval '1 second' WHERE id = '${operationId}';`);
  await h.gov.recover();
  const final = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
  assertEquals(final.receipt!.receipt.outcome, "UNKNOWN_OUTCOME");
  assertEquals(h.ledger.invocations.get(operationId), 1);
}});

Deno.test({ name: "PG-14 TTL: an expired approval window or operation lifetime expires; nothing executes", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const gateExpired = expectStatus(await h.gov.submit(req(w.a), w.tokA), "AWAITING_APPROVAL");
  await shiftClock(`UPDATE public.aef_human_gates SET expires_at = now() - interval '1 second' WHERE id = '${gateExpired.gate!.gateId}';`);
  assertEquals(expectStatus(await approve(h, w, gateExpired), "DENIED").code, "GATE_EXPIRED");

  const { resubmit, operationId } = await approvedRequest(h, w);
  await shiftClock(`UPDATE public.aef_human_gates SET expires_at = now() - interval '1 second' WHERE operation_id = '${operationId}';`);
  const final = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
  assertEquals(final.operation.state, "EXPIRED");
  assertEquals(final.receipt!.receipt.outcome, "NOT_EXECUTED");

  const opExpired = expectStatus(await h.gov.submit(req(w.a), w.tokA), "AWAITING_APPROVAL");
  await shiftClock(`UPDATE public.aef_operations SET expires_at = now() - interval '1 second' WHERE id = '${opExpired.operation.operationId}';`);
  assert((await h.gov.recover()).expired >= 1);
  assertEquals(h.ledger.invocations.size, 0);
}});

Deno.test({ name: "PG-15 cancellation before execution is final; no compensation, no later execution", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const { resubmit, operationId } = await approvedRequest(h, w);
  const cancelled = expectStatus(await h.gov.cancel({ operation_id: operationId, actor: { type: "user", id: w.a, auth_ref: `usr:${w.a}` } }, w.tokA), "FINAL");
  assertEquals(cancelled.operation.state, "CANCELLED");
  assertEquals(cancelled.gate?.state, "CANCELLED");
  const after = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
  assertEquals(after.receipt!.receipt.outcome, "NOT_EXECUTED");
  assertEquals(h.ledger.invocations.size, 0);
}});

Deno.test({ name: "PG-16 receipt forgery: altered, invented or locally built receipts are rejected; returned receipts are frozen", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const done = expectStatus(await h.gov.submit(req(w.a, { action: MOCK_REVERSIBLE_TOOL }), w.tokA), "FINAL");
  const genuine = structuredClone(done.receipt!.receipt) as Record<string, unknown>;
  assertEquals((await h.gov.verifyReceipt(genuine)).valid, true);
  assertEquals((await h.gov.verifyReceipt({ ...genuine, outcome: "FAILURE" })).reason, "RECEIPT_MISMATCH");
  assertEquals((await h.gov.verifyReceipt({ ...genuine, receipt_id: crypto.randomUUID() })).reason, "RECEIPT_UNKNOWN");
  assertEquals((await h.gov.verifyReceipt({ nonsense: true })).reason, "RECEIPT_MALFORMED");
  const v0 = buildSuccess({ request: req(w.a), actorForReceipt: { type: "user", id: w.a, auth_ref: `usr:${w.a}` }, startedAt: new Date() }, "forged");
  assertEquals((await h.gov.verifyReceipt(v0.receipt)).valid, false, "a v0 in-memory receipt is not a persisted receipt");
  let threw = false;
  try {
    (done.receipt!.receipt as Record<string, unknown>).outcome = "FAILURE";
  } catch {
    threw = true;
  }
  assert(threw, "persisted receipt objects are frozen");
}});

Deno.test({ name: "PG-17 IveActionIntent → AEF: suggestion only; unknown/real actions refused; replay maps to one operation", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const intent = { capabilityId: "social-copilot", requestedAction: "publish_content", projectId: w.projectA, riskClass: "READ_ONLY", contextRef: crypto.randomUUID(), parameters: {} };
  const real = await mapIveActionIntent(intent, w.a);
  assert(real.ok);
  assertEquals(expectStatus(await h.gov.submit(real.request, w.tokA), "DENIED").code, "UNKNOWN_TOOL", "no real tool is reachable");

  const testMap = defineIveActionTable({ publish_content: { domain: "internal", action: MOCK_CONSEQUENTIAL_TOOL } });
  const mapped = await mapIveActionIntentWith(testMap, intent, w.a);
  assert(mapped.ok);
  const pending = expectStatus(await h.gov.submit(mapped.request, w.tokA), "AWAITING_APPROVAL");
  assertEquals(pending.operation.actionClass, "CONSEQUENTIAL", "riskClass READ_ONLY in the intent is ignored");
  const replay = await mapIveActionIntentWith(testMap, intent, w.a);
  assert(replay.ok);
  const replayed = expectStatus(await h.gov.submit(replay.request, w.tokA), "AWAITING_APPROVAL");
  assert(replayed.replayed);
  assertEquals(replayed.operation.operationId, pending.operation.operationId);

  const foreign = await mapIveActionIntentWith(testMap, { ...intent, projectId: w.projectB }, w.a);
  assert(foreign.ok);
  assertEquals(expectStatus(await h.gov.submit(foreign.request, w.tokA), "DENIED").code, "RESOURCE_FORBIDDEN");
  const otherUser = await mapIveActionIntentWith(testMap, intent, w.b);
  assert(otherUser.ok);
  assertEquals(expectStatus(await h.gov.submit(otherUser.request, w.tokA), "DENIED").code, "AUTH_FAILED", "mapped subject must match the credential");
  assertEquals(h.ledger.invocations.size, 0);
}});

Deno.test({ name: "PG-18 an approval given under another policy version is invalidated, never honored", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const first = req(w.a);
  const pending = expectStatus(await h.gov.submit(first, w.tokA), "AWAITING_APPROVAL");
  const stale = await h.store.decideGate({ gate_id: pending.gate!.gateId, approver_id: w.a, decision: "APPROVE", binding_hash: pending.gate!.bindingHash, policy_version: "aef-policy/2099-01-01.1" });
  assertEquals(stale.ok ? "ok" : stale.code, "POLICY_VERSION_CHANGED");
  const after = expectStatus(await h.gov.submit({ ...first, request_id: crypto.randomUUID() }, w.tokA), "FINAL");
  assertEquals(after.operation.state, "INVALIDATED");
  assertEquals(h.ledger.invocations.size, 0);
}});

Deno.test({ name: "PG-19 the tool sees only the approved binding: unbound request fields cannot change its input (Codex G1-01)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const first = req(w.a, { project: w.projectA.toUpperCase(), extra: { parameters: undefined } });
  const pending = expectStatus(await h.gov.submit(first, w.tokA), "AWAITING_APPROVAL");
  expectStatus(await approve(h, w, pending), "AUTHORIZED");
  const later = Date.now() + 60_000;
  const variant = {
    ...structuredClone(first),
    request_id: crypto.randomUUID(),
    correlation_id: crypto.randomUUID(),
    requested_at: new Date(later).toISOString(),
    expires_at: new Date(later + 60_000).toISOString(),
    parameters: {},
    metadata: { injected: "x" },
  };
  expectStatus(await h.gov.submit(variant, w.tokA), "FINAL");
  assertEquals(h.ledger.seenRequests.length, 1);
  const seen = h.ledger.seenRequests[0] as unknown as Record<string, unknown>;
  assertEquals(seen.request_id, pending.operation.operationId, "server-owned id, not the client's");
  assertEquals(seen.actor, { type: "user", id: w.a, auth_ref: `usr:${w.a}` });
  assertEquals(seen.parameters, {});
  assertEquals(seen.resource, { type: "project", id: w.projectA });
  for (const unbound of ["correlation_id", "idempotency_key", "metadata", "human_gate_ref", "delegation_ref", "constraints", "context_ref"]) {
    assertEquals(seen[unbound], undefined, unbound);
  }
  assert(Object.isFrozen(seen) && Object.isFrozen(seen.parameters));
}});

Deno.test({ name: "PG-20 a tool that ignores the abort and applies its effect late stays UNKNOWN_OUTCOME (Codex G2-02)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w, { toolTimeoutMs: 200, lateEffectMs: 800 });
  h.setBehavior("IGNORE_ABORT_LATE_EFFECT");
  const { resubmit, operationId } = await approvedRequest(h, w);
  const r = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
  assertEquals(r.receipt!.receipt.outcome, "UNKNOWN_OUTCOME");
  assertEquals(h.ledger.totalEffects(), 0, "the effect has not happened yet when AEF gives up");
  await new Promise((resolve) => setTimeout(resolve, 1_000));
  assertEquals(h.ledger.totalEffects(), 1, "…and happens afterwards: exactly why the outcome is UNKNOWN, not FAILED");
  const later = expectStatus(await h.gov.submit(resubmit(), w.tokA), "FINAL");
  assertEquals(later.receipt!.receipt.outcome, "UNKNOWN_OUTCOME", "a late effect never rewrites the durable record");
  assertEquals(h.ledger.invocations.get(operationId), 1, "and is never retried");
}});

Deno.test({ name: `PG-21 admission: at the open-operation limit, ${CONCURRENCY} concurrent replays of the last admitted key are never refused (Codex CFV-01)`, ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  for (let i = 0; i < 49; i++) expectStatus(await h.gov.submit(req(w.a), w.tokA), "AWAITING_APPROVAL");
  const key = crypto.randomUUID();
  const results = await Promise.all(Array.from({ length: CONCURRENCY }, () => h.gov.submit(req(w.a, { key }), w.tokA)));
  const ids = new Set(results.map((r) => expectStatus(r, "AWAITING_APPROVAL").operation.operationId));
  assertEquals(ids.size, 1, "the 50th operation is admitted once; every concurrent replay returns it");
  assertEquals(expectStatus(await h.gov.submit(req(w.a), w.tokA), "DENIED").code, "OPEN_OPERATION_LIMIT", "the 51st is refused");
  const rows = await runPsql(PG!, `SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}' AND state = 'AWAITING_APPROVAL';`);
  assertEquals(rows[0], "50");
}});
