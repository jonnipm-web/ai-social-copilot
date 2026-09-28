/**
 * Strategy Execution Engine Registry — INSIGHTVALUES-ROBOT-BUILDER-
 * MACRO-06 §14.
 *
 * A closed allowlist mapping an `engineId` to how it actually runs.
 * Nothing in this codebase resolves an engine by dynamically importing a
 * module named from user input -- a spec's `engineId` is always looked up
 * here first, and an unknown id is refused before any execution attempt
 * (§14: "Do not dynamically import arbitrary modules based on user
 * text.").
 */

export type EngineId = 'GENERIC_RULE_ENGINE' | 'PAULO_TREND_FIBONACCI_V10';

export type EngineKind =
  /** Executes in this process, in TypeScript, on rows already validated
   * by ohlcv.ts. No external process, no network call. */
  | 'IN_PROCESS'
  /** Executes via the bounded, timeout-guarded Python backtest bridge
   * (backtest_bridge.ts) -- the ONLY engine kind that leaves this
   * process. */
  | 'EXTERNAL_PYTHON_SERVICE';

export interface EngineRecord {
  readonly engineId: EngineId;
  readonly kind: EngineKind;
  /** Rule ids (rule_catalog.ts) this engine actually executes. A spec
   * referencing a rule outside this set must be refused before running,
   * not silently ignored. */
  readonly supportedRuleIds: readonly string[];
  /** Dataset ids (dataset_registry.ts) this engine is allowed to run
   * against. */
  readonly supportedDatasetIds: readonly string[];
  readonly description: string;
}

export const ENGINE_REGISTRY: readonly EngineRecord[] = Object.freeze([
  {
    engineId: 'GENERIC_RULE_ENGINE',
    kind: 'IN_PROCESS',
    supportedRuleIds: Object.freeze([
      'ENTRY.SESSION_OPEN',
      'STOP.FIXED_DISTANCE',
      'TARGET.FIXED_DISTANCE',
      'BREAK_EVEN.STEPPED',
      'SESSION.WINDOW',
      'EXIT.FORCED_TIME',
      'POSITION_SIZE.FIXED_CONTRACTS',
    ]),
    supportedDatasetIds: Object.freeze([
      'synthetic-fixture-5min-v1',
      // MACRO-07 §14: chronological research/holdout SLICES of the same
      // fixture (dataset_registry.ts's `segmentOf`) -- allowlisted
      // exactly like the full dataset, never resolved by client-supplied
      // text.
      'synthetic-fixture-5min-v1-research',
      'synthetic-fixture-5min-v1-holdout',
    ]),
    description: 'Deterministic, safe, in-process bracket engine for the constrained generic rule subset. No external process.',
  },
  {
    engineId: 'PAULO_TREND_FIBONACCI_V10',
    kind: 'EXTERNAL_PYTHON_SERVICE',
    supportedRuleIds: Object.freeze([
      'ENTRY.PULLBACK_IN_TREND',
      'STOP.FIXED_DISTANCE',
      'TARGET.FIXED_DISTANCE',
      'BREAK_EVEN.STEPPED',
      'SESSION.WINDOW',
      'EXIT.FORCED_TIME',
      'POSITION_SIZE.FIXED_CONTRACTS',
    ]),
    supportedDatasetIds: Object.freeze(['win1-5min-qt01c3']),
    description: 'Strategy #001/V10 -- the verified Python reference implementation (Macro-05), reached only through the bounded backtest bridge.',
  },
]);

const BY_ID: ReadonlyMap<EngineId, EngineRecord> = new Map(ENGINE_REGISTRY.map((e) => [e.engineId, e]));

export function getEngine(engineId: string): EngineRecord | undefined {
  return BY_ID.get(engineId as EngineId);
}

/** Refuses closed: unknown engine, unsupported rule, or unsupported
 * dataset for that engine all return a reason string instead of `null`. */
export function engineAcceptsRunRequest(
  engineId: string,
  ruleIds: readonly string[],
  datasetId: string,
): string | null {
  const engine = getEngine(engineId);
  if (!engine) return `unknown engineId: ${engineId}`;
  for (const r of ruleIds) {
    if (!engine.supportedRuleIds.includes(r)) return `engine ${engineId} does not support rule ${r}`;
  }
  if (!engine.supportedDatasetIds.includes(datasetId)) return `engine ${engineId} does not support dataset ${datasetId}`;
  return null;
}
