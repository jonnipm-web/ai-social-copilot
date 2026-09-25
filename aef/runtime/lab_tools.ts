/**
 * LAB tool registry and IVE action table (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
 *
 * MOCK TOOLS ONLY. The runtime obtains its registry exclusively from
 * createLabToolRegistry(), which registers the frozen LAB_MOCK_TOOLS list
 * and nothing else; this module imports no network client, credential or
 * database handle, and no real tool module exists to import. Every LAB tool:
 *   - is in domain "internal" with an id starting "internal.mock_";
 *   - declares an exact input schema (fail closed on anything else);
 *   - is CONSEQUENTIAL with a mandatory Human Gate, so an IVE proposal can
 *     never execute before its subject approves the exact payload.
 * The only "effect" is a counter in an in-memory MockEffectLedger.
 */
import type { ExecutionRequest } from "../../contracts/aef/types.ts";
import { defineIveActionTable, type IveActionTable } from "../persistence/ive_intent_mapping.ts";
import { createMockEffectTool, type MockBehavior, MockEffectLedger } from "../persistence/mock_effect_tool.ts";
import { defineToolInputSchema, type ToolInputSchema } from "../persistence/tool_input_schema.ts";
import { ToolRegistry } from "../tool_registry.ts";

export const LAB_TOOL_PREFIX = "internal.mock_";

export interface LabToolSpec {
  toolId: string;
  /** The IVE requestedAction mapped onto this tool. */
  iveAction: string;
  inputSchema: ToolInputSchema;
}

export const LAB_MOCK_TOOLS: readonly LabToolSpec[] = Object.freeze([
  Object.freeze({
    toolId: "internal.mock_publish_content",
    iveAction: "publish_content",
    inputSchema: defineToolInputSchema({
      channel: { type: "string", required: true, maxLength: 16, enum: ["instagram", "linkedin", "x", "blog"] },
      text: { type: "string", required: true, minLength: 1, maxLength: 280 },
    }),
  }),
  Object.freeze({
    toolId: "internal.mock_send_message",
    iveAction: "send_message",
    inputSchema: defineToolInputSchema({
      audience: { type: "string", required: true, maxLength: 16, enum: ["customers", "leads", "team"] },
      subject: { type: "string", required: true, minLength: 1, maxLength: 120 },
      body: { type: "string", required: true, minLength: 1, maxLength: 2000 },
    }),
  }),
]);

/**
 * The LAB IVE action table: only the two mock actions above; trade orders
 * stay categorically denied; every other IVE action (payment, transfer,
 * delete, workflow, module action) is absent → INTENT_ACTION_UNKNOWN.
 */
export const LAB_IVE_ACTION_TABLE: IveActionTable = defineIveActionTable({
  publish_content: { domain: "internal", action: "internal.mock_publish_content" },
  send_message: { domain: "internal", action: "internal.mock_send_message" },
  trade_order: { deny: "POLICY_DENIED" },
});

export interface LabRegistryOptions {
  ledger?: MockEffectLedger;
  /** Server-side behaviour of the mock (tests); never taken from a request. */
  behavior?: () => MockBehavior;
  delayMs?: number;
  lateEffectMs?: number;
}

/** Throws if anything but a LAB mock tool would be reachable. */
export function assertMockOnly(specs: readonly LabToolSpec[]): void {
  const seen = new Set<string>();
  for (const s of specs) {
    if (!s.toolId.startsWith(LAB_TOOL_PREFIX) || !/^internal\.mock_[a-z0-9_]{1,60}$/.test(s.toolId)) {
      throw new Error(`LAB runtime refuses non-mock tool '${s.toolId}'`);
    }
    if (!s.inputSchema) throw new Error(`LAB tool '${s.toolId}' has no input schema`);
    if (seen.has(s.toolId)) throw new Error(`duplicate LAB tool '${s.toolId}'`);
    seen.add(s.toolId);
  }
}

export function createLabToolRegistry(opts: LabRegistryOptions = {}): { registry: ToolRegistry; ledger: MockEffectLedger } {
  assertMockOnly(LAB_MOCK_TOOLS);
  const ledger = opts.ledger ?? new MockEffectLedger();
  const behavior = opts.behavior ?? (() => "SUCCEED" as MockBehavior);
  const registry = new ToolRegistry();
  for (const spec of LAB_MOCK_TOOLS) {
    registry.register({
      ...createMockEffectTool({
        toolId: spec.toolId,
        classification: "CONSEQUENTIAL",
        requiresHumanGate: true,
        ledger,
        behavior,
        delayMs: opts.delayMs,
        lateEffectMs: opts.lateEffectMs,
      }),
      inputSchema: spec.inputSchema,
    });
  }
  registry.seal();
  return { registry, ledger };
}

/** For presentation: the reviewed schema field names of a LAB action (never executable). */
export function labToolFor(request: Pick<ExecutionRequest, "domain" | "action">): LabToolSpec | undefined {
  if (request.domain !== "internal") return undefined;
  return LAB_MOCK_TOOLS.find((t) => t.toolId === request.action);
}
