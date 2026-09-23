/**
 * IV-AEF-HARDENING-01 — reconciliation, retention, erasure and audit rate
 * limiting end-to-end against a REAL disposable PostgreSQL (set up by
 * scripts/ci/run_disposable_db_tests.sh, AEF_PG_DB). Every store call is its
 * own psql process = its own connection, so the races below are real.
 * Deadlines are moved only by the superuser helper (replica mode).
 */
import { assert, assertEquals } from "jsr:@std/assert@1";
import type { ExecutionRequest } from "../../contracts/aef/types.ts";
import { AefIdentityResolver, type UserVerification, type UserVerifier } from "../identity_resolver.ts";
import { ToolRegistry } from "../tool_registry.ts";
import { AefGovernance, type GovernanceResult, type ReconciliationVerifier, ReconciliationVerifierRegistry } from "./governance.ts";
import { AEF_POLICY_VERSION } from "./limits.ts";
import { MOCK_CONSEQUENTIAL_TOOL, MOCK_REVERSIBLE_TOOL, type MockBehavior, MockEffectLedger, registerMockEffectTools } from "./mock_effect_tool.ts";
import { type AefRpcName, PostgresAefStore, type RpcTransport } from "./store.ts";
import { PsqlTransport, psqlOptionsFromEnv, runPsql } from "./testing/psql_transport.ts";

const PG = psqlOptionsFromEnv();
const ignore = PG === null;
const N = 40;

class TokenVerifier implements UserVerifier {
  constructor(private readonly tokens: Map<string, string>) {}
  verify(token: string): Promise<UserVerification> {
    const userId = this.tokens.get(token);
    return Promise.resolve(userId ? { ok: true, userId } : { ok: false, reason: "INVALID", detail: "unknown token" });
  }
}

class Overlap implements RpcTransport {
  private readonly now = new Map<string, number>();
  readonly peak = new Map<string, number>();
  constructor(private readonly inner: RpcTransport) {}
  async call(fn: AefRpcName, args: Record<string, unknown>): Promise<unknown> {
    const n = (this.now.get(fn) ?? 0) + 1;
    this.now.set(fn, n);
    this.peak.set(fn, Math.max(this.peak.get(fn) ?? 0, n));
    try {
      return await this.inner.call(fn, args);
    } finally {
      this.now.set(fn, (this.now.get(fn) ?? 1) - 1);
    }
  }
}

type Tok = { kind: "bearer_jwt"; token: string };
interface World { a: string; b: string; admin: string; tokA: Tok; tokB: Tok; tokAdmin: Tok }

async function world(): Promise<World> {
  const [a, b, admin] = [crypto.randomUUID(), crypto.randomUUID(), crypto.randomUUID()];
  await runPsql(PG!, `
    INSERT INTO auth.users (id, email) VALUES ('${a}', 'a-${a}@t.invalid'), ('${b}', 'b-${b}@t.invalid'), ('${admin}', 'x-${admin}@t.invalid');
    INSERT INTO public.subject_roles (subject_type, subject_id, role, source) VALUES ('user', '${admin}', 'admin', 'operator_grant');`);
  const t = (id: string): Tok => ({ kind: "bearer_jwt", token: `tok-${id}` });
  return { a, b, admin, tokA: t(a), tokB: t(b), tokAdmin: t(admin) };
}

const actor = (id: string) => ({ type: "user", id, auth_ref: `usr:${id}` });

interface H {
  gov: AefGovernance;
  store: PostgresAefStore;
  ledger: MockEffectLedger;
  overlap: Overlap;
  setBehavior(b: MockBehavior): void;
  setVerdict(v: "APPLIED" | "NOT_APPLIED" | "UNKNOWN" | "THROW" | "SLOW"): void;
}

