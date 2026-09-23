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
 * Codex adversarial review, round 1 area 10 AND round 2 Finding 2
 * ("direct execution fallback"): the original `lookup()` returned the
 * full `ToolDefinition` including `execute` (round 1); the round-1 fix
 * (`describe()`/`invoke()` split) still left `invoke()` itself PUBLIC
 * and UNCONDITIONALLY callable by anyone holding a `ToolRegistry`
 * reference -- Codex demonstrated `await registry.invoke(validRequest)`
 * executes a tool with zero governance, at any time.
 *
 * Fixed with a SINGLE-ISSUANCE capability pattern: `claimExecutionRights()`
 * returns a bound lookup-and-describe-nothing execution function EXACTLY
 * ONCE across this registry's entire lifetime -- a second call throws.
 * `AefKernel`'s constructor is the only intended caller, immediately
 * after receiving the registry, and stores the returned function in its
 * OWN `#private` field (see kernel.ts). This does not, and cannot,
 * defend against code that already has arbitrary execution inside this
 * process BEFORE a real AefKernel is ever constructed (no in-process
 * capability system can defend against that in any language without
 * real process isolation, which is disproportionate for a v0 with zero
 * network exposure and zero persistence -- Sections 12/27) -- but it
 * DOES close the realistic, demonstrated scenario: once a real
 * `AefKernel` exists and has claimed execution rights, no other code,
 * even code holding that EXACT SAME `ToolRegistry` reference, can ever
 * obtain execution capability from it again. `describe()` remains
 * available afterward for classification/policy purposes (metadata
 * only, always safe to expose).
 */
import type { ExecutionRequest } from "../contracts/aef/types.ts";
import type { ActionClassification, ToolDefinition, ToolExecutionContext, ToolExecutionResult } from "./types.ts";

export interface ToolDescriptor {
  toolId: string;
  domain: ExecutionRequest["domain"];
  classification: ActionClassification;
  requiresHumanGate: boolean;
}

/** A bound execution function returned by `claimExecutionRights()` -- looks up AND executes in one step, so the raw `execute` closure is never separately observable. Returns undefined for an unregistered domain+action. */
export type ExecuteFn = (request: ExecutionRequest, context?: ToolExecutionContext) => Promise<ToolExecutionResult> | undefined;

export class ToolRegistry {
  #tools = new Map<string, ToolDefinition>();
  #sealed = false;
  #executionRightsClaimed = false;

  register(tool: ToolDefinition): void {
    if (this.#sealed) {
      throw new Error("ToolRegistry: registry is sealed -- registration is only permitted during trusted startup wiring, before AefKernel begins processing requests");
    }
    const key = registryKey(tool.domain, tool.toolId);
    if (this.#tools.has(key)) {
      throw new Error(`ToolRegistry: duplicate registration for ${key} -- tool IDs must be unique per domain`);
    }
    // Codex round-3 adversarial review, new finding: storing the CALLER'S
    // own object by reference let them mutate `execute` (or any other
    // field) AFTER registration/sealing, retroactively changing what the
    // kernel runs even though `seal()` had already been called. Storing a
    // frozen, independent shallow copy means the caller's own object can
    // be mutated freely afterward with zero effect on what is actually
    // registered -- Object.freeze() additionally guards the STORED copy
    // itself against mutation via any other path.
    this.#tools.set(key, Object.freeze({ ...tool }));
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

  /**
   * Returns a bound execution function EXACTLY ONCE across this
   * registry's entire lifetime -- throws on any subsequent call. Intended
   * to be called exactly once, by `AefKernel`'s constructor, immediately
   * after it receives the registry. See the module doc comment above for
   * the full threat-model reasoning (Codex round-2, Finding 2).
   */
  claimExecutionRights(): ExecuteFn {
    if (this.#executionRightsClaimed) {
      throw new Error("ToolRegistry.claimExecutionRights: execution rights already claimed -- this can only happen once, by whichever code constructs the real AefKernel; no other caller may obtain execution capability afterward");
    }
    this.#executionRightsClaimed = true;
    // Codex round-3 adversarial review, new finding: relying on wiring
    // code to separately remember to call seal() left a window where a
    // registry could still accept new registrations even after a real
    // AefKernel had already claimed execution rights. Claiming execution
    // rights now unconditionally seals the registry too -- registration
    // and execution-capability issuance close together, in one step.
    this.#sealed = true;
    const tools = this.#tools;
    return (request: ExecutionRequest, context?: ToolExecutionContext) => {
      const tool = tools.get(registryKey(request.domain, request.action));
      if (!tool) return undefined;
      return tool.execute(request, context);
    };
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
