/**
 * HumanGateEvaluator (Section 16). Only reached when the policy engine
 * has already returned REQUIRE_HUMAN_REVIEW -- this component decides
 * whether that review has been genuinely, validly satisfied.
 *
 * Never accepts `human_approved=true` as authorization (that field
 * cannot even reach here -- it is a PROHIBITED_AUTHORITY_FIELD rejected
 * at contract-validation time, before policy evaluation runs at all).
 * The only source of truth is an independently resolved, AUTHORIZED
 * HumanGateRecord whose approver identity was verified at authorization
 * time (see human_gate_store.ts).
 */
import { validateHumanGateRecord } from "../contracts/aef/validators.ts";
import type { ExecutionRequest } from "../contracts/aef/types.ts";
import type { HumanGateResolver, PolicyDecision } from "./types.ts";

export function evaluateHumanGate(
  request: ExecutionRequest,
  humanGateResolver: HumanGateResolver,
  now: Date,
): PolicyDecision {
  if (!request.human_gate_ref) {
    return { decision: "DENY", reason: "missing approval: this action requires human review but no human_gate_ref was supplied." };
  }

  const record = humanGateResolver.resolve(request.human_gate_ref);
  if (!record) {
    return { decision: "DENY", reason: `missing approval: human_gate_ref '${request.human_gate_ref}' does not resolve to any known HumanGateRecord.` };
  }

  const structuralCheck = validateHumanGateRecord(record, { now });
  if (!structuralCheck.ok) {
    // Covers, among other things, an AUTHORIZED record whose expires_at
    // has already passed (Finding F-04) -- an "expired approval" is
    // exactly a structurally-invalid-for-now record, not a separate code
    // path here.
    return { decision: "DENY", reason: `expired or invalid approval: ${structuralCheck.errors?.join("; ")}` };
  }

  // Binding checks (Section 8/16): a gate authorized for a DIFFERENT
  // request or a DIFFERENT action must never satisfy this one, even if
  // otherwise perfectly valid and AUTHORIZED.
  if (record.request_id !== request.request_id) {
    return { decision: "DENY", reason: `approval wrong request: HumanGateRecord '${record.gate_id}' is bound to request_id '${record.request_id}', not this request's '${request.request_id}'.` };
  }
  if (record.action !== request.action) {
    return { decision: "DENY", reason: `approval wrong action: HumanGateRecord '${record.gate_id}' is bound to action '${record.action}', not this request's '${request.action}'.` };
  }

  if (record.state !== "AUTHORIZED") {
    // Covers REQUESTED/REVIEW_REQUIRED (missing approval -- still
    // pending), REJECTED (denied by a human), and EXECUTED (already
    // consumed -- a HumanGateRecord authorizes exactly one execution,
    // never re-use for a second attempt).
    return { decision: "DENY", reason: `human approval is not in AUTHORIZED state (current state: '${record.state}').` };
  }

  return { decision: "ALLOW", reason: `human approval verified: HumanGateRecord '${record.gate_id}', approver auth_ref '${record.approver?.auth_ref}'.` };
}