function harness(w: World, opts: { verifier?: boolean; toolTimeoutMs?: number } = {}): H {
  let behavior: MockBehavior = "SUCCEED";
  let verdict: "APPLIED" | "NOT_APPLIED" | "UNKNOWN" | "THROW" | "SLOW" | "LEDGER" = "LEDGER";
  const ledger = new MockEffectLedger();
  const registry = new ToolRegistry();
  registerMockEffectTools(registry, ledger, () => behavior);
  const verifiers = new ReconciliationVerifierRegistry();
  if (opts.verifier !== false) {
    const v: ReconciliationVerifier = {
      verifierId: "mock.ledger-verifier",
      toolId: MOCK_REVERSIBLE_TOOL,
      async check({ operationId, signal }) {
        if (verdict === "THROW") throw new Error("verifier down");
        if (verdict === "SLOW") {
          await new Promise<void>((resolve) => {
            const t = setTimeout(resolve, 5_000);
            signal.addEventListener("abort", () => { clearTimeout(t); resolve(); }, { once: true });
          });
          return { verdict: "APPLIED", evidenceKind: "LEDGER_CHECK", evidenceRef: "too-late" };
        }
        const applied = (ledger.effects.get(operationId) ?? 0) > 0;
        const out = verdict === "LEDGER" ? (applied ? "APPLIED" : "NOT_APPLIED") : verdict;
        return { verdict: out, evidenceKind: "LEDGER_CHECK", evidenceRef: `ledger:${operationId}` };
      },
    };
    verifiers.register(v);
  }
  verifiers.seal();
  const overlap = new Overlap(new PsqlTransport(PG!));
  const store = new PostgresAefStore(overlap);
  const tokens = new Map([[w.tokA.token, w.a], [w.tokB.token, w.b], [w.tokAdmin.token, w.admin]]);
  const gov = new AefGovernance({
    identityResolver: new AefIdentityResolver(new TokenVerifier(tokens)),
    toolRegistry: registry,
    store,
    verifiers,
    toolTimeoutMs: opts.toolTimeoutMs ?? 300,
  });
  return {
    gov, store, ledger, overlap,
    setBehavior: (b) => (behavior = b),
    setVerdict: (v) => (verdict = v),
  };
}

function req(user: string, o: { key?: string; action?: string; params?: Record<string, unknown> } = {}): ExecutionRequest {
  const now = Date.now();
  return {
    contract_version: "1.0",
    request_id: crypto.randomUUID(),
    requested_at: new Date(now).toISOString(),
    expires_at: new Date(now + 5 * 60_000).toISOString(),
    actor: actor(user),
    intent: "hardening test",
    domain: "internal",
    action: o.action ?? MOCK_REVERSIBLE_TOOL,
    parameters: o.params ?? { n: 1 },
    idempotency_key: o.key ?? crypto.randomUUID(),
  } as unknown as ExecutionRequest;
}

function st<S extends GovernanceResult["status"]>(r: GovernanceResult, s: S): Extract<GovernanceResult, { status: S }> {
  assertEquals(r.status, s, `expected ${s}, got ${JSON.stringify(r)}`);
  return r as Extract<GovernanceResult, { status: S }>;
}
const code = (r: GovernanceResult) => (r.status === "DENIED" ? r.code : r.status);

function sql(q: string): Promise<string[]> {
  return runPsql(PG!, q);
}
async function asReplica(q: string): Promise<void> {
  await sql(`SET session_replication_role = replica;\n${q}\nSET session_replication_role = origin;`);
}
async function registerVerifier(): Promise<void> {
  await sql(`INSERT INTO public.aef_reconciliation_verifiers (verifier_id, tool_id) VALUES ('mock.ledger-verifier', '${MOCK_REVERSIBLE_TOOL}') ON CONFLICT DO NOTHING;`);
}

/** Produces an UNKNOWN_OUTCOME operation (tool hangs past the timeout). */
async function unknownOp(h: H, w: World, key = crypto.randomUUID()) {
  h.setBehavior("HANG");
  const r = req(w.a, { key });
  const done = st(await h.gov.submit(r, w.tokA), "FINAL");
  assertEquals(done.operation.state, "UNKNOWN_OUTCOME");
  h.setBehavior("SUCCEED");
  return { r, operationId: done.operation.operationId, receipt: done.receipt! };
}

