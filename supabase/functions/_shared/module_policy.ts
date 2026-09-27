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
 * - edgeFunctions.gateFile: optional; see EdgeFunctionPolicy.
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
  /** When the function delegates to a shared handler, the file (relative
   * to supabase/functions/) where authentication + requireModuleAccess run.
   * MP-06 checks the gate order in that file instead of index.ts. */
  gateFile?: string;
  /**
   * INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 — a module's actionClass
   * is a default, not a ceiling: a commercially-available module (e.g.
   * action-engine, aef-runtime-lab) can own one narrow, LAB-only function
   * whose real risk is higher than the module's dominant capability (e.g.
   * action-engine's own AI-generation calls are REVERSIBLE; its one
   * execute-transition function serves a CONSEQUENTIAL, Human-Gate-required
   * tool). This is that function's OWN effective actionClass — see
   * effectiveActionClass(). It may only RAISE risk above the module
   * default, never lower it (MP-11) — a function can never use this field
   * to quietly opt out of its module's own protections.
   */
  actionClassOverride?: ActionClass;
}

/**
 * A function's real, enforced risk class: its own override if it has one,
 * otherwise its module's default. This is the value every Promotion Gate
 * (MP-09, MP-11) and any future policy/entitlement code must use instead of
 * reading a function's module's actionClass directly — a function-level
 * override would otherwise silently go unenforced.
 */
export function effectiveActionClass(fn: string, doc: ModulePolicyDoc = MODULE_POLICY): ActionClass | undefined {
  const p = doc.edgeFunctions[fn];
  if (!p) return undefined;
  if (p.actionClassOverride) return p.actionClassOverride;
  if (!p.moduleId) return undefined;
  return doc.modules[p.moduleId]?.actionClass;
}

export interface ModulePolicyDoc {
  version: number;
  modules: Record<string, ModulePolicy>;
  edgeFunctions: Record<string, EdgeFunctionPolicy>;
}

/**
 * AEF persistence (persistent Human Gate records + ExecutionReceipts) is
 * implemented and tested in the Module Lab (IV-AEF-PERSISTENCE-01) but is
 * NOT available at runtime: the migration is not applied, no endpoint
 * exists and IVE is not wired to it. Flip only in the runtime-integration
 * gate. While false, no module whose actionClass is CONSEQUENTIAL may be
 * RELEASE_CANDIDATE or COMMERCIAL — enforced by module_policy_test.ts.
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
    "project-auto-bootstrap": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "context-copilot": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "file-import": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "google-drive-import": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "usage-quota": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "plans-upgrade": { "lifecycle": "COMMERCIAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "improve-post": { "lifecycle": "COMMERCIAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "personas": { "lifecycle": "COMMERCIAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "content-library": { "lifecycle": "COMMERCIAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "calendar": { "lifecycle": "COMMERCIAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "campaigns": { "lifecycle": "COMMERCIAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "performance": { "lifecycle": "COMMERCIAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
    "roi-tracker": { "lifecycle": "COMMERCIAL", "minimumPlan": "pro", "actionClass": "REVERSIBLE" },
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
    "aef-runtime-lab": { "lifecycle": "EXPERIMENTAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "impact": { "lifecycle": "EXPERIMENTAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" },
    "quant-analytics": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "READ_ONLY" },
    "quant-watchlists": { "lifecycle": "INTERNAL", "minimumPlan": "free", "actionClass": "REVERSIBLE" }
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
    "ive-intelligence": { "kind": "MODULE", "moduleId": "context-copilot", "gateFile": "_shared/ive/intelligence.ts" },
    "ive-memory": { "kind": "MODULE", "moduleId": "context-copilot", "gateFile": "_shared/ive/memory_endpoint.ts" },
    "quant-analyze": { "kind": "MODULE", "moduleId": "quant-analytics" },
    "quant-watchlists": { "kind": "MODULE", "moduleId": "quant-watchlists" },
    "create-checkout-session": { "kind": "BILLING" },
    "impact-lab": { "kind": "MODULE", "moduleId": "impact" },
    "module-access": { "kind": "ENTITLEMENT" },
    "stripe-webhook": { "kind": "PUBLIC_WEBHOOK" },
    "ive-agent-runner": { "kind": "RETIRED" },
    "aef-runtime": { "kind": "MODULE", "moduleId": "aef-runtime-lab", "gateFile": "_shared/aef_runtime_endpoint.ts", "actionClassOverride": "CONSEQUENTIAL" },
    "action-engine-runtime": { "kind": "MODULE", "moduleId": "action-engine", "gateFile": "_shared/aef_runtime_endpoint.ts", "actionClassOverride": "CONSEQUENTIAL" },
    "quant-runtime": { "kind": "MODULE", "moduleId": "ive-quant", "gateFile": "_shared/aef_runtime_endpoint.ts" }
  }
}
// END_MODULE_POLICY_JSON
;
