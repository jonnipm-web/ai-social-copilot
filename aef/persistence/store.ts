/**
 * AEF durable store (IV-AEF-PERSISTENCE-01).
 *
 * The PostgreSQL functions in migration 20260925000000_aef_persistence.sql
 * are the ONLY implementation of the AEF state machine. This file is a thin,
 * strict client: it sends one jsonb argument per call and parses the reply.
 * A reply that does not have exactly the expected shape throws
 * StoreProtocolError, which the governance service maps to a fail-closed
 * STORE_PROTOCOL_ERROR — an unexpected reply is never interpreted as success.
 *
 * Transport:
 *   - production: SupabaseRpcTransport over a service_role client
 *     (`client.rpc(fn, { p: args })`); the functions are EXECUTE-granted to
 *     service_role only;
 *   - tests: testing/psql_transport.ts (one psql process = one connection).
 */
import { isStoreCode, type StoreCode } from "./errors.ts";

export const AEF_RPC_NAMES = [
  "aef_register_operation",
  "aef_decide_gate",
  "aef_claim_execution",
  "aef_complete_execution",
  "aef_cancel_operation",
  "aef_recover",
  "aef_get_operation",
  "aef_record_denial",
  "aef_verify_receipt",
  "aef_verify_audit_chain",
] as const;
export type AefRpcName = typeof AEF_RPC_NAMES[number];

export interface RpcTransport {
  call(fn: AefRpcName, args: Record<string, unknown>): Promise<unknown>;
}

/** Minimal surface of a supabase-js client, so this module imports nothing. */
export interface SupabaseRpcClient {
  rpc(fn: string, params: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }>;
}

export class SupabaseRpcTransport implements RpcTransport {
  constructor(private readonly client: SupabaseRpcClient) {}
  async call(fn: AefRpcName, args: Record<string, unknown>): Promise<unknown> {
    const { data, error } = await this.client.rpc(fn, { p: args });
    if (error) throw new Error(`rpc ${fn} failed`);
    return data;
  }
}

export class StoreProtocolError extends Error {}

export type OperationState =
  | "AWAITING_APPROVAL"
  | "AUTHORIZED"
  | "EXECUTING"
  | "SUCCEEDED"
  | "FAILED"
  | "UNKNOWN_OUTCOME"
  | "REJECTED"
  | "EXPIRED"
  | "CANCELLED"
  | "INVALIDATED";
const OPERATION_STATES: readonly OperationState[] = [
  "AWAITING_APPROVAL", "AUTHORIZED", "EXECUTING", "SUCCEEDED", "FAILED",
  "UNKNOWN_OUTCOME", "REJECTED", "EXPIRED", "CANCELLED", "INVALIDATED",
];
export const TERMINAL_STATES: readonly OperationState[] = [
  "SUCCEEDED", "FAILED", "UNKNOWN_OUTCOME", "REJECTED", "EXPIRED", "CANCELLED", "INVALIDATED",
];

export type GateState = "REVIEW_REQUIRED" | "AUTHORIZED" | "REJECTED" | "EXPIRED" | "EXECUTED" | "CANCELLED" | "INVALIDATED";
const GATE_STATES: readonly GateState[] = ["REVIEW_REQUIRED", "AUTHORIZED", "REJECTED", "EXPIRED", "EXECUTED", "CANCELLED", "INVALIDATED"];

export type ReceiptOutcome = "SUCCESS" | "FAILURE" | "PARTIAL" | "NOT_EXECUTED" | "UNKNOWN_OUTCOME";
const RECEIPT_OUTCOMES: readonly ReceiptOutcome[] = ["SUCCESS", "FAILURE", "PARTIAL", "NOT_EXECUTED", "UNKNOWN_OUTCOME"];

export interface OperationView {
  operationId: string;
  state: OperationState;
  stateReason: string | null;
  action: string;
  toolId: string;
  actionClass: string;
  bindingHash: string;
  payloadHash: string;
  policyVersion: string;
  riskVersion: string;
  requiresHumanGate: boolean;
  attemptCount: number;
  expiresAt: string;
}

export interface GateView {
  gateId: string;
  state: GateState;
  bindingHash: string;
  approverId: string | null;
  expiresAt: string;
}

