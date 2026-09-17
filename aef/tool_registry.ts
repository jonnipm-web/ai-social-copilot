/**
 * ToolRegistry (Section 17) + safe mock tools ONLY (Section 18/32).
 *
 * No tool registered here can reach a real side effect: each
 * ToolDefinition.execute() signature (see types.ts) receives only the
 * already-governed ExecutionRequest -- no credential, no network client,
 * no secret, no Supabase/Stripe/broker handle is reachable from inside
 * it. This is a structural guarantee (there is nothing to import that
 * would grant such access from this file), not a policy promise.
 *
 * An action/tool not present in this registry is UNKNOWN and DENIED --
 * there is no dynamic/arbitrary tool selection path (Section 17: "Não
 * permitir dynamic arbitrary command/tool selection").
 */
import type { ExecutionRequest } from "../contracts/aef/types.ts";
import type { ToolDefinition, ToolExecutionResult } from "./types.ts";

export class ToolRegistry {
  private readonly tools = new Map<string, ToolDefinition>();

  register(tool: ToolDefinition): void {
    const key = registryKey(tool.domain, tool.toolId);
    if (this.tools.has(key)) {
      throw new Error(`ToolRegistry: duplicate registration for ${key} -- tool IDs must be unique per domain`);
    }
    this.tools.set(key, tool);
  }

  /** Looks up the tool registered for this request's exact domain+action. Returns undefined for anything not explicitly registered -- callers must treat that as UNKNOWN_TOOL -> DENY, never as "try anyway." */
  lookup(request: ExecutionRequest): ToolDefinition | undefined {
    return this.tools.get(registryKey(request.domain, request.action));
  }
}

function registryKey(domain: string, toolIdOrAction: string): string {
  return `${domain}::${toolIdOrAction}`;
}

/**
 * Registers the fixed set of safe mock tools used to prove the pipeline
 * works end-to-end (Section 18). Domain is "internal" for all of them --
 * the JSON Schema's `domain` enum (core|quant|impact|internal) has no
 * "TEST_ONLY" value, so "internal" plus an explicit `mock_`-prefixed
 * action name is this v0's equivalent marking. NONE of these may ever be
 * pointed at a real system -- see the module doc comment above.
 */
export function registerMockTools(registry: ToolRegistry): void {
  registry.register({
    toolId: "internal.mock_read_echo",
    domain: "internal",
    classification: "READ_ONLY",
    requiresHumanGate: false,
    execute: (request: ExecutionRequest): Promise<ToolExecutionResult> =>
      Promise.resolve({ outcome: "SUCCESS", detail: `echo: ${request.intent}` }),
  });

  registry.register({
    toolId: "internal.mock_reversible_update",
    domain: "internal",
    classification: "REVERSIBLE",
    requiresHumanGate: false,
    execute: (): Promise<ToolExecutionResult> =>
      Promise.resolve({ outcome: "SUCCESS", detail: "mock reversible update applied (in-memory, no real system touched)" }),
  });

  registry.register({
    toolId: "internal.mock_consequential_action",
    domain: "internal",
    classification: "CONSEQUENTIAL",
    requiresHumanGate: true,
    execute: (): Promise<ToolExecutionResult> =>
      Promise.resolve({ outcome: "SUCCESS", detail: "mock consequential action applied (in-memory, no real system touched)" }),
  });

  registry.register({
    toolId: "internal.mock_failing_tool",
    domain: "internal",
    classification: "REVERSIBLE",
    requiresHumanGate: false,
    execute: (): Promise<ToolExecutionResult> =>
      Promise.resolve({ outcome: "FAILURE", detail: "mock tool deliberately fails, for FAILURE-outcome test coverage (Section 27 failure model)" }),
  });
}