Deno.test({ name: "HP-01 verifier reconciliation: append-only, original receipt untouched, never re-executed", ignore, fn: async () => {
  await registerVerifier();
  const w = await world();
  const h = harness(w);
  const { r, operationId, receipt } = await unknownOp(h, w);
  const done = st(await h.gov.reconcile({ operation_id: operationId, actor: actor(w.a) }, w.tokA), "FINAL");
  assertEquals(done.operation.state, "UNKNOWN_OUTCOME", "the operation state never changes");
  assertEquals(done.receipt!.receiptHash, receipt.receiptHash, "the original receipt is untouched");
  assertEquals(done.reconciliation!.receipt.verdict, "CONFIRMED_NOT_APPLIED");
  assertEquals(done.reconciliation!.receipt.original_receipt_hash, receipt.receiptHash);
  assertEquals((await h.gov.verifyReceipt(structuredClone(done.reconciliation!.receipt))).valid, true);
  assertEquals((await h.gov.verifyReceipt(structuredClone(receipt.receipt))).valid, true);
  const replay = st(await h.gov.submit({ ...r, request_id: crypto.randomUUID() }, w.tokA), "FINAL");
  assertEquals(replay.reconciliation!.receipt.receipt_id, done.reconciliation!.receipt.receipt_id);
  assertEquals(h.ledger.invocations.get(operationId), 1, "never re-executed");
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: "HP-02 inconclusive, failing or slow verifiers record nothing; unregistered verifiers are refused", ignore, fn: async () => {
  await registerVerifier();
  const w = await world();
  const h = harness(w);
  const { operationId } = await unknownOp(h, w);
  for (const v of ["UNKNOWN", "THROW", "SLOW"] as const) {
    h.setVerdict(v);
    st(await h.gov.reconcile({ operation_id: operationId, actor: actor(w.a) }, w.tokA), "REMAINS_UNKNOWN");
  }
  const rows = await sql(`SELECT count(*) FROM public.aef_reconciliations WHERE operation_id = '${operationId}';`);
  assertEquals(rows[0], "0");
  const noVerifier = harness(w, { verifier: false });
  assertEquals(code(await noVerifier.gov.reconcile({ operation_id: operationId, actor: actor(w.a) }, w.tokA)), "NO_VERIFIER");
  await sql(`UPDATE public.aef_reconciliation_verifiers SET enabled = false WHERE verifier_id = 'mock.ledger-verifier';`);
  try {
    h.setVerdict("APPLIED");
    assertEquals(code(await h.gov.reconcile({ operation_id: operationId, actor: actor(w.a) }, w.tokA)), "RECONCILER_NOT_AUTHORIZED");
  } finally {
    await sql(`UPDATE public.aef_reconciliation_verifiers SET enabled = true WHERE verifier_id = 'mock.ledger-verifier';`);
  }
}});

Deno.test({ name: "HP-03 only the subject can trigger a check, and only for UNKNOWN_OUTCOME; a client verdict is never accepted", ignore, fn: async () => {
  await registerVerifier();
  const w = await world();
  const h = harness(w);
  const { operationId } = await unknownOp(h, w);
  assertEquals(code(await h.gov.reconcile({ operation_id: operationId, actor: actor(w.b) }, w.tokB)), "OPERATION_NOT_FOUND");
  assertEquals(code(await h.gov.reconcile({ operation_id: operationId, actor: actor(w.a), verdict: "CONFIRMED_APPLIED" }, w.tokA)), "INPUT_REJECTED");
  const ok = st(await h.gov.submit(req(w.a), w.tokA), "FINAL");
  assertEquals(code(await h.gov.reconcile({ operation_id: ok.operation.operationId, actor: actor(w.a) }, w.tokA)), "NOT_RECONCILABLE");
}});

Deno.test({ name: "HP-04 operator reconciliation: admin only, never the subject, identity from the credential", ignore, fn: async () => {
  await sql(`UPDATE public.aef_retention_policy SET operator_reconciliation_enabled = true WHERE id;`);
  const w = await world();
  const h = harness(w);
  const { operationId } = await unknownOp(h, w);
  const body = (op: string) => ({ operation_id: operationId, verdict: "CONFIRMED_APPLIED", evidence_kind: "SUPPORT_TICKET", evidence_ref: "ticket-1", operator: actor(op) });
  assertEquals(code(await h.gov.reconcileByOperator(body(w.a), w.tokA)), "RECONCILER_NOT_AUTHORIZED", "the subject itself");
  assertEquals(code(await h.gov.reconcileByOperator(body(w.b), w.tokB)), "RECONCILER_NOT_AUTHORIZED", "a non-admin");
  assertEquals(code(await h.gov.reconcileByOperator(body(w.admin), w.tokB)), "AUTH_FAILED", "claiming the admin with another credential");
  assertEquals(code(await h.gov.reconcileByOperator({ ...body(w.admin), reconciler_kind: "VERIFIER" }, w.tokAdmin)), "INPUT_REJECTED");
  assertEquals(code(await h.gov.reconcileByOperator({ ...body(w.admin), evidence_ref: "x".repeat(201) }, w.tokAdmin)), "INPUT_REJECTED");
  const done = st(await h.gov.reconcileByOperator(body(w.admin), w.tokAdmin), "FINAL");
  assertEquals(done.reconciliation!.receipt.reconciler_kind, "OPERATOR");
  assert(!JSON.stringify(done.reconciliation).includes(w.admin), "operator id is only referenced by hash");
  assert(!JSON.stringify(done.reconciliation).includes("ticket-1"), "evidence is only referenced by hash");
}});

Deno.test({ name: `HP-05 ${N} concurrent reconciliations of one operation: exactly one is recorded`, ignore, fn: async () => {
  await registerVerifier();
  const w = await world();
  const h = harness(w);
  const { operationId } = await unknownOp(h, w);
  const results = await Promise.all(Array.from({ length: N }, () => h.gov.reconcile({ operation_id: operationId, actor: actor(w.a) }, w.tokA)));
  for (const r of results) assert(r.status === "FINAL" || code(r) === "ALREADY_RECONCILED", JSON.stringify(r));
  assert((h.overlap.peak.get("aef_reconcile") ?? 0) >= 5, `reconciles overlapped: peak ${h.overlap.peak.get("aef_reconcile")}`);
  const rows = await sql(`SELECT count(*) FROM public.aef_reconciliations WHERE operation_id = '${operationId}';`);
  assertEquals(rows[0], "1");
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: "HP-06 reconciliation racing replays: no second execution, one reconciliation", ignore, fn: async () => {
  await registerVerifier();
  const w = await world();
  const h = harness(w);
  const { r, operationId } = await unknownOp(h, w);
  const results = await Promise.all([
    ...Array.from({ length: N / 2 }, () => h.gov.reconcile({ operation_id: operationId, actor: actor(w.a) }, w.tokA)),
    ...Array.from({ length: N / 2 }, () => h.gov.submit({ ...structuredClone(r), request_id: crypto.randomUUID() }, w.tokA)),
  ]);
  for (const x of results) assert(x.status === "FINAL" || code(x) === "ALREADY_RECONCILED", JSON.stringify(x));
  assertEquals(h.ledger.invocations.get(operationId), 1);
  assertEquals((await sql(`SELECT count(*) FROM public.aef_reconciliations WHERE operation_id = '${operationId}';`))[0], "1");
}});

Deno.test({ name: "HP-07 reconciliation racing crash recovery: never reconciles an EXECUTING operation, no deadlock", ignore, fn: async () => {
  await registerVerifier();
  const w = await world();
  const h = harness(w);
  const first = st(await h.gov.submit(req(w.a, { action: MOCK_CONSEQUENTIAL_TOOL }), w.tokA), "AWAITING_APPROVAL");
  st(await h.gov.decideGate({ gate_id: first.gate!.gateId, decision: "APPROVE", binding_hash: first.gate!.bindingHash, approver: actor(w.a) }, w.tokA), "AUTHORIZED");
  const claim = await h.store.claimExecution({ operation_id: first.operation.operationId, subject_id: w.a, binding_hash: first.operation.bindingHash, policy_version: AEF_POLICY_VERSION, lease_seconds: 60 });
  assert(claim.ok);
  await asReplica(`UPDATE public.aef_operations SET lease_expires_at = now() - interval '1 second' WHERE id = '${first.operation.operationId}';`);
  const results = await Promise.all([
    ...Array.from({ length: 5 }, () => h.gov.recover()),
    ...Array.from({ length: 15 }, () => h.store.reconcile({
      operation_id: first.operation.operationId, verdict: "CONFIRMED_NOT_APPLIED", reconciler_kind: "OPERATOR",
      reconciler_id: w.admin, evidence_kind: "SUPPORT_TICKET", evidence_ref: "t", policy_version: AEF_POLICY_VERSION, risk_version: "aef-risk/2026-09-25.1",
    })),
  ]);
  assertEquals(results.length, 20, "every call returned (no deadlock)");
  const rows = await sql(`SELECT o.state || '|' || (SELECT count(*) FROM public.aef_reconciliations r WHERE r.operation_id = o.id) FROM public.aef_operations o WHERE o.id = '${first.operation.operationId}';`);
  assert(rows[0] === "UNKNOWN_OUTCOME|1" || rows[0] === "UNKNOWN_OUTCOME|0", rows[0]);
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: "HP-08 retention racing reconciliation and verification; purged keys are retired forever", ignore, fn: async () => {
  await registerVerifier();
  const w = await world();
  const h = harness(w);
  const { r, operationId, receipt } = await unknownOp(h, w);
  await asReplica(`UPDATE public.aef_operations SET completed_at = now() - interval '400 days' WHERE id = '${operationId}';`);
  const results = await Promise.all([
    ...Array.from({ length: 5 }, () => h.gov.purge()),
    ...Array.from({ length: 10 }, () => h.gov.reconcile({ operation_id: operationId, actor: actor(w.a) }, w.tokA)),
    ...Array.from({ length: 10 }, () => h.gov.verifyReceipt(structuredClone(receipt.receipt))),
  ]);
  assertEquals(results.length, 25);
  const live = await sql(`SELECT count(*) FROM public.aef_operations WHERE id = '${operationId}';`);
  assertEquals(live[0], "1", "an unknown outcome reconciled just now is not purged");
  assertEquals((await h.gov.verifyReceipt(structuredClone(receipt.receipt))).valid, true);
  await asReplica(`UPDATE public.aef_reconciliations SET reconciled_at = now() - interval '400 days' WHERE operation_id = '${operationId}';`);
  assert((await h.gov.purge()).purgedOperations >= 1);
  assertEquals((await h.gov.verifyReceipt(structuredClone(receipt.receipt))).reason, "RECEIPT_UNKNOWN");
  assertEquals(code(await h.gov.submit({ ...structuredClone(r), request_id: crypto.randomUUID() }, w.tokA)), "IDEMPOTENCY_KEY_RETIRED");
  assertEquals(h.ledger.invocations.get(operationId), 1, "a purged operation never runs again");
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: "HP-09 erasure racing an in-flight execution and itself; other subjects unaffected", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const first = st(await h.gov.submit(req(w.b), w.tokB), "FINAL"); // B keeps data
  const pend = st(await h.gov.submit(req(w.a, { action: MOCK_CONSEQUENTIAL_TOOL }), w.tokA), "AWAITING_APPROVAL");
  st(await h.gov.decideGate({ gate_id: pend.gate!.gateId, decision: "APPROVE", binding_hash: pend.gate!.bindingHash, approver: actor(w.a) }, w.tokA), "AUTHORIZED");
  const claim = await h.store.claimExecution({ operation_id: pend.operation.operationId, subject_id: w.a, binding_hash: pend.operation.bindingHash, policy_version: AEF_POLICY_VERSION, lease_seconds: 60 });
  assert(claim.ok);
  assertEquals(await h.gov.eraseSubject(w.a), { ok: false, code: "ERASURE_ACCOUNT_ACTIVE" });
  await sql(`DELETE FROM auth.users WHERE id = '${w.a}';`);
  const racing = await Promise.all([
    ...Array.from({ length: 10 }, () => h.gov.eraseSubject(w.a)),
    h.store.completeExecution({ operation_id: pend.operation.operationId, execution_token: (claim as { executionToken: string }).executionToken, result: "SUCCEEDED" }),
  ]);
  const erasures = racing.slice(0, 10) as { ok: boolean; outcome?: string; code?: string }[];
  for (const e of erasures) assert(e.ok ? true : e.code === "ERASURE_BLOCKED_ACTIVE", JSON.stringify(e));
  const again = await Promise.all(Array.from({ length: 10 }, () => h.gov.eraseSubject(w.a)));
  const erasedNow = [...erasures, ...again].filter((e) => e.ok && e.outcome === "ERASED").length;
  assertEquals(erasedNow, 1, "exactly one erasure takes effect");
  const left = await sql(`SELECT (SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}') + (SELECT count(*) FROM public.aef_audit_events WHERE subject_id = '${w.a}');`);
  assertEquals(left[0], "0");
  assertEquals((await h.gov.verifyReceipt(structuredClone(first.receipt!.receipt))).valid, true, "B's receipt still verifies");
  assertEquals((await h.gov.verifyAuditChain(w.b)).valid, true);
}});

Deno.test({ name: `HP-10 denial flood: ${N}×10 concurrent denials — bounded storage, every denial accounted for`, ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  await Promise.all(Array.from({ length: N }, async () => {
    for (let i = 0; i < 10; i++) assertEquals(code(await h.gov.submit(req(w.a, { action: "internal.no_such_tool" }), w.tokA)), "UNKNOWN_TOOL");
  }));
  const rows = await sql(`SELECT (SELECT count(*) FROM public.aef_audit_events WHERE subject_id = '${w.a}')
    || '|' || coalesce((SELECT sum(count) FROM public.aef_audit_pending WHERE subject_id = '${w.a}'), 0)
    || '|' || coalesce((SELECT sum(count) FROM public.aef_audit_coalesced WHERE subject_id = '${w.a}'), 0);`);
  const [events, pending, coalesced] = rows[0].split("|").map(Number);
  assert(events <= 60, `events stored: ${events}`);
  const individual = Number((await sql(`SELECT count(*) FROM public.aef_audit_events WHERE subject_id = '${w.a}' AND event_type = 'REQUEST_DENIED';`))[0]);
  assertEquals(individual + pending + coalesced, N * 10, "no denial lost");
  await sql(`UPDATE public.aef_audit_windows SET window_start = now() - interval '2 minutes' WHERE subject_id = '${w.a}';`);
  assert((await h.gov.recover()).coalescedFlushed >= 1);
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: "HP-11 legal hold racing retention: a hold committed before the purge touches the subject is always honored (Codex HG1-01)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const ops: string[] = [];
  for (let i = 0; i < 10; i++) ops.push(st(await h.gov.submit(req(w.a), w.tokA), "FINAL").operation.operationId);
  await asReplica(`UPDATE public.aef_operations SET completed_at = now() - interval '400 days' WHERE subject_id = '${w.a}';`);
  const holdAt: number[] = [];
  await Promise.all([
    ...Array.from({ length: 5 }, () => h.gov.purge()),
    (async () => {
      await sql(`INSERT INTO public.aef_legal_holds (subject_id, reason_code) VALUES ('${w.a}', 'RACE_HOLD');`);
      holdAt.push(Date.now());
    })(),
  ]);
  // Whatever the interleaving: once the hold is committed, nothing more of A is ever purged.
  const before = Number((await sql(`SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}';`))[0]);
  for (let i = 0; i < 3; i++) await h.gov.purge();
  const after = Number((await sql(`SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}';`))[0]);
  assertEquals(after, before, "purge ignored a committed legal hold");
  assert(holdAt.length === 1);
  assertEquals((await h.gov.verifyAuditChain(w.a)).valid, true);
}});

Deno.test({ name: "HP-12 recovery flushing a denial window racing erasure: no deadlock, erasure completes (Codex HG2-01)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  for (let i = 0; i < 30; i++) assertEquals(code(await h.gov.submit(req(w.a, { action: "internal.no_such_tool" }), w.tokA)), "UNKNOWN_TOOL");
  await sql(`UPDATE public.aef_audit_windows SET window_start = now() - interval '2 minutes' WHERE subject_id = '${w.a}';`);
  await sql(`DELETE FROM auth.users WHERE id = '${w.a}';`);
  const results = await Promise.allSettled([
    ...Array.from({ length: 10 }, () => h.gov.recover()),
    ...Array.from({ length: 10 }, () => h.gov.eraseSubject(w.a)),
  ]);
  for (const r of results) assertEquals(r.status, "fulfilled", `a call failed (deadlock?): ${JSON.stringify(r)}`);
  const left = await sql(`SELECT (SELECT count(*) FROM public.aef_audit_events WHERE subject_id = '${w.a}')
    + (SELECT count(*) FROM public.aef_audit_pending WHERE subject_id = '${w.a}')
    + (SELECT count(*) FROM public.aef_audit_windows WHERE subject_id = '${w.a}');`);
  assertEquals(left[0], "0");
}});

Deno.test({ name: "HP-13 registration racing erasure, and reuse after erasure: never an operation outliving the erasure (Codex HG2-02)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const old = req(w.a);
  st(await h.gov.submit(old, w.tokA), "FINAL");
  await sql(`DELETE FROM auth.users WHERE id = '${w.a}';`);
  // The identity resolver still accepts the token here on purpose: the database must refuse on its own.
  const results = await Promise.allSettled([
    ...Array.from({ length: 10 }, () => h.gov.submit(req(w.a), w.tokA)),
    ...Array.from({ length: 5 }, () => h.gov.eraseSubject(w.a)),
  ]);
  for (const r of results) assertEquals(r.status, "fulfilled", JSON.stringify(r));
  const left = await sql(`SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}';`);
  const erased = await h.gov.eraseSubject(w.a);
  assert(erased.ok);
  const after = await sql(`SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}';`);
  assertEquals(after[0], "0", `operations survived erasure (before final erase: ${left[0]})`);
  assertEquals(code(await h.gov.submit({ ...structuredClone(old), request_id: crypto.randomUUID() }, w.tokA)), "SUBJECT_ERASED");
  assertEquals(code(await h.gov.submit(req(w.a), w.tokA)), "SUBJECT_ERASED");
  assertEquals(h.ledger.totalEffects() <= 11, true);
}});

