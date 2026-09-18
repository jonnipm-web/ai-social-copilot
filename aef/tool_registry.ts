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
 *
 * Codex round-1 adversarial review, area 10 ("direct execution fallback"):
 * the original `lookup()` returned the full `ToolDefinition`, including
 * its `execute` closure -- ANY caller holding a `ToolRegistry` reference
 * could grab a tool and call `.execute()` directly, completely bypassing
 * AefKernel's governed pipeline (identity/contract/policy/human-gate/
 * idempotency). Fixed by never handing out the executable capability at
 * all: `describe()` returns only descriptive metadata (`ToolDescriptor`,
 * no `execute` field), and `invoke()` is the ONLY way to actually run a
 * tool -- it does its own internal lookup and calls `execute` itself,
 * so the function value is never exposed to any caller, including
 * AefKernel itself (which only ever calls `invoke()`, never destructures
 * a stored ToolDefinition).
 */
import type { ExecutionRequest } from "../contracts/aef/types.ts";
import type { ActionClassification, ToolDefinition, ToolExecutionResult } from "./types.ts";

export interface ToolDescriptor {
  toolId: string;
  domain: ExecutionRequest["domain"];
  classification: ActionClassification;
  requiresHumanGate: boolean;
}

export class ToolRegistry {
  #tools = new Map<string, ToolDefinition>();
  #sealed = false;

  register(tool: ToolDefinition): void {
    if (this.#sealed) {
      throw new Error("ToolRegistry: registry is sealed -- registration is only permitted during trusted startup wiring, before AefKernel begins processing requests");
    }
    const key = registryKey(tool.domain, tool.toolId);
    if (this.#tools.has(key)) {
      throw new Error(`ToolRegistry: duplicate registration for ${key} -- tool IDs must be unique per domain`);
    }
    this.#tools.set(key, tool);
  }

  /**
   * Freezes the registry against further registration. Production wiring
   * should call this immediately after registering all tools, before
   * constructing AefKernel -- defense in depth (Codex round-1, area 4)
   * against a later, accidental or malicious `register()` call
   * introducing an unreviewed tool once request processing has begun.
   * Does not, and cannot, defend against code that already has arbitrary
   * execution inside this process (no in-process boundary can) -- it
   * narrows the legitimate registration window to startup only.
   */
  seal(): void {
    this.#sealed = true;
  }

  /** Descriptive metadata only -- NEVER exposes the executable capability. Returns undefined for anything not explicitly registered; callers must treat that as UNKNOWN_TOOL -> DENY, never as "try anyway." */
  describe(request: ExecutionRequest): ToolDescriptor | undefined {
    const tool = this.#tools.get(registryKey(request.domain, request.action));
    if (!tool) return undefined;
    return { toolId: tool.toolId, domain: tool.domain, classification: tool.classification, requiresHumanGate: tool.requiresHumanGate };
  }

  /** The ONLY way to actually execute a tool. Does its own internal lookup so `execute` is never handed out to a caller. Returns undefined if the tool is not registered -- callers must already have confirmed existence via `describe()` first; this defensively re-checks rather than assume. */
  invoke(request: ExecutionRequest): Promise<ToolExecutionResult> | undefined {
    const tool = this.#tools.get(registryKey(request.domain, request.action));
    if (!tool) return undefined;
    return tool.execute(request);
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
