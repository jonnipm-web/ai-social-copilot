/**
 * Policy engine v0 (Section 13/14). Deterministic code, never an LLM or
 * any other non-deterministic/authoritative-by-inference component.
 *
 * IVE MAY REQUEST. IVE MUST NOT AUTHORIZE (Section 14) -- nothing in the
 * ExecutionRequest itself (intent text, metadata, constraints) is
 * consulted here as an authorization signal. The only inputs are: the
 * tool's own declared classification/requirements (a property of the
 * reviewed ToolDefinition, not of the request) and the domain boundary
 * check (action_classification.ts), which runs first and can veto
 * unconditionally.
 */
import { checkDomainBoundary } from "./action_classification.ts";
import type { ExecutionRequest } from "../contracts/aef/types.ts";
import type { PolicyDecision, ToolDefinition } from "./types.ts";

export function evaluatePolicy(request: ExecutionRequest, tool: ToolDefinition): PolicyDecision {
  const boundary = checkDomainBoundary(request, tool.classification);
  if (boundary) return boundary;

  if (tool.classification === "READ_ONLY") {
    return { decision: "ALLOW", reason: "READ_ONLY actions are eligible for ALLOW by default (Section 15)." };
  }

  if (tool.classification === "REVERSIBLE") {
    if (tool.requiresHumanGate) {
      return { decision: "REQUIRE_HUMAN_REVIEW", reason: "This REVERSIBLE tool explicitly requires human review." };
    }
    return { decision: "ALLOW", reason: "REVERSIBLE action, tool does not require human review (Section 15: policy-controlled default = ALLOW)." };
  }

  // CONSEQUENTIAL: conservative default per Section 15 ("REQUIRE_HUMAN_REVIEW
  // ou DENY") -- v0 picks REQUIRE_HUMAN_REVIEW, which still requires a
  // valid, AUTHORIZED HumanGateRecord to actually proceed (see
  // human_gate_evaluator.ts). It is never auto-ALLOW.
  return { decision: "REQUIRE_HUMAN_REVIEW", reason: "CONSEQUENTIAL actions always require human review in AEF v0 (Section 15)." };
}