const pause = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

Deno.test({ name: "HP-14 deterministic: a session holding the denial window (recovery order window → head) never deadlocks an erasure (Codex HG2-01)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  for (let i = 0; i < 3; i++) assertEquals(code(await h.gov.submit(req(w.a, { action: "internal.no_such_tool" }), w.tokA)), "UNKNOWN_TOOL");
  await sql(`DELETE FROM auth.users WHERE id = '${w.a}';`);
  // Session R follows the append/recovery lock order: window, pause, then head.
  const recovery = sql(`BEGIN;
    SELECT 1 FROM public.aef_audit_windows WHERE subject_id = '${w.a}' FOR UPDATE;
    SELECT pg_sleep(2);
    SELECT 1 FROM public.aef_audit_heads WHERE subject_id = '${w.a}' FOR UPDATE;
    COMMIT;`);
  await pause(700);
  const [r, e] = await Promise.allSettled([recovery, h.gov.eraseSubject(w.a)]);
  assertEquals(r.status, "fulfilled", `recovery-order session failed (deadlock?): ${JSON.stringify(r)}`);
  assertEquals(e.status, "fulfilled", `erasure failed (deadlock?): ${JSON.stringify(e)}`);
  assertEquals((e as PromiseFulfilledResult<{ ok: boolean }>).value.ok, true);
}});

