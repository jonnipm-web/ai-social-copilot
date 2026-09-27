/**
 * Result -> Learning: the Supabase-specific half of
 * INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §7-9.
 *
 * aef/runtime/ive_aef_runtime.ts computes WHEN to write (a terminal,
 * receipted result, and only that) and WHAT the fact is
 * (LearningEntryInput) without any Supabase dependency of its own. This
 * file is the other half: turning that fact into a business_memory row
 * (20260930000000_result_learning.sql) and actually writing it, with a
 * service-role client so origin can truthfully be 'system_derived' --
 * business_memory's own RLS policies (20260924000000_ive_memory_
 * governance.sql) already refuse that origin for the authenticated role,
 * on purpose: derived learning is never self-attested by the user's JWT.
 *
 * Idempotent by construction: dedup_key is deterministic from
 * (operation_id, receipt_id), and business_memory's own unique partial
 * index (uq_business_memory_active_dedup) refuses a second active row for
 * the same key -- a retried/replayed terminal result can never duplicate
 * a learning entry. That unique-violation is the expected, successful case
 * here, not an error.
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import { sha256Hex } from '../../../aef/persistence/canonical.ts';
import type { LearningEntryInput } from '../../../aef/runtime/ive_aef_runtime.ts';

const KNOWN_OUTCOMES = new Set(['SUCCESS', 'FAILURE', 'PARTIAL', 'NOT_EXECUTED', 'UNKNOWN_OUTCOME']);

export interface BusinessMemoryLearningRow {
  user_id: string;
  project_id: string | null;
  memory_type: string;
  title: string;
  content: string;
  confidence_score: number;
  source: string;
  origin: 'system_derived';
  dedup_key: string;
  source_action_id: string | null;
  source_operation_id: string;
  source_receipt_id: string;
  verification_state: 'verified' | 'unverified';
}

/**
 * §8 (Learning safety): the ONLY outcome that may ever be marked
 * 'verified' is a real AEF receipt saying SUCCESS. Every other receipted
 * outcome -- including PARTIAL, where something plausibly did happen -- is
 * 'unverified': a real execution FACT is recorded (a receipt exists), but
 * IVE must never read it as confirmation the task succeeded. An unknown/
 * malformed outcome fails closed to 'unverified', never 'verified'.
 */
function verificationStateFor(outcome: string): 'verified' | 'unverified' {
  return outcome === 'SUCCESS' ? 'verified' : 'unverified';
}

/** Existing BusinessMemory.types vocabulary only (lib/data/models/business_memory.dart)
 * -- no new memory_type invented; the real nuance lives in verification_state. */
function memoryTypeFor(outcome: string): string {
  if (outcome === 'SUCCESS') return 'success';
  if (outcome === 'FAILURE' || outcome === 'NOT_EXECUTED') return 'failure';
  return 'decision'; // PARTIAL / UNKNOWN_OUTCOME / anything unrecognized: neither claim
}

function confidenceFor(outcome: string): number {
  if (outcome === 'SUCCESS') return 90;
  if (outcome === 'FAILURE' || outcome === 'NOT_EXECUTED') return 10;
  return 30; // PARTIAL / UNKNOWN_OUTCOME: real but unresolved
}

export async function buildLearningRow(input: LearningEntryInput): Promise<BusinessMemoryLearningRow> {
  const outcome = KNOWN_OUTCOMES.has(input.outcome) ? input.outcome : 'UNKNOWN_OUTCOME';
  const dedupKey = `action_result|${await sha256Hex(`${input.operationId}|${input.receiptId}`)}`;
  return {
    user_id: input.subjectId,
    project_id: input.projectId,
    memory_type: memoryTypeFor(outcome),
    title: `${input.source}:${input.requestedAction} -> ${outcome}`,
    content: `action=${input.requestedAction};outcome=${outcome};phase=${input.phase};operation=${input.operationId};receipt=${input.receiptId}`,
    confidence_score: confidenceFor(outcome),
    source: `aef:${input.source}`,
    origin: 'system_derived',
    dedup_key: dedupKey,
    source_action_id: input.contextRef,
    source_operation_id: input.operationId,
    source_receipt_id: input.receiptId,
    verification_state: verificationStateFor(outcome),
  };
}

function log(event: string, fields: Record<string, unknown>): void {
  // deno-lint-ignore no-console
  console.log(JSON.stringify({ event, ...fields, ts: new Date().toISOString() }));
}

/**
 * Fire-and-forget from the caller's perspective (ive_aef_runtime.ts already
 * wraps this in try/catch): this function itself never throws. A unique-
 * violation (Postgres 23505, via PostgREST) means the exact same governed
 * fact was already learned -- success, not failure.
 */
export function writeLearningEntry(client: SupabaseClient): (input: LearningEntryInput) => Promise<void> {
  return async (input: LearningEntryInput): Promise<void> => {
    const row = await buildLearningRow(input);
    const { error } = await client.from('business_memory').insert(row);
    if (!error) {
      log('result_learning_written', { source_operation_id: row.source_operation_id, verification_state: row.verification_state });
      return;
    }
    if (error.code === '23505') {
      log('result_learning_duplicate_ignored', { source_operation_id: row.source_operation_id });
      return;
    }
    log('result_learning_write_failed', { source_operation_id: row.source_operation_id, error: error.message, code: error.code });
  };
}
