/**
 * ReceiptBuilder (Section 21/22). Builds the KernelResult (kernel-internal
 * outcome + a schema-valid contracts/aef ExecutionReceipt) for every
 * processable attempt -- "toda tentativa processável deve gerar receipt
 * quando tecnicamente seguro." Never records a fictitious success.
 *
 * ## Kernel outcome vs. contract outcome
 *
 * Section 21 asks for 7 kernel-level outcomes: SUCCESS, FAILURE, DENIED,
 * HUMAN_REVIEW_REQUIRED, DUPLICATE, INVALID, AUTH_FAILED. The EXISTING,
 * already-adversarially-reviewed contracts/aef ExecutionReceipt v1 schema
 * constrains `outcome` to only 5 values (SUCCESS, FAILURE, PARTIAL,
 * ROLLED_BACK, NOT_EXECUTED) and separately has `policy_decision`
 * (ALLOWED|DENIED). Rather than reopen and re-version that already-PASSed
 * v1 contract just to add four more enum values (a bigger, riskier change
 * than this mission's scope), this kernel keeps its own richer
 * KernelOutcome as INTERNAL vocabulary and maps it onto the existing
 * contract fields:
 *
 * | KernelOutcome          | policy_decision | outcome      | error (prefix)          |
 * |------------------------|------------------|--------------|--------------------------|
 * | SUCCESS                | ALLOWED          | SUCCESS      | null                     |
 * | FAILURE                | ALLOWED          | FAILURE      | tool failure detail      |
 * | DENIED                 | DENIED           | NOT_EXECUTED | POLICY_DENIED: ...       |
 * | HUMAN_REVIEW_REQUIRED  | DENIED           | NOT_EXECUTED | HUMAN_REVIEW_REQUIRED: ..|
 * | DUPLICATE              | (see below)      | (see below)  | DUPLICATE_REQUEST: ...   |
 * | INVALID                | DENIED           | NOT_EXECUTED | INVALID_CONTRACT: ...    |
 * | AUTH_FAILED            | DENIED           | NOT_EXECUTED | AUTH_FAILED: ...         |
 *
 * DUPLICATE has two shapes: if a prior COMPLETED result exists for the
 * same idempotency_key, the ORIGINAL receipt is returned verbatim
 * (kernelOutcome tags it DUPLICATE at the kernel level without altering
 * the persisted receipt's own truthful outcome). If no prior result
 * exists yet (a concurrent in-flight duplicate, or a bare request_id
 * replay with no idempotency_key), a fresh NOT_EXECUTED/DENIED receipt is
 * built, since nothing has actually completed to return.
 */
import type { Actor, ExecutionRequest, ExecutionReceipt } from "../contracts/aef/types.ts";
import type { KernelOutcome, KernelResult } from "./types.ts";

function newReceiptId(): string {
  return crypto.randomUUID();
}

interface BuildParams {
  request: ExecutionRequest;
  /** The verified actor reference (Section 21) when identity resolution succeeded; falls back to the claimed, unverified actor otherwise -- always Actor-shaped so the receipt schema's required `actor` field is satisfiable, but callers must check policy_decision/outcome/error to know whether it was actually verified. */
  actorForReceipt: Actor;
  startedAt: Date;
  completedAt?: Date;
  humanGateRef?: string | null;
  tool?: string | null;
}

function baseReceipt(params: BuildParams): Omit<ExecutionReceipt, "policy_decision" | "outcome" | "error" | "verification_ref"> {
  return {
    contract_version: "1.0",
    receipt_id: newReceiptId(),
    request_id: params.request.request_id,
    actor: params.actorForReceipt,
    action: params.request.action,
    human_gate_ref: params.humanGateRef ?? null,
    tool: params.tool ?? null,
    started_at: params.startedAt.toISOString(),
    completed_at: params.completedAt ? params.completedAt.toISOString() : null,
    rollback_ref: null,
    deployment_identity: null,
  };
}

function result(kernelOutcome: KernelOutcome, receipt: ExecutionReceipt, verificationState?: "EXECUTION_SUCCEEDED_UNVERIFIED"): KernelResult {
  return { kernelOutcome, receipt, verificationState };
}

export function buildDenied(params: BuildParams, reason: string): KernelResult {
  return result("DENIED", { ...baseReceipt(params), policy_decision: "DENIED", outcome: "NOT_EXECUTED", verification_ref: null, error: `POLICY_DENIED: ${reason}` });
}

export function buildHumanReviewRequired(params: BuildParams, reason: string): KernelResult {
  return result("HUMAN_REVIEW_REQUIRED", { ...baseReceipt(params), policy_decision: "DENIED", outcome: "NOT_EXECUTED", verification_ref: null, error: `HUMAN_REVIEW_REQUIRED: ${reason}` });
}

export function buildInvalid(params: BuildParams, reason: string): KernelResult {
  return result("INVALID", { ...baseReceipt(params), policy_decision: "DENIED", outcome: "NOT_EXECUTED", verification_ref: null, error: `INVALID_CONTRACT: ${reason}` });
}

export function buildAuthFailed(params: BuildParams, reason: string): KernelResult {
  return result("AUTH_FAILED", { ...baseReceipt(params), policy_decision: "DENIED", outcome: "NOT_EXECUTED", verification_ref: null, error: `AUTH_FAILED: ${reason}` });
}

export function buildDuplicateNoPriorResult(params: BuildParams, reason: string): KernelResult {
  return result("DUPLICATE", { ...baseReceipt(params), policy_decision: "DENIED", outcome: "NOT_EXECUTED", verification_ref: null, error: `DUPLICATE_REQUEST: ${reason}` });
}

/** Returns the ORIGINAL completed result verbatim, only re-tagging the kernel-level outcome as DUPLICATE -- never re-executes, never fabricates a new receipt for an operation that already truthfully completed. */
export function tagAsDuplicate(priorResult: KernelResult): KernelResult {
  return { ...priorResult, kernelOutcome: "DUPLICATE" };
}

export function buildSuccess(params: BuildParams, detail: string | undefined): KernelResult {
  const verificationRef = detail ? `EXECUTION_SUCCEEDED_UNVERIFIED: ${detail}` : "EXECUTION_SUCCEEDED_UNVERIFIED";
  return result(
    "SUCCESS",
    { ...baseReceipt(params), policy_decision: "ALLOWED", outcome: "SUCCESS", verification_ref: verificationRef, error: null },
    "EXECUTION_SUCCEEDED_UNVERIFIED",
  );
}

export function buildFailure(params: BuildParams, detail: string | undefined): KernelResult {
  return result("FAILURE", { ...baseReceipt(params), policy_decision: "ALLOWED", outcome: "FAILURE", verification_ref: null, error: detail ?? "tool execution failed" });
}
