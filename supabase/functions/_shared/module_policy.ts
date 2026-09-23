/**
 * Server-side Module Policy — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
 *
 * The SERVER authority for "which modules exist, in which lifecycle, behind
 * which plan" and "which Edge Function belongs to which module". Edge
 * Functions decide access from THIS file (via entitlement.ts), never from
 * anything the client sends.
 *
 * Relationship to lib/core/modules/module_registry.dart (the Flutter
 * registry): the registry stays the source of truth for presentation
 * metadata (names, readiness text, routes, admin inventory). This manifest
 * holds only the commercial/authorization subset, and the two are kept in
 * lockstep by test/core/modules/server_module_policy_drift_test.dart, which
 * parses the JSON block below and fails CI on any disagreement (missing
 * module on either side, lifecycle or plan mismatch).
 *
 * The block between the BEGIN/END markers MUST stay strict JSON (double
 * quotes, no comments, no trailing commas) — the Dart drift test and
 * module_policy_test.ts both parse it as JSON.
 *
 * Field semantics:
 * - lifecycle: EXPERIMENTAL | INTERNAL | ALPHA | BETA | RELEASE_CANDIDATE |
 *   COMMERCIAL | DEPRECATED (docs/architecture/modules/MODULE_PROMOTION_GATE.md).
 * - minimumPlan: free | pro | premium. Admin-only modules are expressed by
 *   lifecycle (INTERNAL/EXPERIMENTAL), never by a plan — admin is a role.
 * - actionClass: the highest AEF ActionClassification (aef/types.ts:
 *   READ_ONLY | REVERSIBLE | CONSEQUENTIAL — the A/B/C risk classes of the
 *   Promotion Gate) that any IVE/agent path may request from this module.
 *   Human-driven UI flows (e.g. Stripe checkout) are not agent-invocable
 *   and do not raise it.
 * - edgeFunctions.kind: MODULE (entitlement required, moduleId mandatory) |
 *   BILLING | ENTITLEMENT | PUBLIC_WEBHOOK | RETIRED (no module gate; each
 *   has its own boundary, documented in MODULE_ARCHITECTURE.md §13).
 */

export type ModuleLifecycle =
  | "EXPERIMENTAL"
  | "INTERNAL"
  | "ALPHA"
  | "BETA"
  | "RELEASE_CANDIDATE"
  | "COMMERCIAL"
  | "DEPRECATED";

export type Plan = "free" | "pro" | "premium";

export type ActionClass = "READ_ONLY" | "REVERSIBLE" | "CONSEQUENTIAL";

export interface ModulePolicy {
  lifecycle: ModuleLifecycle;
  minimumPlan: Plan;
  actionClass: ActionClass;
}

export type EdgeFunctionKind = "MODULE" | "BILLING" | "ENTITLEMENT" | "PUBLIC_WEBHOOK" | "RETIRED";

export interface EdgeFunctionPolicy {
  kind: EdgeFunctionKind;
  moduleId?: string;
}

export interface ModulePolicyDoc {
  version: number;
  modules: Record<string, ModulePolicy>;
  edgeFunctions: Record<string, EdgeFunctionPolicy>;
}

/**
 * AEF persistence (persistent Human Gate records + ExecutionReceipts,
 * IV-AEF-PERSISTENCE-01) does not exist yet. While false, no module whose
 * actionClass is CONSEQUENTIAL may be RELEASE_CANDIDATE or COMMERCIAL —
 * enforced by module_policy_test.ts, not just documented.
 */
export const AEF_PERSISTENCE_AVAILABLE = false;

export const MODULE_POLICY: ModulePolicyDoc =
// BEGIN_MODULE_POLICY_JSON
{
  "version": 1,
  "modules": {
    "command-center": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "business-dashboard": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "projects": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "knowledge-vault": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "strategy-generation": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "website-analyzer": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "market-intelligence": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "competitor-discovery": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "gap-analysis": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "niche-discovery": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "opportunity-discovery": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "content-cluster": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "revenue-planner": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "opportunity-lab": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "action-engine": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "context-copilot": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "file-import": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "google-drive-import": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "usage-quota": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "plans-upgrade": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "improve-post": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "personas": { "lifecycle": "INTERNAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "content-library": { "lifecycle": "INTERNAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "calendar": { "lifecycle": "INTERNAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "campaigns": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "performance": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "roi-tracker": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "executive-dashboard": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "decision-center": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "resource-allocation": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "weekly-briefing": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "advisor-onboarding": { "lifecycle": "EXPERIMENTAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "decision-simulator": { "lifecycle": "EXPERIMENTAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "intelligence-debug": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "admin-panel": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "ive-avatar": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "ive-quant": { "lifecycle": "EXPERIMENTAL", "minimumPlan": "free", "actionClass": "CONSEQUENTIAL" },
    "quant-analytics": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "READ_ONLY" }
  },
  "edgeFunctions": {
    "analyze-website": { "kind": "MODULE", "moduleId": "website-analyzer" },
    "competitor-discovery": { "kind": "MODULE", "moduleId": "competitor-discovery" },
    "content-cluster": { "kind": "MODULE", "moduleId": "content-cluster" },
    "context-copilot": { "kind": "MODULE", "moduleId": "context-copilot" },
    "decision-simulator": { "kind": "MODULE", "moduleId": "decision-simulator" },
    "extract-knowledge": { "kind": "MODULE", "moduleId": "knowledge-vault" },
    "gap-analysis": { "kind": "MODULE", "moduleId": "gap-analysis" },
    "generate-campaign": { "kind": "MODULE", "moduleId": "campaigns" },
    "generate-project-actions": { "kind": "MODULE", "moduleId": "action-engine" },
    "generate-project-opportunities": { "kind": "MODULE", "moduleId": "opportunity-lab" },
    "generate-strategy": { "kind": "MODULE", "moduleId": "strategy-generation" },
    "improve-post": { "kind": "MODULE", "moduleId": "improve-post" },
    "market-analysis": { "kind": "MODULE", "moduleId": "market-intelligence" },
    "niche-discovery": { "kind": "MODULE", "moduleId": "niche-discovery" },
    "opportunity-discovery": { "kind": "MODULE", "moduleId": "opportunity-discovery" },
    "process-file": { "kind": "MODULE", "moduleId": "file-import" },
    "revenue-planner": { "kind": "MODULE", "moduleId": "revenue-planner" },
    "quant-analyze": { "kind": "MODULE", "moduleId": "quant-analytics" },
    "quant-watchlists": { "kind": "MODULE", "moduleId": "quant-analytics" },
    "create-checkout-session": { "kind": "BILLING" },
    "module-access": { "kind": "ENTITLEMENT" },
    "stripe-webhook": { "kind": "PUBLIC_WEBHOOK" },
    "ive-agent-runner": { "kind": "RETIRED" }
  }
}
// END_MODULE_POLICY_JSON
;
