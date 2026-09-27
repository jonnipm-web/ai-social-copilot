/**
 * INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §7-9 — Result -> Learning,
 * the pure half: what a governed fact turns into as a business_memory row.
 *   deno test --allow-read supabase/functions/_shared/result_learning_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildLearningRow } from './result_learning.ts';
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
  const success = await buildLearningRow({ ...BASE, outcome: 'SUCCESS' });
  assertEquals(success.verification_state, 'verified');
  for (const outcome of ['FAILURE', 'PARTIAL', 'NOT_EXECUTED', 'UNKNOWN_OUTCOME', 'GARBAGE']) {
    const row = await buildLearningRow({ ...BASE, outcome });
    assertEquals(row.verification_state, 'unverified', outcome);
  }
});

Deno.test('RL-02 memory_type uses only the existing BusinessMemory.types vocabulary (lib/data/models/business_memory.dart) -- no new type invented', async () => {
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'SUCCESS' })).memory_type, 'success');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'FAILURE' })).memory_type, 'failure');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'NOT_EXECUTED' })).memory_type, 'failure');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'PARTIAL' })).memory_type, 'decision');
  assertEquals((await buildLearningRow({ ...BASE, outcome: 'UNKNOWN_OUTCOME' })).memory_type, 'decision');
});

Deno.test('RL-03 dedup_key is deterministic from (operationId, receiptId) alone -- idempotent by construction', async () => {
  const a = await buildLearningRow(BASE);
  const b = await buildLearningRow({ ...BASE, subjectId: BASE.subjectId, phase: 'SUCCEEDED', requestedAction: 'irrelevant_for_dedup' });
  assertEquals(a.dedup_key, b.dedup_key, 'same operation+receipt must dedup together regardless of other fields');
  const different = await buildLearningRow({ ...BASE, receiptId: '0f000000-0000-4000-8000-00000000000f' });
  assert(a.dedup_key !== different.dedup_key, 'a different receipt must never collide');
});

Deno.test('RL-04 project binding: projectId passes through untouched, including null (never invented)', async () => {
  assertEquals((await buildLearningRow({ ...BASE, projectId: BASE.projectId })).project_id, BASE.projectId);
  assertEquals((await buildLearningRow({ ...BASE, projectId: null })).project_id, null);
});

Deno.test('RL-05 receipt/operation identity is preserved verbatim for audit traceability', async () => {
  const row = await buildLearningRow(BASE);
  assertEquals(row.source_operation_id, BASE.operationId);
  assertEquals(row.source_receipt_id, BASE.receiptId);
  assertEquals(row.source_action_id, BASE.contextRef);
});

Deno.test('RL-06 origin is always system_derived -- a learning row can never be self-attested by the authenticated user', async () => {
  const row = await buildLearningRow(BASE);
  assertEquals(row.origin, 'system_derived');
});

Deno.test('RL-07 confidence_score reflects the real epistemic strength: SUCCESS highest, FAILURE/NOT_EXECUTED lowest, PARTIAL/UNKNOWN_OUTCOME in between', async () => {
  const success = await buildLearningRow({ ...BASE, outcome: 'SUCCESS' });
  const failure = await buildLearningRow({ ...BASE, outcome: 'FAILURE' });
  const partial = await buildLearningRow({ ...BASE, outcome: 'PARTIAL' });
  assert(success.confidence_score > partial.confidence_score);
  assert(partial.confidence_score > failure.confidence_score);
});

Deno.test('RL-08 source is tagged with the calling surface (aef:<source>), never a bare/ambiguous tag', async () => {
  const ae = await buildLearningRow({ ...BASE, source: 'action_engine' });
  const ive = await buildLearningRow({ ...BASE, source: 'ive' });
  assertEquals(ae.source, 'aef:action_engine');
  assertEquals(ive.source, 'aef:ive');
  assert(ae.source !== ive.source, 'two different calling surfaces must remain distinguishable in provenance');
});
