/**
 * INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §7-9 — Result -> Learning,
 * the pure half: what a governed fact turns into as a business_memory row.
 *   deno test --allow-read supabase/functions/_shared/result_learning_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildLearningRow, expiresAtForPlan, RESULT_LEARNING_RETENTION_DAYS } from './result_learning.ts';
import type { LearningEntryInput } from '../../../aef/runtime/ive_aef_runtime.ts';

const BASE: LearningEntryInput = {
  subjectId: '0a000000-0000-4000-8000-00000000000a',
  projectId: '0d000000-0000-4000-8000-00000000000d',
  contextRef: '0b000000-0000-4000-8000-00000000000b',
  source: 'action_engine',
  requestedAction: 'internal.mock_complete_action',
  operationId: '0c000000-0000-4000-8000-00000000000c',
  receiptId: '0e000000-0000-4000-8000-00000000000e',
  outcome: 'SUCCESS',
  phase: 'SUCCEEDED',
};

Deno.test('RL-01 SUCCESS is the ONLY outcome ever marked verified -- every other outcome, including PARTIAL, is unverified', async () => {
  const success = await buildLearningRow({ ...BASE, outcome: 'SUCCESS' }, 'free');
  assertEquals(success.verification_state, 'verified');
  for (const outcome of ['FAILURE', 'PARTIAL', 'NOT_EXECUTED', 'UNKNOWN_OUTCOME', 'GARBAGE']) {
    const row = await buildLearningRow({ ...BASE, outcome }, 'free');
    assertEquals(row.verification_state, 'unverified', outcome);
  }
});

Deno.test('RL-02 memory_type uses only the existing BusinessMemory.types vocabulary (lib/data/models/business_memory.dart) -- no new type invented', async () => {
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'SUCCESS' }, 'free')).memory_type, 'success');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'FAILURE' }, 'free')).memory_type, 'failure');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'NOT_EXECUTED' }, 'free')).memory_type, 'failure');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'PARTIAL' }, 'free')).memory_type, 'decision');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'UNKNOWN_OUTCOME' }, 'free')).memory_type, 'decision');
});

Deno.test('RL-03 dedup_key is deterministic from (operationId, receiptId) alone -- idempotent by construction', async () => {
  const a = await buildLearningRow(BASE, 'free');
  const b = await buildLearningRow({ ...BASE, subjectId: BASE.subjectId, phase: 'SUCCEEDED', requestedAction: 'irrelevant_for_dedup' }, 'free');
  assertEquals(a.dedup_key, b.dedup_key, 'same operation+receipt must dedup together regardless of other fields');
  const different = await buildLearningRow({ ...BASE, receiptId: '0f000000-0000-4000-8000-00000000000f' }, 'free');
  assert(a.dedup_key !== different.dedup_key, 'a different receipt must never collide');
});

Deno.test('RL-04 project binding: projectId passes through untouched, including null (never invented)', async () => {
  assertEquals((await buildLearningRow({ ...BASE, projectId: BASE.projectId }, 'free')).project_id, BASE.projectId);
  assertEquals((await buildLearningRow({ ...BASE, projectId: null }, 'free')).project_id, null);
});

Deno.test('RL-05 receipt/operation identity is preserved verbatim for audit traceability', async () => {
  const row = await buildLearningRow(BASE, 'free');
  assertEquals(row.source_operation_id, BASE.operationId);
  assertEquals(row.source_receipt_id, BASE.receiptId);
  assertEquals(row.source_action_id, BASE.contextRef);
});

Deno.test('RL-06 origin is always system_derived -- a learning row can never be self-attested by the authenticated user', async () => {
  const row = await buildLearningRow(BASE, 'free');
  assertEquals(row.origin, 'system_derived');
});

Deno.test('RL-07 confidence_score reflects the real epistemic strength: SUCCESS highest, FAILURE/NOT_EXECUTED lowest, PARTIAL/UNKNOWN_OUTCOME in between', async () => {
  const success = await buildLearningRow({ ...BASE, outcome: 'SUCCESS' }, 'free');
  const failure = await buildLearningRow({ ...BASE, outcome: 'FAILURE' }, 'free');
  const partial = await buildLearningRow({ ...BASE, outcome: 'PARTIAL' }, 'free');
  assert(success.confidence_score > partial.confidence_score);
  assert(partial.confidence_score > failure.confidence_score);
});

Deno.test('RL-08 source is tagged with the calling surface (aef:<source>), never a bare/ambiguous tag', async () => {
  const ae = await buildLearningRow({ ...BASE, source: 'action_engine' }, 'free');
  const ive = await buildLearningRow({ ...BASE, source: 'ive' }, 'free');
  assertEquals(ae.source, 'aef:action_engine');
  assertEquals(ive.source, 'aef:ive');
  assert(ae.source !== ive.source, 'two different calling surfaces must remain distinguishable in provenance');
});

// ── Premium value: retention (INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §20-21) ──
Deno.test('RL-09 Premium learning entries never expire; Free/Pro entries expire after the configured retention window', () => {
  const now = new Date('2026-01-01T00:00:00.000Z');
  assertEquals(expiresAtForPlan('premium', now), null);
  for (const plan of ['free', 'pro'] as const) {
    const expires = expiresAtForPlan(plan, now);
    assert(expires !== null, plan);
    const days = RESULT_LEARNING_RETENTION_DAYS[plan]!;
    assertEquals(new Date(expires).getTime() - now.getTime(), days * 24 * 60 * 60 * 1000, plan);
  }
});

Deno.test('RL-10 an unresolvable plan (lookup failure/null) fails closed to the SHORTEST retention, never to Premium\'s "never expires"', () => {
  const now = new Date('2026-01-01T00:00:00.000Z');
  assertEquals(expiresAtForPlan(null, now), expiresAtForPlan('free', now));
  assert(expiresAtForPlan(null, now) !== null, 'a lookup failure must never accidentally grant unlimited retention');
});

Deno.test('RL-11 buildLearningRow actually carries the plan-derived expires_at through to the row', async () => {
  const now = new Date('2026-01-01T00:00:00.000Z');
  const premiumRow = await buildLearningRow(BASE, 'premium', now);
  const freeRow = await buildLearningRow(BASE, 'free', now);
  assertEquals(premiumRow.expires_at, null);
  assertEquals(freeRow.expires_at, expiresAtForPlan('free', now));
});
