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
  /**
   * The component asserting this delegation. Actor-shaped (not a bare
   * string) so the issuer's OWN identity requires an auth_ref an
   * independent component must resolve -- fixed after Codex adversarial
   * review (Finding F-02) found that a bare issuer string let any caller
   * simply declare itself e.g. "aef_policy_engine" with no binding to a
   * verifiable identity, a textbook confused-deputy setup.
   */
  issuer: Actor;
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

/**
 * Pluggable nonce store for DelegationEnvelope replay defense (Section 9).
 *
 * Exposes a SINGLE atomic operation, `tryConsume`, deliberately instead of
 * a `hasSeen()` + `record()` pair. A Codex adversarial review (Finding
 * F-05) correctly noted that a check-then-record API invites a
 * time-of-check-to-time-of-use race under concurrency -- two callers can
 * both observe `hasSeen() === false` before either calls `record()`. This
 * is not just an in-memory-test-store concern: even a "durable" store
 * built against this two-step shape would inherit the race unless its
 * caller wraps both calls in a transaction, which nothing here would
 * force it to do. A single `tryConsume` makes atomicity a property of the
 * interface itself, not something every implementer must remember.
 */
export interface NonceStore {
  /** Atomically checks-and-records in one step. Returns true if this is the FIRST time `value` has been seen (i.e. consumption succeeded); false if it was already consumed (replay). */
  tryConsume(value: string): boolean;
}

/**
 * Reference in-memory implementation for TESTS ONLY. A real AEF must use a
 * durable store with a real atomic/unique-constraint guarantee (e.g. a
 * database unique index and an INSERT ... ON CONFLICT DO NOTHING pattern)
 * -- an in-memory Set is lost on process restart, is not safe across
 * multiple instances, and (JavaScript's single-threaded event loop aside)
 * is not a substitute for cross-process atomicity in a real deployment.
 */
export class InMemoryNonceStore implements NonceStore {
  private readonly seen = new Set<string>();
  tryConsume(value: string): boolean {
    if (this.seen.has(value)) return false;
    this.seen.add(value);
    return true;
  }
}

/** Pluggable request-id store for execution-replay defense (Section 9). Same atomic-by-design shape and "tests only" caveat as NonceStore. */
export interface RequestIdStore {
  tryConsume(value: string): boolean;
}

export class InMemoryRequestIdStore implements RequestIdStore {
  private readonly seen = new Set<string>();
  tryConsume(value: string): boolean {
    if (this.seen.has(value)) return false;
    this.seen.add(value);
    return true;
  }
}
