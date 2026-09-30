/**
 * Action classification (Section 15) and the Quant/Impact hard domain
 * boundaries (Sections 24/25).
 *
 * Design decision: classification is NOT inferred from the action string
 * by a heuristic/NLP-ish classifier -- that would let anything "declare"
 * itself READ_ONLY just by choosing a friendly-sounding name. Instead,
 * classification is a property of the specific, reviewed ToolDefinition
 * registered in the ToolRegistry (Section 17) for that domain+action --
 * single source of truth, and an unregistered action can never acquire a
 * favorable classification by construction (see tool_registry.ts: unknown
 * tool -> DENY, independent of classification entirely).
 *
 * The domain boundary check below is independent of tool classification
 * and runs first: even a hypothetical, correctly-registered Quant
 * real-money tool or Impact consequential tool must be hard-denied by
 * v0, unconditionally, per Sections 24/25 -- this is not overridable by
 * HumanGate (Section 24: "Mesmo com HumanGate").
 */
import type { ActionClassification, PolicyDecision } from "./types.ts";
import type { ExecutionRequest } from "../contracts/aef/types.ts";

const REAL_MONEY_QUANT_TIERS = new Set(["controlled_live", "expanded_live"]);

/**
 * Hard, unconditional domain boundary. Returns a DENY decision if this
 * request must be refused regardless of policy/tool/human-gate outcome;
 * returns null if the domain boundary has nothing to say (the request may
 * still be denied later for other reasons).
 */
export function checkDomainBoundary(
  request: ExecutionRequest,
  classification: ActionClassification,
): PolicyDecision | null {
  if (request.domain === "quant") {
    // Section 24: any real-money tier is DENY_BY_V0, even with a valid,
    // AUTHORIZED HumanGateRecord. AEF v0 has no broker, no live-trading
    // capability, and no financial credentials -- there is structurally
    // nothing safe to execute here, so policy must not even reach the
    // human-gate stage for these.
    if (request.quant_execution_tier && REAL_MONEY_QUANT_TIERS.has(request.quant_execution_tier)) {
      return {
        decision: "DENY",
        reason: `DENY_BY_V0: Quant real-money tier '${request.quant_execution_tier}' has no safe execution path in AEF v0 (no broker, no live trading, no financial credentials -- Section 24). Denied unconditionally, even with an AUTHORIZED HumanGateRecord.`,
      };
    }
  }

  if (request.domain === "impact" && classification !== "READ_ONLY") {
    // Section 25 / Finding F-09: Impact has no consequential-action risk
    // taxonomy yet (contracts/aef/README.md's known, acknowledged gap).
    // Until that taxonomy exists, AEF v0 cannot distinguish a safe
    // Impact consequential/reversible action from an unsafe one -- so
    // EVERYTHING except READ_ONLY is denied, not just CONSEQUENTIAL.
    // Codex adversarial review (round 1, area 5) correctly noted that
    // gating on `classification === "CONSEQUENTIAL"` alone puts full
    // trust in whatever classification the tool's registrar declared --
    // a REVERSIBLE-but-actually-mutating Impact action (e.g. a
    // misclassified tool) would previously bypass this boundary
    // entirely. Narrowing the allowed set to exactly READ_ONLY reduces
    // (does not eliminate -- see Section 17's registration-time trust
    // model, documented at the top of this file) that blast radius,
    // without inventing the Impact risk taxonomy this mission correctly
    // defers (Section 25: "não implementar Quant/Impact").
    return {
      decision: "DENY",
      reason: "DENY_BY_V0: Impact has no canonical consequential-action taxonomy yet (Finding F-09, deliberately deferred) -- only READ_ONLY Impact actions are permitted in v0; REVERSIBLE and CONSEQUENTIAL are both denied unconditionally.",
    };
  }

  return null;
}
