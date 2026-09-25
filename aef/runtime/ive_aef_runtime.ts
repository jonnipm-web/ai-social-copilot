/**
 * IveAefRuntime — the explicit boundary between IVE output and a governed
 * AEF request (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
 *
 *   IveActionIntent (+ the parameters the user reviewed)
 *     → mapIveActionIntentWith(LAB table)   — intent only; subject = verified id
 *     → AefGovernance.submit()              — identity, contract, schema,
 *                                             policy, durable request, gate
 *     → AWAITING_APPROVAL
 *   decide()   — the subject's bound decision (gate id + binding hash)
 *   execute()  — the SAME proposal again; runs only if the durable operation
 *                is AUTHORIZED (approval bound to this exact payload), once
 *
 * This class never authorizes, executes or builds a receipt itself: it has
 * no tool capability (AefGovernance claimed it) and no store access. It
 * takes the subject only from the caller's verified identity, never from
 * the intent, the parameters or any client field. A changed payload maps to
 * a different idempotency key → a different operation that needs its own
 * approval; an approval never carries over.
 */
import type { RawCredential } from "../types.ts";
import type { AefGovernance } from "../persistence/governance.ts";
import { type IveActionTable, mapIveActionIntentWith } from "../persistence/ive_intent_mapping.ts";
import { LAB_IVE_ACTION_TABLE } from "./lab_tools.ts";
import { presentResult, type RuntimePresentation } from "./presentation.ts";

export interface IveAefRuntimeDeps {
  governance: AefGovernance;
  table?: IveActionTable;
  now?: () => Date;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HEX64 = /^[0-9a-f]{64}$/;

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function denied(code: string): RuntimePresentation {
  return { phase: "DENIED", completed: false, reconciliationRequired: false, retryAllowed: false, operationId: null, denialCode: code, gate: null, receipt: null, replayed: false };
}

export class IveAefRuntime {
  constructor(private readonly deps: IveAefRuntimeDeps) {}

  private actor(subjectId: string) {
    return { type: "user" as const, id: subjectId.toLowerCase(), auth_ref: `usr:${subjectId.toLowerCase()}` };
  }

  /** Registers the proposal. With LAB tools this always stops at AWAITING_APPROVAL. */
  propose(intent: unknown, subjectId: string, credential: RawCredential): Promise<RuntimePresentation> {
    return this.submit(intent, subjectId, credential);
  }

  /**
   * Resubmits the same proposal. Executes (once) only when the durable
   * operation for exactly this payload is AUTHORIZED; otherwise it reports
   * the persisted state (still pending, already final, …).
   */
  execute(intent: unknown, subjectId: string, credential: RawCredential): Promise<RuntimePresentation> {
    return this.submit(intent, subjectId, credential);
  }

  private async submit(intent: unknown, subjectId: string, credential: RawCredential): Promise<RuntimePresentation> {
    if (typeof subjectId !== "string" || !UUID.test(subjectId)) return denied("AUTH_FAILED");
    const mapped = await mapIveActionIntentWith(this.deps.table ?? LAB_IVE_ACTION_TABLE, intent, subjectId, { now: this.deps.now?.() });
    if (!mapped.ok) {
      // Refused before AEF could register anything: still recorded in the
      // subject's audit chain (Codex RG2-02).
      if (mapped.code !== "AUTH_FAILED") await this.deps.governance.auditRefusal(this.actor(subjectId), credential, mapped.code);
      return denied(mapped.code);
    }
    return presentResult(await this.deps.governance.submit(mapped.request, credential));
  }

  /** `input` is exactly { gateId, decision, bindingHash } — anything else is refused. */
  async decide(input: unknown, subjectId: string, credential: RawCredential): Promise<RuntimePresentation> {
    if (!isRecord(input)) return denied("INPUT_REJECTED");
    const keys = Object.keys(input);
    if (keys.length !== 3 || !["gateId", "decision", "bindingHash"].every((k) => keys.includes(k))) return denied("INPUT_REJECTED");
    const { gateId, decision, bindingHash } = input;
    if (typeof gateId !== "string" || !UUID.test(gateId)) return denied("INPUT_REJECTED");
    if (decision !== "APPROVE" && decision !== "REJECT") return denied("INPUT_REJECTED");
    if (typeof bindingHash !== "string" || !HEX64.test(bindingHash)) return denied("INPUT_REJECTED");
    if (typeof subjectId !== "string" || !UUID.test(subjectId)) return denied("AUTH_FAILED");
    return presentResult(await this.deps.governance.decideGate({
      gate_id: gateId,
      decision,
      binding_hash: bindingHash,
      approver: this.actor(subjectId),
    }, credential));
  }

  async status(operationId: unknown, subjectId: string, credential: RawCredential): Promise<RuntimePresentation> {
    if (typeof operationId !== "string" || !UUID.test(operationId)) return denied("INPUT_REJECTED");
    if (typeof subjectId !== "string" || !UUID.test(subjectId)) return denied("AUTH_FAILED");
    return presentResult(await this.deps.governance.getOperation({ operation_id: operationId, actor: this.actor(subjectId) }, credential));
  }

  async cancel(operationId: unknown, subjectId: string, credential: RawCredential): Promise<RuntimePresentation> {
    if (typeof operationId !== "string" || !UUID.test(operationId)) return denied("INPUT_REJECTED");
    if (typeof subjectId !== "string" || !UUID.test(subjectId)) return denied("AUTH_FAILED");
    return presentResult(await this.deps.governance.cancel({ operation_id: operationId, actor: this.actor(subjectId) }, credential));
  }
}