/**
 * The server-issued receipt, exactly as stored (aef-receipt/1). Returned
 * frozen: it is read from the database, never built by this process.
 */
export interface PersistedReceipt {
  receipt: Readonly<Record<string, unknown>> & { receipt_id: string; outcome: ReceiptOutcome; final_state: OperationState };
  receiptHash: string;
}

export interface StoreView {
  operation: OperationView;
  gate: GateView | null;
  receipt: PersistedReceipt | null;
}

export type StoreReply<T = StoreView> = ({ ok: true } & T) | { ok: false; code: StoreCode; state: string | null };

const HEX64 = /^[0-9a-f]{64}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function rec(v: unknown, what: string): Record<string, unknown> {
  if (typeof v !== "object" || v === null || Array.isArray(v)) throw new StoreProtocolError(`${what}: object expected`);
  return v as Record<string, unknown>;
}
function str(o: Record<string, unknown>, k: string, re?: RegExp): string {
  const v = o[k];
  if (typeof v !== "string" || (re && !re.test(v))) throw new StoreProtocolError(`${k}: invalid`);
  return v;
}
function strOrNull(o: Record<string, unknown>, k: string, re?: RegExp): string | null {
  return o[k] === null || o[k] === undefined ? null : str(o, k, re);
}
function oneOf<T extends string>(o: Record<string, unknown>, k: string, allowed: readonly T[]): T {
  const v = o[k];
  if (typeof v !== "string" || !(allowed as readonly string[]).includes(v)) throw new StoreProtocolError(`${k}: invalid`);
  return v as T;
}

function parseOperation(v: unknown): OperationView {
  const o = rec(v, "operation");
  const attempt = o.attempt_count;
  if (attempt !== 0 && attempt !== 1) throw new StoreProtocolError("attempt_count: invalid");
  if (typeof o.requires_human_gate !== "boolean") throw new StoreProtocolError("requires_human_gate: invalid");
  return {
    operationId: str(o, "operation_id", UUID),
    state: oneOf(o, "state", OPERATION_STATES),
    stateReason: strOrNull(o, "state_reason"),
    action: str(o, "action"),
    toolId: str(o, "tool_id"),
    actionClass: str(o, "action_class"),
    bindingHash: str(o, "binding_hash", HEX64),
    payloadHash: str(o, "payload_hash", HEX64),
    policyVersion: str(o, "policy_version"),
    riskVersion: str(o, "risk_version"),
    requiresHumanGate: o.requires_human_gate,
    attemptCount: attempt,
    expiresAt: str(o, "expires_at"),
  };
}

function parseGate(v: unknown): GateView | null {
  if (v === null || v === undefined) return null;
  const g = rec(v, "gate");
  return {
    gateId: str(g, "gate_id", UUID),
    state: oneOf(g, "state", GATE_STATES),
    bindingHash: str(g, "binding_hash", HEX64),
    approverId: strOrNull(g, "approver_id", UUID),
    expiresAt: str(g, "expires_at"),
  };
}

function deepFreeze<T>(v: T): T {
  if (typeof v === "object" && v !== null) {
    for (const child of Object.values(v)) deepFreeze(child);
    Object.freeze(v);
  }
  return v;
}

function parseReceipt(v: unknown, op: OperationView): PersistedReceipt | null {
  if (v === null || v === undefined) return null;
  const wrap = rec(v, "receipt");
  const r = rec(wrap.receipt, "receipt.receipt");
  const receiptHash = str(wrap, "receipt_hash", HEX64);
  str(r, "receipt_id", UUID);
  oneOf(r, "outcome", RECEIPT_OUTCOMES);
  if (r.operation_id !== op.operationId || r.final_state !== op.state || r.binding_hash !== op.bindingHash) {
    throw new StoreProtocolError("receipt does not belong to this operation state");
  }
  return deepFreeze({ receipt: r as PersistedReceipt["receipt"], receiptHash });
}

function parseView(o: Record<string, unknown>): StoreView {
  const operation = parseOperation(o.operation);
  return { operation, gate: parseGate(o.gate), receipt: parseReceipt(o.receipt, operation) };
}

function parseError(o: Record<string, unknown>): { ok: false; code: StoreCode; state: string | null } {
  if (!isStoreCode(o.code)) throw new StoreProtocolError("unknown error code");
  return { ok: false, code: o.code, state: strOrNull(o, "state") };
}

