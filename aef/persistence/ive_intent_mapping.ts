/**
 * IveActionIntent → AEF ExecutionRequest (IV-AEF-PERSISTENCE-01).
 *
 * An IveActionIntent is a SUGGESTION produced by IVE (a language model
 * pipeline). It carries no authority. This mapping:
 *   - accepts exactly the six IveActionIntent keys (anything else — user,
 *     role, plan, approval, tool, risk override… — is INTENT_INVALID);
 *   - takes the subject ONLY from the caller's verified identity, never from
 *     the intent;
 *   - maps `requestedAction` through a server-owned table; unknown actions
 *     are refused, and categorically forbidden ones (real-money trading)
 *     are refused here already;
 *   - ignores `riskClass` for authority: risk and gate requirement come from
 *     the server tool registry and policy when the request is submitted;
 *   - turns `projectId` into a `project` resource whose ownership the
 *     database verifies at registration;
 *   - derives the idempotency key from the intent content, so a replayed
 *     intent maps to the same durable operation instead of a second one.
 * The result still goes through AefGovernance.submit(), which re-verifies
 * the credential and runs the full contract validation and policy.
 *
 * Not wired into ive-intelligence (mission rule): IVE keeps answering
 * ACTION_REQUIRES_AEF; this is the documented, tested contract for the
 * future runtime integration.
 */
import type { Domain, ExecutionRequest } from "../../contracts/aef/types.ts";
import { canonicalJson, sha256Hex } from "./canonical.ts";
import type { AefErrorCode } from "./errors.ts";

export type IveActionTarget = { domain: Domain; action: string } | { deny: AefErrorCode };

/** Server-owned. None of these actions has a registered tool today, so they
 * are all refused as UNKNOWN_TOOL by the governance service: IVE cannot
 * cause any real action through AEF in this mission. */
export const IVE_ACTION_MAP: Readonly<Record<string, IveActionTarget>> = Object.freeze({
  publish_content: { domain: "core", action: "core.publish_content" },
  send_message: { domain: "core", action: "core.send_message" },
  payment: { domain: "core", action: "core.payment" },
  transfer_funds: { domain: "core", action: "core.transfer_funds" },
  delete_data: { domain: "core", action: "core.delete_data" },
  execute_workflow: { domain: "core", action: "core.execute_workflow" },
  module_action: { domain: "core", action: "core.module_action" },
  trade_order: { deny: "POLICY_DENIED" },
});

const INTENT_KEYS = ["capabilityId", "requestedAction", "projectId", "riskClass", "contextRef", "parameters"] as const;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CAPABILITY = /^[a-z0-9][a-z0-9-]{0,63}$/;
const REQUEST_LIFETIME_MS = 5 * 60 * 1000;

export type IveMappingResult = { ok: true; request: ExecutionRequest } | { ok: false; code: AefErrorCode };

function isPlainObject(v: unknown): v is Record<string, unknown> {
  if (typeof v !== "object" || v === null || Array.isArray(v)) return false;
  const proto = Object.getPrototypeOf(v);
  return proto === Object.prototype || proto === null;
}

export interface IveMappingOptions {
  now?: Date;
  /** Test wiring only; production uses IVE_ACTION_MAP. */
  actionMap?: Readonly<Record<string, IveActionTarget>>;
}

export async function mapIveActionIntent(
  raw: unknown,
  verifiedUserId: string,
  opts: IveMappingOptions = {},
): Promise<IveMappingResult> {
  const fail = (code: AefErrorCode): IveMappingResult => ({ ok: false, code });
  if (typeof verifiedUserId !== "string" || !UUID.test(verifiedUserId)) return fail("AUTH_FAILED");
  if (!isPlainObject(raw)) return fail("INTENT_INVALID");
  const keys = Object.keys(raw);
  if (keys.length !== INTENT_KEYS.length || !INTENT_KEYS.every((k) => keys.includes(k))) return fail("INTENT_INVALID");

  const { capabilityId, requestedAction, projectId, riskClass, contextRef, parameters } = raw;
  if (capabilityId !== null && (typeof capabilityId !== "string" || !CAPABILITY.test(capabilityId))) return fail("INTENT_INVALID");
  if (typeof requestedAction !== "string") return fail("INTENT_INVALID");
  if (projectId !== null && (typeof projectId !== "string" || !UUID.test(projectId))) return fail("INTENT_INVALID");
  if (riskClass !== "READ_ONLY" && riskClass !== "REVERSIBLE" && riskClass !== "CONSEQUENTIAL") return fail("INTENT_INVALID");
  if (typeof contextRef !== "string" || !UUID.test(contextRef)) return fail("INTENT_INVALID");
  if (!isPlainObject(parameters)) return fail("INTENT_INVALID");

  const map = opts.actionMap ?? IVE_ACTION_MAP;
  if (!Object.prototype.hasOwnProperty.call(map, requestedAction)) return fail("INTENT_ACTION_UNKNOWN");
  const target = map[requestedAction];
  if ("deny" in target) return fail(target.deny);

  const canonical = canonicalJson({
    contextRef: contextRef.toLowerCase(),
    requestedAction,
    projectId: projectId === null ? null : projectId.toLowerCase(),
    parameters,
  });
  if (!canonical.ok) return fail(canonical.code);

  const now = opts.now ?? new Date();
  const request: ExecutionRequest = {
    contract_version: "1.0",
    request_id: crypto.randomUUID(),
    requested_at: now.toISOString(),
    expires_at: new Date(now.getTime() + REQUEST_LIFETIME_MS).toISOString(),
    actor: { type: "user", id: verifiedUserId.toLowerCase(), auth_ref: `usr:${verifiedUserId.toLowerCase()}` },
    intent: `ive:${requestedAction}`,
    domain: target.domain,
    action: target.action,
    parameters: structuredClone(parameters),
    context_ref: contextRef.toLowerCase(),
    idempotency_key: `ive:${await sha256Hex(canonical.json)}`,
    metadata: capabilityId === null ? { source: "ive" } : { source: "ive", capability_hint: capabilityId },
  };
  if (projectId !== null) request.resource = { type: "project", id: projectId.toLowerCase() };
  return { ok: true, request };
}
