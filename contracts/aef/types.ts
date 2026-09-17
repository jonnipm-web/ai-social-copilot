/**
 * TypeScript types mirroring the JSON Schemas in schema/. These are for
 * the reference validator only -- the JSON Schemas are the canonical
 * contract definition (README.md, "Repository decision").
 */

export type ActorType = "user" | "service" | "system";

export interface Actor {
  type: ActorType;
  id: string;
  /** Reference to a verifiable authentication assertion. Never trust `id` alone. */
  auth_ref: string;
}

export type Domain = "core" | "quant" | "impact" | "internal";

export type QuantExecutionTier =
  | "research"
  | "backtest"
  | "paper"
  | "controlled_live"
  | "expanded_live";

export interface ExecutionRequest {
  contract_version: "1.0";
  request_id: string;
  correlation_id?: string;
  requested_at: string;
  expires_at: string;
  actor: Actor;
  intent: string;
  domain: Domain;
  action: string;
  resource?: { type: string; id: string };
  parameters?: Record<string, unknown>;
  constraints?: { max_cost_estimate?: number; note?: string };
  quant_execution_tier?: QuantExecutionTier;
  context_ref?: string;
  idempotency_key?: string;
  delegation_ref?: string;
  human_gate_ref?: string;
  metadata?: Record<string, string>;
}

export interface DelegationEnvelope {
  contract_version: "1.0";
  delegation_id: string;
  issuer: string;
  subject: Actor;
  audience: string;
  issued_at: string;
  expires_at: string;
  nonce: string;
  purpose: string;
  scope: string[];
  request_binding: string;
  auth_assertion_ref: string;
}

export type HumanGateState =
  | "REQUESTED"
  | "REVIEW_REQUIRED"
  | "AUTHORIZED"
  | "REJECTED"
  | "EXPIRED"
  | "EXECUTED";

export interface HumanGateRecord {
  contract_version: "1.0";
  gate_id: string;
  request_id: string;
  action: string;
  state: HumanGateState;
  approver?: Actor;
  decided_at?: string | null;
  expires_at: string;
  audit_ref?: string;
}

export type PolicySignalKind = "ADVISORY" | "AUTHORITATIVE";

export interface PolicySignal {
  contract_version: "1.0";
  kind: PolicySignalKind;
  source: string;
  signal: string;
  computed_at: string;
  request_ref?: string;
}

export type ExecutionOutcome =
  | "SUCCESS"
  | "FAILURE"
  | "PARTIAL"
  | "ROLLED_BACK"
  | "NOT_EXECUTED";

export interface ExecutionReceipt {
  contract_version: "1.0";
  receipt_id: string;
  request_id: string;
  actor: Actor;
  action: string;
  policy_decision: "ALLOWED" | "DENIED";
  human_gate_ref?: string | null;
  tool?: string | null;
  started_at: string;
  completed_at?: string | null;
  outcome: ExecutionOutcome;
  verification_ref?: string | null;
  error?: string | null;
  rollback_ref?: string | null;
  deployment_identity?: string | null;
}

/** Result type every validator function returns. Never throws for an invalid input -- invalid input is an expected, first-class outcome, not an exception. */
export type ValidationResult =
  | { ok: true }
  | { ok: false; errors: string[] };

/**
 * A component allowed to issue AUTHORITATIVE PolicySignals (Section 13).
 * IVE (and any source not on this list) may only ever issue ADVISORY
 * signals -- enforced in validators.ts, not merely by convention.
 */
export const AUTHORITATIVE_SOURCE_ALLOWLIST: readonly string[] = [
  "aef.policy_engine",
  "aef.cost_guard",
  "aef.human_gate",
  "evidence_trust.legal_gate",
] as const;

/** Pluggable nonce store for DelegationEnvelope replay defense (Section 9). */
export interface NonceStore {
  hasSeen(nonce: string): boolean;
  record(nonce: string): void;
}

/**
 * Reference in-memory implementation for TESTS ONLY. A real AEF must use a
 * durable store (e.g. a database unique constraint) -- an in-memory Set is
 * lost on process restart and is not safe across multiple instances.
 */
export class InMemoryNonceStore implements NonceStore {
  private readonly seen = new Set<string>();
  hasSeen(nonce: string): boolean {
    return this.seen.has(nonce);
  }
  record(nonce: string): void {
    this.seen.add(nonce);
  }
}

/** Pluggable request-id store for execution-replay defense (Section 9). Same "tests only" caveat as NonceStore. */
export interface RequestIdStore {
  hasSeen(requestId: string): boolean;
  record(requestId: string): void;
}

export class InMemoryRequestIdStore implements RequestIdStore {
  private readonly seen = new Set<string>();
  hasSeen(requestId: string): boolean {
    return this.seen.has(requestId);
  }
  record(requestId: string): void {
    this.seen.add(requestId);
  }
}
