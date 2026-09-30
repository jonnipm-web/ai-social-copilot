/**
 * AEF v0 kernel-internal types. These are DELIBERATELY separate from
 * contracts/aef/types.ts: that package defines the external, versioned,
 * cross-boundary WIRE contract (ExecutionRequest, DelegationEnvelope,
 * HumanGateRecord, PolicySignal, ExecutionReceipt) that IVE and a future
 * real AEF both speak. This file defines the KERNEL's own richer internal
 * vocabulary for reasoning about a request as it moves through the
 * pipeline -- it is never serialized across a trust boundary, so it is
 * free to evolve without a schema-versioning process.
 *
 * See README.md "Kernel outcome vs. contract outcome" for why
 * KernelOutcome (7 values, Section 21 of the mission brief) is NOT the
 * same enum as contracts/aef's ExecutionReceipt.outcome (5 values) --
 * the mapping between them is in receipt_builder.ts, not here.
 */
import type { Actor, ExecutionRequest } from "../contracts/aef/types.ts";

// ---------------------------------------------------------------------
// Identity resolution (Section 7)
// ---------------------------------------------------------------------

/**
 * A future AEF resolves auth_ref using material the IVE side never
 * controls -- e.g. the raw bearer token that arrived on the actual HTTP
 * request. `auth_ref` in the contract is only a REFERENCE; this is the
 * actual credential material an IdentityResolver verifies against a real
 * trust boundary (here: Supabase Auth/GoTrue for `usr:` actors).
 */
export type RawCredential =
  | { kind: "bearer_jwt"; token: string }
  | { kind: "none" };

export type IdentityResolutionStatus =
  | "VERIFIED"
  | "INVALID"
  | "EXPIRED"
  | "UNSUPPORTED"
  | "UNAVAILABLE";

export type IdentityResolution =
  | {
    status: "VERIFIED";
    /** The independently-verified identity. NEVER copied from the request's own claimed actor.id. */
    verifiedId: string;
    verifiedType: "user";
    /** Where this verification came from, for audit (Section 28) -- never the raw credential itself. */
    source: string;
  }
  | { status: "INVALID"; reason: string }
  | { status: "EXPIRED"; reason: string }
  | { status: "UNSUPPORTED"; reason: string }
  | { status: "UNAVAILABLE"; reason: string };

export interface IdentityResolver {
  /**
   * Resolves a CLAIMED actor against real credential material. MUST NEVER
   * return VERIFIED merely because `actor.auth_ref` is well-formed
   * (Section 7's core invariant: SCHEMA_VALID != AUTHENTICATED). MUST
   * NEVER throw for malformed input -- return INVALID instead.
   */
  resolve(actor: Actor, credential: RawCredential): Promise<IdentityResolution>;
}

// ---------------------------------------------------------------------
// Action classification (Section 15)
// ---------------------------------------------------------------------

export type ActionClassification = "READ_ONLY" | "REVERSIBLE" | "CONSEQUENTIAL";

// ---------------------------------------------------------------------
// Policy (Section 13)
// ---------------------------------------------------------------------

export type PolicyDecisionKind = "ALLOW" | "DENY" | "REQUIRE_HUMAN_REVIEW";

export interface PolicyDecision {
  decision: PolicyDecisionKind;
  reason: string;
}

export interface PolicyContext {
  request: ExecutionRequest;
  classification: ActionClassification;
}

// ---------------------------------------------------------------------
// Tool registry (Section 17/18)
// ---------------------------------------------------------------------

export interface ToolDefinition {
  toolId: string;
  domain: ExecutionRequest["domain"];
  classification: ActionClassification;
  /** Declarative only -- the kernel enforces human-gate requirements itself; a tool cannot opt out of policy. */
  requiresHumanGate: boolean;
  /**
   * Exact shape of `request.parameters` (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
   * When present, AefGovernance refuses any other input before persisting
   * anything; the LAB runtime requires it for every tool it registers.
   */
  inputSchema?: ToolInputSchema;
  /**
   * Mock execution ONLY (Section 18/32). Real side effects
   * (Supabase writes, Stripe, email, publishing, broker orders, Impact
   * actions, deploys) are structurally impossible here: this function
   * signature has no access to any credential, network client, or
   * secret -- it receives only the already-governed request.
   */
  execute(request: ExecutionRequest, context?: ToolExecutionContext): Promise<ToolExecutionResult>;
}

/** Supplied by the persistent governance service (IV-AEF-PERSISTENCE-01); the in-memory v0 kernel passes none. */
export interface ToolExecutionContext {
  /** The durable operation this invocation belongs to. */
  operationId: string;
  /** Aborted when the governance service stops waiting (timeout). */
  signal: AbortSignal;
}

export interface ToolExecutionResult {
  outcome: "SUCCESS" | "FAILURE";
  detail?: string;
  /**
   * For FAILURE: whether any side effect happened before the failure.
   * Omitted = unknown, which the persistent service records as
   * UNKNOWN_OUTCOME (never as a clean failure).
   */
  sideEffect?: "NONE" | "APPLIED";
}

// ---------------------------------------------------------------------
// Idempotency (Section 19/20)
// ---------------------------------------------------------------------

/**
 * Business-idempotency store: idempotency_key -> the KernelResult already
 * produced for it. Deliberately distinct from contracts/aef's
 * RequestIdStore (execution-replay defense) and NonceStore
 * (authentication-replay defense) -- see contracts/aef/README.md's "three
 * distinct replay/idempotency concepts" note, which this kernel preserves
 * rather than collapses.
 */
export interface IdempotencyStore {
  get(key: string): KernelResult | undefined;
  put(key: string, result: KernelResult): void;
}

// ---------------------------------------------------------------------
// Delegation / Human Gate resolution (in-memory test stores, Section 27)
// ---------------------------------------------------------------------

import type { DelegationEnvelope, HumanGateRecord } from "../contracts/aef/types.ts";

export interface DelegationResolver {
  resolve(delegationRef: string): DelegationEnvelope | undefined;
}

export interface HumanGateResolver {
  resolve(humanGateRef: string): HumanGateRecord | undefined;
}

// ---------------------------------------------------------------------
// Kernel outcome (Section 21) -- see README for mapping onto
// contracts/aef's constrained ExecutionReceipt.outcome enum.
// ---------------------------------------------------------------------

export type KernelOutcome =
  | "SUCCESS"
  | "FAILURE"
  | "DENIED"
  | "HUMAN_REVIEW_REQUIRED"
  | "DUPLICATE"
  | "INVALID"
  | "AUTH_FAILED";

import type { ExecutionReceipt } from "../contracts/aef/types.ts";
import type { ToolInputSchema } from "./persistence/tool_input_schema.ts";

export interface KernelResult {
  kernelOutcome: KernelOutcome;
  /** Always a schema-valid ExecutionReceipt per contracts/aef v1 -- never null, even for denials (Section 21: "toda tentativa processável deve gerar receipt"). */
  receipt: ExecutionReceipt;
  /** Present only when kernelOutcome === "SUCCESS" and the tool ran -- see Section 22, never silently promoted to a claim of independent verification. */
  verificationState?: "EXECUTION_SUCCEEDED_UNVERIFIED";
}