export interface RegisterArgs {
  subject_id: string;
  request_id: string;
  idempotency_key: string;
  domain: string;
  action: string;
  tool_id: string;
  action_class: string;
  resource_type: string | null;
  resource_id: string | null;
  payload_hash: string;
  payload_bytes: number;
  policy_version: string;
  risk_version: string;
  requires_human_gate: boolean;
  ttl_seconds: number;
  gate_ttl_seconds: number;
}

export class PostgresAefStore {
  constructor(private readonly transport: RpcTransport) {}

  private async reply(fn: AefRpcName, args: Record<string, unknown>): Promise<Record<string, unknown>> {
    return rec(await this.transport.call(fn, args), fn);
  }

  private async viewReply<T extends object = Record<never, never>>(
    fn: AefRpcName,
    args: Record<string, unknown>,
    extra: (o: Record<string, unknown>) => T = () => ({} as T),
  ): Promise<StoreReply<StoreView & T>> {
    const o = await this.reply(fn, args);
    if (o.ok === false) return parseError(o);
    if (o.ok !== true) throw new StoreProtocolError(`${fn}: ok flag missing`);
    return { ok: true, ...parseView(o), ...extra(o) };
  }

  register(args: RegisterArgs): Promise<StoreReply<StoreView & { replayed: boolean }>> {
    return this.viewReply("aef_register_operation", { ...args }, (o) => {
      if (o.outcome !== "CREATED" && o.outcome !== "REPLAY") throw new StoreProtocolError("register: outcome invalid");
      return { replayed: o.outcome === "REPLAY" };
    });
  }

  decideGate(args: { gate_id: string; approver_id: string; decision: "APPROVE" | "REJECT"; binding_hash: string; policy_version: string }) {
    return this.viewReply("aef_decide_gate", { ...args });
  }

  claimExecution(args: { operation_id: string; subject_id: string; binding_hash: string; policy_version: string; lease_seconds: number }) {
    return this.viewReply("aef_claim_execution", { ...args }, (o) => ({ executionToken: str(o, "execution_token", UUID) }));
  }

  completeExecution(args: {
    operation_id: string;
    execution_token: string;
    result: "SUCCEEDED" | "FAILED_NO_SIDE_EFFECT" | "FAILED_AFTER_SIDE_EFFECT" | "UNKNOWN_OUTCOME";
  }) {
    return this.viewReply("aef_complete_execution", { ...args });
  }

  cancel(args: { operation_id: string; subject_id: string }) {
    return this.viewReply("aef_cancel_operation", { ...args });
  }

  getOperation(args: { operation_id: string; subject_id: string }) {
    return this.viewReply("aef_get_operation", { ...args });
  }

  async recordDenial(args: { subject_id: string; reason_code: string }): Promise<void> {
    const o = await this.reply("aef_record_denial", { ...args });
    if (o.ok !== true) throw new StoreProtocolError("record_denial failed");
  }

  async recover(limit: number): Promise<{ unknownOutcome: number; expired: number }> {
    const o = await this.reply("aef_recover", { limit });
    if (o.ok !== true || typeof o.unknown_outcome !== "number" || typeof o.expired !== "number") {
      throw new StoreProtocolError("recover: invalid reply");
    }
    return { unknownOutcome: o.unknown_outcome, expired: o.expired };
  }

  async verifyReceipt(receipt: unknown): Promise<{ valid: boolean; reason: string | null }> {
    const o = await this.reply("aef_verify_receipt", { receipt });
    if (o.ok !== true || typeof o.valid !== "boolean") throw new StoreProtocolError("verify_receipt: invalid reply");
    return { valid: o.valid, reason: o.valid ? null : str(o, "reason") };
  }

  async verifyAuditChain(subjectId: string): Promise<{ valid: boolean; events: number | null; reason: string | null }> {
    const o = await this.reply("aef_verify_audit_chain", { subject_id: subjectId });
    if (o.ok !== true || typeof o.valid !== "boolean") throw new StoreProtocolError("verify_audit_chain: invalid reply");
    return o.valid
      ? { valid: true, events: typeof o.events === "number" ? o.events : null, reason: null }
      : { valid: false, events: null, reason: str(o, "reason") };
  }
}
