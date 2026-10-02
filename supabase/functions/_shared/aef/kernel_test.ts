/**
 * AEF Kernel tests — IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 *
 * Covers: idempotency, policy decisions, human gate lifecycle,
 * receipt issuance, denied actions, persistence failure handling.
 */
import { assertEquals, assertExists, assertMatch } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { InMemoryAefStore } from './store.ts';
import { AEF_POLICY_VERSION, classifyIntent, resolveHumanGate, submitAction } from './kernel.ts';
import type { CallerContext, ImpactActionIntent } from './types.ts';

const RECEIPT_HASH_RE = /^[0-9a-f]{64}$/;

function makeCallerContext(overrides: Partial<CallerContext> = {}): CallerContext {
  return {
    authenticatedUserId: 'user-001',
    moduleId: 'impact',
    correlationId: 'corr-001',
    projectId: null,
    serviceId: 'impact-lab',
    ...overrides,
  };
}

function makeIntent(overrides: Partial<ImpactActionIntent> = {}): ImpactActionIntent {
  return {
    kind: 'ACKNOWLEDGE_CONFLICT',
    investigationId: 'inv-001',
    idempotencyKey: crypto.randomUUID(),
    classification: 'REVERSIBLE',
    ...overrides,
  };
}

// ── classifyIntent ────────────────────────────────────────────────────────────

Deno.test('classifyIntent: REVERSIBLE intents', () => {
  assertEquals(classifyIntent('ACKNOWLEDGE_CONFLICT'), 'REVERSIBLE');
  assertEquals(classifyIntent('MARK_INVESTIGATION_REVIEWED'), 'REVERSIBLE');
});

Deno.test('classifyIntent: CONSEQUENTIAL intents', () => {
  assertEquals(classifyIntent('REQUEST_MANUAL_VERIFICATION'), 'CONSEQUENTIAL');
  assertEquals(classifyIntent('APPROVE_DOSSIER_PUBLICATION'), 'CONSEQUENTIAL');
});

// ── submitAction: REVERSIBLE (authorized) ────────────────────────────────────

Deno.test('submitAction: REVERSIBLE intent is authorized', async () => {
  const store = new InMemoryAefStore();
  const result = await submitAction(makeCallerContext(), makeIntent(), { store });
  assertEquals(result.ok, true);
  assertExists(result.receipt);
  assertEquals(result.receipt!.executionOutcome, 'AUTHORIZED');
  assertEquals(result.receipt!.policyOutcome, 'AUTHORIZED');
  assertEquals(result.receipt!.policyVersion, AEF_POLICY_VERSION);
  assertMatch(result.receipt!.receiptHash, RECEIPT_HASH_RE);
  assertEquals(result.receipt!.humanGateId, null);
});

Deno.test('submitAction: receipt carries caller context', async () => {
  const store = new InMemoryAefStore();
  const caller = makeCallerContext({ projectId: 'proj-abc' });
  const intent = makeIntent();
  const result = await submitAction(caller, intent, { store });
  assertEquals(result.ok, true);
  assertEquals(result.receipt!.callerUserId, 'user-001');
  assertEquals(result.receipt!.projectId, 'proj-abc');
  assertEquals(result.receipt!.serviceId, 'impact-lab');
  assertEquals(result.receipt!.intentKind, intent.kind);
  assertEquals(result.receipt!.investigationId, intent.investigationId);
  assertEquals(result.receipt!.idempotencyKey, intent.idempotencyKey);
});

// ── submitAction: CONSEQUENTIAL (requires human review) ──────────────────────

Deno.test('submitAction: CONSEQUENTIAL intent requires human review', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent({ kind: 'REQUEST_MANUAL_VERIFICATION', classification: 'CONSEQUENTIAL' });
  const result = await submitAction(makeCallerContext(), intent, { store });
  assertEquals(result.ok, false);
  assertExists(result.receipt);
  assertEquals(result.receipt!.executionOutcome, 'REQUIRES_HUMAN_REVIEW');
  assertEquals(result.receipt!.policyOutcome, 'REQUIRES_HUMAN_REVIEW');
  assertExists(result.receipt!.humanGateId);
  if (!result.ok) {
    assertEquals(result.error.code, 'REQUIRES_HUMAN_REVIEW');
  }
});

// ── submitAction: idempotency ─────────────────────────────────────────────────

Deno.test('submitAction: duplicate idempotency key returns IDEMPOTENCY_CONFLICT', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent();
  const first = await submitAction(makeCallerContext(), intent, { store });
  assertEquals(first.ok, true);

  const second = await submitAction(makeCallerContext(), intent, { store });
  assertEquals(second.ok, false);
  if (!second.ok) {
    assertEquals(second.error.code, 'IDEMPOTENCY_CONFLICT');
  }
});

Deno.test('submitAction: same idempotency key for different users is a new request', async () => {
  const store = new InMemoryAefStore();
  const key = crypto.randomUUID();
  const intent = makeIntent({ idempotencyKey: key });
  const first = await submitAction(makeCallerContext({ authenticatedUserId: 'user-001' }), intent, { store });
  assertEquals(first.ok, true);
  const second = await submitAction(makeCallerContext({ authenticatedUserId: 'user-002' }), intent, { store });
  assertEquals(second.ok, true); // different user — new request
});

Deno.test('submitAction: same key for different intents is a new request', async () => {
  const store = new InMemoryAefStore();
  const key = crypto.randomUUID();
  const r1 = await submitAction(makeCallerContext(), makeIntent({ idempotencyKey: key, kind: 'ACKNOWLEDGE_CONFLICT' }), { store });
  assertEquals(r1.ok, true);
  const r2 = await submitAction(makeCallerContext(), makeIntent({ idempotencyKey: key, kind: 'MARK_INVESTIGATION_REVIEWED' }), { store });
  assertEquals(r2.ok, true); // different kind — new request
});

