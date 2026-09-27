/**
 * Rule Catalog — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §18.
 *
 * A discoverability/metadata registry: for each rule a Strategy
 * Specification (strategy_spec.ts) can reference, what category it
 * belongs to, whether it is actually backed by an implementation yet
 * (backtestSupport/simulationSupport/liveExecutionEligible), and its risk
 * implications. This is deliberately NOT a dynamic parameter-schema/AST
 * engine -- the Strategy Specification itself uses strongly-typed fields
 * (entry/stop/target/breakEven/trailing/session/positionSize), because a
 * fully generic "any rule, any param shape" engine is speculative
 * complexity this macro has no concrete second use for yet (§13: "Do not
 * implement speculative complexity with no immediate use"). The catalog's
 * job is to answer, honestly, "what does this product actually support
 * today" for the Builder UI and for validation error messages -- never to
 * claim support a rule doesn't have (§18: "Do not claim support until
 * implementation exists").
 */

export type RuleCategory =
  | 'TREND'
  | 'ENTRY'
  | 'STRUCTURE'
  | 'INDICATOR'
  | 'STOP'
  | 'TARGET'
  | 'BREAK_EVEN'
  | 'TRAILING'
  | 'SESSION'
  | 'POSITION_SIZE'
  | 'RISK'
  | 'EXIT';

export interface RuleDefinition {
  readonly ruleId: string;
  readonly category: RuleCategory;
  /** Human-readable summary -- NOT a translation; UI layers own PT/EN copy. */
  readonly summary: string;
  /** Asset classes this rule has been validated against. 'ANY' means the
   * rule has no asset-class-specific assumption (e.g. fixed-distance stop
   * works the same for any instrument once tickSize is known). */
  readonly supportedAssetClasses: readonly string[] | 'ANY';
  readonly riskImplications: string;
  readonly backtestSupport: boolean;
  readonly simulationSupport: boolean;
  /** Always false today -- no live-execution eligibility exists yet for
   * ANY rule (hard boundary §56: no broker connection, no live order).
   * Kept as an explicit field, not an assumption, so a future rule that
   * genuinely earns eligibility does so visibly, one rule at a time. */
  readonly liveExecutionEligible: boolean;
}

export const RULE_CATALOG: readonly RuleDefinition[] = Object.freeze([
  {
    ruleId: 'ENTRY.PULLBACK_IN_TREND',
    category: 'ENTRY',
    summary: 'Enter on a pullback in the direction of the prevailing structural trend.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Entry timing risk only; does not itself size or bound loss.',
    // backtestSupport is true because Strategy #001/V10's own Python
    // engine executes it (Macro-05) -- the generic TS engine
    // (generic_rule_engine.ts, Macro-06) does NOT implement this rule;
    // see ENGINE_REGISTRY's supportedRuleIds for which engine a given
    // spec must run under.
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'ENTRY.SESSION_OPEN',
    category: 'ENTRY',
    summary: 'Enter once per session, in the single allowed direction, at the first bar of the session window.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'No signal condition at all -- entry timing risk is maximal; exists to prove the generic engine architecture (§11), not as a recommended rule.',
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'STOP.FIXED_DISTANCE',
    category: 'STOP',
    summary: 'Initial protective stop a fixed price distance from entry.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Directly bounds the per-trade structural loss before break-even/trailing activate.',
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'TARGET.FIXED_DISTANCE',
    category: 'TARGET',
    summary: 'Profit target a fixed price distance from entry.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Caps per-trade upside; interacts with break-even trigger distance.',
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'BREAK_EVEN.STEPPED',
    category: 'BREAK_EVEN',
    summary: 'After a trigger distance in favor, protection steps up in fixed increments and never retreats.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Reduces realized-loss tail risk on winning-then-reversing trades; never widens risk.',
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'TRAILING.FIXED_DISTANCE',
    category: 'TRAILING',
    summary: 'Stop trails price by a fixed distance once active.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Alternative to stepped break-even; the two must not both be enabled (see CONTRADICTORY_CONFIGURATION).',
    backtestSupport: false,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'SESSION.WINDOW',
    category: 'SESSION',
    summary: 'Entries only allowed within a daily local-time window on allowed weekdays.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Bounds exposure to a defined trading session; excludes non-modeled hours.',
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'EXIT.FORCED_TIME',
    category: 'EXIT',
    summary: 'All open positions force-closed at a fixed local time.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Eliminates overnight/after-session gap risk.',
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'POSITION_SIZE.FIXED_CONTRACTS',
    category: 'POSITION_SIZE',
    summary: 'A fixed, integer number of contracts per entry.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Direct multiplier on every other risk figure; no dynamic sizing yet.',
    backtestSupport: true,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'RISK.MAX_DAILY_LOSS',
    category: 'RISK',
    summary: 'Hard ceiling on realized loss for a single trading day.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Safety control (§36) -- declarable and validated today, not yet enforced by any backtest/execution engine.',
    backtestSupport: false,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
  {
    ruleId: 'RISK.MAX_STRATEGY_LOSS',
    category: 'RISK',
    summary: 'Hard ceiling on cumulative realized loss for the strategy across all time.',
    supportedAssetClasses: 'ANY',
    riskImplications: 'Safety control (§36) -- declarable and validated today, not yet enforced by any backtest/execution engine.',
    backtestSupport: false,
    simulationSupport: false,
    liveExecutionEligible: false,
  },
]);

const CATALOG_BY_ID: ReadonlyMap<string, RuleDefinition> = new Map(RULE_CATALOG.map((r) => [r.ruleId, r]));

export function getRule(ruleId: string): RuleDefinition | undefined {
  return CATALOG_BY_ID.get(ruleId);
}

export function isSupportedRule(ruleId: string): boolean {
  return CATALOG_BY_ID.has(ruleId);
}

export function rulesByCategory(category: RuleCategory): readonly RuleDefinition[] {
  return RULE_CATALOG.filter((r) => r.category === category);
}