Deno.test({ name: "HP-15 deterministic: while a legal hold is being written for a subject, retention purges nothing of it (Codex HG1-01)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  for (let i = 0; i < 3; i++) st(await h.gov.submit(req(w.a), w.tokA), "FINAL");
  await asReplica(`UPDATE public.aef_operations SET completed_at = now() - interval '400 days' WHERE subject_id = '${w.a}';`);
  const holder = sql(`BEGIN;
    INSERT INTO public.aef_legal_holds (subject_id, reason_code) VALUES ('${w.a}', 'PENDING_HOLD');
    SELECT pg_sleep(2);
    COMMIT;`);
  await pause(700);
  await h.gov.purge();
  await holder;
  const left = await sql(`SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}';`);
  assertEquals(left[0], "3", "purge deleted data of a subject whose legal hold was being placed");
  await h.gov.purge();
  assertEquals((await sql(`SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}';`))[0], "3", "hold not honored after commit");
}});

Deno.test({ name: "HP-16 real recovery (expired lease + pending denial window) racing erasure of the same subject: every call returns (Codex HG2V-01)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  for (let i = 0; i < 25; i++) assertEquals(code(await h.gov.submit(req(w.a, { action: "internal.no_such_tool" }), w.tokA)), "UNKNOWN_TOOL");
  const pend = st(await h.gov.submit(req(w.a, { action: MOCK_CONSEQUENTIAL_TOOL }), w.tokA), "AWAITING_APPROVAL");
  st(await h.gov.decideGate({ gate_id: pend.gate!.gateId, decision: "APPROVE", binding_hash: pend.gate!.bindingHash, approver: actor(w.a) }, w.tokA), "AUTHORIZED");
  assert((await h.store.claimExecution({ operation_id: pend.operation.operationId, subject_id: w.a, binding_hash: pend.operation.bindingHash, policy_version: AEF_POLICY_VERSION, lease_seconds: 60 })).ok);
  await asReplica(`UPDATE public.aef_operations SET lease_expires_at = now() - interval '1 second' WHERE id = '${pend.operation.operationId}';`);
  await sql(`UPDATE public.aef_audit_windows SET window_start = now() - interval '2 minutes' WHERE subject_id = '${w.a}';`);
  await sql(`DELETE FROM auth.users WHERE id = '${w.a}';`);
  await sql(`UPDATE public.aef_retention_policy SET erasure_blocks_on_unreconciled = false WHERE id;`);
  try {
    const results = await Promise.allSettled([
      ...Array.from({ length: 10 }, () => h.gov.recover()),
      ...Array.from({ length: 10 }, () => h.gov.eraseSubject(w.a)),
    ]);
    for (const r of results) assertEquals(r.status, "fulfilled", `a call failed (deadlock?): ${JSON.stringify(r)}`);
    for (let i = 0; i < 3; i++) await h.gov.recover();
    const final = await h.gov.eraseSubject(w.a);
    assert(final.ok, JSON.stringify(final));
    const left = await sql(`SELECT (SELECT count(*) FROM public.aef_operations WHERE subject_id = '${w.a}')
      + (SELECT count(*) FROM public.aef_audit_events WHERE subject_id = '${w.a}')
      + (SELECT count(*) FROM public.aef_audit_windows WHERE subject_id = '${w.a}')
      + (SELECT count(*) FROM public.aef_audit_pending WHERE subject_id = '${w.a}');`);
    assertEquals(left[0], "0");
  } finally {
    await sql(`UPDATE public.aef_retention_policy SET erasure_blocks_on_unreconciled = true WHERE id;`);
  }
}});