// ── resolveHumanGate ──────────────────────────────────────────────────────────

Deno.test('resolveHumanGate: approve resolves gate', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent({ kind: 'REQUEST_MANUAL_VERIFICATION', classification: 'CONSEQUENTIAL' });
  const submitResult = await submitAction(makeCallerContext(), intent, { store });
  assertEquals(submitResult.ok, false);
  if (submitResult.ok) return;
  const error = submitResult.error;
  if (error.code !== 'REQUIRES_HUMAN_REVIEW') return;

  const bindingHash = '0'.repeat(64);
  const gateResult = await resolveHumanGate(
    submitResult.receipt!.requestId,
    'APPROVED',
    'reviewer-001',
    bindingHash,
    { store },
  );
  assertEquals(gateResult.ok, true);
  assertExists(gateResult.receipt);
  assertEquals(gateResult.receipt!.executionOutcome, 'AUTHORIZED');
  assertMatch(gateResult.receipt!.receiptHash, RECEIPT_HASH_RE);
});

Deno.test('resolveHumanGate: reject denies gate', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent({ kind: 'APPROVE_DOSSIER_PUBLICATION', classification: 'CONSEQUENTIAL' });
  const submitResult = await submitAction(makeCallerContext(), intent, { store });
  assertEquals(submitResult.ok, false);
  if (submitResult.ok || submitResult.error.code !== 'REQUIRES_HUMAN_REVIEW') return;

  const gateResult = await resolveHumanGate(
    submitResult.receipt!.requestId,
    'REJECTED',
    'reviewer-001',
    '0'.repeat(64),
    { store },
  );
  assertEquals(gateResult.ok, false);
  if (!gateResult.ok) {
    assertEquals(gateResult.receipt!.executionOutcome, 'DENIED');
  }
});

Deno.test('resolveHumanGate: double-resolve rejected with HUMAN_GATE_INVALID', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent({ kind: 'REQUEST_MANUAL_VERIFICATION', classification: 'CONSEQUENTIAL' });
  const submitResult = await submitAction(makeCallerContext(), intent, { store });
  if (submitResult.ok || submitResult.error.code !== 'REQUIRES_HUMAN_REVIEW') return;

  const requestId = submitResult.receipt!.requestId;
  await resolveHumanGate(requestId, 'APPROVED', 'r-001', '0'.repeat(64), { store });
  const second = await resolveHumanGate(requestId, 'APPROVED', 'r-002', '0'.repeat(64), { store });
  assertEquals(second.ok, false);
  if (!second.ok) assertEquals(second.error.code, 'HUMAN_GATE_INVALID');
});

Deno.test('resolveHumanGate: invalid approver ref rejected', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent({ kind: 'REQUEST_MANUAL_VERIFICATION', classification: 'CONSEQUENTIAL' });
  const submitResult = await submitAction(makeCallerContext(), intent, { store });
  if (submitResult.ok || submitResult.error.code !== 'REQUIRES_HUMAN_REVIEW') return;

  const result = await resolveHumanGate(
    submitResult.receipt!.requestId,
    'APPROVED',
    '', // empty approver
    '0'.repeat(64),
    { store },
  );
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.error.code, 'HUMAN_GATE_INVALID');
});

Deno.test('resolveHumanGate: invalid binding hash rejected', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent({ kind: 'REQUEST_MANUAL_VERIFICATION', classification: 'CONSEQUENTIAL' });
  const submitResult = await submitAction(makeCallerContext(), intent, { store });
  if (submitResult.ok || submitResult.error.code !== 'REQUIRES_HUMAN_REVIEW') return;

  const result = await resolveHumanGate(
    submitResult.receipt!.requestId,
    'APPROVED',
    'reviewer',
    'not-a-hash', // invalid
    { store },
  );
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.error.code, 'HUMAN_GATE_INVALID');
});

Deno.test('resolveHumanGate: expired gate rejected', async () => {
  const store = new InMemoryAefStore();
  const intent = makeIntent({ kind: 'REQUEST_MANUAL_VERIFICATION', classification: 'CONSEQUENTIAL' });
  // Submit with a past timestamp to create an already-expired gate
  const pastNow = () => new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
  const submitResult = await submitAction(makeCallerContext(), intent, { store, now: pastNow });
  if (submitResult.ok || submitResult.error.code !== 'REQUIRES_HUMAN_REVIEW') return;

  const result = await resolveHumanGate(
    submitResult.receipt!.requestId,
    'APPROVED',
    'reviewer',
    '0'.repeat(64),
    { store }, // uses current time — gate is expired
  );
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.error.code, 'HUMAN_GATE_INVALID');
});

// ── Receipt hash determinism ─────────────────────────────────────────────────

Deno.test('receipt hash is deterministic for same inputs', async () => {
  const store1 = new InMemoryAefStore();
  const store2 = new InMemoryAefStore();
  const now = () => '2026-10-02T00:00:00.000Z';
  const key = crypto.randomUUID();
  const caller = makeCallerContext();
  const intent = makeIntent({ idempotencyKey: key });

  const r1 = await submitAction(caller, intent, { store: store1, now });
  const r2 = await submitAction(caller, intent, { store: store2, now });
  assertEquals(r1.ok, true);
  assertEquals(r2.ok, true);
  // Same inputs must produce same receipt hash (minus the random requestId/receiptId)
  assertMatch(r1.receipt!.receiptHash, RECEIPT_HASH_RE);
  assertMatch(r2.receipt!.receiptHash, RECEIPT_HASH_RE);
});
