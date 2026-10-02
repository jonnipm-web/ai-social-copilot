/**
 * Action Execution Framework — types.
 * IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 *
 * Every consequential Impact action MUST pass through the AEF kernel before
 * execution. The AEF separates:
 *   AUTHENTICATION (who is the user?)
 *   AUTHORIZATION  (what are they allowed to do?)
 *   SERVICE IDENTITY (which backend service is making the call?)
 *   USER IDENTITY   (which user does the action belong to?)
 *   TENANT/PROJECT SCOPE (which project is in scope?)
 *   ACTION AUTHORITY (what policy governs this action?)
 *
 * Service_role is a technical capability; it is NOT authorization.
 *
 * CallerContext is defined in ../impact/trust.ts and re-exported here so AEF
 * callers need only import from aef/types.ts.
 */
import type { CallerContext as _CallerContext } from '../impact/trust.ts';
export type { CallerContext } from '../impact/trust.ts';

// ── Action classification ────────────────────────────────────────────────────

export type ActionClassification = 'READ_ONLY' | 'REVERSIBLE' | 'CONSEQUENTIAL' | 'IRREVERSIBLE';

export const CLASSIFICATION_ORDER: readonly ActionClassification[] = [
  'READ_ONLY', 'REVERSIBLE', 'CONSEQUENTIAL', 'IRREVERSIBLE',
];

// ── Impact action intent ─────────────────────────────────────────────────────

/**
 * An ImpactActionIntent is the strongly-typed representation of a consequential
 * Impact action BEFORE it is executed. Every class C action must produce one
 * before touching any external system or publishing any result.
 */
export type ImpactActionIntentKind =
  | 'REQUEST_MANUAL_VERIFICATION'
  | 'APPROVE_DOSSIER_PUBLICATION'
  | 'ACKNOWLEDGE_CONFLICT'
  | 'MARK_INVESTIGATION_REVIEWED';

export const IMPACT_ACTION_INTENTS: readonly ImpactActionIntentKind[] = [
  'REQUEST_MANUAL_VERIFICATION',
  'APPROVE_DOSSIER_PUBLICATION',
  'ACKNOWLEDGE_CONFLICT',
  'MARK_INVESTIGATION_REVIEWED',
];

export interface ImpactActionIntent {
  readonly kind: ImpactActionIntentKind;
  readonly investigationId: string;
  /** Caller-provided idempotency key (UUID). If absent, the kernel generates one. */
  readonly idempotencyKey: string;
  /** The action classification — computed by the kernel from the intent kind. */
  readonly classification: ActionClassification;
}

// ── AEF execution request ────────────────────────────────────────────────────

export interface AefExecutionRequest {
  readonly requestId: string;
  readonly correlationId: string;
  readonly caller: _CallerContext;
  readonly intent: ImpactActionIntent;
  readonly requestedAt: string;
}

// ── Policy decision ──────────────────────────────────────────────────────────

export type PolicyOutcome =
  | 'AUTHORIZED'
  | 'DENIED'
  | 'REQUIRES_HUMAN_REVIEW';

export interface PolicyDecision {
  readonly requestId: string;
  readonly outcome: PolicyOutcome;
  readonly policyVersion: string;
  readonly decidedAt: string;
  readonly reason: string;
}

// ── Human gate ───────────────────────────────────────────────────────────────

export type HumanGateStatus =
  | 'PENDING'
  | 'APPROVED'
  | 'REJECTED'
  | 'EXPIRED';

export interface HumanGateState {
  readonly gateId: string;
  readonly requestId: string;
  /** Opaque approver reference — never a real name or email. */
  readonly approverRef: string | null;
  readonly status: HumanGateStatus;
  /** ISO-8601 — the gate expires if not resolved before this time. */
  readonly expiresAt: string;
  readonly resolvedAt: string | null;
  /** Binding hash of the request state at approval time. Any change invalidates it. */
  readonly bindingHash: string | null;
}

// ── Execution attempt ────────────────────────────────────────────────────────

export type ExecutionOutcome =
  | 'AUTHORIZED'
  | 'DENIED'
  | 'REQUIRES_HUMAN_REVIEW'
  | 'EXECUTED'
  | 'FAILED'
  | 'CANCELLED';

export interface ExecutionAttempt {
  readonly attemptId: string;
  readonly requestId: string;
  readonly attemptedAt: string;
  readonly outcome: ExecutionOutcome;
  readonly errorCode: string | null;
}

// ── Execution receipt ────────────────────────────────────────────────────────

/**
 * Every AEF execution attempt produces a receipt, regardless of outcome.
 * Receipts are append-only and never deleted. They contain no secrets,
 * no document content, no personal data beyond opaque refs.
 */
export interface ExecutionReceipt {
  readonly receiptId: string;
  readonly requestId: string;
  readonly correlationId: string;
  readonly callerUserId: string;
  readonly projectId: string | null;
  readonly serviceId: string;
  readonly intentKind: ImpactActionIntentKind;
  readonly investigationId: string;
  readonly idempotencyKey: string;
  readonly classification: ActionClassification;
  readonly policyVersion: string;
  readonly policyOutcome: PolicyOutcome;
  readonly executionOutcome: ExecutionOutcome;
  readonly humanGateId: string | null;
  readonly errorCode: string | null;
  readonly issuedAt: string;
  /** SHA-256 hex of the canonical receipt fields (integrity, not crypto-proof). */
  readonly receiptHash: string;
}

// ── AEF result ───────────────────────────────────────────────────────────────

export type AefError =
  | { readonly code: 'DENIED'; readonly reason: string }
  | { readonly code: 'REQUIRES_HUMAN_REVIEW'; readonly gateId: string; readonly expiresAt: string }
  | { readonly code: 'HUMAN_GATE_INVALID'; readonly reason: string }
  | { readonly code: 'IDEMPOTENCY_CONFLICT'; readonly existingRequestId: string }
  | { readonly code: 'AEF_PERSISTENCE_UNAVAILABLE' }
  | { readonly code: 'INTERNAL_ERROR'; readonly reason: string };

export type AefResult<T> =
  | { readonly ok: true; readonly value: T; readonly receipt: ExecutionReceipt }
  | { readonly ok: false; readonly error: AefError; readonly receipt: ExecutionReceipt | null };