Deno.test({ name: "HP-17 deterministic: a decision waiting on an operation that is deleted meanwhile gets GATE_NOT_FOUND, never an error", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  const pend = st(await h.gov.submit(req(w.a, { action: MOCK_CONSEQUENTIAL_TOOL }), w.tokA), "AWAITING_APPROVAL");
  // Owner session deleting the operation (as purge/erasure would) and holding its lock.
  const deleter = sql(`BEGIN;
    SELECT set_config('aef.maintenance', 'on', true);
    SELECT 1 FROM public.aef_operations WHERE id = '${pend.operation.operationId}' FOR UPDATE;
    DELETE FROM public.aef_human_gates WHERE operation_id = '${pend.operation.operationId}';
    DELETE FROM public.aef_operations WHERE id = '${pend.operation.operationId}';
    SELECT pg_sleep(2);
    COMMIT;`);
  await pause(700);
  const decided = await h.gov.decideGate({ gate_id: pend.gate!.gateId, decision: "APPROVE", binding_hash: pend.gate!.bindingHash, approver: actor(w.a) }, w.tokA);
  await deleter;
  assertEquals(code(decided), "GATE_NOT_FOUND");
  assertEquals(h.ledger.invocations.size, 0);
}});

Deno.test({ name: "HP-18 deterministic: a denial racing the erasure of its subject never re-creates the subject (Codex HG2V-02)", ignore, fn: async () => {
  const w = await world();
  const h = harness(w);
  for (let i = 0; i < 2; i++) assertEquals(code(await h.gov.submit(req(w.a, { action: "internal.no_such_tool" }), w.tokA)), "UNKNOWN_TOOL");
  await sql(`DELETE FROM auth.users WHERE id = '${w.a}';`);
  // Slow the erasure down: a session holds the subject's denial window for 2 s.
  const holder = sql(`BEGIN; SELECT 1 FROM public.aef_audit_windows WHERE subject_id = '${w.a}' FOR UPDATE; SELECT pg_sleep(2); COMMIT;`);
  await pause(500);
  const erasing = h.gov.eraseSubject(w.a);
  await pause(500);
  const denied = h.store.recordDenial({ subject_id: w.a, reason_code: "UNKNOWN_TOOL" }).then(() => "RECORDED", (e) => `ERR:${e}`);
  const [e] = await Promise.all([erasing, holder, denied]);
  assert(e.ok, JSON.stringify(e));
  const left = await sql(`SELECT (SELECT count(*) FROM public.aef_audit_events WHERE subject_id = '${w.a}')
    + (SELECT count(*) FROM public.aef_audit_heads WHERE subject_id = '${w.a}')
    + (SELECT count(*) FROM public.aef_audit_windows WHERE subject_id = '${w.a}')
    + (SELECT count(*) FROM public.aef_audit_pending WHERE subject_id = '${w.a}');`);
  assertEquals(left[0], "0", "the erased subject was re-created by a racing denial");
}});

Deno.test({ name: "HP-19 operator reconciliation is refused while the Owner has not enabled it (Codex HCF-01)", ignore, fn: async () => {
  await sql(`UPDATE public.aef_retention_policy SET operator_reconciliation_enabled = false WHERE id;`);
  try {
    const w = await world();
    const h = harness(w);
    const { operationId } = await unknownOp(h, w);
    const r = await h.gov.reconcileByOperator({ operation_id: operationId, verdict: "CONFIRMED_APPLIED", evidence_kind: "SUPPORT_TICKET", evidence_ref: "invented", operator: actor(w.admin) }, w.tokAdmin);
    assertEquals(code(r), "RECONCILER_NOT_AUTHORIZED");
    assertEquals((await sql(`SELECT count(*) FROM public.aef_reconciliations WHERE operation_id = '${operationId}';`))[0], "0");
  } finally {
    await sql(`UPDATE public.aef_retention_policy SET operator_reconciliation_enabled = true WHERE id;`);
  }
}});
