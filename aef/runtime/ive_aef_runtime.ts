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
import type { ExecutionRequest } from "../../contracts/aef/types.ts";
import type { AefGovernance } from "../persistence/governance.ts";
import { type IveActionTable, mapIveActionIntentWith } from "../persistence/ive_intent_mapping.ts";
import { LAB_IVE_ACTION_TABLE } from "./lab_tools.ts";
import { presentResult, type RuntimePresentation } from "./presentation.ts";

/**
 * INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §7-9 — Result -> Learning.
 * Everything this runtime already has at hand once a governed result comes
 * back: who asked, what project/context it was about, and the receipted
 * outcome. Deliberately NOT the raw RuntimePresentation or ExecutionRequest
 * (those carry fields a learning entry has no business repeating, like the
 * gate's binding hash) -- this is the minimal, stable shape a writer needs.
 */
export interface LearningEntryInput {
  subjectId: string;
  projectId: string | null;
  contextRef: string | null;
  source: string;
  requestedAction: string;
  operationId: string;
  receiptId: string;
  outcome: string;
  phase: string;
}

/** Never allowed to throw into the caller's response -- see submit()'s call site. */
export type LearningWriter = (entry: LearningEntryInput) => Promise<void>;

export interface IveAefRuntimeDeps {
  governance: AefGovernance;
  table?: IveActionTable;
  now?: () => Date;
  /** Tags metadata.source/intent-prefix (INTEGRATION-MACRO-03); defaults to "ive". */
  source?: string;
  /**
   * Optional (INTELLIGENCE-AUTOMATION-MACRO-04 §7-9). Called once, after a
   * terminal, RECEIPTED result -- never for AWAITING_APPROVAL/AUTHORIZED/
   * EXECUTING, never for a denial with no receipt. This is deliberately the
   * same "terminal + receipted" condition the Dart client's own
   * aefReceiptOutcomeToActionStatus requires before it will ever write a
   * status (lib/data/models/aef_runtime.dart) -- one fail-closed rule for
   * what counts as a real, governed fact, enforced on both sides of the
   * boundary. This runtime has no Supabase/business_memory dependency of
   * its own; the actual write lives in
   * supabase/functions/_shared/result_learning.ts and is injected here so
   * aef/ stays free of any Supabase-specific code.
   */
  learningWriter?: LearningWriter;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HEX64 = /^[0-9a-f]{64}$/;

/**
 * Codex final audit (round 4, P2) -- the closed set of RuntimePhase values a
 * governed operation may be in when it is genuinely done (never
 * AWAITING_APPROVAL/AUTHORIZED/EXECUTING/DENIED). UNKNOWN_OUTCOME belongs
 * here too (RU-23): a FAILED-to-confirm outcome that governance still
 * attached a receipt to (presentResult's FINAL/default branch, as opposed
 * to the OUTCOME_UNCONFIRMED/REMAINS_UNKNOWN branches, which never carry a
 * receipt and are already excluded by the receipt check below) is exactly
 * the "the fact of execution happened, even if uncertain" case this
 * learning entry exists to record -- not a phase still in flight. Kept
 * local to this file rather than exported from presentation.ts: this
 * runtime is the only caller that needs a "may I derive a learning entry
 * from this" gate.
 */
const TERMINAL_PHASES = new Set(["SUCCEEDED", "FAILED", "REJECTED", "EXPIRED", "CANCELLED", "INVALIDATED", "UNKNOWN_OUTCOME"]);

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
    const mapped = await mapIveActionIntentWith(this.deps.table ?? LAB_IVE_ACTION_TABLE, intent, subjectId, {
      now: this.deps.now?.(),
      source: this.deps.source,
    });
    if (!mapped.ok) {
      // Refused before AEF could register anything: still recorded in the
      // subject's audit chain (Codex RG2-02).
      if (mapped.code !== "AUTH_FAILED") await this.deps.governance.auditRefusal(this.actor(subjectId), credential, mapped.code);
      return denied(mapped.code);
    }
    const presentation = presentResult(await this.deps.governance.submit(mapped.request, credential));
    await this.writeLearning(presentation, mapped.request, subjectId);
    return presentation;
  }

  /**
   * §7-9: fires only for a terminal, RECEIPTED result -- the same condition
   * the Dart client itself requires before writing anything. Errors here
   * are contained: a learning-write failure must never change what the
   * caller sees for their own governed action, and must never retry
   * automatically (this runtime never retries anything -- see the class
   * doc). Swallowed, not silently: the writer itself is responsible for
   * its own structured error logging (result_learning.ts).
   */
  private async writeLearning(presentation: RuntimePresentation, request: ExecutionRequest, subjectId: string): Promise<void> {
    const writer = this.deps.learningWriter;
    // Codex final audit (round 4, INTELLIGENCE-AUTOMATION-MACRO-04, P2): the
    // receipt/operationId check above already implies a terminal phase given
    // presentResult()'s current shape (EMPTY.receipt stays null for every
    // still-in-flight/DENIED/OUTCOME_UNCONFIRMED/REMAINS_UNKNOWN branch) --
    // but that is an UPSTREAM invariant of AefGovernance/presentResult, not
    // something this method enforces itself. A defense-in-depth explicit
    // allowlist means a future change to presentResult (e.g. attaching a
    // provisional receipt to
    // EXECUTING) cannot silently make this fire on a non-terminal phase.
    if (!writer || !presentation.receipt || !presentation.operationId || !TERMINAL_PHASES.has(presentation.phase)) return;
    try {
      await writer({
        subjectId,
        projectId: request.resource?.type === "project" ? request.resource.id : null,
        contextRef: request.context_ref ?? null,
        source: this.deps.source ?? "ive",
        requestedAction: request.action,
        operationId: presentation.operationId,
        receiptId: presentation.receipt.receiptId,
        outcome: presentation.receipt.outcome,
        phase: presentation.phase,
      });
    } catch {
      // Never let a best-effort learning write fail the actual response.
    }
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
