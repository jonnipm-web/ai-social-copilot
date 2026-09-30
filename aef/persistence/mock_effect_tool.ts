/**
 * Deterministic mock tool for the persistent AEF (IV-AEF-PERSISTENCE-01).
 * TEST-ONLY: its only "side effect" is a counter in an in-memory ledger.
 * It has no network, credential or database access.
 *
 * The behavior is chosen by the test wiring (server side), never by the
 * request. The ledger records every invocation and every applied effect per
 * operation id, which is how the tests prove "at most one execution per
 * operation" under concurrency and crash scenarios.
 */
import type { ExecutionRequest } from "../../contracts/aef/types.ts";
import type { ToolRegistry } from "../tool_registry.ts";
import type { ActionClassification, ToolDefinition, ToolExecutionContext, ToolExecutionResult } from "../types.ts";

export type MockBehavior =
  | "SUCCEED"
  | "FAIL_BEFORE_EFFECT"
  | "FAIL_AFTER_EFFECT"
  | "FAIL_UNDECLARED"
  | "THROW_AFTER_EFFECT"
  | "HANG"
  /** Ignores the abort signal and applies its effect after `lateEffectMs` (Codex G2-02). */
  | "IGNORE_ABORT_LATE_EFFECT";

export class MockEffectLedger {
  readonly invocations = new Map<string, number>();
  readonly effects = new Map<string, number>();
  seenRequests: ExecutionRequest[] = [];

  invoke(operationId: string, request: ExecutionRequest): void {
    this.invocations.set(operationId, (this.invocations.get(operationId) ?? 0) + 1);
    this.seenRequests.push(request);
  }
  applyEffect(operationId: string): void {
    this.effects.set(operationId, (this.effects.get(operationId) ?? 0) + 1);
  }
  totalEffects(): number {
    let n = 0;
    for (const v of this.effects.values()) n += v;
    return n;
  }
}

export interface MockEffectToolOptions {
  toolId: string;
  classification: ActionClassification;
  requiresHumanGate: boolean;
  ledger: MockEffectLedger;
  behavior: () => MockBehavior;
  /** Simulated work before the effect (ms); lets concurrency tests overlap. */
  delayMs?: number;
  /** For IGNORE_ABORT_LATE_EFFECT. */
  lateEffectMs?: number;
}

function wait(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    if (ms <= 0) return resolve();
    const t = setTimeout(resolve, ms);
    signal?.addEventListener("abort", () => {
      clearTimeout(t);
      resolve();
    }, { once: true });
  });
}

export function createMockEffectTool(opts: MockEffectToolOptions): ToolDefinition {
  return {
    toolId: opts.toolId,
    domain: "internal",
    classification: opts.classification,
    requiresHumanGate: opts.requiresHumanGate,
    async execute(request: ExecutionRequest, context?: ToolExecutionContext): Promise<ToolExecutionResult> {
      const operationId = context?.operationId ?? "no-operation";
      opts.ledger.invoke(operationId, request);
      const behavior = opts.behavior();
      await wait(opts.delayMs ?? 0, context?.signal);
      switch (behavior) {
        case "SUCCEED":
          opts.ledger.applyEffect(operationId);
          return { outcome: "SUCCESS", detail: "mock effect applied" };
        case "FAIL_BEFORE_EFFECT":
          return { outcome: "FAILURE", sideEffect: "NONE", detail: "mock failed before any effect" };
        case "FAIL_AFTER_EFFECT":
          opts.ledger.applyEffect(operationId);
          return { outcome: "FAILURE", sideEffect: "APPLIED", detail: "mock failed after its effect" };
        case "FAIL_UNDECLARED":
          return { outcome: "FAILURE", detail: "mock failed without saying whether an effect happened" };
        case "THROW_AFTER_EFFECT":
          opts.ledger.applyEffect(operationId);
          throw new Error("mock threw after its effect");
        case "IGNORE_ABORT_LATE_EFFECT":
          await wait(opts.lateEffectMs ?? 500);
          opts.ledger.applyEffect(operationId);
          return { outcome: "SUCCESS", detail: "late effect after the caller gave up" };
        case "HANG":
          // Never settles on its own; resolves only when the caller aborts.
          await new Promise<void>((resolve) => {
            if (!context || context.signal.aborted) return resolve();
            context.signal.addEventListener("abort", () => resolve(), { once: true });
          });
          return { outcome: "SUCCESS", detail: "late result after abort (must be ignored)" };
      }
    },
  };
}

export const MOCK_CONSEQUENTIAL_TOOL = "internal.mock_effect_consequential";
export const MOCK_REVERSIBLE_TOOL = "internal.mock_effect_reversible";

/** Registers the two mock effect tools used by the persistence tests. */
export function registerMockEffectTools(
  registry: ToolRegistry,
  ledger: MockEffectLedger,
  behavior: () => MockBehavior,
  delayMs = 0,
  lateEffectMs?: number,
): void {
  registry.register(createMockEffectTool({
    toolId: MOCK_CONSEQUENTIAL_TOOL,
    classification: "CONSEQUENTIAL",
    requiresHumanGate: true,
    ledger,
    behavior,
    delayMs,
    lateEffectMs,
  }));
  registry.register(createMockEffectTool({
    toolId: MOCK_REVERSIBLE_TOOL,
    classification: "REVERSIBLE",
    requiresHumanGate: false,
    ledger,
    behavior,
    delayMs,
    lateEffectMs,
  }));
}
